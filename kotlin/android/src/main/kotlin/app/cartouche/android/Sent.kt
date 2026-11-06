// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.android

import app.cartouche.android.art.AbsentArt
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.LabelDownload
import app.cartouche.android.art.LabelNews
import app.cartouche.android.art.OwnPicture
import app.cartouche.android.art.VariantFailure
import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.Folder
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.Coming
import app.cartouche.core.library.CountedReason
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.SkipReason
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.MediaType
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.serialName
import app.cartouche.core.settings.Backdrop
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.settings.Language
import app.cartouche.core.settings.Setting
import app.cartouche.core.settings.SoundLevel
import app.cartouche.core.storage.Volume
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import app.cartouche.core.library.Arrivals as CoreArrivals
import app.cartouche.core.library.Game as CoreGame
import app.cartouche.core.library.Library as CoreLibrary
import app.cartouche.core.library.PlatformSetup as CoreSetup
import app.cartouche.core.platforms.Player as CorePlayer
import app.cartouche.core.search.Mark as CoreMark
import app.cartouche.core.search.View as CoreView
import app.cartouche.core.settings.Settings as CoreSettings
import app.cartouche.core.shelves.Shelves as CoreShelves

/**
 * Everything the plugin sends to Godot, each as one JSON text ([wireJson]): the getters' values, the answers and the
 * signals. `app/adapters/android/android_wire.gd` reads them, generated from these types by `WireScriptTest`: a class
 * per type, named as here, a field per property under its key, in snake_case (a `@SerialName` for two words; the
 * generator refuses another). An [Option], declared `= None`, is an absent key until it has a
 * value, read in GDScript as `has_<key>` beside the value; an enum crosses as its `@SerialName`. A property may have
 * another default only when it is its type's zero (false, 0, empty), which GDScript reads for an absent key: the
 * generator refuses any other.
 */
internal object Sent {
    @Serializable
    class CatalogSummary(val platforms: List<Platform>, val offered: List<OfferedConsole>, val rejected: List<String>)

    /** [medium] is the platform's default medium: the shelf's model can load before its games are known. */
    @Serializable
    class Platform(val id: String, val name: String, val media: MediaType, val medium: String)

    /** A platform of the Type chooser; a [coming] one is shown greyed, never added. */
    @Serializable
    class OfferedConsole(val id: String, val model: String, val maker: Option<String> = None, val coming: Boolean)

    @Serializable
    class Players(val players: List<Player>)

    /** [extensions] only when the player's definition says them plainly. */
    @Serializable
    class Player(
        val id: String,
        val name: String,
        @SerialName("emulator_name") val emulatorName: String,
        val extensions: Option<List<String>> = None,
    )

    /**
     * What the carousel shows of a shelf of [count] games: the positions in the shelf of the [games] shown, their
     * [groups], and the index into [games] each key of the ribbon brings the carousel to (a lowercase letter, a digit,
     * a space).
     */
    @Serializable
    class Browse(val count: Int, val games: List<Int>, val groups: List<Group>, val keys: Map<String, Int>)

    @Serializable
    class Group(val label: String, val start: Int)

    /** Where the words typed are in a title, in characters. */
    @Serializable
    class Marks(val marks: List<Mark>)

    @Serializable
    class Mark(val start: Int, val length: Int)

    /** The backdrop stored, read as the app starts. */
    @Serializable
    class BackdropAnswer(
        val backdrop: Backdrop,
        @SerialName("pixel_veil") val pixelVeil: Boolean,
    )

    @Serializable
    class Battery(
        @SerialName("level_percent") val levelPercent: Option<Int> = None,
        val plugged: Boolean,
    )

    /** A scraping run's progress, and what it just learnt: the art [found], or the ids of games no source has art for. */
    @Serializable
    class ArtChange(val progress: ArtProgress, val found: Option<Art> = None, val absent: List<String> = emptyList())

    @Serializable
    class ArtProgress(val done: Int, val total: Int, val stall: Option<Stall> = None)

    /** A game's label image, at an absolute [path] to a JPEG. */
    @Serializable
    class Art(
        @SerialName("game_id") val gameId: String,
        val path: String,
    )

    /** How far a label's download has come: [fraction] from 0 to 1 while [running], -1 when the image's size is unknown. */
    @Serializable
    class LabelDownload(
        @SerialName("game_id") val gameId: String,
        val running: Boolean,
        val fraction: Double,
    )

