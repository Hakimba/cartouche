// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class CartridgesTest {
    private val ines = "NES\u001A".toByteArray(Charsets.ISO_8859_1) + ByteArray(12) { (it + 1).toByte() }

    @Test
    fun `a NES ROM's print leaves its iNES header out, and a ROM without one is counted whole`() = runBlocking<Unit> {
        checkAll(bytes(16..4096), Arb.boolean()) { rom, headed ->
            facts("nes", "game.nes", if (headed) ines + rom else rom) shouldBe FileFacts.Print(crc32(rom))
        }
    }

    @Test
    fun `a Super Nintendo ROM's print leaves a copier header out, told by the size`() = runBlocking<Unit> {
        checkAll(bytes(1024..4096).map { it.copyOf(it.size / 1024 * 1024) }, Arb.boolean()) { rom, headed ->
            facts("snes", "game.sfc", if (headed) ByteArray(512) { 0x55 } + rom else rom) shouldBe FileFacts.Print(crc32(rom))
        }
    }

    @Test
    fun `a Nintendo 64 ROM's print is of its big-endian bytes, whatever order and extension the file has`() = runBlocking<Unit> {
        val roms = bytes(12..4096).map { byteArrayOf(0x80.toByte(), 0x37, 0x12, 0x40) + it.copyOf(it.size / 4 * 4) }
        checkAll(roms, Arb.element("z64", "v64", "n64")) { rom, extension ->
            val byteSwapped = ByteArray(rom.size) { rom[it xor 1] }
            val wordSwapped = ByteArray(rom.size) { rom[it xor 3] }
            listOf(rom, byteSwapped, wordSwapped).forEach { facts("n64", "game.$extension", it) shouldBe FileFacts.Print(crc32(rom)) }
        }
    }

    @Test
    fun `a Game Boy ROM is counted whole`() = runBlocking<Unit> {
        checkAll(bytes(16..4096), Arb.element("gb" to "gb", "gbc" to "gbc", "gbc" to "gb", "gba" to "gba")) { rom, (platform, extension) ->
            facts(platform, "game.$extension", rom) shouldBe FileFacts.Print(crc32(rom))
        }
    }

    @Test
    fun `a zip's only entry gives the print the archive records, and several entries give nothing`() = runBlocking<Unit> {
        checkAll(bytes(0..4096), Arb.boolean(), Arb.string(0..3000)) { rom, stored, comment ->
            facts("gba", "game.zip", zip("game.gba" to rom, stored = stored, comment = comment)) shouldBe FileFacts.Print(crc32(rom))
            facts("gba", "game.zip", zip("game.gba" to rom, "notes.txt" to rom)) shouldBe FileFacts.Silent
        }
    }

    @Test
    fun `a ROM read in several pieces is counted whole, without its header, in its own byte order`() {
        // Two whole reads and seven bytes: a last read shorter than the others, a last group of each N64 order cut short.
        val rom = byteArrayOf(0x80.toByte(), 0x37, 0x12, 0x40) + ByteArray(2 * CHUNK + 3) { (it * 31 + it / 4099).toByte() }
        val print = FileFacts.Print(crc32(rom))
        // Each pair, then each group of four, written the other way round; a last part too short for one as it is.
        val byteSwapped = rom.copyOf()
        (0 until rom.size - 1 step 2).forEach { at -> (0..1).forEach { byteSwapped[at + it] = rom[at + 1 - it] } }
        val wordSwapped = rom.copyOf()
        (0 until rom.size - 3 step 4).forEach { at -> (0..3).forEach { wordSwapped[at + it] = rom[at + 3 - it] } }
        facts("nes", "game.nes", ines + rom) shouldBe print
        facts("n64", "game.v64", byteSwapped) shouldBe print
        facts("n64", "game.n64", wordSwapped) shouldBe print
        facts("gba", "game.gba", rom) shouldBe print
        // A Super Nintendo ROM is a whole number of kilobytes, 512 bytes more with a copier's header; any other size is counted whole.
        val snes = rom.copyOf(2 * CHUNK + 1024)
        facts("snes", "game.sfc", ByteArray(512) { 0x55 } + snes) shouldBe FileFacts.Print(crc32(snes))
        facts("snes", "game.smc", rom) shouldBe print
    }

    @Test
    fun `a zip's entry is found past a comment of the longest kind`() {
        val rom = ByteArray(4096) { it.toByte() }
        facts("gba", "game.zip", zip("game.gba" to rom, comment = "c".repeat(65_000))) shouldBe FileFacts.Print(crc32(rom))
    }

    @Test
    fun `a file too short to start with a header, or that is not a zip, gives nothing`() {
        facts("nes", "game.nes", ByteArray(15)) shouldBe FileFacts.Silent
        facts("gba", "game.zip", ByteArray(100)) shouldBe FileFacts.Silent
        facts("gba", "game.zip", ByteArray(0)) shouldBe FileFacts.Silent
    }
}
