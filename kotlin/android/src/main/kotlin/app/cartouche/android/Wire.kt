// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.util.Log
import app.cartouche.android.apps.LaunchableApp
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.LabelFailure
import app.cartouche.android.art.OwnPicture
import app.cartouche.android.art.VariantFailure
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.CountedReason
import app.cartouche.core.library.Disc
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.SkipReason
import app.cartouche.core.library.SkippedFolder
import app.cartouche.core.platforms.Candidate
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.platforms.MediaType
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.Player
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.settings.Settings
import app.cartouche.core.shelves.Shelves
import app.cartouche.core.storage.Volume
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterIsInstance
import arrow.core.toOption
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.godotengine.godot.Dictionary

// The Dictionary format shared with the GDScript adapter (app/adapters/android/android_services.gd).
// Getters return plain Dictionaries; operations answer through the `answered` signal with
// `{"request_id", "ok": true, …}` or `{"request_id", "ok": false, "code", "detail"}`.
// A value that may be missing is an absent key, never null.

internal const val ANSWERED_SIGNAL = "answered"

internal const val TAG = "Cartouche"

/** One `area: detail` line in the log of debug builds, read with `dev/logs.sh`; release builds skip [detail]. */
internal inline fun trace(area: String, detail: () -> String) {
    if (BuildConfig.DEBUG) Log.i(TAG, "$area: ${detail()}")
}

/** Stable error codes, for the UI to tell failures apart. Spelled out so renaming a constant cannot change them. */
internal enum class ErrorCode(val wire: String) {
    CANCELLED("cancelled"),
    NO_ACTIVITY("no_activity"),
    INVALID_REQUEST("invalid_request"),
    UNKNOWN_PLAYER("unknown_player"),
    UNSUPPORTED_FILE("unsupported_file"),
    INVALID_TEMPLATE("invalid_template"),
    NOT_INSTALLED("not_installed"),
    NO_PLAYER("no_player"),
    GAME_MISSING("game_missing"),
    UNKNOWN_PLATFORM("unknown_platform"),
    UNKNOWN_GAME("unknown_game"),
    NO_FOLDER("no_folder"),
    ACTIVITY_NOT_FOUND("activity_not_found"),
    PERMISSION_DENIED("permission_denied"),
    FOLDER_UNAVAILABLE("folder_unavailable"),
    TOO_MANY_FILES("too_many_files"),
    NO_IMAGE("no_image"),
    UNREADABLE_IMAGE("unreadable_image"),
    UNEXPECTED("unexpected"),
}

internal fun dictionary(vararg entries: Pair<String, Any>): Dictionary = Dictionary().apply { putAll(entries) }

internal fun success(vararg payload: Pair<String, Any>): Dictionary = dictionary("ok" to true, *payload)

internal fun failure(code: ErrorCode, detail: String): Dictionary = dictionary("ok" to false, "code" to code.wire, "detail" to detail)

/**
 * The wire form of a list of Dictionaries. Godot's JNI bridge only turns an `Object[]` into an
 * Array, and a String inside one stays an opaque JavaObject: lists of texts are sent as `String[]`,
 * which becomes a PackedStringArray. Any other typed array is an opaque object.
 */
internal fun <T> List<T>.toWireArray(transform: (T) -> Dictionary): Array<Any> = map(transform).toTypedArray()

/** Puts [value] under [key] when there is one: absence is an absent key. */
internal fun Dictionary.putSome(key: String, value: Option<Any>): Dictionary = apply { value.onSome { put(key, it) } }

/** The String under [key]; none when it is absent or of another type. */
internal fun Dictionary.text(key: String): Option<String> = this[key].toOption().filterIsInstance<String>()

/** The integer under [key] (GDScript ints arrive as Long); none when it is absent, of another type or out of range. */
internal fun Dictionary.integer(key: String): Option<Int> = this[key].toOption().flatMap { value ->
    when (value) {
        is Long -> Some(value).filter { it in Int.MIN_VALUE..Int.MAX_VALUE }.map(Long::toInt)
        is Int -> Some(value)
        else -> None
    }
}

