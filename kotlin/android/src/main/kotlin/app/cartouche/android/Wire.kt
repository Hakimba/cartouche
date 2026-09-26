// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.util.Log
import app.cartouche.android.apps.LaunchableApp
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.platforms.Candidate
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.LaunchError
import arrow.core.Either
import arrow.core.Option
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

internal fun Catalog.toWire(): Dictionary = dictionary(
    "platforms" to platforms.toWireArray { it.name },
    "rejected" to rejected.toWireArray { dictionary("source" to it.source, "detail" to it.message) },
)

internal fun Candidate.toWire(): Dictionary =
    dictionary("platform_name" to platform.name, "player_id" to player.id.value, "player_name" to player.name)
