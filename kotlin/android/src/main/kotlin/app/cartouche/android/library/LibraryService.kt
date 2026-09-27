// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.trace
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.FolderPath
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.Library
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.library.StoredLibrary
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlin.time.TimeSource

internal sealed interface LibraryFailure {
    data class NoFolder(val platform: PlatformId) : LibraryFailure

    data class UnknownGame(val id: GameId) : LibraryFailure

    data class NoDisc(val game: GameId, val disc: Int) : LibraryFailure

    data class Storage(val failure: StorageFailure) : LibraryFailure

    data class TooManyEntries(val walk: WalkFailure.TooManyEntries) : LibraryFailure

    val message: String
        get() =
            when (this) {
                is NoFolder -> "No folder is set for ${platform.value}"
                is UnknownGame -> "No game ${id.value} in the library"
                is NoDisc -> "${game.value} has no disc $disc"
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

/**
 * The library and the selection, held in memory and in their files. Not thread-safe: the plugin
 * runs every call on one single-threaded dispatcher, in the order the calls arrive. A launch reads
 * its choice, starts the emulator on the main thread, then records its disc: other calls can run in
 * between.
 */
internal class LibraryService(private val store: LibraryStore, private val selections: SelectionStore, private val folders: Folders) {
    private var loaded: Option<Library> = None

    private var selected: Option<Selection> = None

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

    /** The selection, read from its file on first use; an unreadable one only means starting from the first game. */
    fun selection(): Selection = selected.getOrElse {
        selections
            .load()
            .getOrElse { problem ->
                trace("selection") { "not read, starting from the first game: ${problem.detail}" }
                Selection()
            }.also { selected = Some(it) }
    }

    /** The shelves of [platforms] (in the catalog's order), where the selection left the user. */
    fun shelves(platforms: List<PlatformId>): Option<Shelves> = Shelves.of(library(), platforms, selection())

    /** Remembers game [id] as selected, and its platform as shown; the file is written only when that changes. */
    fun select(id: GameId): Either<LibraryFailure, Selection> = either {
        val game = library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id)) }
        val selection = selection().with(game)
        if (selection != selection()) {
            val started = TimeSource.Monotonic.markNow()
            selections.save(selection).mapLeft(LibraryFailure::Storage).bind()
            selected = Some(selection)
            trace("selection") { "saved ${id.value} in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
        selection
    }

    fun setUp(platform: PlatformId, setup: PlatformSetup): Either<LibraryFailure, Library> = save(library().withSetup(platform, setup))

    /** Lists [platform]'s folder and replaces its games with what the scan finds. */
    fun scan(platform: Platform, titles: TitleIndex, dataFolders: DataFolders): Either<LibraryFailure, Pair<Library, ScanReport>> = either {
        val setup = library().setup(platform.id)
        val folder = setup.folder.getOrElse { raise(LibraryFailure.NoFolder(platform.id)) }
        val started = TimeSource.Monotonic.markNow()
        val contents =
            folders
                .files(folder, setup.depth, dataFolders)
                .mapLeft { failure ->
                    when (failure) {
                        is WalkFailure.Unlisted -> LibraryFailure.Storage(failure.error)
                        is WalkFailure.TooManyEntries -> LibraryFailure.TooManyEntries(failure)
                    }
                }.bind()
        val listed = started.elapsedNow().inWholeMilliseconds
        val scan = Scan.of(platform, contents, titles, setup.discs)
        val report =
            ScanReport(
                files = contents.files.size,
                games = scan.games.size,
                identified = scan.games.count { it.identified },
                ignored = scan.ignored.size,
                skippedFolders = scan.skippedFolders.size,
                milliseconds = started.elapsedNow().inWholeMilliseconds,
            )
        trace("scan") { "${platform.id.value}: $report, of which listing $listed ms" }
        // A folder may hold thousands of files that are not games: the log shows how many, and the first ones.
        scan.ignored.groupBy { it.reason }.forEach { (reason, files) ->
            trace(
                "scan",
            ) { "ignored $reason: ${files.size}, such as ${files.take(IgnoredCount.EXAMPLES).joinToString { it.file.name.value }}" }
        }
        scan.skippedFolders.forEach { trace("scan") { "skipped folder ${it.path.value}: ${it.reason}" } }
        save(library().withScan(platform.id, scan)).bind() to report
    }

    /** What launching game [id] takes: [disc] (an index) if given, else the disc launched last, and its platform's choices. */
    fun launchChoice(id: GameId, disc: Option<Int>): Either<LibraryFailure, LaunchChoice> = either {
        val game = library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id)) }
        val index = disc.getOrElse { game.lastDisc }
        ensure(index in game.discs.indices) { LibraryFailure.NoDisc(id, index) }
        LaunchChoice(game, index, game.discs[index].file, library().setup(game.platform))
    }

    fun recordLaunch(id: GameId, disc: Int): Either<LibraryFailure, Library> = save(library().withLastDisc(id, disc))

    private fun save(library: Library): Either<LibraryFailure, Library> = either {
        ensure(writable) { LibraryFailure.Storage(StorageFailure.Unavailable("the unreadable library file could not be set aside")) }
        val started = TimeSource.Monotonic.markNow()
        store.save(library).mapLeft(LibraryFailure::Storage).bind()
        trace("library") { "saved ${library.games.size} games in ${started.elapsedNow().inWholeMilliseconds} ms" }
        library.also { loaded = Some(it) }
    }
}
