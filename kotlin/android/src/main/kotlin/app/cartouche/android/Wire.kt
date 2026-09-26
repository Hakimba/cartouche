// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.util.Log
import app.cartouche.android.apps.LaunchableApp
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.Game
import app.cartouche.core.library.IgnoreReason
import app.cartouche.core.library.IgnoredFile
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.platforms.Candidate
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.platforms.MediaType
import app.cartouche.core.platforms.Player
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterIsInstance
import arrow.core.toOption
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
    UNKNOWN_PLATFORM("unknown_platform"),
    UNKNOWN_GAME("unknown_game"),
    NO_FOLDER("no_folder"),
    ACTIVITY_NOT_FOUND("activity_not_found"),
    PERMISSION_DENIED("permission_denied"),
    FOLDER_UNAVAILABLE("folder_unavailable"),
    UNEXPECTED("unexpected"),
}

internal fun dictionary(vararg entries: Pair<String, Any>): Dictionary = Dictionary().apply { putAll(entries) }

internal fun success(vararg payload: Pair<String, Any>): Dictionary = dictionary("ok" to true, *payload)

internal fun failure(code: ErrorCode, detail: String): Dictionary = dictionary("ok" to false, "code" to code.wire, "detail" to detail)

/**
 * The wire form of a list. Godot's JNI bridge only turns an `Object[]` into an Array: a `String[]`
 * becomes a PackedStringArray and any other typed array an opaque object.
 */
internal fun <T> List<T>.toWireArray(transform: (T) -> Any): Array<Any> = map(transform).toTypedArray()

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

internal fun Folder.toWire(): Dictionary = dictionary("uri" to uri.value, "name" to name).putSome("path", path.map { it.value })

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
}

internal fun Library.toWire(): Dictionary = dictionary(
    "setups" to Dictionary().apply { setups.forEach { (id, setup) -> put(id.value, setup.toWire()) } },
    "games" to games.toWireArray { it.toWire() },
    "ignored" to Dictionary().apply { ignored.forEach { (id, files) -> put(id.value, files.toWireArray { it.toWire() }) } },
)

internal fun PlatformSetup.toWire(): Dictionary = dictionary("disc_grouping" to discs.wire, "folder_depth" to depth.wire)
    .putSome("folder_uri", folder.map { it.value })
    .putSome("player_id", player.map { it.value })

internal fun Game.toWire(): Dictionary = dictionary(
    "id" to id.value,
    "platform_id" to platform.value,
    "title" to title,
    "regions" to regions.toWireArray { it },
    "languages" to languages.toWireArray { it },
    "serials" to serials.toWireArray { it },
    "discs" to discs.toWireArray { dictionary("name" to it.file.name.value).putSome("number", it.number) },
    "last_disc" to lastDisc,
    "identified" to identified,
).putSome("version", version).putSome("redump_name", redumpName)

internal fun IgnoredFile.toWire(): Dictionary = dictionary(
    "name" to file.name.value,
    "reason" to
        when (reason) {
            IgnoreReason.HIDDEN -> "hidden"
            IgnoreReason.UNSUPPORTED -> "unsupported"
            IgnoreReason.NOT_A_GAME -> "not_a_game"
        },
)

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

internal val MediaType.wire: String
    get() =
        when (this) {
            MediaType.DVD -> "dvd"
            MediaType.CARTRIDGE -> "cartridge"
            MediaType.MINIDISC -> "minidisc"
        }

internal fun ScanReport.toWire(): Dictionary =
    dictionary("files" to files, "games" to games, "identified" to identified, "ignored" to ignored, "milliseconds" to milliseconds)

internal fun Catalog.toWire(): Dictionary = dictionary(
    "platforms" to
        platforms.toWireArray { dictionary("id" to it.id.value, "name" to it.name, "media" to it.profile.media.wire) },
    "rejected" to rejected.toWireArray { dictionary("source" to it.source, "detail" to it.message) },
)

internal fun Player.toWire(): Dictionary = dictionary("player_id" to id.value, "player_name" to name)

internal fun Candidate.toWire(): Dictionary = player.toWire().apply { put("platform_name", platform.name) }
