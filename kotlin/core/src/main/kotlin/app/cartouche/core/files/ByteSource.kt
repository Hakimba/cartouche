// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.raise.Raise

/**
 * A game file open for reading, as a documents provider or a filesystem hands it: its [size] and the bytes at any
 * place in it. Every decoder of this package reads through it, the Android plugin opens the file, tests hold bytes in
 * memory. It has no way to write.
 */
public interface ByteSource {
    public val size: Long

    /**
     * The [length] bytes at [offset], fewer when the file ends before, in a new array the caller may change; a
     * failure when the file cannot be read there. Decoders only ask within [size] and take fewer bytes than asked as
     * a damaged file.
     */
    public fun read(offset: Long, length: Int): Either<ReadFailure, ByteArray>
}

/** Why bytes could not be read: the provider's or the filesystem's own words. */
@JvmInline public value class ReadFailure(public val detail: String)

/**
 * The [length] bytes of [source] at [offset], all of them; none when they lie outside the file or it gives fewer. A
 * failure to read is raised: it says nothing about the file's content.
 */
internal fun Raise<ReadFailure>.bytes(source: ByteSource, offset: Long, length: Int): Option<ByteArray> =
    if (offset < 0 || length < 0 || offset > source.size - length) {
        None
    } else {
        Some(source.read(offset, length).bind()).filter { it.size == length }
    }

internal fun ByteArray.unsignedByte(at: Int): Int = this[at].toInt() and 0xFF

/** A big-endian number of [count] bytes, as CHD headers write them. */
internal fun ByteArray.bigEndian(at: Int, count: Int): Long =
    (0 until count).fold(0L) { value, i -> (value shl 8) or unsignedByte(at + i).toLong() }

/** A little-endian number of [count] bytes, as ISO 9660 and zip files write them. */
internal fun ByteArray.littleEndian(at: Int, count: Int): Long =
    (0 until count).fold(0L) { value, i -> value or (unsignedByte(at + i).toLong() shl (8 * i)) }

/** [length] bytes from [at] as text, one character per byte. */
internal fun ByteArray.text(at: Int, length: Int): String = String(this, at, length, Charsets.ISO_8859_1)
