// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SerialScansTest {
    private val source = SerialScans.of("https://scans.test/{serial}/{serial}-D.jpg").shouldBeSome()

    @Test
    fun `a disc's scan is named after each of its serials, in order, once`() {
        source.scansOf(listOf("SLPM-66363", "SCAJ-20175", "SLPM-66363")).map { it.value } shouldBe
            listOf("https://scans.test/SLPM-66363/SLPM-66363-D.jpg", "https://scans.test/SCAJ-20175/SCAJ-20175-D.jpg")
    }

    @Test
    fun `serials of another form are left out, as the reference lists hold some`() {
        source.scansOf(listOf("SLES-53974/GER", "SLES---54355", "SCES-53133-ANZ/P", "slus-20148", "")).map { it.value } shouldBe emptyList()
    }

    @Test
    fun `every serial of the shipped PS2 list makes an https URL of the shipped source`() = runBlocking<Unit> {
        val shipped = SerialScans.of(Shipped.ps2.profile.scansBySerial.shouldBeSome()).shouldBeSome()
        val serials = Shipped.text("redump/ps2.tsv").lines().flatMap { line -> line.substringAfter('\t').split(',') }
        checkAll(Arb.element(serials)) { serial ->
            shipped.scansOf(listOf(serial)).forEach { it.value shouldStartWith "https://psxdatacenter.com/" }
        }
    }

    @Test
    fun `a source that is not https or names no serial is none`() {
        SerialScans.of("http://scans.test/{serial}.jpg").shouldBeNone()
        SerialScans.of("https://scans.test/disc.jpg").shouldBeNone()
    }
}
