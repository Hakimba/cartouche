// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.art.regionNames
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.toOption
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldBeIn
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.flatMap
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.orNull
import io.kotest.property.arbitrary.shuffle
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class MediaRuleTest {
    private val pal = Arb.element("Europe", "France", "UK", "Australia", "Scandinavia")
    private val americas = Arb.element("USA", "United States", "Canada", "Brazil", "Latin America")
    private val eastAsia = Arb.element("Japan", "Korea", "Asia", "Taiwan")
    private val neutral = Arb.element("World", "", "Atlantis")

    private fun medium(): Arb<Option<MediumId>> = Arb.element("a", "b", "c").orNull(0.4).map { it.toOption().map(::mediumId) }

    private val rules: Arb<MediaRule> = Arb.bind(Arb.element("d", "a"), medium(), medium()) { d, u, j -> MediaRule(mediumId(d), u, j) }

    /** [regions] with [region] put among them at [at]. */
    private fun among(regions: List<String>, region: String, at: Int) = regions.toMutableList().apply { add(at % (size + 1), region) }

    @Test
    fun `every game gets a medium its platform declares, whatever its regions`() = runBlocking<Unit> {
        checkAll(rules, Arb.list(regionNames, 0..4)) { rule, regions ->
            rule.of(regions) shouldBeIn listOf(rule.default) + rule.ntscU.toList() + rule.ntscJ.toList()
        }
    }

    @Test
    fun `a game sold in PAL lands takes the default, then the Americas' medium before East Asia's`() = runBlocking<Unit> {
        val others = Arb.list(Arb.element(listOf("USA", "Japan", "Korea", "Canada", "World", "")), 0..3)
        checkAll(rules, others, pal, Arb.int(0..3)) { rule, regions, region, at ->
            rule.of(among(regions, region, at)) shouldBe rule.default
        }
        val notPal = Arb.list(Arb.element(listOf("Japan", "Korea", "World", "", "Atlantis")), 0..3)
        checkAll(rules, notPal, americas, Arb.int(0..3)) { rule, regions, region, at ->
            rule.of(among(regions, region, at)) shouldBe rule.ntscU.getOrElse { rule.default }
        }
        checkAll(rules, Arb.list(neutral, 0..3), eastAsia, Arb.int(0..3)) { rule, regions, region, at ->
            rule.of(among(regions, region, at)) shouldBe rule.ntscJ.getOrElse { rule.default }
        }
    }

    @Test
    fun `a game of no known region takes the default, and the order of its regions does not matter`() = runBlocking<Unit> {
        checkAll(rules, Arb.list(neutral, 0..3)) { rule, regions -> rule.of(regions) shouldBe rule.default }
        val shuffled = Arb.list(regionNames, 0..4).flatMap { regions -> Arb.shuffle(regions).map { regions to it } }
        checkAll(rules, shuffled) { rule, (regions, shuffled) ->
            rule.of(shuffled) shouldBe rule.of(regions)
        }
    }

    @Test
    fun `a medium is declared under the keys of the profiles file, overrides left out when none`() {
        val text = """{"p": {"media": "cartridge", "medium": {"default": "nes_cart", "ntsc_j": "famicom_cart"}, "minimumGameBytes": 1}}"""
        val parsed = Catalog.parse(listOf(definition(platform = "p")), DefinitionSource("profiles.json", text))
        parsed.platform(PlatformId("p")).shouldBeSome().profile.medium shouldBe
            MediaRule(mediumId("nes_cart"), None, Some(mediumId("famicom_cart")))
    }

    @Test
    fun `a medium is never blank, a profile declaring a blank one refused`() = runBlocking<Unit> {
        checkAll(Arb.choice(Arb.element("", " ", "\t\n", " a "), Arb.string(0..8))) { text ->
            MediumId.of(text).map(MediumId::value) shouldBe if (text.any { !it.isWhitespace() }) Some(text) else None
        }
        listOf("", " ").forEach { blank ->
            val text = """{"p": {"media": "cartridge", "medium": {"default": "$blank"}, "minimumGameBytes": 1}}"""
            Catalog.parse(listOf(definition(platform = "p")), DefinitionSource("profiles.json", text)).platforms.shouldBeEmpty()
        }
    }
}
