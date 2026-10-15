// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.longs.shouldBeGreaterThan
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class Iso9660Test {
    private val boot = "BOOT2 = cdrom0:\\$FIXTURE_SERIAL;1"

    @Test
    fun `the serial SYSTEM CNF boots is read from the root of the volume`() {
        Iso9660.bootSerial(sectorsOf(disc)) shouldBeSome FileFacts.Serial(FIXTURE_SERIAL)
    }

    @Test
    fun `SYSTEM CNF is found in a root directory over several sectors`() {
        val crowded = image("disc-crowded.iso")
        // The root directory's record in the volume descriptor: its size, beyond a sector.
        crowded.littleEndian(16 * SECTOR + 156 + 10, 4) shouldBeGreaterThan SECTOR.toLong()
        Iso9660.bootSerial(sectorsOf(crowded)) shouldBeSome FileFacts.Serial(FIXTURE_SERIAL)
    }

    @Test
    fun `a PlayStation's BOOT line is read as a PlayStation 2's BOOT2`() {
        Iso9660.bootSerial(sectorsOf(disc.patched(boot, "BOOT = cdrom:\\SLUS_012.34;1"))) shouldBeSome FileFacts.Serial("SLUS_012.34")
    }

    @Test
    fun `the file is found whatever the case and version its record writes`() {
        Iso9660.bootSerial(sectorsOf(disc.patched("SYSTEM.CNF;1", "system.cnf;2"))) shouldBeSome FileFacts.Serial(FIXTURE_SERIAL)
    }

    @Test
    fun `nothing is read without an ISO 9660 volume, without SYSTEM CNF at the root, or without a boot line`() {
        Iso9660.bootSerial(sectorsOf(disc.patched("CD001", "XXXXX"))).shouldBeNone()
        Iso9660.bootSerial(sectorsOf(disc.patched("SYSTEM.CNF;1", "SYSTEM.CNG;1"))).shouldBeNone()
        Iso9660.bootSerial(sectorsOf(disc.patched(boot, "ROOT2 = cdrom0:\\$FIXTURE_SERIAL;1"))).shouldBeNone()
        Iso9660.bootSerial(sectorsOf(disc.patched(boot, "BOOT2 = cdrom0:\\SLES-52495;1"))).shouldBeNone()
        Iso9660.bootSerial(sectorsOf(disc.copyOf(16 * SECTOR))).shouldBeNone()
    }

    @Test
    fun `the boot line is read however the disc spaces and slashes it, and the serial as written`() = runBlocking<Unit> {
        val serials =
            Arb.bind(
                Arb.list(Arb.element(('A'..'Z').toList()), 4..4),
                Arb.int(0..999),
                Arb.int(0..99),
                Arb.element("_", "-"),
            ) { letters, n, m, sep ->
                "${letters.joinToString("")}$sep${n.toString().padStart(3, '0')}.${m.toString().padStart(2, '0')}"
            }
        val lines =
            Arb.bind(
                Arb.element("BOOT2", "BOOT", "boot2"),
                Arb.element("", " ", "  "),
                Arb.element("cdrom0", "cdrom"),
                Arb.element("", "\\", "\\\\"),
                serials,
            ) { key, space, drive, slashes, serial ->
                "$key$space=$space$drive:$slashes$serial;1" to serial
            }
        checkAll(lines) { (line, serial) -> Iso9660.bootSerial(sectorsOf(disc.patched(boot, line))) shouldBeSome FileFacts.Serial(serial) }
    }
}
