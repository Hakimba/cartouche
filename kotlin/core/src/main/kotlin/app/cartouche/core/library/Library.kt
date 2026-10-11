// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class, NonEmptyListSerializer::class)

package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.ParsedSerializer
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
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.builtins.serializer

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

/** A region an image of a game was printed for, as the art sources name it (`Japan`); empty when they name none. */
@Serializable @JvmInline
public value class LabelRegion(public val name: String)

/**
 * A name the user gave a game, shown in place of its title: one line, its spaces single, trimmed,
 * never blank, at most [LONGEST] characters. Only what is shown changes: identification and art keep
 * looking for its title, and the shelves keep it in its title's place.
 */
@Serializable(with = DisplayNameSerializer::class)
@JvmInline
public value class DisplayName private constructor(public val text: String) {
    public companion object {
        public const val LONGEST: Int = 80

        // Every kind of space, line break and invisible control: a name is one line.
        private val SPACES = Regex("[\\s\\p{Z}\\p{Cc}]+")

        /** [text] as a game's name, as its type says; none when it is blank, the game showing its title again. */
        public fun of(text: String): Option<DisplayName> {
            val single = text.replace(SPACES, " ").trim()
            // Characters, not UTF-16 units: a name is never cut inside one.
            val end = single.offsetByCodePoints(0, minOf(LONGEST, single.codePointCount(0, single.length)))
            val cut = single.substring(0, end).trimEnd()
            return if (cut.isEmpty()) None else Some(DisplayName(cut))
        }
    }
}

/** Stored names are checked when read back, like any other: decoding fails on anything [DisplayName.of] would not give. */
private object DisplayNameSerializer : KSerializer<DisplayName> by ParsedSerializer(
    "display name",
    String.serializer(),
    { text -> DisplayName.of(text).filter { it.text == text } },
    DisplayName::text,
)

/** Which image a game's label shows. */
@Serializable
public sealed interface LabelChoice {
    /** The image of the region closest to the game's own, as its art is looked for. */
    @Serializable
    @SerialName("automatic")
    public data object Automatic : LabelChoice

    /** The image the art sources have for [region], chosen by the user. */
    @Serializable
    @SerialName("region")
    public data class Region(public val region: LabelRegion) : LabelChoice

    /** A picture of the user's own, framed by them (`app.cartouche.core.art.LabelFraming`); the app keeps the framed copy. */
    @Serializable
    @SerialName("own")
    public data object Own : LabelChoice
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
    /** Left out of the stored library while automatic, as most games' are. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val label: LabelChoice = LabelChoice.Automatic,
    /** The name the user gave it, if any; left out of the stored library otherwise. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val displayName: Option<DisplayName> = None,
) {
    /** Whether the reference list knows the game: as an exact disc, or by the serials of its release. */
    public val identified: Boolean get() = redumpName.isSome() || serials.isNotEmpty()

    /** What the game is called on screen: the name the user gave it, else its title. */
    public val shownTitle: String get() = displayName.fold({ title }) { it.text }
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
    /** The player that opens [file]: the chosen one when [available], else the first available one in definition order. */
    public fun playerFor(platform: Platform, file: FileName, available: (Player) -> Boolean): Option<Player> {
        val candidates = platform.players.filter { it.accepts.matches(file) && available(it) }
        return player.flatMap { id -> candidates.firstOrNone { it.id == id } }.fold({ candidates.firstOrNone() }, ::Some)
    }
}

