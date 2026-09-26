// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.trace
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.withError
import kotlin.time.TimeSource

internal sealed interface LibraryFailure {
    data class NoFolder(val platform: PlatformId) : LibraryFailure

    data class UnknownGame(val id: GameId) : LibraryFailure

    data class NoDisc(val game: GameId, val disc: Int) : LibraryFailure

    data class Storage(val failure: StorageFailure) : LibraryFailure

    val message: String
        get() =
            when (this) {
                is NoFolder -> "No folder is set for ${platform.value}"
                is UnknownGame -> "No game ${id.value} in the library"
                is NoDisc -> "${game.value} has no disc $disc"
                is Storage -> failure.message
            }
}

internal data class LaunchChoice(val game: Game, val disc: Int, val file: ListedFile, val setup: PlatformSetup)

/** How a scan went, for the log and the screen. */
internal data class ScanReport(val files: Int, val games: Int, val identified: Int, val ignored: Int, val milliseconds: Long)

/**
 * The library held in memory and its file. Not thread-safe: the plugin runs every call on one
 * single-threaded dispatcher, in the order the calls arrive. A launch reads its choice, starts the
 * emulator on the main thread, then records its disc: other calls can run in between.
 */
internal class LibraryService(private val store: LibraryStore, private val folders: Folders) {
    private var loaded: Option<Library> = None

    /** Why the stored library could not be read, if it could not; the library then started empty. */
    var loadProblem: Option<String> = None
        private set

    /** Saving is refused when an unreadable library file could not be set aside: it would be lost. */
    private var writable = true

    /** The library, read from its file on first use. */
    fun library(): Library = loaded.getOrElse {
        store
            .load()
            .getOrElse { problem ->
                val setAside = store.setAside()
                trace("library") { "${problem.message}; set aside: $setAside" }
                loadProblem = Some(problem.message + if (setAside) "" else "; it could not be set aside, so nothing is saved")
                writable = setAside
                Library()
            }.also { loaded = Some(it) }
    }

    fun setUp(platform: PlatformId, setup: PlatformSetup): Either<LibraryFailure, Library> = save(library().withSetup(platform, setup))

    /** Lists [platform]'s folder and replaces its games with what the scan finds. */
    fun scan(platform: Platform, titles: TitleIndex): Either<LibraryFailure, Pair<Library, ScanReport>> = either {
        val setup = library().setup(platform.id)
        val folder = setup.folder.getOrElse { raise(LibraryFailure.NoFolder(platform.id)) }
        val started = TimeSource.Monotonic.markNow()
        val files = withError(LibraryFailure::Storage) { folders.files(folder, setup.depth).bind() }
        val scan = Scan.of(platform, files, titles, setup.discs)
        val identified = scan.games.count { it.identified }
        val report = ScanReport(files.size, scan.games.size, identified, scan.ignored.size, started.elapsedNow().inWholeMilliseconds)
        trace("scan") { "${platform.id.value}: $report" }
        scan.ignored.forEach { trace("scan") { "ignored ${it.file.name.value}: ${it.reason}" } }
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
        store.save(library).mapLeft(LibraryFailure::Storage).bind()
        library.also { loaded = Some(it) }
    }
}
