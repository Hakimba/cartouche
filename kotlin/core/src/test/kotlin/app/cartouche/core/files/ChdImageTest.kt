// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.assertions.withClue
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.longs.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ChdImageTest {
    /** The fixture CHDs hold the disc padded with zeros to 64 sectors. */
    private val sectors = 64

    private fun expected(n: Int): ByteArray =
        if ((n + 1) * SECTOR <= disc.size) disc.copyOfRange(n * SECTOR, (n + 1) * SECTOR) else ByteArray(SECTOR)

    @Test
    fun `every sector of a CD CHD in each codec and track type, and of a DVD CHD in each codec, is the disc's`() {
        READABLE_CHDS.forEach { name ->
            chdOf(image(name)) { sector ->
                (0 until sectors).forEach { n -> withClue("$name sector $n") { sector(n).shouldBeSome() shouldBe expected(n) } }
                sector(sectors).shouldBeNone()
            }.shouldBeSome()
        }
    }

    @Test
    fun `hunks of a long run of one codec, stored as they are or repeating others, read as the disc wrote them`() {
        chdOf(image("dvd-runs.chd")) { sector ->
            (0 until runsDisc.size / SECTOR).forEach { n ->
                withClue("sector $n") { sector(n).shouldBeSome() shouldBe runsDisc.copyOfRange(n * SECTOR, (n + 1) * SECTOR) }
            }
            sector(runsDisc.size / SECTOR).shouldBeNone()
        }.shouldBeSome()
    }

    @Test
    fun `an image that is not a CHD version 5, cut short, or uncompressed does not open`() {
        val chd = image("dvd-lzma.chd")
        chdOf(disc) {}.shouldBeNone()
        chdOf(chd.copyOf(100)) {}.shouldBeNone()
        chdOf(chd.copyOf().also { it[15] = 4 }) {}.shouldBeNone()
        // An uncompressed image names no codec.
        chdOf(chd.copyOf().also { ByteArray(16).copyInto(it, 16) }) {}.shouldBeNone()
    }

    @Test
    fun `a hunk repeating a stored one reads as it, and one repeating a repetition reads nothing`() {
        chdOf(selfChain(hunks = 4).bytes) { sector ->
            sector(0).shouldBeSome() shouldBe ByteArray(SECTOR) { it.toByte() }
            sector(1).shouldBeSome() shouldBe ByteArray(SECTOR) { it.toByte() }
            sector(2).shouldBeNone()
            sector(3).shouldBeNone()
        }.shouldBeSome()
    }

    @Test
    fun `a CD track's type gives where a sector's data starts`() {
        listOf("MODE1" to 0, "MODE2_FORM1" to 0, "MODE2" to 8, "MODE2_FORM_MIX" to 8).forEach { (type, at) ->
            val frame = ByteArray(FRAME) { it.toByte() }
            Layout.ofTrack(type).data(frame, 0).shouldBeSome() shouldBe frame.copyOfRange(at, at + SECTOR)
        }
        Layout.ofTrack("MODE1_RAW") shouldBe Layout.RAW
        Layout.ofTrack("MODE2_RAW") shouldBe Layout.RAW
    }

    @Test
    fun `a CHD is read where its header says, and only within the file`() {
        val source = InMemoryBytes(image("dvd-zlib.chd"))
        chdOf(source) { sector -> sector(16).shouldBeSome() }.shouldBeSome()
        source.requests.first() shouldBe (0L to 124)
        source.withinFile shouldBe true
    }

    @Test
    fun `a sector is read from the part of the map it needs, as from the whole map, however long the codes before the entries`() {
        listOf(storedHunks(40_000), storedHunks(40_001, alternating = true), storedHunks(400_001, alternating = true), storedHunks(3))
            .forEach { image ->
                val source = InMemoryBytes(image.bytes, size = image.size)
                val map = image.bytes.copyOfRange(124, 128).fold(0) { value, byte -> (value shl 8) or (byte.toInt() and 0xFF) }
                val mapReads = { source.requests.count { (offset, _) -> offset >= 124 + 16 && offset < 124 + 16 + map } }
                withClue(image) {
                    chdOf(source) { sector ->
                        sector(0).shouldBeSome() shouldBe ByteArray(SECTOR) { it.toByte() }
                        // Run-length coded, the codes of tens of thousands of hunks take a few bytes.
                        if (image.hunks == 40_000L) source.requests.sumOf { it.second } shouldBeLessThan map
                        sector(image.hunks.toInt() - 1).shouldBeSome() shouldBe ByteArray(SECTOR)
                        // However long the map, it is read at most twice: a hostile one is walked at most twice per sector.
                        mapReads() shouldBeLessThanOrEqual 2
                    }.shouldBeSome()
                }
            }
    }

    @Test
    fun `INV-03 a CHD claiming any hunks, lengths, map or metadata reads nothing rather than fail, and never more than its bounds`() =
        runBlocking<Unit> {
            var opened = 0
            checkAll(500, hostileChds) { chd ->
                val source = InMemoryBytes(chd.bytes, size = chd.size)
                chdOf(source) { sector ->
                    opened++
                    sector(chd.sector)
                }
                source.withinFile shouldBe true
                // A hunk, the map (9 bytes a hunk at most), a header, or a metadata entry's text.
                val bound =
                    maxOf(
                        124L,
                        minOf(chd.hunkBytes, MAX_HUNK.toLong()),
                        9 * chd.hunks.coerceIn(0L, MAX_HUNKS.toLong()) + 64,
                        MAX_METADATA_TEXT.toLong(),
                    )
                source.requests.forEach { (_, length) -> length.toLong() shouldBeLessThanOrEqual bound }
            }
            // Enough of them opened, to be asked for a hunk.
            opened shouldBeGreaterThan 100
        }
}
