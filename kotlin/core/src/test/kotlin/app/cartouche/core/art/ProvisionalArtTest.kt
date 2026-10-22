// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.lastOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.pair
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ProvisionalArtTest {
    private val games = Arb.element("a", "b", "c", "ps2/content://x")

    @Test
    fun `a game shows the last image it was remembered with, until settled, and what is stored reads back the same`() = runBlocking<Unit> {
        checkAll(
            Arb.list(Arb.pair(games, Arb.element("lb", "ss:58:1:t", "").map(::Identity)), 0..6),
            games,
            Arb.list(games, 0..3),
        ) { shown, game, settled ->
            val remembered = shown.fold(ProvisionalArt()) { all, (g, identity) -> all.with(GameId(g), identity) }
            val after = settled.fold(remembered) { all, g -> all.without(GameId(g)) }
            val expected = shown.lastOrNone { it.first == game }.map { it.second }.filter { game !in settled }
            after.shown(GameId(game)) shouldBe expected
            ProvisionalArt.decode(ProvisionalArt.encode(after)).shouldBeSome() shouldBe after
            after.keeping(setOf(GameId(game))).shown(GameId(game)) shouldBe after.shown(GameId(game))
            after.keeping(emptySet()).shown(GameId(game)).shouldBeNone()
        }
        ProvisionalArt.decode("{broken").shouldBeNone()
    }

    @Test
    fun `keeping one provisional game removes every other marked game`() = runBlocking<Unit> {
        checkAll(Arb.element("a", "b", "c"), Arb.element("lb", "ss:58:1:t")) { name, image ->
            val kept = GameId("kept/$name")
            val gone = GameId("gone/$name")
            val after = ProvisionalArt().with(kept, Identity(image)).with(gone, Identity("other")).keeping(setOf(kept))
            after.shown(kept).shouldBeSome() shouldBe Identity(image)
            after.shown(gone).shouldBeNone()
        }
    }
}
