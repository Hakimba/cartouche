// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.util.Log
import app.cartouche.android.art.LabelFailure
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.library.PlacementError
import app.cartouche.core.library.VariantError
import app.cartouche.core.platforms.LaunchError
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterIsInstance
import arrow.core.toOption
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.StructureKind
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.descriptors.element
import kotlinx.serialization.descriptors.elementNames
import kotlinx.serialization.encoding.CompositeEncoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer
import org.godotengine.godot.Dictionary
import kotlin.time.Duration
import kotlin.time.TimeSource

// Everything the plugin sends to Godot is one JSON text of a type of [Sent] (INV-23). Getters return it, signals carry
// it, and operations answer through `answered` with `{"request_id", "ok": true, …payload}` or `{"request_id", "ok":
// false, "code", "detail"}`, and `"revision"` for a library call.
internal const val ANSWERED_SIGNAL = "answered"

internal const val ART_SIGNAL = "art_changed"

/** How the download of a game's label on screen goes ([Sent.LabelDownload]). */
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

/**
 * A property at its default, [None] above all, is left out: GDScript reads an absent key as the default (see [Sent]).
 * An [Option] given [None] without being declared `= None` would cross as null: `WireScriptTest` refuses such a type.
 * Written straight into one buffer, without a tree of elements.
 */
internal val wireJson = Json { encodeDefaults = false }

internal inline fun <reified T> jsonOf(value: T): String = wireJson.encodeToString(serializer<T>(), value)

/** An answer's own fields, a value of a type of [Sent]; [NONE] for an answer that only succeeds. */
internal class Payload private constructor(private val write: (Envelope) -> String) {
    companion object {
        val NONE: Payload = of(Unit.serializer(), Unit)

        /** [serializer] writes an object whose keys are not the envelope's: its fields go in the answer's own object. */
        fun <T> of(serializer: KSerializer<T>, value: T): Payload {
            val fields = serializer.descriptor
            require(fields.kind == StructureKind.CLASS || fields.kind == StructureKind.OBJECT) { "${fields.serialName} is no object" }
            require(fields.elementNames.none(Envelope.KEYS::contains)) { "${fields.serialName} has a key of the envelope" }
            return Payload { envelope -> wireJson.encodeToString(envelope.around(serializer), value) }
        }
    }

    fun answer(envelope: Envelope): String = write(envelope)
}

internal inline fun <reified T> payload(value: T): Payload = Payload.of(serializer<T>(), value)

/** What every answer says before its own fields: the request it answers, the library's revision for a library call, and whether it succeeded. */
internal class Envelope(private val requestId: Int, private val revision: Option<Int>, private val ok: Boolean) {
    /** [payload] written with this envelope's fields first, inside the payload's own object: one text, written once. */
    fun <T> around(payload: SerializationStrategy<T>): SerializationStrategy<T> = object : SerializationStrategy<T> {
        override val descriptor: SerialDescriptor = payload.descriptor

        override fun serialize(encoder: Encoder, value: T) = payload.serialize(
            object : Encoder by encoder {
                override fun beginStructure(descriptor: SerialDescriptor): CompositeEncoder = encoder.beginStructure(descriptor).apply {
                    encodeIntElement(FIELDS, 0, requestId)
                    revision.onSome { encodeIntElement(FIELDS, 1, it) }
                    encodeBooleanElement(FIELDS, 2, ok)
                }
            },
            value,
        )
    }

    companion object {
        private val FIELDS =
            buildClassSerialDescriptor("Envelope") {
                element<Int>("request_id")
                element<Int>("revision")
                element<Boolean>("ok")
            }

        val KEYS: Set<String> = FIELDS.elementNames.toSet()
    }
}

/** Why an operation failed, as GDScript tells failures apart; [detail] is English, for logs. */
@Serializable
internal class Failed(val code: Code, val detail: String)

@Serializable
internal enum class Code {
    @SerialName("cancelled")
    CANCELLED,

    @SerialName("no_activity")
    NO_ACTIVITY,

    @SerialName("invalid_request")
    INVALID_REQUEST,

    @SerialName("unknown_player")
    UNKNOWN_PLAYER,

    @SerialName("unsupported_file")
    UNSUPPORTED_FILE,

    @SerialName("invalid_template")
    INVALID_TEMPLATE,

    @SerialName("not_installed")
    NOT_INSTALLED,

    @SerialName("no_player")
    NO_PLAYER,

    @SerialName("game_missing")
    GAME_MISSING,

    @SerialName("too_late")
    TOO_LATE,

    @SerialName("unknown_platform")
    UNKNOWN_PLATFORM,

    @SerialName("unknown_variant")
    UNKNOWN_VARIANT,

    @SerialName("coming_console")
    COMING_CONSOLE,

    @SerialName("not_in_library")
    NOT_IN_LIBRARY,

    @SerialName("gap_out_of_range")
    GAP_OUT_OF_RANGE,