    /**
     * One image a game's label can show: [source]'s for [region], at [path] once downloaded, or the [failure] that kept
     * it from being downloaded. [gameId] only when it arrives through `label_variant_downloaded`.
     */
    @Serializable
    class LabelVariant(
        @SerialName("game_id") val gameId: Option<String> = None,
        val region: String,
        val source: ArtSource,
        @SerialName("source_name") val sourceName: String,
        val path: Option<String> = None,
        val failure: Option<VariantFailure> = None,
    )

    @Serializable
    class LabelVariants(val variants: List<LabelVariant>)

    /** A folder granted through the system picker; [volume] and [folders] say where it is when it is on the device's storage. */
    @Serializable
    class Folder(
        val uri: String,
        val name: String,
        val path: Option<String> = None,
        val volume: Option<Volume> = None,
        val folders: List<String> = emptyList(),
    )

    @Serializable
    class Pick(val folder: Folder)

    @Serializable
    class FolderList(val folders: List<Folder>)

    /** The platform ids of all the consoles, first to last. */
    @Serializable
    class Placed(val order: List<String>)

    /** The choices made for one platform; without a player, the first installed one is used. */
    @Serializable
    class PlatformSetup(
        @SerialName("disc_grouping") val discGrouping: DiscGrouping,
        @SerialName("folder_depth") val folderDepth: FolderDepth,
        @SerialName("folder_uri") val folderUri: Option<String> = None,
        @SerialName("player_id") val playerId: Option<String> = None,
        @SerialName("variant_id") val variantId: Option<String> = None,
    )

    @Serializable
    class Disc(val name: String, val number: Option<Int> = None)

    /**
     * [medium] is the one its platform gives a game of its regions, none when the platform is unknown; [title] the name
     * the user gave it, [originalTitle] its own then. [labelRegion] and [labelSource] name the image the user chose for
     * its label, [labelOwn] tells a picture of their own.
     */
    @Serializable
    class Game(
        val id: String,
        @SerialName("platform_id") val platformId: String,
        val title: String,
        @SerialName("original_title") val originalTitle: Option<String> = None,
        val regions: List<String>,
        val medium: Option<String> = None,
        val languages: List<String>,
        val serials: List<String>,
        val discs: List<Disc>,
        @SerialName("last_disc") val lastDisc: Int,
        val identified: Boolean,
        val version: Option<String> = None,
        @SerialName("redump_name") val redumpName: Option<String> = None,
        @SerialName("label_region") val labelRegion: Option<String> = None,
        @SerialName("label_source") val labelSource: Option<ArtSource> = None,
        @SerialName("label_own") val labelOwn: Boolean = false,
    )

    @Serializable
    class IgnoredCount(val reason: CountedReason, val count: Int, val examples: List<String>)

    @Serializable
    class SkippedFolder(val path: String, val reason: SkipReason)

    /** One platform's games in the carousel's order, as indexes into [Library.games]. */
    @Serializable
    class Shelf(
        @SerialName("platform_id") val platformId: String,
        @SerialName("game_indexes") val gameIndexes: List<Int>,
        val selected: Int,
    )

    /** The library at [revision]: one shelf per platform with games, [selectedShelf] the one shown first. */
    @Serializable
    class Library(
        val revision: Int,
        val setups: Map<String, PlatformSetup>,
        val games: List<Game>,
        @SerialName("not_games") val notGames: Map<String, List<String>>,
        @SerialName("ignored_counts") val ignoredCounts: Map<String, List<IgnoredCount>>,
        @SerialName("skipped_folders") val skippedFolders: Map<String, List<SkippedFolder>>,
        @SerialName("console_variants") val consoleVariants: Map<String, String>,
        val shelves: List<Shelf>,
        @SerialName("selected_shelf") val selectedShelf: Int,
    )

    /** The games a re-read brought that the user has not seen yet, and those each console announces. */
    @Serializable
    class Arrivals(val unseen: List<String>, val announced: Map<String, List<String>>)

    /** [loadProblem] tells why the stored library could not be read: it then started empty. */
    @Serializable
    class LibraryAnswer(
        val library: Library,
        val art: List<Art> = emptyList(),
        val absent: List<String> = emptyList(),
        val arrivals: Option<Arrivals> = None,
        @SerialName("load_problem") val loadProblem: Option<String> = None,
    )

