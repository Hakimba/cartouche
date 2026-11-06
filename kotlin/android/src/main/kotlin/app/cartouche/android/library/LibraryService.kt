// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

import app.cartouche.android.Threads
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.FileStamp
import app.cartouche.android.storage.FolderListing
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.KnownFacts
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.StateFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.trace
import app.cartouche.core.ContentUri
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.FileReading
import app.cartouche.core.library.Arrivals
import app.cartouche.core.library.ArrivalsFormat
import app.cartouche.core.library.Coming
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderPath
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.Library
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.PlacementError
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.library.StoredLibrary
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.VariantError
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.search.Finders
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.SelectionFormat
import app.cartouche.core.shelves.Shelves
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.recover
import arrow.core.right
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import java.io.File
import kotlin.time.TimeSource

internal sealed interface LibraryFailure {
    data class NoFolder(val platform: PlatformId) : LibraryFailure

    data class UnknownGame(val id: GameId) : LibraryFailure

    data class NoDisc(val game: GameId, val disc: Int) : LibraryFailure

    data class UnknownPlatform(val platform: PlatformId) : LibraryFailure

    data class Placement(val error: PlacementError) : LibraryFailure

    data class Variant(val error: VariantError) : LibraryFailure

    data class Storage(val failure: StorageFailure) : LibraryFailure

    data class TooManyEntries(val walk: WalkFailure.TooManyEntries) : LibraryFailure

    val message: String
        get() =
            when (this) {
                is NoFolder -> "No folder is set for ${platform.value}"
                is UnknownGame -> "No game ${id.value} in the library"
                is NoDisc -> "${game.value} has no disc $disc"
                is UnknownPlatform -> "No console ${platform.value} in the library"
                is Placement ->
                    when (error) {
                        is PlacementError.NotInLibrary -> "No console ${error.platform.value} in the library to place"
                        is PlacementError.GapOutOfRange -> "No gap ${error.gap} among ${error.consoles} other consoles"
                    }
                is Variant ->
                    when (error) {
                        is VariantError.Unknown -> "Unknown variant ${error.id} of ${error.platform.value}"
                        is VariantError.NotInLibrary -> "No console ${error.platform.value} in the library"
                        is VariantError.Coming -> "${error.id} of ${error.platform.value} is not fully supported yet"
                    }
                is Storage -> failure.message
                is TooManyEntries -> {
                    fun name(folder: Option<FolderPath>) = folder.fold({ "the folder itself" }) { it.value }
                    "More than ${walk.limit} files and folders, ${walk.entries} of them in ${name(walk.largest)}; the scan stopped in " +
                        "${name(walk.stoppedIn)}. Pick the folder of the games."
                }
            }
}

internal data class LaunchChoice(val game: Game, val disc: Int, val file: ListedFile, val setup: PlatformSetup)

/** How a scan went, for the log and the screen. */
internal data class ScanReport(
    val files: Int,
    val games: Int,
    val identified: Int,
    val ignored: Int,
    val skippedFolders: Int,
    val milliseconds: Long,
)

/** What a re-read the user did not ask for left: the library when it changed, and the games not seen yet. */
internal data class Reread(val library: Option<Library>, val arrivals: Arrivals)

/**
 * Not thread-safe but for [finders]: the plugin runs every call on one single-threaded dispatcher. A launch reads its choice, starts the
 * emulator on the main thread, then records its disc: other calls can run in between.
 */
