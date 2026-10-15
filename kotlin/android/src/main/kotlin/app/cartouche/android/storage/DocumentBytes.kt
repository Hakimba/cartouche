// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.files.ByteSource
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.ReadFailure
import arrow.core.Either
import arrow.core.raise.catch
import arrow.core.raise.either
import java.io.IOException
import java.nio.ByteBuffer

/**
 * A document opened read-only, read where the decoders ask through [readAt], a positional read on
 * its descriptor's channel (`FileChannel.read(buffer, position)`). [size] is the descriptor's, -1
 * when it is not a file (a pipe), which no decoder reads.
 */
internal class DocumentBytes(private val readAt: (ByteBuffer, Long) -> Int, override val size: Long) : ByteSource {
    /** The bytes read so far, for the traces. */
    var bytesRead: Long = 0
        private set

    override fun read(offset: Long, length: Int): Either<ReadFailure, ByteArray> = either {
        val buffer = ByteBuffer.allocate(length)
        catch({
            // A positional read may stop short of the end; -1 only comes at the end of the file.
            while (buffer.hasRemaining() && readAt(buffer, offset + buffer.position()) >= 0) Unit
        }) { e: IOException -> raise(ReadFailure(e.toString())) }
        bytesRead += buffer.position()
        if (buffer.hasRemaining()) buffer.array().copyOf(buffer.position()) else buffer.array()
    }
}

/** [FileFacts] in the words of the traces. */
internal val FileFacts.described: String
    get() =
        when (this) {
            is FileFacts.Serial -> "serial $code"
            is FileFacts.Print -> "print $hex"
            FileFacts.Silent -> "nothing read"
        }
