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

    private fun texture(game: Int, media: String, region: String) =
        Candidate.Texture(ps2, ScreenScraperGame(game), TextureMedia(media), region)

    @Test
    fun `a release's textures are its game's, one per region and disc, under the app's region names`() {
        val table = TextureTable.parse("# 2026-10-18\nOkage (USA)\t1234\tus jp\nOkage (Japan) (Disc 2)\t1234\tjp[2] eu[2]\n", ps2)
        table.version shouldBe Some(ArtVersion("2026-10-18"))
        table.size shouldBe 2
        table.texturesOf("Okage (USA)") shouldBe
            listOf(texture(1234, "support-texture(us)", "USA"), texture(1234, "support-texture(jp)", "Japan"))
        table.texturesOf("Okage (Japan) (Disc 2)") shouldBe
            listOf(texture(1234, "support-texture(jp)[2]", "Japan"), texture(1234, "support-texture(eu)[2]", "Europe"))
        table.texturesOf("Okage (Europe)").shouldBeEmpty()
        TextureTable.EMPTY.texturesOf("Okage (USA)").shouldBeEmpty()
    }

    @Test
    fun `INV-E11-06 a texture's identity names its system, game and media, never a URL`() {
        texture(195388, "support-texture(jp)[2]", "Japan").identity shouldBe Identity("ss:58:195388:support-texture(jp)[2]")
    }

    @Test
    fun `a texture of no region the app knows, and a line of no game id, are left out`() {
        val table = TextureTable.parse("# 2026-10-18\nA\t1\tss cus us\nB\tnone\tus\nC\t2\n", ps2)
        table.texturesOf("A") shouldBe listOf(texture(1, "support-texture(us)", "USA"))
        table.texturesOf("B").shouldBeEmpty()
        table.texturesOf("C").shouldBeEmpty()
    }

    @Test
    fun `INV-E11-07 every region the table may name is one the app ranks, France inside Europe and apart from Germany`() {
        val unknown = Regions.rank(emptyList(), "Atlantis")
        TextureTable.regionNames.forEach { Regions.rank(emptyList(), it) shouldBeLessThan unknown }
        // Of a French game's region: France and Europe, not Germany, which is only of its group.
        Regions.isOwn(listOf("France"), "France") shouldBe true
        Regions.isOwn(listOf("France"), "Europe") shouldBe true
        Regions.isOwn(listOf("France"), "Germany") shouldBe false
        Regions.rank(listOf("France"), "Germany") shouldBe 2
        // A zone's umbrella is not a country's outside it; a country's own zone is.
        Regions.isOwn(listOf("Korea"), "Japan") shouldBe false
        Regions.isOwn(listOf("Korea"), "Asia") shouldBe true
        Regions.isOwn(listOf("Brazil"), "North America") shouldBe false
        Regions.isOwn(listOf("Brazil"), "South America") shouldBe true
        Regions.isOwn(listOf("Australia"), "Oceania") shouldBe true
        Regions.isOwn(listOf("Australia"), "Europe") shouldBe false
        Regions.isOwn(listOf("USA"), "North America") shouldBe true
        Regions.isOwn(listOf("World"), "World") shouldBe true
        Regions.isOwn(emptyList(), "World") shouldBe false
        Regions.isOwn(listOf("France"), "") shouldBe false
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
        (codes - TextureTable.regionCodes - TextureTable.SKIPPED_CODES).shouldBeEmpty()
        TextureTable.parse("# 2026-10-18\nA\t1\tc cc us\n", ps2).texturesOf("A") shouldBe listOf(texture(1, "support-texture(us)", "USA"))
    }

    @Test
    fun `reading any text never fails`() = runBlocking<Unit> {
        checkAll(Arb.string()) { text -> TextureTable.parse(text, ps2).size shouldBeGreaterThan -1 }
    }

    @Test
    fun `INV-E11-04 every shipped table is dated, belongs to a platform whose profile names its system, and reads whole`() {
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

    @Test
    fun `ScreenScraper region codes keep the documented country and zone names`() {
        val table = TextureTable.parse("# 2026-10-18\nRegions\t7\tfr de eu ame asi au oce br wor\n", ps2)
        table.texturesOf("Regions") shouldBe
            listOf(
                texture(7, "support-texture(fr)", "France"),
                texture(7, "support-texture(de)", "Germany"),
                texture(7, "support-texture(eu)", "Europe"),
                texture(7, "support-texture(ame)", "North America"),
                texture(7, "support-texture(asi)", "Asia"),
                texture(7, "support-texture(au)", "Australia"),
                texture(7, "support-texture(oce)", "Oceania"),
                texture(7, "support-texture(br)", "Brazil"),
                texture(7, "support-texture(wor)", "World"),
            )
    }
}
