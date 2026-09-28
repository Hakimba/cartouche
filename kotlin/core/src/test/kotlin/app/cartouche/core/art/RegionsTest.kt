// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import io.kotest.matchers.collections.shouldBeSortedWith
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class RegionsTest {
    private fun order(game: List<String>, images: List<String>) = images.sortedBy { Regions.rank(game, it) }

    @Test
    fun `INV-E4-01 a French game prefers a French image, then European ones, the world, America, then Japan`() {
        order(listOf("France"), listOf("Japan", "North America", "World", "United Kingdom", "Europe", "France")) shouldBe
            listOf("France", "Europe", "United Kingdom", "World", "North America", "Japan")
    }

    @Test
    fun `a Japanese game prefers Japan, then Asia, then the world, America and Europe`() {
        order(listOf("Japan"), listOf("Europe", "North America", "", "Korea", "Japan")) shouldBe
            listOf("Japan", "Korea", "", "North America", "Europe")
    }

    @Test
    fun `Redump's and LaunchBox's names of a region are the same region`() {
        Regions.rank(listOf("USA"), "North America") shouldBe 0
        Regions.rank(listOf("USA"), "United States") shouldBe 0
        Regions.rank(listOf("UK"), "United Kingdom") shouldBe 0
    }

    @Test
    fun `INV-E4-01 an image of one of the game's regions comes first, and the world before the other groups`() = runBlocking<Unit> {
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
    fun `a game of no region takes the world first, then America, Europe and Japan`() {
        val ranks = listOf("World", "North America", "Europe", "Japan", "Atlantis").map { Regions.rank(emptyList(), it) }
        ranks shouldBeSortedWith compareBy { it }
        ranks.distinct().size shouldBe ranks.size
    }
}
