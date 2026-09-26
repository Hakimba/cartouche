// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class, NonEmptyListSerializer::class)

package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.launch.GameFile
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.Player
import app.cartouche.core.platforms.PlayerId
import arrow.core.Either
import arrow.core.NonEmptyList
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.separateEither
import arrow.core.serialization.NonEmptyListSerializer
import arrow.core.serialization.OptionSerializer
import arrow.core.toNonEmptyListOrNone
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers

@Serializable @JvmInline
public value class GameId(public val value: String)

/** A file of a scanned folder; [sizeBytes] is none when the provider does not report it. */
@Serializable
public data class ListedFile(
    public val name: FileName,
    public val uri: ContentUri,
    public val path: Option<FilePath>,
    public val sizeBytes: Option<Long>,
) {
    public val asGameFile: GameFile get() = GameFile(name, uri, path)
}

/** One disc of a game; [number] is none when the file names no disc. */
@Serializable
public data class Disc(public val number: Option<Int>, public val file: ListedFile)

/**
 * A game of the library. [redumpName] is the reference-list disc it is exactly, if any; its
 * regions, languages and version are what its file name states.
 */
@Serializable
public data class Game(
    public val id: GameId,
    public val platform: PlatformId,
    public val title: String,
    public val regions: List<String>,
    public val languages: List<String>,
    public val version: Option<String>,
    public val serials: List<String>,
    public val redumpName: Option<String>,
    public val discs: NonEmptyList<Disc>,
    /** The disc launched last, as an index into [discs]; launches start from it. */
    public val lastDisc: Int = 0,
) {
    /** Whether the reference list knows the game: as an exact disc, or by the serials of its release. */
    public val identified: Boolean get() = redumpName.isSome() || serials.isNotEmpty()
}

@Serializable
public enum class IgnoreReason {
    @SerialName("hidden")
    HIDDEN,

    @SerialName("unsupported")
    UNSUPPORTED,

    @SerialName("not_a_game")
    NOT_A_GAME,
}

/** Whether `Game (Disc 1)` and `Game (Disc 2)` make one game. */
@Serializable
public enum class DiscGrouping {
    @SerialName("grouped")
    GROUPED,

    @SerialName("separate")
    SEPARATE,
}

/** How deep a scan looks into a platform's folder. */
@Serializable
public enum class FolderDepth {
    @SerialName("top_level")
    TOP_LEVEL,

    @SerialName("subfolders")
    SUBFOLDERS,
}

@Serializable
public data class IgnoredFile(public val file: ListedFile, public val reason: IgnoreReason)

/** The user's choices for one platform. */
@Serializable
public data class PlatformSetup(
    public val folder: Option<ContentUri> = None,
    /** The player chosen for this platform; none uses the first installed one. */
    public val player: Option<PlayerId> = None,
    public val discs: DiscGrouping = DiscGrouping.GROUPED,
    public val depth: FolderDepth = FolderDepth.TOP_LEVEL,
) {
    /** The player that opens [file]: the chosen one when [available], else the first available one in definition order. */
    public fun playerFor(platform: Platform, file: FileName, available: (Player) -> Boolean): Option<Player> {
        val candidates = platform.players.filter { it.accepts.matches(file) && available(it) }
        return player.flatMap { id -> candidates.firstOrNone { it.id == id } }.fold({ candidates.firstOrNone() }, ::Some)
    }
}

