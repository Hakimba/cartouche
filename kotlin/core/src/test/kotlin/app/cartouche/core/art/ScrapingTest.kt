// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds

class ScrapingTest {
    private sealed interface Step {
        /** A scan: the games of [games] that have no art are looked for. */
        data class Rescan(val games: Set<Int>) : Step

        data object Take : Step

        /** The request under way picked by [pick] found its art, or none. */
        data class Finish(val pick: Int) : Step

        /** The request under way picked by [pick] stalled for [why]. */
        data class Halt(val pick: Int, val why: Stall) : Step

        data object Resume : Step

        /** The request under way picked by [pick] was set aside before its end. */
        data class Return(val pick: Int) : Step

        /** The games on screen: their requests go first. */
        data class Focus(val games: List<Int>) : Step
    }

    /** [game]'s request, as the scan numbered [scan] plans it. */
    private fun request(game: Int, scan: Int = 0) =
        ArtRequest(GameId("ps2/$game"), "Game $game, scan $scan", nonEmptyListOf(web("https://a/$game.png")), None, PS2_DISC)

    private val steps: Arb<Step> =
        Arb.choice(
            Arb.list(Arb.int(0..7), 0..8).map { Step.Rescan(it.toSet()) },
            Arb.constant(Step.Take),
            Arb.constant(Step.Take),
            Arb.int(0..7).map(Step::Finish),
            Arb.bind(Arb.int(0..7), Arb.enum<Stall>(), Step::Halt),
            Arb.constant(Step.Resume),
            Arb.int(0..7).map(Step::Return),
            Arb.list(Arb.int(0..7), 0..3).map(Step::Focus),
        )

    @Test
    fun `INV-E4-03 INV-E6-03 a game is under way once at most, not looked for once done or dropped, and a resumed run asks for the rest`() =
        runBlocking<Unit> {
            var finished = 0
            checkAll(Arb.list(steps, 1..40)) { script ->
                var run = Scraping.NONE
                // The model: the games whose art was found, which no scan asks for again, and the last scan's requests.
                val found = mutableSetOf<GameId>()
                var scans = 0
                var planned = emptyList<ArtRequest>()
                val scanned = { planned.map { it.game } }
                script.forEach { step ->
                    when (step) {
                        is Step.Rescan -> {
                            scans++
                            planned = step.games.map { request(it, scans) }.filter { it.game !in found }
                            run = run.with(planned)
                        }
                        Step.Take -> {
                            val taken = run.take()
                            taken.isSome() shouldBe (run.stall.isNone() && run.waiting.isNotEmpty())
                            taken.onSome { (request, next) ->
                                request shouldBe run.waiting.first()
                                run = next
                            }
                        }
                        is Step.Finish ->
                            run.underWay.getOrNone(step.pick).onSome {
                                run = run.finished(it.game)
                                found += it.game
                                finished++
                            }
                        is Step.Halt ->
                            run.underWay.getOrNone(step.pick).onSome {
                                run = run.stalled(it.game, step.why)
                                // It waits again, last, as the last scan asks for it, unless that scan no longer does.
                                (it.game in run.waiting.map { w -> w.game }) shouldBe (it.game in scanned())
                                if (it.game in scanned()) run.waiting.last() shouldBe planned.first { p -> p.game == it.game }
                                run.stall shouldBe Some(step.why)
                            }
                        Step.Resume -> run = run.resumed()
                        is Step.Return ->
                            run.underWay.getOrNone(step.pick).onSome {
                                val stall = run.stall
                                run = run.returned(it.game)
                                (it.game in run.waiting.map { w -> w.game }) shouldBe (it.game in scanned())
                                if (it.game in scanned()) run.waiting.first() shouldBe planned.first { p -> p.game == it.game }
                                run.stall shouldBe stall
                            }
                        is Step.Focus -> {
                            val before = run
                            val focused = step.games.map { GameId("ps2/$it") }
                            run = run.ahead(focused)
                            // The same requests wait, the focused ones first in the order given, the others in theirs.
                            run.waiting.toSet() shouldBe before.waiting.toSet()
                            val first = focused.distinct().flatMap { game -> before.waiting.filter { it.game == game } }
                            run.waiting shouldBe first + (before.waiting - first.toSet())
                            (run.underWay to run.stall) shouldBe (before.underWay to before.stall)
                            run.total shouldBe before.total
                        }
                    }
                    val looked = (run.waiting + run.underWay).map { it.game }
                    looked.distinct() shouldBe looked
                    looked.filter { it in found }.shouldBeEmpty()
                    run.total shouldBe run.done + run.waiting.size + run.underWay.size
                }
                val underWay = run.underWay.map { it.game }
                run = run.resumed()
                val asked = mutableListOf<GameId>()
                var taken = run.take()
                while (taken is Some) {
                    asked += taken.value.first.game
                    run = taken.value.second
                    taken = run.take()
                }
                // Only what the last scan asks for: a game it dropped is not looked for again.
                asked.filter { it in found || it !in scanned() }.shouldBeEmpty()
                scanned().filter { it !in found && it !in asked + underWay }.shouldBeEmpty()
            }
            finished shouldBeGreaterThan 100
        }

    @Test
    fun `INV-E4-05 a stall waits 30 s, twice as long with each one in a row up to 15 min, and 30 s again once a game is done`() {
        var run = Scraping.NONE.with((0..20).map(::request))
        val delays =
            (0..8).map {
                val (request, next) = run.resumed().take().shouldBeSome()
                run = next.stalled(request.game, Stall.OFFLINE)
                run.retryDelay
            }
        delays shouldBe listOf(30.seconds, 60.seconds, 2.minutes, 4.minutes, 8.minutes, 15.minutes, 15.minutes, 15.minutes, 15.minutes)
        val (request, next) = run.resumed().take().shouldBeSome()
        run = next.finished(request.game)
        val (again, after) = run.take().shouldBeSome()
        after.stalled(again.game, Stall.REFUSED).retryDelay shouldBe 30.seconds
    }

    @Test
    fun `INV-E4-05 requests that stall together are one stall`() {
        val (first, one) = Scraping.NONE.with((0..2).map(::request)).take().shouldBeSome()
        val (second, two) = one.take().shouldBeSome()
        two.stalled(first.game, Stall.OFFLINE).stalled(second.game, Stall.OFFLINE).retryDelay shouldBe 30.seconds
    }

    @Test
    fun `a run that was over starts again from nothing done`() {
        val (request, next) = Scraping.NONE.with(listOf(request(1))).take().shouldBeSome()
        val over = next.finished(request.game)
        over.isOver shouldBe true
        over.with(listOf(request(2))).let {
            it.done shouldBe 0
            it.total shouldBe 1
        }
        Scraping.NONE.take().shouldBeNone()
    }

    private fun <T> List<T>.getOrNone(pick: Int): Option<T> = if (isEmpty()) None else Some(this[pick % size])
}
