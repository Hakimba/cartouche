// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
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
private object ContentUriSerializer : KSerializer<ContentUri> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("app.cartouche.ContentUri", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: ContentUri): Unit = encoder.encodeString(value.value)

    // The serialization library reports invalid input by exception; decoders catch it at their boundary.
    override fun deserialize(decoder: Decoder): ContentUri =
        decoder.decodeString().let { text -> ContentUri.parse(text).getOrElse { throw SerializationException("Not a content URI: $text") } }
}
