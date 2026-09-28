// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class AbsentArtTest {
    private fun request(game: String, version: Option<String>) =
        ArtRequest(GameId("ps2/$game"), game, nonEmptyListOf(ArtUrl("https://a/$game.png")), version.map(::ArtVersion))

    @Test
    fun `INV-E4-05 a game is absent only from the version of the sources it was looked for in`() {
        val absent = AbsentArt().with(request("a", Some("2026-09-28")))
        absent.covers(request("a", Some("2026-09-28"))) shouldBe true
        absent.covers(request("a", Some("2026-10-01"))) shouldBe false
        absent.covers(request("b", Some("2026-09-28"))) shouldBe false
        absent.with(request("a", Some("2026-10-01"))).covers(request("a", Some("2026-09-28"))) shouldBe false
    }

    @Test
    fun `INV-E4-05 sources of no version never make a game absent`() {
        AbsentArt().with(request("a", None)).covers(request("a", None)) shouldBe false
    }

    @Test
    fun `what is stored reads back the same, and an unreadable text is none`() = runBlocking<Unit> {
        checkAll(
            Arb.list(Arb.element("a", "b", "c", "ps2/content://x"), 0..6),
            Arb.list(Arb.element("2026-09-28", "2026-10-01"), 6..6),
        ) { games, versions ->
            val absent = games.foldIndexed(AbsentArt()) { i, all, game -> all.with(request(game, Some(versions[i]))) }
            AbsentArt.decode(AbsentArt.encode(absent)).shouldBeSome() shouldBe absent
        }
        AbsentArt.decode("{broken").shouldBeNone()
    }
}
