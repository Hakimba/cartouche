// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class, NonEmptyListSerializer::class)

package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.ParsedSerializer
import app.cartouche.core.files.Shell
import app.cartouche.core.launch.GameFile
import app.cartouche.core.platforms.PlatformId
import arrow.core.NonEmptyList
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.serialization.NonEmptyListSerializer
import arrow.core.serialization.OptionSerializer
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
 * A name the user gave a game, shown in place of its title: one line, its spaces single, trimmed, never blank, at
 * most [LONGEST] characters. Only what is shown changes: identification and art keep looking for its title, and the
 * shelves keep it in its title's place.
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

private object DisplayNameSerializer : KSerializer<DisplayName> by ParsedSerializer(
    "display name",
    String.serializer(),
    { text -> DisplayName.of(text).filter { it.text == text } },
    DisplayName::text,
)

/**
 * Where a label's image comes from: the chooser names each image by its region and its source, and a chosen label
 * remembers both. Stored and sent to Godot by [wire], spelled out so that renaming a constant cannot change it; shown
 * as [label].
 */
@Serializable
public enum class ArtSource(public val wire: String, public val label: String) {
    @SerialName("launchbox")
    LAUNCHBOX("launchbox", "LaunchBox"),

    @SerialName("screenscraper")
    SCREENSCRAPER("screenscraper", "ScreenScraper"),

    @SerialName("psxdatacenter")
    PSXDATACENTER("psxdatacenter", "psxdatacenter"),
}

/** Which image a game's label shows. */
@Serializable
public sealed interface LabelChoice {
    /** The image of the region closest to the game's own, as its art is looked for. */
    @Serializable
    @SerialName("automatic")
    public data object Automatic : LabelChoice

    /** The image [source] has for [region], chosen by the user. */
    @Serializable
    @SerialName("region")
    public data class Region(public val region: LabelRegion, public val source: ArtSource = ArtSource.LAUNCHBOX) : LabelChoice

    /**
     * A picture of the user's own, framed by them (`app.cartouche.core.art.LabelFraming`); the app keeps the framed
     * copy.
     */
    @Serializable
    @SerialName("own")
    public data object Own : LabelChoice
}

/** One disc of a game; [number] is none when the file names no disc. */
@Serializable
public data class Disc(public val number: Option<Int>, public val file: ListedFile)

/**
 * A game of the library. [redumpName] is the reference-list disc it is exactly, if any; its regions, languages and
 * version are that disc's, else what its file name states (its regions those its possible versions share, when known
 * by its content).
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
    /**
     * The shell its first file's header tells; left out of the stored library while unknown, as it is for most games.
     */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val shell: Shell = Shell.UNKNOWN,
) {
    /** Whether the reference list knows the game: as an exact disc, or by the serials of its release. */
    public val identified: Boolean get() = redumpName.isSome() || serials.isNotEmpty()

    /** What the game is called on screen: the name the user gave it, else its title. */
    public val shownTitle: String get() = displayName.fold({ title }) { it.text }
}
