// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.util.Log
import app.cartouche.android.apps.LaunchableApp
import app.cartouche.android.art.AbsentArt
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.LabelDownload
import app.cartouche.android.art.LabelFailure
import app.cartouche.android.art.LabelNews
import app.cartouche.android.art.OwnPicture
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.art.Scraping
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlacementError
import app.cartouche.core.library.VariantError
import app.cartouche.core.platforms.Candidate
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.settings.Language
import app.cartouche.core.settings.Settings
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterIsInstance
import arrow.core.getOrElse
import arrow.core.toOption
import kotlinx.serialization.json.put
import kotlinx.serialization.serializer
import org.godotengine.godot.Dictionary
import kotlin.time.Duration
import kotlin.time.TimeSource

// Dictionary format shared with app/adapters/android/android_services.gd: operations answer through `answered` with
// `{"request_id", "ok": true, …}` or `{"request_id", "ok": false, "code", "detail"}`; a missing value is an absent key.

// The Dictionary format shared with the GDScript adapter (app/adapters/android/android_services.gd). Getters return
// plain Dictionaries; operations answer through the `answered` signal with `{"request_id", "ok": true, …}` or
// `{"request_id", "ok": false, "code", "detail"}`. A value that may be missing is an absent key, never null.
internal const val ANSWERED_SIGNAL = "answered"

internal const val ART_SIGNAL = "art_changed"

/** How the download of a game's label on screen goes ([LabelDownload.toWire]). */
internal const val ART_PROGRESS_SIGNAL = "art_progress"

internal const val VARIANT_SIGNAL = "label_variant_downloaded"

/** The battery's level, or whether a charger is plugged in, changed. */
internal const val BATTERY_SIGNAL = "battery_changed"

internal const val TAG = "Cartouche"

/** One `area: detail` line in the debug log; release builds skip [detail]. */
internal inline fun trace(area: String, detail: () -> String) {
    if (BuildConfig.DEBUG) Log.i(TAG, "$area: ${detail()}")
}

internal inline fun <T> timed(area: String, describe: (T, Duration) -> String, block: () -> T): T {
    val started = TimeSource.Monotonic.markNow()
    return block().also { result -> trace(area) { describe(result, started.elapsedNow()) } }
}

/** Spelled out so renaming a constant cannot change the codes. */
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
    TOO_LATE("too_late"),
    UNKNOWN_PLATFORM("unknown_platform"),
    UNKNOWN_VARIANT("unknown_variant"),
    NOT_IN_LIBRARY("not_in_library"),
    GAP_OUT_OF_RANGE("gap_out_of_range"),
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

/** The enum's name in the stored format (`@SerialName`), so the two cannot drift; `WireTest` pins the strings. */
internal inline val <reified E : Enum<E>> E.wire: String get() = serializer<E>().descriptor.getElementName(ordinal)

internal val Enum<*>.plainWire: String get() = name.lowercase()

internal fun dictionary(vararg entries: Pair<String, Any>): Dictionary = Dictionary().apply { putAll(entries) }

internal fun success(vararg payload: Pair<String, Any>): Dictionary = dictionary("ok" to true, *payload)

internal fun failure(code: ErrorCode, detail: String): Dictionary = dictionary("ok" to false, "code" to code.wire, "detail" to detail)

/** Where unexpected exceptions stop: logged, answered as a failure. */
internal fun unexpected(e: Throwable): Dictionary {
    Log.e(TAG, "Unexpected failure", e)
    return failure(ErrorCode.UNEXPECTED, e.toString())
}

/** Godot's JNI bridge only turns an `Object[]` into an Array, and a String inside one stays opaque: texts are sent as `String[]`. */
internal fun <T> List<T>.toWireArray(transform: (T) -> Dictionary): Array<Any> = map(transform).toTypedArray()

/** Puts [value] under [key] when there is one: absence is an absent key. */
internal fun Dictionary.putSome(key: String, value: Option<Any>): Dictionary = apply { value.onSome { put(key, it) } }

/** The String under [key]; none when it is absent or of another type. */
internal fun Dictionary.text(key: String): Option<String> = this[key].toOption().filterIsInstance<String>()

/** GDScript ints arrive as Long. */
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
        LaunchFailure.TooLate -> ErrorCode.TOO_LATE
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
    .putSome("place", place.map { dictionary("volume" to it.volume.plainWire, "folders" to it.folders.toTypedArray()) })

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
    is LibraryFailure.Placement ->
        failure(
            when (error) {
                is PlacementError.NotInLibrary -> ErrorCode.NOT_IN_LIBRARY
                is PlacementError.GapOutOfRange -> ErrorCode.GAP_OUT_OF_RANGE
            },
            message,
        )
    is LibraryFailure.Variant ->
        failure(
            when (error) {
                is VariantError.Unknown -> ErrorCode.UNKNOWN_VARIANT
                is VariantError.NotInLibrary -> ErrorCode.NOT_IN_LIBRARY
            },
            message,
        )
    is LibraryFailure.TooManyEntries -> failure(ErrorCode.TOO_MANY_FILES, message)
}