    /** A re-read's answer: the [library] only when the re-read changed it. */
    @Serializable
    class RefreshAnswer(val arrivals: Arrivals, val library: Option<Library> = None)

    @Serializable
    class ArrivalsAnswer(val arrivals: Arrivals)

    @Serializable
    class ScanReport(
        val files: Int,
        val games: Int,
        val identified: Int,
        val ignored: Int,
        @SerialName("skipped_folders") val skippedFolders: Int,
        val milliseconds: Long,
    )

    @Serializable
    class ScanAnswer(val library: Library, val report: ScanReport, val arrivals: Arrivals)

    @Serializable
    class PreviewAnswer(val report: ScanReport)

    /** How scraping again went: the games of the library, the labels looked for that were found, the consoles not scanned and why. */
    @Serializable
    class RescrapeAnswer(val library: Library, val games: Int, val labels: Int, val failures: List<String>)

    /**
     * Each setting of [Setting.all] under its key, a choice not made yet absent, and each choice's names under its key
     * and `s`, the only ones `saveSetting` takes. [firstLaunch]: no button style chosen and no platform yet.
     */
    @Serializable
    class SettingsAnswer(
        @SerialName("first_launch") val firstLaunch: Boolean,
        @SerialName("button_style") val buttonStyle: Option<ButtonStyle> = None,
        @SerialName("edge_smoothing") val edgeSmoothing: EdgeSmoothing,
        @SerialName("preferred_region") val preferredRegion: Option<PreferredRegion> = None,
        @SerialName("games_float") val gamesFloat: Boolean,
        @SerialName("sound_level") val soundLevel: SoundLevel,
        val language: Option<Language> = None,
        val backdrop: Backdrop,
        @SerialName("pixel_veil") val pixelVeil: Boolean,
        @SerialName("button_styles") val buttonStyles: List<String>,
        @SerialName("edge_smoothings") val edgeSmoothings: List<String>,
        @SerialName("preferred_regions") val preferredRegions: List<String>,
        val languages: List<String>,
        val backdrops: List<String>,
    )

    /** What a game is called once renamed, and its own title when the user gave it a name. */
    @Serializable
    class Renamed(
        val title: String,
        @SerialName("original_title") val originalTitle: Option<String> = None,
    )

    /** A picture of the user's own being framed: the app's upright copy at [path]. */
    @Serializable
    class LabelPicture(val path: String, val width: Int, val height: Int)

    @Serializable
    class ArtAnswer(val art: Art)
}

internal fun Catalog.sent(coming: Coming): Sent.CatalogSummary = Sent.CatalogSummary(
    platforms.map { Sent.Platform(it.id.value, it.name, it.profile.media, it.profile.medium.default.value) },
    offered.map { Sent.OfferedConsole(it.platform.value, it.model, it.maker, it.platform in coming) },
    rejected.map { "${it.source}: ${it.message}" },
)

internal fun CorePlayer.sent(): Sent.Player = Sent.Player(id.value, name, emulatorName, accepts.extensions)

internal fun CoreView.sent(count: Int): Sent.Browse =
    Sent.Browse(count, games, groups.map { Sent.Group(it.label, it.start) }, keys.mapKeys { it.key.toString() })

internal fun List<CoreMark>.sent(): Sent.Marks = Sent.Marks(map { Sent.Mark(it.start, it.length) })

internal fun CoreSettings.sentBackdrop(): Sent.BackdropAnswer = Sent.BackdropAnswer(backdrop, pixelVeil)

internal fun BatteryState.sent(): Sent.Battery = Sent.Battery(levelPercent, plugged)

internal fun FoundArt.sent(): Sent.Art = Sent.Art(game.value, art.file.path)

internal fun Scraping.sent(news: Option<LabelNews>): Sent.ArtChange {
    val progress = Sent.ArtProgress(done, total, stall)
    return news.fold({ Sent.ArtChange(progress) }) {
        when (it) {
            is FoundArt -> Sent.ArtChange(progress, found = Some(it.sent()))
            is AbsentArt -> Sent.ArtChange(progress, absent = it.games.map(GameId::value))
        }
    }
}