/**
 * What a scan found in a platform's folder: every file ends up either in one game's discs or
 * ignored, and the sub-folders it did not look into are in [skippedFolders].
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
         * `Game (Disc 1)` and `Game (Disc 2)` make one game. Pure and total; the result does not
         * depend on the order of the files.
         */
        public fun of(platform: Platform, folder: FolderContents, titles: TitleIndex, discs: DiscGrouping): Scan {
            val (ignored, kept) = folder.files.sortedWith(FILE_ORDER).separateEither { classify(platform, titles, it) }
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

/**
 * The games of every platform, the user's choices for each platform, and what its last scan set
 * aside. Its size follows the games, not the folders: hidden and unsupported files are only
 * counted, since a folder may hold tens of thousands of them.
 */
@Serializable
public data class Library(
    public val setups: Map<PlatformId, PlatformSetup> = emptyMap(),
    public val games: List<Game> = emptyList(),
    /** Files a player of the platform opens that were not taken for games (a BIOS, too small): all of them, as one may be a game. */
    public val notGames: Map<PlatformId, List<ListedFile>> = emptyMap(),
    public val ignoredCounts: Map<PlatformId, Map<CountedReason, IgnoredCount>> = emptyMap(),
    public val skippedFolders: Map<PlatformId, List<SkippedFolder>> = emptyMap(),
    /** The names the user gave consoles, shown in place of their own; left out of the stored library while there is none. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val consoleNames: Map<PlatformId, DisplayName> = emptyMap(),
    /** The order the user put consoles in; left out of the stored library while they put none anywhere. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val consoleOrder: List<PlatformId> = emptyList(),
) {
    public fun setup(platform: PlatformId): PlatformSetup = setups.getOrElse(platform) { PlatformSetup() }

    public fun game(id: GameId): Option<Game> = games.firstOrNone { it.id == id }

    public fun withSetup(platform: PlatformId, setup: PlatformSetup): Library = copy(setups = setups + (platform to setup))

    /** Replaces [platform]'s games with [scan]'s, keeping what the user chose for games still there. */
    public fun withScan(platform: PlatformId, scan: Scan): Library {
        val previous = games.filter { it.platform == platform }.associateBy { it.id }
        val scanned =
            scan.games.map { game ->
                previous.getOrNone(game.id).fold({ game }) { kept ->
                    game.copy(lastDisc = kept.lastDisc.coerceIn(game.discs.indices), label = kept.label, displayName = kept.displayName)
                }
            }
        return copy(
            games = games.filter { it.platform != platform } + scanned,
            skippedFolders = skippedFolders + (platform to scan.skippedFolders),
        ).withIgnored(platform, scan.ignored)
    }

    /** Keeps [platform]'s files that are not games, and counts the others. */
    internal fun withIgnored(platform: PlatformId, ignored: List<IgnoredFile>): Library {
        val byReason = ignored.groupBy({ it.reason }, { it.file })
        val counts =
            byReason.entries.flatMap { (reason, files) ->
                when (reason) {
                    IgnoreReason.HIDDEN -> listOf(CountedReason.HIDDEN to IgnoredCount.of(files))
                    IgnoreReason.UNSUPPORTED -> listOf(CountedReason.UNSUPPORTED to IgnoredCount.of(files))
                    IgnoreReason.NOT_A_GAME -> emptyList()
                }
            }
        return copy(
            notGames = notGames + (platform to byReason.getOrElse(IgnoreReason.NOT_A_GAME) { emptyList() }),
            ignoredCounts = ignoredCounts + (platform to counts.toMap()),
        )
    }

    /** The library without [platform]: its choices, its games and what its scans set aside. The others are untouched. */
    public fun without(platform: PlatformId): Library = copy(
        setups = setups - platform,
        games = games.filter { it.platform != platform },
        notGames = notGames - platform,
        ignoredCounts = ignoredCounts - platform,
        skippedFolders = skippedFolders - platform,
        consoleNames = consoleNames - platform,
        consoleOrder = consoleOrder - platform,
    )

    /** [platform]'s console shown as [name], or under its own name, [own], again when none or when [name] is it. */
    public fun withConsoleName(platform: PlatformId, name: Option<DisplayName>, own: String): Library =
        copy(consoleNames = name.filter { it.text != own }.fold({ consoleNames - platform }) { consoleNames + (platform to it) })

    /** Consoles shown in [order] from now on; those put somewhere before and not in it follow, in their order. */
    public fun withConsoleOrder(order: List<PlatformId>): Library = copy(consoleOrder = (order + consoleOrder).distinct())

    /** [platforms] in the order the user put their consoles in: those put somewhere first, then the others as given. */
    public fun inConsoleOrder(platforms: List<PlatformId>): List<PlatformId> =
        (consoleOrder.filter { it in platforms } + platforms).distinct()

    /** Records [disc] (an index into the game's discs, kept within them) as the one launched last. */
    public fun withLastDisc(id: GameId, disc: Int): Library = withGame(id) { it.copy(lastDisc = disc.coerceIn(it.discs.indices)) }

    /** Records which image game [id]'s label shows; the other games are untouched. */
    public fun withLabel(id: GameId, label: LabelChoice): Library = withGame(id) { it.copy(label = label) }

    /** Game [id] shown as [name], or as its title again when none or when [name] is its title. */
    public fun withDisplayName(id: GameId, name: Option<DisplayName>): Library =
        withGame(id) { game -> game.copy(displayName = name.filter { it.text != game.title }) }

    private fun withGame(id: GameId, change: (Game) -> Game): Library = copy(games = games.map { if (it.id == id) change(it) else it })
}