/** `{"path", "width", "height"}`. */
internal fun OwnPicture.toWire(): Dictionary = dictionary("path" to file.path, "width" to width, "height" to height)

internal fun Either<LaunchFailure, Unit>.toWire(): Dictionary = fold({ it.toWire() }, { success() })

internal fun LaunchFailure.toWire(): Dictionary = failure(
    when (this) {
        is LaunchFailure.Rejected ->
            when (error) {
                is LaunchError.UnknownPlayer -> ErrorCode.UNKNOWN_PLAYER
                is LaunchError.UnsupportedFile -> ErrorCode.UNSUPPORTED_FILE
                is LaunchError.InvalidTemplate -> ErrorCode.INVALID_TEMPLATE
            }
        is LaunchFailure.NotInstalled -> ErrorCode.NOT_INSTALLED
        is LaunchFailure.ActivityNotFound -> ErrorCode.ACTIVITY_NOT_FOUND
        is LaunchFailure.PermissionDenied -> ErrorCode.PERMISSION_DENIED
        is LaunchFailure.NoPlayer -> ErrorCode.NO_PLAYER
        is LaunchFailure.GameMissing -> ErrorCode.GAME_MISSING
    },
    message,
)

internal fun StorageFailure.toWire(): Dictionary = failure(
    when (this) {
        is StorageFailure.Unavailable -> ErrorCode.FOLDER_UNAVAILABLE
        is StorageFailure.PermissionDenied -> ErrorCode.PERMISSION_DENIED
    },
    message,
)

/** `{"uri", "name", "path"?, "place"?: {"volume": "internal" or "card", "folders": [name]}}`. */
internal fun Folder.toWire(): Dictionary = dictionary("uri" to uri.value, "name" to name)
    .putSome("path", path.map { it.value })
    .putSome("place", place.map { dictionary("volume" to it.volume.wire, "folders" to it.folders.toTypedArray()) })

private val Volume.wire: String
    get() =
        when (this) {
            Volume.INTERNAL -> "internal"
            Volume.CARD -> "card"
        }

internal fun DocumentEntry.toWire(): Dictionary = dictionary(
    "name" to name.value,
    "document_id" to documentId.value,
    "uri" to uri.value,
    "is_directory" to (kind == EntryKind.DIRECTORY),
).putSome("path", path.map { it.value })

internal fun LaunchableApp.toWire(): Dictionary = dictionary("package" to packageName.value, "label" to label)

internal fun LibraryFailure.toWire(): Dictionary = when (this) {
    is LibraryFailure.Storage -> failure.toWire()
    is LibraryFailure.NoFolder -> failure(ErrorCode.NO_FOLDER, message)
    is LibraryFailure.UnknownGame -> failure(ErrorCode.UNKNOWN_GAME, message)
    is LibraryFailure.NoDisc -> failure(ErrorCode.INVALID_REQUEST, message)
    is LibraryFailure.UnknownPlatform -> failure(ErrorCode.UNKNOWN_PLATFORM, message)
    is LibraryFailure.TooManyEntries -> failure(ErrorCode.TOO_MANY_FILES, message)
}

/**
 * The library and its [shelves] as JSON text, read on the Godot side with its JSON parser: a few
 * hundred games as Dictionaries take about a second to cross the JNI bridge, as JSON a few
 * milliseconds. The shape is the one Dictionaries would have: `{"setups": {platform id: setup},
 * "games": [game], "not_games": {platform id: [file name]}, "ignored_counts": {platform id:
 * {"hidden" or "unsupported": {"count", "examples"}}}, "skipped_folders": {platform id: [{"path",
 * "reason"}]}, "shelves"?: {"shelves": [{"platform", "games": [index into games], "selected"}],
 * "selected"}}`, with the keys below; a missing value is an absent key.
 */
