// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.platforms.SerialScans
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.junit.Test

class SerialScansTest {
    private val source = SerialScans.of("https://scans.test/{serial}/{serial}-D.jpg", PLAYSTATION_SERIAL).shouldBeSome()

    @Test
    fun `a disc's scan is named after each of its serials, in order, once`() {
        source.scansOf(listOf("SLPM-66363", "SCAJ-20175", "SLPM-66363")).map { it.url.value } shouldBe
            listOf("https://scans.test/SLPM-66363/SLPM-66363-D.jpg", "https://scans.test/SCAJ-20175/SCAJ-20175-D.jpg")
    }

    @Test
    fun `serials of another form are left out, as the reference lists hold some`() {
        source.scansOf(listOf("SLES-53974/GER", "SLES---54355", "SCES-53133-ANZ/P", "slus-20148", "")).map { it.url.value } shouldBe
            emptyList()
    }

    @Test
    fun `a source names only serials of its platform's form`() {
        val cartridges = SerialScans.of("https://scans.test/{serial}.png", "[A-Z0-9]{4}").shouldBeSome()
        cartridges.scansOf(listOf("BJBE", "SLES-53047", "bjbe", "AGB-BJBE")).map { it.url.value } shouldBe
            listOf("https://scans.test/BJBE.png")
        source.scansOf(listOf("BJBE")) shouldBe emptyList()
    }

    @Test
    fun `a source that is not https, names no serial or no form of serial is none`() {
        SerialScans.of("http://scans.test/{serial}.jpg", PLAYSTATION_SERIAL).shouldBeNone()
        SerialScans.of("https://scans.test/disc.jpg", PLAYSTATION_SERIAL).shouldBeNone()
        SerialScans.of("https://scans.test/{serial}.jpg", "[A-Z").shouldBeNone()
    }
}
