// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/** An Android application id, such as `org.dolphinemu.dolphinemu`. */
@JvmInline public value class PackageName private constructor(public val value: String) {
    public companion object {
        /** Android's rule: at least two dot-separated segments, each a letter then letters, digits or `_`. */
        private val SYNTAX = Regex("""[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+""")

        public fun parse(text: String): Option<PackageName> = Some(text).filter(SYNTAX::matches).map(::PackageName)
    }
}

/** A `content://` URI, readable by the app that holds (or is granted) access to it. */
@Serializable(with = ContentUriSerializer::class)
@JvmInline
public value class ContentUri private constructor(public val value: String) {
    public companion object {
        public fun parse(text: String): Option<ContentUri> = Some(text).filter { it.startsWith("content://") }.map(::ContentUri)
    }
}

/** An absolute filesystem path, such as `/storage/1A2B-3C4D/ROMs/ps2/Game.chd`. */
@Serializable @JvmInline
public value class FilePath(public val value: String)

/** A file name as the user sees it, such as `Game (Europe).chd`. */
@Serializable @JvmInline
public value class FileName(public val value: String) {
    /** Dot files and macOS `._` resource forks: never games. */
    public val isHidden: Boolean get() = value.startsWith('.')
}

/** Stored URIs are checked when read back, like any other: decoding fails on anything else. */
private object ContentUriSerializer : KSerializer<ContentUri> by ParsedSerializer(
    "content URI",
    String.serializer(),
    ContentUri::parse,
    ContentUri::value,
)

/**
 * Values checked when read, like any other: [T] written as its [surrogate], and read back through
 * [parse], decoding failing on anything it refuses ([what] names [T] in the failure).
 */
internal class ParsedSerializer<S, T>(
    private val what: String,
    private val surrogate: KSerializer<S>,
    private val parse: (S) -> Option<T>,
    private val written: (T) -> S,
) : KSerializer<T> {
    override val descriptor: SerialDescriptor get() = surrogate.descriptor

    override fun serialize(encoder: Encoder, value: T): Unit = encoder.encodeSerializableValue(surrogate, written(value))

    // The serialization library reports invalid input by exception; decoders catch it at their boundary.
    override fun deserialize(decoder: Decoder): T = decoder.decodeSerializableValue(surrogate).let { read ->
        parse(read).getOrElse { throw SerializationException("Not a $what: $read") }
    }
}