internal fun Library.toWireJson(shelves: Option<Shelves>): String = buildJsonObject {
    put("setups", setups.toJson(PlatformId::value) { it.toJson() })
    put("games", games.toJson { it.toJson() })
    put("not_games", notGames.toJson(PlatformId::value) { files -> files.toJson { JsonPrimitive(it.name.value) } })
    put("ignored_counts", ignoredCounts.toJson(PlatformId::value) { counts -> counts.toJson({ it.wire }) { it.toJson() } })
    put("skipped_folders", skippedFolders.toJson(PlatformId::value) { folders -> folders.toJson { it.toJson() } })
    put("console_names", consoleNames.toJson(PlatformId::value) { JsonPrimitive(it.text) })
    shelves.onSome { put("shelves", it.toJson(games.withIndex().associate { (at, game) -> game.id to at })) }
}.toString()

private fun <K, V> Map<K, V>.toJson(key: (K) -> String, value: (V) -> JsonElement): JsonObject =
    JsonObject(entries.associate { key(it.key) to value(it.value) })

private fun <T> List<T>.toJson(item: (T) -> JsonElement): JsonArray = JsonArray(map(item))

private fun JsonObjectBuilder.putSome(key: String, value: Option<String>) = value.onSome { put(key, it) }

private fun PlatformSetup.toJson(): JsonObject = buildJsonObject {
    put("disc_grouping", discs.wire)
    put("folder_depth", depth.wire)
    putSome("folder_uri", folder.map { it.value })
    putSome("player_id", player.map { it.value })
}

private fun Game.toJson(): JsonObject = buildJsonObject {
    put("id", id.value)
    put("platform_id", platform.value)
    put("title", shownTitle)
    putSome("original_title", displayName.map { title })
    put("regions", regions.toJson(::JsonPrimitive))
    put("languages", languages.toJson(::JsonPrimitive))
    put("serials", serials.toJson(::JsonPrimitive))
    put("discs", discs.toJson { it.toJson() })
    put("last_disc", lastDisc)
    put("identified", identified)
    putSome("version", version)
    putSome("redump_name", redumpName)
    when (val chosen = label) {
        LabelChoice.Automatic -> Unit
        is LabelChoice.Region -> put("label_region", chosen.region.name)
        LabelChoice.Own -> put("label_own", true)
    }
}

private fun Disc.toJson(): JsonObject = buildJsonObject {
    put("name", file.name.value)
    number.onSome { put("number", it) }
}

private fun IgnoredCount.toJson(): JsonObject = buildJsonObject {
    put("count", count)
    put("examples", examples.toJson { JsonPrimitive(it.value) })
}

/** [indexes] places each game in the library's games; the shelves are made of those games, so each has one. */
private fun Shelves.toJson(indexes: Map<GameId, Int>): JsonObject = buildJsonObject {
    put(
        "shelves",
        shelves.toJson { shelf ->
            buildJsonObject {
                put("platform", shelf.platform.value)
                put("games", shelf.games.toJson { JsonPrimitive(indexes.getValue(it.id)) })
                put("selected", shelf.selected)
            }
        },
    )
    put("selected", selected)
}

private fun SkippedFolder.toJson(): JsonObject = buildJsonObject {
    put("path", path.value)
    put("reason", reason.wire)
}

private val CountedReason.wire: String
    get() =
        when (this) {
            CountedReason.HIDDEN -> "hidden"
            CountedReason.UNSUPPORTED -> "unsupported"
        }

internal val SkipReason.wire: String
    get() =
        when (this) {
            SkipReason.HIDDEN -> "hidden"
            SkipReason.EMULATOR_DATA -> "emulator_data"
            SkipReason.TOO_DEEP -> "too_deep"
            SkipReason.UNREADABLE -> "unreadable"
        }

internal val DiscGrouping.wire: String
    get() =
        when (this) {
            DiscGrouping.GROUPED -> "grouped"
            DiscGrouping.SEPARATE -> "separate"
        }

internal val FolderDepth.wire: String
    get() =
        when (this) {
            FolderDepth.TOP_LEVEL -> "top_level"
            FolderDepth.SUBFOLDERS -> "subfolders"
        }