internal fun LabelDownload.sent(game: GameId): Sent.LabelDownload = when (this) {
    is LabelDownload.Running -> Sent.LabelDownload(game.value, running = true, fraction = fraction.getOrElse { -1.0 })
    LabelDownload.Over -> Sent.LabelDownload(game.value, running = false, fraction = -1.0)
}

internal fun ArtVariant.sent(game: Option<GameId>, path: Option<String>, failure: Option<VariantFailure>): Sent.LabelVariant =
    Sent.LabelVariant(game.map { it.value }, region.name, candidate.source, candidate.source.label, path, failure)

internal fun Folder.sent(): Sent.Folder = Sent.Folder(
    uri.value,
    name,
    path.map { it.value },
    place.map { it.volume },
    place.fold({ emptyList() }) { it.folders },
)

internal fun OwnPicture.sent(): Sent.LabelPicture = Sent.LabelPicture(file.path, width, height)

internal fun CoreSetup.sent(variant: Option<String>): Sent.PlatformSetup =
    Sent.PlatformSetup(discs, depth, folder.map { it.value }, player.map { it.value }, variant)

internal fun CoreArrivals.sent(): Sent.Arrivals =
    Sent.Arrivals(unseen.map { it.value }, announced.entries.associate { (platform, games) -> platform.value to games.map { it.value } })

internal fun ScanReport.sent(): Sent.ScanReport = Sent.ScanReport(files, games, identified, ignored, skippedFolders, milliseconds)

internal fun CoreSettings.sent(firstLaunch: Boolean): Sent.SettingsAnswer = Sent.SettingsAnswer(
    firstLaunch,
    buttonStyle,
    edgeSmoothing,
    preferredRegion,
    gamesFloat,
    soundLevel,
    language,
    backdrop,
    pixelVeil,
    Setting.BUTTON_STYLE.names,
    Setting.EDGE_SMOOTHING.names,
    Setting.PREFERRED_REGION.names,
    Setting.LANGUAGE.names,
    Setting.BACKDROP.names,
)

/** Each game carries its platform's medium from [catalog], none when the platform is unknown. */
internal fun CoreLibrary.sent(revision: Int, shelves: Option<CoreShelves>, catalog: Catalog): Sent.Library {
    val media = catalog.platforms.associate { it.id to it.profile.medium }
    val indexes = games.withIndex().associate { (at, game) -> game.id to at }
    return Sent.Library(
        revision,
        setups.entries.associate { (platform, setup) -> platform.value to setup.sent(variantOf(platform).map { it.serialName }) },
        games.map { it.sent(media.getOrNone(it.platform).map { medium -> medium.of(it.regions).value }) },
        notGames.byPlatform { files -> files.map { it.name.value } },
        ignoredCounts.byPlatform { counts ->
            counts.map { (reason, count) -> Sent.IgnoredCount(reason, count.count, count.examples.map { it.value }) }
        },
        skippedFolders.byPlatform { folders -> folders.map { Sent.SkippedFolder(it.path.value, it.reason) } },
        setups.keys.flatMap { platform -> variantOf(platform).map { platform.value to it.serialName }.toList() }.toMap(),
        shelves.fold({ emptyList() }) { found ->
            found.shelves.map { shelf -> Sent.Shelf(shelf.platform.value, shelf.games.map { indexes.getValue(it.id) }, shelf.selected) }
        },
        shelves.fold({ 0 }) { it.selected },
    )
}

private fun <V, T> Map<PlatformId, V>.byPlatform(sent: (V) -> T): Map<String, T> = entries.associate { (platform, value) ->
    platform.value to
        sent(value)
}

private fun CoreGame.sent(medium: Option<String>): Sent.Game {
    val chosen =
        when (val choice = label) {
            LabelChoice.Automatic, LabelChoice.Own -> None
            is LabelChoice.Region -> Some(choice)
        }
    return Sent.Game(
        id.value,
        platform.value,
        shownTitle,
        displayName.map { title },
        regions,
        medium,
        languages,
        serials,
        discs.map { Sent.Disc(it.file.name.value, it.number) },
        lastDisc,
        identified,
        version,
        redumpName,
        labelRegion = chosen.map { it.region.name },
        labelSource = chosen.map { it.source },
        labelOwn = label == LabelChoice.Own,
    )
}
