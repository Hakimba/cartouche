// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.lastOrNone
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.pair
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class AbsentArtTest {
    private fun request(game: String, version: Option<String>) =
        ArtRequest(GameId("ps2/$game"), game, nonEmptyListOf(ArtUrl("https://a/$game.png")), version.map(::ArtVersion), PS2_DISC)

    private fun AbsentArt.coversGameOf(request: ArtRequest): Boolean = covers(request.game, request.version)

    @Test
    fun `INV-E4-05 a game is absent only from the version of the sources it was looked for in`() {
        val absent = AbsentArt().with(request("a", Some("2026-09-28")))
        absent.coversGameOf(request("a", Some("2026-09-28"))) shouldBe true
        absent.coversGameOf(request("a", Some("2026-10-01"))) shouldBe false
        absent.coversGameOf(request("b", Some("2026-09-28"))) shouldBe false
        absent.with(request("a", Some("2026-10-01"))).coversGameOf(request("a", Some("2026-09-28"))) shouldBe false
    }

    @Test
    fun `a game is absent from the version it was last looked for in, and from no other`() = runBlocking<Unit> {
        val games = Arb.element("a", "b", "c")
        val versions = Arb.element(Some("2026-09-28"), Some("2026-10-01"), None)
        checkAll(Arb.list(Arb.pair(games, versions), 0..5), games, versions) { looked, game, version ->
            val absent = looked.fold(AbsentArt()) { all, (a, v) -> all.with(request(a, v)) }
            // Sources of no version are never remembered, and never make a game absent.
            val last = looked.filter { it.second.isSome() }.lastOrNone { it.first == game }.flatMap { it.second }
            absent.covers(GameId("ps2/$game"), version.map(::ArtVersion)) shouldBe (version.isSome() && last == version)
        }
    }

    @Test
    fun `INV-E4-05 sources of no version never make a game absent`() {
        AbsentArt().with(request("a", None)).coversGameOf(request("a", None)) shouldBe false
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

    @Test
    fun `INV-E6-03 only the games kept stay absent, as they were`() = runBlocking<Unit> {
        val names = Arb.list(Arb.element("a", "b", "c", "d"), 0..4)
        checkAll(names, names, Arb.element("a", "b", "c", "d")) { absentOnes, kept, game ->
            val absent = absentOnes.fold(AbsentArt()) { all, name -> all.with(request(name, Some("2026-09-28"))) }
            val asked = request(game, Some("2026-09-28"))
            absent.keeping(kept.map { GameId("ps2/$it") }.toSet()).coversGameOf(asked) shouldBe (game in kept && absent.coversGameOf(asked))
        }
    }
}
