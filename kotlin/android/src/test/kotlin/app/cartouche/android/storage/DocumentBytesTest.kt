// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.shouldBe
import org.junit.After
import org.junit.Test
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import kotlin.io.path.createTempFile

class DocumentBytesTest {
    private val bytes = ByteArray(5000) { it.toByte() }
    private val file: File = createTempFile().toFile().apply { writeBytes(bytes) }

    @After
    fun deleteFile() {
        file.delete()
    }

    @Test
    fun `bytes are read where asked, fewer past the end of the file, and counted`() {
        RandomAccessFile(file, "r").use { opened ->
            val source = DocumentBytes(opened.channel::read, file.length())
            source.size shouldBe 5000L
            source.read(1000, 16).shouldBeRight() shouldBe bytes.copyOfRange(1000, 1016)
            source.read(4990, 16).shouldBeRight() shouldBe bytes.copyOfRange(4990, 5000)
            source.read(0, 4).shouldBeRight() shouldBe bytes.copyOfRange(0, 4)
            source.bytesRead shouldBe 30L
        }
    }

    @Test
    fun `reads that stop short are taken up where they stopped, until the length asked or the end of the file`() {
        RandomAccessFile(file, "r").use { opened ->
            // Seven bytes at most a read, as a provider streaming the file may give them.
            val stingy = { buffer: ByteBuffer, at: Long ->
                val window = buffer.slice().limit(minOf(7, buffer.remaining())) as ByteBuffer
                opened.channel.read(window, at).also { if (it > 0) buffer.position(buffer.position() + it) }
            }
            val source = DocumentBytes(stingy, file.length())
            source.read(1000, 100).shouldBeRight() shouldBe bytes.copyOfRange(1000, 1100)
            source.read(4990, 100).shouldBeRight() shouldBe bytes.copyOfRange(4990, 5000)
            source.bytesRead shouldBe 110L
        }
    }

    @Test
    fun `a read that fails is a failure`() {
        val channel = RandomAccessFile(file, "r").channel.apply { close() }
        DocumentBytes(channel::read, file.length()).read(0, 16).shouldBeLeft()
    }
}
