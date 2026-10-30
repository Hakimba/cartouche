// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.assertions.withClue
import io.kotest.matchers.ints.shouldBeGreaterThan
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
            val chd = chdOf(image(name)).shouldBeSome()
            (0 until sectors).forEach { n -> withClue("$name sector $n") { chd.sectorOf(n).shouldBeSome() shouldBe expected(n) } }
            chd.sectorOf(sectors).shouldBeNone()
        }
    }

    @Test
    fun `hunks of a long run of one codec, stored as they are or repeating others, read as the disc wrote them`() {
        val chd = chdOf(image("dvd-runs.chd")).shouldBeSome()
        (0 until runsDisc.size / SECTOR).forEach { n ->
            withClue("sector $n") { chd.sectorOf(n).shouldBeSome() shouldBe runsDisc.copyOfRange(n * SECTOR, (n + 1) * SECTOR) }
        }
        chd.sectorOf(runsDisc.size / SECTOR).shouldBeNone()
    }

    @Test
    fun `an image that is not a CHD version 5, cut short, or uncompressed does not open`() {
        val chd = image("dvd-lzma.chd")
        chdOf(disc).shouldBeNone()
        chdOf(chd.copyOf(100)).shouldBeNone()
        chdOf(chd.copyOf().also { it[15] = 4 }).shouldBeNone()
        // An uncompressed image names no codec.
        chdOf(chd.copyOf().also { ByteArray(16).copyInto(it, 16) }).shouldBeNone()
    }

    @Test
    fun `a hunk repeating a stored one reads as it, and one repeating a repetition reads nothing`() {
        val chd = chdOf(selfChain(hunks = 4).bytes).shouldBeSome()
        chd.sectorOf(0).shouldBeSome() shouldBe ByteArray(SECTOR) { it.toByte() }
        chd.sectorOf(1).shouldBeSome() shouldBe ByteArray(SECTOR) { it.toByte() }
        chd.sectorOf(2).shouldBeNone()
        chd.sectorOf(3).shouldBeNone()
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
        readable { chdImage(source).shouldBeSome().run { sector(16) } }.shouldBeSome()
        source.requests.first() shouldBe (0L to 124)
        source.withinFile shouldBe true
    }

    @Test
    fun `INV-03 a CHD claiming any hunks, lengths, map or metadata reads nothing rather than fail, and never more than its bounds`() =
        runBlocking<Unit> {
            var opened = 0
            checkAll(500, hostileChds) { chd ->
                val source = InMemoryBytes(chd.bytes, size = chd.size)
                readable { chdImage(source).onSome { opened++ }.flatMap { with(it) { sector(chd.sector) } } }
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
