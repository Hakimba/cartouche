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

class AbsencesTest {
    private fun request(game: String, version: Option<String>) =
        ArtRequest(GameId("ps2/$game"), game, nonEmptyListOf(web("https://a/$game.png")), version.map(::ArtVersion), PS2_DISC)

    private fun Absences<GameId>.with(request: ArtRequest): Absences<GameId> = with(request.game, request.version)

    private fun Absences<GameId>.coversGameOf(request: ArtRequest): Boolean = covers(request.game, request.version)

    @Test
    fun `INV-17 a game is absent from the version it was last looked for in, and from no other`() = runBlocking<Unit> {
        val games = Arb.element("a", "b", "c")
        val versions = Arb.element(Some("2026-09-28"), Some("2026-10-01"), None)
        checkAll(Arb.list(Arb.pair(games, versions), 0..5), games, versions) { looked, game, version ->
            val absent = looked.fold(Absences<GameId>()) { all, (a, v) -> all.with(request(a, v)) }
            // Sources of no version are never remembered, and never make a game absent.
            val last = looked.filter { it.second.isSome() }.lastOrNone { it.first == game }.flatMap { it.second }
            absent.covers(GameId("ps2/$game"), version.map(::ArtVersion)) shouldBe (version.isSome() && last == version)
        }
    }

    @Test
    fun `what is stored reads back the same, games and textures alike, and an unreadable text is none`() = runBlocking<Unit> {
        checkAll(
            Arb.list(Arb.element("a", "b", "c", "ps2/content://x"), 0..6),
            Arb.list(Arb.element("2026-09-28", "2026-10-01"), 6..6),
        ) { games, versions ->
            val absent = games.foldIndexed(Absences<GameId>()) { i, all, game -> all.with(request(game, Some(versions[i]))) }
            Absences.decode(Absences.encode(absent, GameId.serializer()), GameId.serializer()).shouldBeSome() shouldBe absent
        }
        Absences.decode("{broken", GameId.serializer()).shouldBeNone()
        // A texture ScreenScraper has none of, remembered by its identity for the sources' version.
        val missing = Absences<Identity>().with(Identity("ss:58:1234:support-texture(jp)"), Some(ArtVersion("2026-09-28 2026-10-18")))
        Absences.decode(Absences.encode(missing, Identity.serializer()), Identity.serializer()).shouldBeSome() shouldBe missing
        missing.covers(Identity("ss:58:1234:support-texture(jp)"), Some(ArtVersion("2026-09-28 2026-10-18"))) shouldBe true
        missing.covers(Identity("ss:58:1234:support-texture(jp)"), Some(ArtVersion("2026-09-28 2026-11-01"))) shouldBe false
    }

    @Test
    fun `INV-13 only the games kept stay absent, as they were`() = runBlocking<Unit> {
        val names = Arb.list(Arb.element("a", "b", "c", "d"), 0..4)
        checkAll(names, names, Arb.element("a", "b", "c", "d")) { absentOnes, kept, game ->
            val absent = absentOnes.fold(Absences<GameId>()) { all, name -> all.with(request(name, Some("2026-09-28"))) }
            val asked = request(game, Some("2026-09-28"))
            absent.keeping(kept.map { GameId("ps2/$it") }.toSet()).coversGameOf(asked) shouldBe (game in kept && absent.coversGameOf(asked))
        }
    }
}