/** What a scan found in a platform's folder: every file ends up either in one game's discs or ignored. */
public data class Scan(public val games: List<Game>, public val ignored: List<IgnoredFile>) {
    public companion object {
        /**
         * Sorts [files] into games and ignored files. A file is a game when a player of [platform]
         * accepts it, unless it looks like a BIOS, or is unknown to [titles] and smaller than any
         * game of the platform. With [DiscGrouping.GROUPED], `Game (Disc 1)` and `Game (Disc 2)` make one game.
         * Pure and total; the result does not depend on the order of [files].
         */
        public fun of(platform: Platform, files: List<ListedFile>, titles: TitleIndex, discs: DiscGrouping): Scan {
            val (ignored, kept) = files.sortedWith(FILE_ORDER).separateEither { classify(platform, titles, it) }
            val groups =
                when (discs) {
                    DiscGrouping.GROUPED -> kept.groupBy { it.name.copy(disc = None) }.values.flatMap(::asDiscs)
                    DiscGrouping.SEPARATE -> kept.map(::listOf)
                }
            return Scan(
                groups.map { it.sortedWith(DISC_ORDER).toNonEmptyListOrNone() }.filterOption().map { game(platform.id, it) },
                ignored,
            )
        }

        private data class Candidate(val file: ListedFile, val name: GameName, val known: Option<Identification>)

        private val FILE_ORDER = compareBy<ListedFile>({ it.name.value }, { it.uri.value })
        private val DISC_ORDER = compareBy<Candidate> { it.name.disc.getOrElse { 0 } }.thenBy { it.file.uri.value }

        /** One game when the files are distinct numbered discs; otherwise (copies, other formats) one game each. */
        private fun asDiscs(files: List<Candidate>): List<List<Candidate>> {
            val numbers = files.map { it.name.disc }
            return if (numbers.all { it.isSome() } && numbers.distinct().size == numbers.size) listOf(files) else files.map(::listOf)
        }

        private val BIOS = Regex("""(?i)(?<![a-z0-9])(bios|scph-?\d+)(?![a-z0-9])""")

        private fun classify(platform: Platform, titles: TitleIndex, file: ListedFile): Either<IgnoredFile, Candidate> = either {
            ensure(!file.name.isHidden) { IgnoredFile(file, IgnoreReason.HIDDEN) }
            val accepted = platform.accepts.matches(file.name) && platform.players.any { it.accepts.matches(file.name) }
            ensure(accepted) { IgnoredFile(file, IgnoreReason.UNSUPPORTED) }
            val name = GameName.parse(file.name.value.substringBeforeLast('.'))
            val known = titles.identify(name)
            val tooSmall = file.sizeBytes.isSome { it < platform.profile.minimumGameBytes }
            // A known game is kept whatever its name or size (a Redump title may mention a SCPH accessory).
            ensure(known.isSome() || !(tooSmall || BIOS.containsMatchIn(file.name.value))) { IgnoredFile(file, IgnoreReason.NOT_A_GAME) }
            Candidate(file, name, known)
        }

        /**
         * The game made of [discs]. Regions, languages and version are what its first file name
         * states; the title is the reference one when the game is identified.
         */
        private fun game(platform: PlatformId, discs: NonEmptyList<Candidate>): Game {
            val first = discs.head
            return Game(
                id = GameId("${platform.value}/${first.file.uri.value}"),
                platform = platform,
                title = first.known.fold({ first.name }) { it.title }.displayTitle,
                regions = first.name.regions,
                languages = first.name.languages,
                version = first.name.version,
                serials = discs.toList().flatMap { disc -> disc.known.fold({ emptyList() }) { it.serials } }.distinct(),
                redumpName = first.known.flatMap { known -> if (known is Identification.Disc) Some(known.disc.text) else None },
                discs = discs.map { Disc(it.name.disc, it.file) },
            )
        }
    }
}

/** The games of every platform, and the user's choices for each platform. */
@Serializable
public data class Library(
    public val setups: Map<PlatformId, PlatformSetup> = emptyMap(),
    public val games: List<Game> = emptyList(),
    public val ignored: Map<PlatformId, List<IgnoredFile>> = emptyMap(),
) {
    public fun setup(platform: PlatformId): PlatformSetup = setups.getOrElse(platform) { PlatformSetup() }

    public fun game(id: GameId): Option<Game> = games.firstOrNone { it.id == id }

    public fun withSetup(platform: PlatformId, setup: PlatformSetup): Library = copy(setups = setups + (platform to setup))

    /** Replaces [platform]'s games with [scan]'s, keeping what the user chose for games still there. */
    public fun withScan(platform: PlatformId, scan: Scan): Library {
        val previous = games.filter { it.platform == platform }.associateBy { it.id }
        val scanned =
            scan.games.map { game ->
                previous.getOrNone(game.id).fold({ game }) { game.copy(lastDisc = it.lastDisc.coerceIn(game.discs.indices)) }
            }
        return copy(games = games.filter { it.platform != platform } + scanned, ignored = ignored + (platform to scan.ignored))
    }

    /** Records [disc] (an index into the game's discs, kept within them) as the one launched last. */
    public fun withLastDisc(id: GameId, disc: Int): Library =
        copy(games = games.map { if (it.id == id) it.copy(lastDisc = disc.coerceIn(it.discs.indices)) else it })
}