    @SerialName("unknown_game")
    UNKNOWN_GAME,

    @SerialName("no_folder")
    NO_FOLDER,

    @SerialName("activity_not_found")
    ACTIVITY_NOT_FOUND,

    @SerialName("permission_denied")
    PERMISSION_DENIED,

    @SerialName("folder_unavailable")
    FOLDER_UNAVAILABLE,

    @SerialName("too_many_files")
    TOO_MANY_FILES,

    @SerialName("no_image")
    NO_IMAGE,

    @SerialName("unreadable_image")
    UNREADABLE_IMAGE,

    @SerialName("unexpected")
    UNEXPECTED,
}

/** The answer to [requestId]: its envelope ([Envelope]), then its [result]'s fields, a failure's code and detail. */
internal fun answered(requestId: Int, revision: Option<Int>, result: Either<Failed, Payload>): String = result.fold(
    { wireJson.encodeToString(Envelope(requestId, revision, ok = false).around(Failed.serializer()), it) },
    { it.answer(Envelope(requestId, revision, ok = true)) },
)

/** Where unexpected exceptions stop: logged, answered as a failure. */
internal fun unexpected(e: Throwable): Failed {
    Log.e(TAG, "Unexpected failure", e)
    return Failed(Code.UNEXPECTED, e.toString())
}

internal fun invalid(detail: String): Failed = Failed(Code.INVALID_REQUEST, detail)

internal val LaunchFailure.failed: Failed
    get() =
        Failed(
            when (this) {
                is LaunchFailure.Rejected ->
                    when (error) {
                        is LaunchError.UnknownPlayer -> Code.UNKNOWN_PLAYER
                        is LaunchError.UnsupportedFile -> Code.UNSUPPORTED_FILE
                        is LaunchError.InvalidTemplate -> Code.INVALID_TEMPLATE
                    }
                is LaunchFailure.NotInstalled -> Code.NOT_INSTALLED
                is LaunchFailure.ActivityNotFound -> Code.ACTIVITY_NOT_FOUND
                is LaunchFailure.PermissionDenied -> Code.PERMISSION_DENIED
                is LaunchFailure.NoPlayer -> Code.NO_PLAYER
                is LaunchFailure.GameMissing -> Code.GAME_MISSING
                LaunchFailure.TooLate -> Code.TOO_LATE
            },
            message,
        )

internal val StorageFailure.failed: Failed
    get() =
        Failed(
            when (this) {
                is StorageFailure.Unavailable -> Code.FOLDER_UNAVAILABLE
                is StorageFailure.PermissionDenied -> Code.PERMISSION_DENIED
            },
            message,
        )

internal val LibraryFailure.failed: Failed
    get() =
        when (this) {
            is LibraryFailure.Storage -> failure.failed
            is LibraryFailure.NoFolder -> Failed(Code.NO_FOLDER, message)
            is LibraryFailure.UnknownGame -> Failed(Code.UNKNOWN_GAME, message)
            is LibraryFailure.NoDisc -> Failed(Code.INVALID_REQUEST, message)
            is LibraryFailure.UnknownPlatform -> Failed(Code.UNKNOWN_PLATFORM, message)
            is LibraryFailure.Placement ->
                Failed(
                    when (error) {
                        is PlacementError.NotInLibrary -> Code.NOT_IN_LIBRARY
                        is PlacementError.GapOutOfRange -> Code.GAP_OUT_OF_RANGE
                    },
                    message,
                )
            is LibraryFailure.Variant ->
                Failed(
                    when (error) {
                        is VariantError.Unknown -> Code.UNKNOWN_VARIANT
                        is VariantError.NotInLibrary -> Code.NOT_IN_LIBRARY
                        is VariantError.Coming -> Code.COMING_CONSOLE
                    },
                    message,
                )
            is LibraryFailure.TooManyEntries -> Failed(Code.TOO_MANY_FILES, message)
        }

internal val LabelFailure.failed: Failed
    get() =
        when (this) {
            LabelFailure.NotDownloaded -> Failed(Code.NO_IMAGE, "The image is not downloaded")
            LabelFailure.NotPicked -> Failed(Code.NO_IMAGE, "No picture is being framed")
            is LabelFailure.Unreadable -> Failed(Code.UNREADABLE_IMAGE, "The picture cannot be read: $reason")
            is LabelFailure.Library -> failure.failed
            is LabelFailure.Storage -> failure.failed
        }

/** The String under [key] of a request from GDScript; none when it is absent or of another type. */
internal fun Dictionary.text(key: String): Option<String> = this[key].toOption().filterIsInstance<String>()

/** GDScript ints arrive as Long. */
internal fun Dictionary.integer(key: String): Option<Int> = this[key].toOption().flatMap { value ->
    when (value) {
        is Long -> Some(value).filter { it in Int.MIN_VALUE..Int.MAX_VALUE }.map(Long::toInt)
        is Int -> Some(value)
        else -> None
    }
}
