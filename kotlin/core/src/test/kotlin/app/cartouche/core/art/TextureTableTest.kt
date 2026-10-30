// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.ScreenScraperSystem
import app.cartouche.core.regions.Regions
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import io.kotest.matchers.maps.shouldNotBeEmpty as mapShouldNotBeEmpty

class TextureTableTest {
    private val ps2 = ScreenScraperSystem(58)

    @Test
    fun `a release's textures are its game's, one per region and disc, under the app's region names`() {
        val table = TextureTable.parse("# 2026-10-18\nOkage (USA)\t1234\tus jp\nOkage (Japan) (Disc 2)\t1234\tjp[2] eu[2]\n", ps2)
        table.version shouldBe Some(ArtVersion("2026-10-18"))
        table.size shouldBe 2
        table.texturesOf("Okage (USA)") shouldBe
            listOf(texture(58, 1234, "support-texture(us)", "USA"), texture(58, 1234, "support-texture(jp)", "Japan"))
        table.texturesOf("Okage (Japan) (Disc 2)") shouldBe
            listOf(texture(58, 1234, "support-texture(jp)[2]", "Japan"), texture(58, 1234, "support-texture(eu)[2]", "Europe"))
        table.texturesOf("Okage (Europe)").shouldBeEmpty()
        TextureTable.EMPTY.texturesOf("Okage (USA)").shouldBeEmpty()
    }

    @Test
    fun `INV-19 a texture's identity names its system, game and media, never a URL`() {
        texture(58, 195388, "support-texture(jp)[2]", "Japan").identity shouldBe Identity("ss:58:195388:support-texture(jp)[2]")
    }

    @Test
    fun `a texture of no region the app knows, and a line of no game id, are left out`() {
        val table = TextureTable.parse("# 2026-10-18\nA\t1\tss cus us\nB\tnone\tus\nC\t2\n", ps2)
        table.texturesOf("A") shouldBe listOf(texture(58, 1, "support-texture(us)", "USA"))
        table.texturesOf("B").shouldBeEmpty()
        table.texturesOf("C").shouldBeEmpty()
    }

    @Test
    fun `every region the table may name is one the app ranks`() {
        val unknown = Regions.rank(emptyList(), "Atlantis")
        TextureTable.REGIONS.values.forEach { Regions.rank(emptyList(), it) shouldBeLessThan unknown }
    }

    @Test
    fun `every region code the shipped tables use is one the app maps, or one it leaves out on purpose`() {
        val codes =
            Shipped
                .lists("screenscraper")
                .values
                .flatMap { text -> text.lines().filterNot { it.startsWith("#") || it.isBlank() } }
                .flatMap { line -> line.split('\t').drop(2).flatMap { it.split(' ') } }
                .map { it.substringBefore('[') }
                .filter { it.isNotEmpty() }
                .toSet()
        codes.shouldNotBeEmpty()
        // `ss` is ScreenScraper's own, `cus` custom, `c` and `cc` of no region.
        (codes - TextureTable.REGIONS.keys - setOf("ss", "cus", "c", "cc")).shouldBeEmpty()
        TextureTable.parse("# 2026-10-18\nA\t1\tc cc us\n", ps2).texturesOf("A") shouldBe
            listOf(texture(58, 1, "support-texture(us)", "USA"))
    }

    @Test
    fun `reading any text never fails`() = runBlocking<Unit> {
        checkAll(Arb.string()) { text -> TextureTable.parse(text, ps2).size shouldBeGreaterThan -1 }
    }

    @Test
    fun `INV-17 every shipped table is dated, belongs to a platform whose profile names its system, and reads whole`() {
        val tables = Shipped.lists("screenscraper")
        tables.mapShouldNotBeEmpty()
        tables.forEach { (platform, text) ->
            val system = Shipped.catalog.platform(platform).shouldBeSome().profile.screenScraperSystem.shouldBeSome()
            val table = TextureTable.parse(text, system)
            table.version.shouldBeSome()
            table.size shouldBe text.lines().count { it.isNotBlank() && !it.startsWith("#") }
        }
        TextureTable.parse(tables.getValue(PlatformId("ps2")), ps2).texturesOf("Okage - Shadow King (USA)").shouldNotBeEmpty()
    }
}
