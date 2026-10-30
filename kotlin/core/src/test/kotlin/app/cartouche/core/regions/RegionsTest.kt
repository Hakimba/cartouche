// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.regions

import app.cartouche.core.art.regionNames
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class RegionsTest {
    private fun order(game: List<String>, images: List<String>) = images.sortedBy { Regions.rank(game, it) }

    @Test
    fun `a game prefers its own region, then its zone, then the world, America, Europe and Japan`() {
        order(listOf("France"), listOf("Japan", "North America", "World", "United Kingdom", "Europe", "France")) shouldBe
            listOf("France", "Europe", "United Kingdom", "World", "North America", "Japan")
        order(listOf("Japan"), listOf("Europe", "North America", "", "Korea", "Japan")) shouldBe
            listOf("Japan", "Korea", "", "North America", "Europe")
        order(emptyList(), listOf("Atlantis", "Japan", "Europe", "North America", "World")) shouldBe
            listOf("World", "North America", "Europe", "Japan", "Atlantis")
    }

    @Test
    fun `Redump's and LaunchBox's names of a region are the same region`() {
        Regions.rank(listOf("USA"), "North America") shouldBe 0
        Regions.rank(listOf("USA"), "United States") shouldBe 0
        Regions.rank(listOf("UK"), "United Kingdom") shouldBe 0
    }

    @Test
    fun `an image of one of the game's regions comes first, and the world before the other groups`() = runBlocking<Unit> {
        checkAll(Arb.list(regionNames, 0..3), regionNames) { game, image ->
            if (image in game) Regions.rank(game, image) shouldBe 0
            if (image in setOf("World", "") && image !in game) {
                listOf("North America", "Europe", "Japan", "Atlantis")
                    .filter { other -> Regions.rank(game, other) > 2 }
                    .forEach { other -> Regions.rank(game, image) shouldBeLessThan Regions.rank(game, other) }
            }
        }
    }

    @Test
    fun `an image of the game's own region is one of its own or of its group, and a game of no region has none`() = runBlocking<Unit> {
        var own = 0
        checkAll(Arb.list(regionNames, 0..2), regionNames) { game, image ->
            if (Regions.isOwn(game, image)) {
                // Its country or its zone, never a region of another group nor the world of a game of a known region.
                Regions.rank(game, image) shouldBeLessThanOrEqual 2
                if (game.map(Regions::same).contains(Regions.same(image))) Regions.rank(game, image) shouldBe 0
                own++
            }
            if (game.isEmpty() || image.isEmpty()) Regions.isOwn(game, image) shouldBe false
        }
        own shouldBeGreaterThan 9
    }
}
