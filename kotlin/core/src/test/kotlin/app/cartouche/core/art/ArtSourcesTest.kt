// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.game
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ArtSourcesTest {
    private val index = ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png")))))

    private val bySerial = SerialScans.of("https://scans.test/{serial}.jpg")

    @Test
    fun `a game is looked for as the extract's scans, then those of its serials, in the sources' version`() {
        val okage = game("Okage").copy(serials = listOf("SCUS-97129"))
        val request = ArtSources(index, bySerial).requestFor(okage).shouldBeSome()
        request.title shouldBe "Okage"
        request.version shouldBe Some(ArtVersion("2026-09-28"))
        request.candidates.map { it.value.substringAfterLast('/') } shouldBe listOf("na.png", "jp.png", "SCUS-97129.jpg")
    }

    @Test
    fun `a game the extract does not know is looked for by its serials, and a game no source can have is not`() {
        ArtSources(index, bySerial).requestFor(game("Unknown").copy(serials = listOf("SLPS-25358"))).shouldBeSome().candidates.size shouldBe
            1
        ArtSources(index, bySerial).requestFor(game("Unknown")).shouldBeNone()
        ArtSources(index, None).requestFor(game("Unknown").copy(serials = listOf("SLPS-25358"))).shouldBeNone()
        ArtSources(ArtIndex.EMPTY, None).requestFor(game("Okage")).shouldBeNone()
    }

    @Test
    fun `INV-E7-03 a game whose label shows a chosen region is looked for in that region's scan first, among the same scans`() =
        runBlocking<Unit> {
            var moved = 0
            // Mostly a region of the game's scans, sometimes one it has no scan for; another game
            // beside it, whose scans must never come.
            checkAll(Arb.list(regionNames, 1..5), Arb.list(regionNames, 0..2), regionNames, Arb.int(0..6)) { discs, regions, other, pick ->
                val chosen = sameRegion(discs.getOrElse(pick) { other })
                val lines = discs.mapIndexed { i, region -> "$region=d$i.png" }
                val extract =
                    extract(listOf(ExtractGame("Okage", emptySet(), lines), ExtractGame("Okage 2", emptySet(), listOf("$chosen=o.png"))))
                val sources = ArtSources(ArtIndex.parse(extract), bySerial)
                val okage = game("Okage").copy(regions = regions, serials = listOf("SCUS-97129"))
                val automatic = sources.requestFor(okage).shouldBeSome().candidates
                val picked = sources.requestFor(okage.copy(label = LabelChoice.Region(LabelRegion(chosen)))).shouldBeSome().candidates
                // The first scan the extract lists for the chosen region, under any of its names.
                val first = discs.indexOfFirst { sameRegion(it) == chosen }
                val expected =
                    if (first <
                        0
                    ) {
                        automatic
                    } else {
                        automatic.first { it.value.endsWith("/d$first.png") }.let { listOf(it) + (automatic - it) }
                    }
                picked shouldBe expected
                if (picked != automatic) moved++
            }
            moved shouldBeGreaterThan 200
        }

    @Test
    fun `INV-E7-04 a game whose label is a picture of the user's own is never looked for, whatever its sources have`() = runBlocking<Unit> {
        var withScans = 0
        checkAll(Arb.list(regionNames, 0..5), Arb.list(regionNames, 0..2), Arb.list(Arb.element("SCUS-97129", "SLPS-25358"), 0..2)) {
            discs,
            regions,
            serials,
            ->
            val extract = extract(listOf(ExtractGame("Okage", emptySet(), discs.mapIndexed { i, region -> "$region=d$i.png" })))
            val okage = game("Okage").copy(regions = regions, serials = serials)
            val sources = ArtSources(ArtIndex.parse(extract), bySerial)
            if (sources.requestFor(okage).isSome()) withScans++
            sources.requestFor(okage.copy(label = LabelChoice.Own)).shouldBeNone()
        }
        // Mostly games the sources do have scans for, which an automatic label would get.
        withScans shouldBeGreaterThan 500
    }
}
