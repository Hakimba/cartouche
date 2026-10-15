// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import arrow.core.Either
import arrow.core.left
import arrow.core.right

/**
 * A file held in memory, standing for a documents provider's file in the readers: a read past the end gives the
 * bytes there are, as a file does, and every read fails when the file is not [readable]. A file can be said larger
 * than [bytes], zeros after them, to stand for a disc image of gigabytes. [requests] records each read, offset and
 * length.
 */
class InMemoryBytes(private val bytes: ByteArray, private val readable: Boolean = true, override val size: Long = bytes.size.toLong()) :
    ByteSource {
    val requests: MutableList<Pair<Long, Int>> = mutableListOf()

    override fun read(offset: Long, length: Int): Either<ReadFailure, ByteArray> {
        requests += offset to length
        if (!readable) return ReadFailure("not readable").left()
        val from = offset.coerceIn(0L, size)
        val to = (offset + length).coerceIn(from, size)
        return ByteArray((to - from).toInt()) { if (from + it < bytes.size) bytes[(from + it).toInt()] else 0 }.right()
    }

    /** Whether every read so far asked for bytes the file holds. */
    val withinFile: Boolean get() = requests.all { (offset, length) -> offset >= 0 && length >= 0 && offset + length <= size }
}