/** `{"level_percent": int (absent when unknown), "plugged": bool}` */
internal fun BatteryState.toWire(): Dictionary = dictionary("plugged" to plugged).putSome("level_percent", levelPercent)

/**
 * `{"first_launch", "button_style"?, "edge_smoothing", "games_float", "sound_level", "preferred_region"?, "preferred_regions",
 * "language"?, "languages"}`: the style, the region and the language are absent until one is chosen; the regions are
 * those a preference can name, as [PreferredRegion.region] names them, the only ones `savePreferredRegion` takes; the
 * languages are those the app's text is written in, the only ones `saveLanguage` takes.
 */
internal fun Settings.toWire(firstLaunch: Boolean): Dictionary = dictionary(
    "first_launch" to firstLaunch,
    "edge_smoothing" to edgeSmoothing.wire,
    "games_float" to gamesFloat,
    "sound_level" to soundLevel.steps,
    "preferred_regions" to PreferredRegion.entries.map { it.region }.toTypedArray(),
    "languages" to Language.entries.map { it.wire }.toTypedArray(),
).putSome("button_style", buttonStyle.map { it.wire })
    .putSome("preferred_region", preferredRegion.map { it.region })
    .putSome("language", language.map { it.wire })

/**
 * What the `art_changed` signal carries: a scraping run's progress, `{"done", "total", "stall"?}`, and what it just
 * learnt of games' labels, if anything: the art found under `"found"` ([FoundArt.toWire]), or the ids of games no
 * source has art for under `"absent"`.
 */
internal fun Scraping.toWire(news: Option<LabelNews>): Dictionary =
    dictionary("done" to done, "total" to total).putSome("stall", stall.map { it.plainWire }).apply {
        news.onSome {
            when (it) {
                is FoundArt -> put("found", it.toWire())
                is AbsentArt -> put("absent", it.games.map(GameId::value).toTypedArray())
            }
        }
    }

/**
 * What the `art_progress` signal carries of [game]'s label: `{"game_id", "fraction"}` while it downloads, the fraction from 0 to 1,
 * or -1 when the image's size is unknown; `{"game_id"}` once its look is over.
 */
internal fun LabelDownload.toWire(game: GameId): Dictionary = when (this) {
    is LabelDownload.Running -> dictionary("game_id" to game.value, "fraction" to fraction.getOrElse { -1.0 })
    LabelDownload.Over -> dictionary("game_id" to game.value)
}

/** `{"game_id", "path"}`, the path an absolute one to a JPEG. */
internal fun FoundArt.toWire(): Dictionary = dictionary("game_id" to game.value, "path" to art.file.path)

internal fun LabelFailure.toWire(): Dictionary = when (this) {
    LabelFailure.NotDownloaded -> failure(ErrorCode.NO_IMAGE, "The image is not downloaded")
    LabelFailure.NotPicked -> failure(ErrorCode.NO_IMAGE, "No picture is being framed")
    is LabelFailure.Unreadable -> failure(ErrorCode.UNREADABLE_IMAGE, "The picture cannot be read: $reason")
    is LabelFailure.Library -> failure.toWire()
    is LabelFailure.Storage -> failure.toWire()
}

internal fun ScanReport.toWire(): Dictionary = dictionary(
    "files" to files,
    "games" to games,
    "identified" to identified,
    "ignored" to ignored,
    "skipped_folders" to skippedFolders,
    "milliseconds" to milliseconds,
)

/**
 * How scraping again went: the games of the library, how many of the labels looked for were found, the consoles not
 * scanned and why.
 */
internal data class Rescraped(val games: Int, val labels: Int, val failures: List<String>)

internal fun Rescraped.toWire(): Dictionary = dictionary("games" to games, "labels" to labels, "failures" to failures.toTypedArray())

internal fun Catalog.offeredToWire(): Array<Any> =
    offered.toWireArray { dictionary("id" to it.platform.value, "model" to it.model).putSome("maker", it.maker) }

internal fun Catalog.toWire(): Dictionary = dictionary(
    "platforms" to platforms.toWireArray { dictionary("id" to it.id.value, "name" to it.name, "media" to it.profile.media.wire) },
    "rejected" to rejected.toWireArray { dictionary("source" to it.source, "detail" to it.message) },
    "offered" to offeredToWire(),
)

internal fun Candidate.toWire(): Dictionary =
    dictionary("player_id" to player.id.value, "player_name" to player.name, "platform_name" to platform.name)
