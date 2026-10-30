// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class, NonEmptyListSerializer::class)

package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.Shell
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
import arrow.core.toOption
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers

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

/** Why a file that is not a game is only counted, as a folder may hold thousands of them. */
@Serializable
public enum class CountedReason {
    @SerialName("hidden")
    HIDDEN,

    @SerialName("unsupported")
    UNSUPPORTED,
}

/** How many files a scan set aside for one reason, with the first of their names. */
@Serializable
public data class IgnoredCount(public val count: Int, public val examples: List<FileName>) {
    public companion object {
        public const val EXAMPLES: Int = 20

        public fun of(files: List<ListedFile>): IgnoredCount = IgnoredCount(files.size, files.take(EXAMPLES).map { it.name })
    }
}

/** The user's choices for one platform. */
@Serializable
public data class PlatformSetup(
    public val folder: Option<ContentUri> = None,
    /** The player chosen for this platform; none uses the first installed one. */
    public val player: Option<PlayerId> = None,
    public val discs: DiscGrouping = DiscGrouping.GROUPED,
    public val depth: FolderDepth = FolderDepth.TOP_LEVEL,
) {
    /**
     * The player that opens [file]: the chosen one when [available], else the first available one in definition
     * order.
     */
    public fun playerFor(platform: Platform, file: FileName, available: (Player) -> Boolean): Option<Player> {
        val candidates = platform.players.filter { it.accepts.matches(file) && available(it) }
        return player.flatMap { id -> candidates.firstOrNone { it.id == id } }.fold({ candidates.firstOrNone() }, ::Some)
    }
}

/**
 * What a scan found in a platform's folder: every file ends up either in one game's discs or ignored, and the
 * sub-folders it did not look into are in [skippedFolders].
 */
public data class Scan(
    public val games: List<Game>,
    public val ignored: List<IgnoredFile>,
    public val skippedFolders: List<SkippedFolder>,
) {
    public companion object {
        /**
         * Sorts the files of [folder] into games and ignored files, and keeps its skipped sub-folders.
         * A file is a game when a player of [platform] accepts it, unless it looks like a BIOS, or is
         * unknown to [titles] and smaller than any game of the platform. With [DiscGrouping.GROUPED],
         * `Game (Disc 1)` and `Game (Disc 2)` make one game. A game is identified by what its first
         * file holds ([facts], by the file's URI) when that names a game, each disc then giving its
         * own serials by what it holds; otherwise by its files' names. Pure and total; the result
         * does not depend on the order of the files.
         */
        public fun of(
            platform: Platform,
            folder: FolderContents,
            titles: TitleIndex,
            discs: DiscGrouping,
            facts: Map<ContentUri, FileFacts> = emptyMap(),
        ): Scan {
            val (ignored, kept) = folder.files.sortedWith(FILE_ORDER).separateEither { classify(platform, titles, facts, it) }
            val groups =
                when (discs) {
                    DiscGrouping.GROUPED -> kept.groupBy { it.name.copy(disc = None) }.values.flatMap(::asDiscs)
                    DiscGrouping.SEPARATE -> kept.map(::listOf)
                }
            return Scan(
                groups.map { it.sortedWith(DISC_ORDER).toNonEmptyListOrNone() }.filterOption().map { game(platform.id, it) },
                ignored,
                folder.skipped.sortedWith(compareBy({ it.path.value }, { it.reason })),
            )
        }

        private data class Candidate(
            val file: ListedFile,
            val name: GameName,
            val byContent: Option<Identification>,
            val byName: Option<Identification>,
            val shell: Shell,
        )

        private val FILE_ORDER = compareBy<ListedFile>({ it.name.value }, { it.uri.value })
        private val DISC_ORDER = compareBy<Candidate> { it.name.disc.getOrElse { 0 } }.thenBy { it.file.uri.value }

        /** One game when the files are distinct numbered discs; otherwise (copies, other formats) one game each. */
        private fun asDiscs(files: List<Candidate>): List<List<Candidate>> {
            val numbers = files.map { it.name.disc }
            return if (numbers.all { it.isSome() } && numbers.distinct().size == numbers.size) listOf(files) else files.map(::listOf)
        }

        private val BIOS = Regex("""(?i)(?<![a-z0-9])(bios|scph-?\d+)(?![a-z0-9])""")

        private fun classify(
            platform: Platform,
            titles: TitleIndex,
            facts: Map<ContentUri, FileFacts>,
            file: ListedFile,
        ): Either<IgnoredFile, Candidate> = either {
            ensure(!file.name.isHidden) { IgnoredFile(file, IgnoreReason.HIDDEN) }
            val accepted = platform.accepts.matches(file.name) && platform.players.any { it.accepts.matches(file.name) }
            ensure(accepted) { IgnoredFile(file, IgnoreReason.UNSUPPORTED) }
            val stem = file.name.value.substringBeforeLast('.')
            val name = GameName.parse(stem)
            val byContent = facts.getOrNone(file.uri).flatMap { titles.identifyByContent(it, name) }
            val byName = titles.identifyByName(stem)
            val known = byContent.isSome() || byName.isSome()
            val tooSmall = file.sizeBytes.isSome { it < platform.profile.minimumGameBytes }
            // A known game is kept whatever its name or size (a Redump title may mention a SCPH accessory).
            ensure(known || !(tooSmall || BIOS.containsMatchIn(file.name.value))) { IgnoredFile(file, IgnoreReason.NOT_A_GAME) }
            val shell = (facts[file.uri] as? FileFacts.Print).toOption().fold({ Shell.UNKNOWN }, FileFacts.Print::shell)
            Candidate(file, name, byContent, byName, shell)
        }

        /**
         * The game made of [discs], identified by their content when the first one's names a game (a disc 2 that
         * tells nothing then gives no serial), else by their names. The title is the reference one when the game is
         * identified.
         */
        private fun game(platform: PlatformId, discs: NonEmptyList<Candidate>): Game {
            val first = discs.head
            val known = discs.map(if (first.byContent.isSome()) Candidate::byContent else Candidate::byName)
            val exact = known.head.flatMap { if (it is Identification.Disc) Some(it.disc) else None }
            val named = exact.fold({ first.name }, KnownTitle::name)
            return Game(
                id = GameId("${platform.value}/${first.file.uri.value}"),
                platform = platform,
                title = known.head.fold({ first.name }, Identification::title).displayTitle,
                regions = known.head.fold({ first.name.regions }, Identification::regions),
                languages = named.languages,
                version = named.version,
                serials = known.toList().flatMap { disc -> disc.fold({ emptyList() }, Identification::serials) }.distinct(),
                redumpName = exact.map(KnownTitle::text),
                discs = discs.map { Disc(it.name.disc, it.file) },
                shell = first.shell,
            )
        }
    }
}