/** `{"level_percent": int (absent when unknown), "plugged": bool}` */
internal fun BatteryState.toWire(): Dictionary = dictionary("plugged" to plugged).putSome("level_percent", levelPercent)

internal val ButtonStyle.wire: String
    get() =
        when (this) {
            ButtonStyle.XBOX -> "xbox"
            ButtonStyle.NINTENDO -> "nintendo"
            ButtonStyle.PLAYSTATION -> "playstation"
        }

internal val EdgeSmoothing.wire: String
    get() =
        when (this) {
            EdgeSmoothing.FOUR_TIMES -> "4x"
            EdgeSmoothing.TWICE -> "2x"
            EdgeSmoothing.OFF -> "off"
        }

/** `{"first_launch", "button_style"?, "edge_smoothing"}`: the style is absent until one is chosen. */
internal fun Settings.toWire(firstLaunch: Boolean): Dictionary =
    dictionary("first_launch" to firstLaunch, "edge_smoothing" to edgeSmoothing.wire)
        .putSome("button_style", buttonStyle.map { it.wire })

internal val MediaType.wire: String
    get() =
        when (this) {
            MediaType.DVD -> "dvd"
            MediaType.CARTRIDGE -> "cartridge"
            MediaType.MINIDISC -> "minidisc"
        }

/**
 * What the `art_changed` signal carries: a scraping run's progress, `{"done", "total", "stall"?}`,
 * and the art just found, if any, under `"found"` ([FoundArt.toWire]).
 */
internal fun Scraping.toWire(): Dictionary = dictionary("done" to done, "total" to total).putSome("stall", stall.map { it.wire })

/** `{"game_id", "path"}`, the path an absolute one to a JPEG. */
internal fun FoundArt.toWire(): Dictionary = dictionary("game_id" to game.value, "path" to art.file.path)

/** Stored art as JSON text, `[{"game_id", "path"}]`: a library's worth of Dictionaries would cost as much as its games (see [toWireJson]). */
internal fun List<FoundArt>.artWireJson(): String = toJson { found ->
    buildJsonObject {
        put("game_id", found.game.value)
        put("path", found.art.file.path)
    }
}.toString()

internal fun LabelFailure.toWire(): Dictionary = when (this) {
    LabelFailure.NotDownloaded -> failure(ErrorCode.NO_IMAGE, "The image is not downloaded")
    LabelFailure.NotPicked -> failure(ErrorCode.NO_IMAGE, "No picture is being framed")
    is LabelFailure.Unreadable -> failure(ErrorCode.UNREADABLE_IMAGE, "The picture cannot be read: $reason")
    is LabelFailure.Library -> failure.toWire()
    is LabelFailure.Storage -> failure.toWire()
}

internal val VariantFailure.wire: String
    get() =
        when (this) {
            VariantFailure.OFFLINE -> "offline"
            VariantFailure.REFUSED -> "refused"
            VariantFailure.NOT_FOUND -> "not_found"
            VariantFailure.UNREADABLE -> "unreadable"
            VariantFailure.STORAGE -> "storage"
        }

internal val Stall.wire: String
    get() =
        when (this) {
            Stall.OFFLINE -> "offline"
            Stall.REFUSED -> "refused"
            Stall.STORAGE -> "storage"
        }

internal fun ScanReport.toWire(): Dictionary = dictionary(
    "files" to files,
    "games" to games,
    "identified" to identified,
    "ignored" to ignored,
    "skipped_folders" to skippedFolders,
    "milliseconds" to milliseconds,
)

internal fun Catalog.toWire(): Dictionary = dictionary(
    "platforms" to platforms.toWireArray { dictionary("id" to it.id.value, "name" to it.name, "media" to it.profile.media.wire) },
    "rejected" to rejected.toWireArray { dictionary("source" to it.source, "detail" to it.message) },
)

internal fun Player.toWire(): Dictionary = dictionary("player_id" to id.value, "player_name" to name)

internal fun Candidate.toWire(): Dictionary = player.toWire().apply { put("platform_name", platform.name) }