internal class LibraryService(
    private val store: LibraryStore,
    selectionFile: File,
    arrivalsFile: File,
    private val folders: Folders,
    private val facts: FactsStore,
    /** Where a scan reads its game files, [Threads.FILE_READS] at a time ([Threads.fileReads]). */
    private val fileReads: CoroutineDispatcher,
    /** Given new [finders] to make, as soon as possible but not on the caller's thread. */
    private val prepare: (Finders) -> Unit = {},
) {
    private var loaded: Option<Library> = None
        set(kept) {
            field = kept
            val next = kept.fold({ Finders.NONE }, finders::after)
            if (next !== finders) prepare(next)
            finders = next
        }

    /** The finders of the library last kept: read from Godot's thread, as the getters answer at once. */
    @Volatile
    var finders: Finders = Finders.NONE
        private set

    /** An unreadable selection only means starting from the first game. */
    private val selections =
        StateFile(selectionFile, Selection(), SelectionFormat::decode, SelectionFormat::encode) { problem ->
            trace("selection") { "not read, starting from the first game: ${problem.detail}" }
        }

    /** Unreadable arrivals only mean none. */
    private val marks =
        StateFile(arrivalsFile, Arrivals(), ArrivalsFormat::decode, ArrivalsFormat::encode) { problem ->
            trace("arrivals") { "not read, no game marked: ${problem.detail}" }
        }

    /** One more at each write of the library: an answer telling it shows whether a library sent before is the latest. */
    var revision: Int = 0
        private set

    /** Why the stored library could not be read, if it could not; the library then started empty. */
    var loadProblem: Option<String> = None
        private set

    /** Saving is refused when an unreadable library file could not be set aside: it would be lost. */
    private var writable = true

    /** The library, read from its file on first use; a file of an earlier format is saved again, upgraded. */
    fun library(): Library = loaded.getOrElse {
        val started = TimeSource.Monotonic.markNow()
        store
            .load()
            .onRight { stored ->
                trace("library") { "loaded ${stored.library.games.size} games in ${started.elapsedNow().inWholeMilliseconds} ms" }
                if (stored.isOutdated) save(stored.library).onLeft { trace("library") { "upgraded library not saved: ${it.message}" } }
            }.map(StoredLibrary::library)
            .getOrElse { problem ->
                val setAside = store.setAside()
                trace("library") { "${problem.message}; set aside: $setAside" }
                loadProblem = Some(problem.message + if (setAside) "" else "; it could not be set aside, so nothing is saved")
                writable = setAside
                Library()
            }.also { loaded = Some(it) }
    }

    /** The selection, read from its file on first use. */
    fun selection(): Selection = selections.get()

    /** The games not seen yet, of the library only, read from their file on first use. */
    fun arrivals(): Arrivals = marks.get().within(library())

    /** The user entered [platform]'s console: it announces no new game any more. */
    fun enter(platform: PlatformId): Either<LibraryFailure, Arrivals> = mark(arrivals().entered(platform))

    /** The user left game [id] on its shelf: it is not new any more. */
    fun leave(id: GameId): Either<LibraryFailure, Arrivals> = mark(arrivals().left(id))

    private fun mark(arrivals: Arrivals): Either<LibraryFailure, Arrivals> = either {
        if (arrivals != marks.get()) {
            marks.set(arrivals).mapLeft(LibraryFailure::Storage).bind()
            trace("arrivals") { "${arrivals.unseen.size} games new, announced on ${arrivals.announced.keys.map { it.value }}" }
        }
        arrivals
    }

    /** Keeps [arrivals] along with a library already saved: marks not stored then are only traced, the library stands. */
    private fun keepMarks(arrivals: Arrivals): Arrivals = mark(arrivals).getOrElse { failure ->
        trace("arrivals") { "not saved: ${failure.message}" }
        arrivals
    }

    /** The shelves of [platforms] (in the catalog's order), where the selection left the user. */
    fun shelves(platforms: List<PlatformId>): Option<Shelves> = Shelves.of(library(), platforms, selection())

    /** Remembers game [id] as selected, and its platform as shown; the file is written only when that changes. */
    fun select(id: GameId): Either<LibraryFailure, Selection> = either {
        val game = library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id)) }
        remember(selection().with(game)).bind()
    }

    /**
     * Stores [setup] for [platform], unless it is a [coming] console not yet in the library ([Library.setUp]); the access to a
     * folder no platform uses any more is given up.
     */
    fun setUp(
        platform: PlatformId,
        setup: PlatformSetup,
        variant: Option<String> = None,
        coming: Coming = Coming.NONE,
    ): Either<LibraryFailure, Library> = either {
        val chosen = library().setUp(platform, setup, variant, coming).mapLeft(LibraryFailure::Variant).bind()
        save(chosen).bind().also(::keepFoldersOf)
    }

    /**
     * Removes [platform]: its choices, games and what its scans set aside, what the selection remembers of it, and
     * the access to its folder unless another platform uses it. The files in the folder are not touched.
     */
    fun remove(platform: PlatformId): Either<LibraryFailure, Library> = either {
        // The selection first: one left remembering a platform that stayed only starts it from its first game.
        remember(selection().without(platform)).bind()
        save(library().without(platform)).bind().also(::keepFoldersOf).also {
            facts.forget(platform)
            // Else they would come back with its games, the same folder added again.
            keepMarks(marks.get().within(it))
        }
    }

    /**
     * The games whose art is kept: those of the library; none when it could not be read, as its games are not known
     * then.
     */
    fun gamesWithArt(): Option<Set<GameId>> {
        // Read first: whether it could be is known once it is.
        val games = library().games
        return if (loadProblem.isSome()) None else Some(games.mapTo(HashSet()) { it.id })
    }

    private fun remember(selection: Selection): Either<LibraryFailure, Selection> = either {
        if (selection != selection()) {
            val started = TimeSource.Monotonic.markNow()
            selections.set(selection).mapLeft(LibraryFailure::Storage).bind()
            trace("selection") { "saved in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
        selection
    }

    /** Not while the library could not be read: the folders of the one set aside are not known. */
    private fun keepFoldersOf(library: Library) {
        if (loadProblem.isSome()) return
        folders
            .keepOnly(library.setups.values.flatMapTo(HashSet()) { it.folder.toList() })
            .onRight { released -> if (released > 0) trace("library") { "access to $released folders given up" } }
            .onLeft { trace("library") { "folder access not given up: ${it.message}" } }
    }

    /**
     * Lists [platform]'s folder, reads its game files new or changed since the last scan (see [factsOf]) and replaces
     * its games with what the scan finds.
     */
    fun scan(platform: Platform, titles: TitleIndex, dataFolders: DataFolders): Either<LibraryFailure, Pair<Library, ScanReport>> = either {
        val (scan, report) = found(platform, library().setup(platform.id), titles, dataFolders) { factsOf(platform.id, it) }.bind()
        // The marks of games gone go with them: back in their folder, they are no new games.
        save(library().withScan(platform.id, scan)).bind().also { keepMarks(marks.get().within(it)) } to report
    }

    /**
     * Scans [platform] as [scan] does, the user not asking for it: the games it brings are marked as new
     * ([Arrivals.after]). The library is written only when the scan changed it, as a re-read usually finds what was
     * there, and answered only when its games changed. The marks are another file, written after the library: a kill
     * in between leaves those games unmarked.
     */
    fun reread(platform: Platform, titles: TitleIndex, dataFolders: DataFolders): Either<LibraryFailure, Reread> = either {
        val started = TimeSource.Monotonic.markNow()
        val before = library()
        val (scan, report) = found(platform, before.setup(platform.id), titles, dataFolders) { factsOf(platform.id, it) }.bind()
        val after = before.withScan(platform.id, scan)
        val kept = if (after.scansAlike(platform.id, before)) before else save(after).bind()
        val shown = if (after.gamesAlike(platform.id, before)) None else Some(kept)
        val arrivals = keepMarks(arrivals().after(platform.id, before, after))
        trace("refresh") {
            val written =
                if (kept === before) {
                    "unchanged"
                } else if (shown.isSome()) {
                    "written"
                } else {
                    "written, its games the same"
                }
            "${platform.id.value}: read again in ${started.elapsedNow().inWholeMilliseconds} ms (scan ${report.milliseconds} ms), " +
                "library $written, ${arrivals.unseen.size} games new"
        }
        Reread(shown, arrivals)
    }

    /**
     * How many games a scan of [platform] with [setup] would find, its files identified by what they told at the last
     * scan: no file is read, nothing is saved.
     */
    fun preview(
        platform: Platform,
        setup: PlatformSetup,
        titles: TitleIndex,
        dataFolders: DataFolders,
    ): Either<LibraryFailure, ScanReport> =
        found(platform, setup, titles, dataFolders) { facts.load(platform.id).mapValues { it.value.facts } }.map { it.second }

    private fun found(
        platform: Platform,
        setup: PlatformSetup,
        titles: TitleIndex,
        dataFolders: DataFolders,
        told: (FolderListing) -> Map<ContentUri, FileFacts>,
    ): Either<LibraryFailure, Pair<Scan, ScanReport>> = either {
        val folder = setup.folder.getOrElse { raise(LibraryFailure.NoFolder(platform.id)) }
        val started = TimeSource.Monotonic.markNow()
        val listing =
            folders
                .files(folder, setup.depth, dataFolders)
                .mapLeft { failure ->
                    when (failure) {
                        is WalkFailure.Unlisted -> LibraryFailure.Storage(failure.error)
                        is WalkFailure.TooManyEntries -> LibraryFailure.TooManyEntries(failure)
                    }
                }.bind()
        val listed = started.elapsedNow().inWholeMilliseconds
        val contents = listing.contents
        val known = told(listing)
        val read = started.elapsedNow().inWholeMilliseconds - listed
        val scan = Scan.of(platform, contents, titles, setup.discs, known)
        val report =
            ScanReport(
                files = contents.files.size,
                games = scan.games.size,
                identified = scan.games.count { it.identified },
                ignored = scan.ignored.size,
                skippedFolders = scan.skippedFolders.size,
                milliseconds = started.elapsedNow().inWholeMilliseconds,
            )
        trace("scan") { "${platform.id.value}: $report, of which listing $listed ms, facts of ${known.size} files $read ms" }
        // A folder may hold thousands of files that are not games: the log shows how many, and the first ones.
        scan.ignored.groupBy { it.reason }.forEach { (reason, files) ->
            trace("scan") {
                "ignored $reason: ${files.size}, such as ${files.take(IgnoredCount.EXAMPLES).joinToString { it.file.name.value }}"
            }
        }
        scan.skippedFolders.forEach { trace("scan") { "skipped folder ${it.path.value}: ${it.reason}" } }
        scan to report
    }

    /** A file that cannot be opened or read tells nothing, and is read again at the next scan. */
    private fun factsOf(platform: PlatformId, listing: FolderListing): Map<ContentUri, FileFacts> {
        val kept = facts.load(platform)
        val stamps =
            listing.contents.files
                .filter { !it.name.isHidden && FileReading.reads(platform, it.name) }
                .associateWith { FileStamp(it.sizeBytes, listing.modified.getOrNone(it.uri)) }
        val unchanged = stamps.mapValues { (file, stamp) -> kept.getOrNone(file.uri).filter { it.stamp == stamp }.map { it.facts } }
        val read = readAll(platform, unchanged.filterValues { it.isNone() }.keys.toList())
        val known =
            stamps.entries
                .flatMap { (file, stamp) ->
                    val told = unchanged.getValue(file).recover { read.getValue(file).bind() }
                    told.map { file.uri to KnownFacts(stamp, it) }.toList()
                }.toMap()
        if (known != kept) facts.save(platform, known).onLeft { trace("files") { "what the files told not kept: ${it.message}" } }
        return known.mapValues { it.value.facts }
    }

    /**
     * [files] read [Threads.FILE_READS] at a time. A library call runs on the library's own thread, which waits for
     * them: every call of this class is blocking, as its callers expect.
     */
    private fun readAll(platform: PlatformId, files: List<ListedFile>): Map<ListedFile, Option<FileFacts>> {
        if (files.isEmpty()) return emptyMap()
        val before = folders.bytesRead.get()
        val started = TimeSource.Monotonic.markNow()
        val read = runBlocking(fileReads) { files.map { file -> async { file to read(platform, file) } }.awaitAll() }.toMap()
        trace("files") {
            "${files.size} files read, up to ${Threads.FILE_READS} at a time: ${(folders.bytesRead.get() - before) / 1024} kB in " +
                "${started.elapsedNow().inWholeMilliseconds} ms"
        }
        return read
    }

    private fun read(platform: PlatformId, file: ListedFile): Option<FileFacts> =
        folders.facts(platform, file).onLeft { trace("files") { "${file.name.value} not read: ${it.message}" } }.getOrNone()

    /** Forgets what the game files told: every one is read again at its platform's next scan. */
    fun forgetFacts(): Either<StorageFailure, Unit> = facts.forget()

    /**
     * What launching game [id] takes: [disc] (an index) if given, else the disc launched last, and its platform's
     * choices.
     */
    fun launchChoice(id: GameId, disc: Option<Int>): Either<LibraryFailure, LaunchChoice> = either {
        val game = library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id)) }
        val index = disc.getOrElse { game.lastDisc }
        ensure(index in game.discs.indices) { LibraryFailure.NoDisc(id, index) }
        LaunchChoice(game, index, game.discs[index].file, library().setup(game.platform))
    }

    /** Records [disc] as the one game [id] starts from next; nothing is written when it already does. */
    fun recordLaunch(id: GameId, disc: Int): Either<LibraryFailure, Library> =
        library().withLastDisc(id, disc).let { if (it == library()) it.right() else save(it) }

    /** Records which image game [id]'s label shows. */
    fun chooseLabel(id: GameId, label: LabelChoice): Either<LibraryFailure, Library> = either {
        ensure(library().game(id).isSome()) { LibraryFailure.UnknownGame(id) }
        save(library().withLabel(id, label)).bind()
    }

    /** Shows game [id] as [name] from now on, or as its title again when none; answers the game renamed. */
    fun rename(id: GameId, name: Option<DisplayName>): Either<LibraryFailure, Game> = either {
        ensure(library().game(id).isSome()) { LibraryFailure.UnknownGame(id) }
        save(library().withDisplayName(id, name)).bind().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id)) }
    }

    /** Shows the consoles in [order] from now on (see [Library.withConsoleOrder]); every one must be in the library. */
    fun orderConsoles(order: List<PlatformId>): Either<LibraryFailure, Library> = either {
        order.forEach { ensure(it in library().setups) { LibraryFailure.UnknownPlatform(it) } }
        save(library().withConsoleOrder(order)).bind()
    }

    /**
     * Puts [platform]'s console at [gap] among the others shown ([Library.withConsoleAt]), [platforms] being the
     * catalog's, and keeps the order.
     */
    fun placeConsole(platform: PlatformId, gap: Int, platforms: List<PlatformId>): Either<LibraryFailure, Library> = either {
        save(library().withConsoleAt(platform, gap, platforms).mapLeft(LibraryFailure::Placement).bind()).bind()
    }

    private fun save(library: Library): Either<LibraryFailure, Library> = either {
        ensure(writable) { LibraryFailure.Storage(StorageFailure.Unavailable("the unreadable library file could not be set aside")) }
        val started = TimeSource.Monotonic.markNow()
        store.save(library).mapLeft(LibraryFailure::Storage).bind()
        revision += 1
        trace("library") { "saved ${library.games.size} games in ${started.elapsedNow().inWholeMilliseconds} ms" }
        library.also { loaded = Some(it) }
    }
}
