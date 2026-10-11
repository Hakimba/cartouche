// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.BitmapFactory
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.GameId
import arrow.core.Some
import arrow.core.toNonEmptyListOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.GraphicsMode
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScraperTest {
    /** What the server holds at a URL. */
    private enum class Held { IMAGE, NOT_AN_IMAGE, NOTHING, REFUSAL }

    private sealed interface Step {
        data class LookFor(val games: Int) : Step

        data class Network(val online: Boolean) : Step

        data object Stop : Step

        /** A scan, and the app leaving the screen before its downloads start. */
        data class LookForThenStop(val games: Int) : Step

        data object Start : Step

        data class Wait(val millis: Long) : Step
    }

    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
    private val image = scan(diameter = 40, margin = 4)
    private val version = ArtVersion("2026-09-28")

    private val steps: Arb<Step> =
        Arb.choice(
            Arb.int(0..6).map(Step::LookFor),
            Arb.element(true, false).map(Step::Network),
            Arb.constant(Step.Stop),
            Arb.int(1..6).map(Step::LookForThenStop),
            Arb.constant(Step.Start),
            Arb.long(0L..120_000L).map(Step::Wait),
        )

    /** A game's candidates: what the server holds at each, in order. */
    private val games: Arb<List<List<Held>>> = Arb.list(Arb.list(Arb.element(Held.entries), 1..3), 6..6)

    private fun requests(held: List<List<Held>>, count: Int): List<ArtRequest> = held.take(count).mapIndexed { game, candidates ->
        val artwork = candidates.indices.map { ArtUrl("https://art/$game/$it.png") }
        ArtRequest(GameId("ps2/$game"), "Game $game", artwork.toNonEmptyListOrNone().shouldBeSome(), Some(version), PS2_DISC)
    }

    private fun imageUrls(held: List<List<Held>>): Set<String> = held
        .flatMapIndexed {
            game,
            candidates,
            ->
            candidates.indices.filter { candidates[it] == Held.IMAGE }.map { "https://art/$game/$it.png" }
        }.toSet()

    private fun server(held: List<List<Held>>): FakeFetch {
        val urls = held.flatMapIndexed { game, candidates -> candidates.mapIndexed { i, what -> "https://art/$game/$i.png" to what } }
        return FakeFetch(
            images =
                urls.filter { it.second == Held.IMAGE }.associate { it.first to image } +
                    urls.filter { it.second == Held.NOT_AN_IMAGE }.associate { it.first to "<html/>".encodeToByteArray() },
            answers = urls.filter { it.second == Held.REFUSAL }.associate { it.first to FetchFailure.Refused(429) },
        )
    }

    @Test
    fun `INV-E4-03 INV-E4-05 whatever the network and the app do, an image is downloaded once, and only art no source has is given up`() =
        runBlocking<Unit> {
            var stored = 0
            checkAll(150, games, Arb.list(steps, 1..14)) { held, script ->
                folder.deleteRecursively()
                val scope = TestScope(StandardTestDispatcher())
                val store = ArtStore(folder)
                val fetch = server(held)
                var stopped = false
                // Games whose downloads were under way when the app stopped: only theirs may go on.
                var going = emptySet<String>()
                val askedWhileStopped = mutableListOf<String>()
                var last = Scraping.NONE
                val scraper = Scraper(store, fetch, scope) { run, _ -> last = run }
                script.forEach { step ->
                    val before = fetch.asked.size
                    when (step) {
                        is Step.LookFor -> scraper.lookFor(requests(held, step.games))
                        is Step.Network -> {
                            fetch.online = step.online
                            if (step.online) scraper.networkBack()
                        }
                        Step.Stop -> {
                            if (!stopped) going = last.underWay.map { it.game.value.substringAfter('/') }.toSet()
                            scraper.stop()
                            stopped = true
                        }
                        is Step.LookForThenStop -> {
                            if (!stopped) going = last.underWay.map { it.game.value.substringAfter('/') }.toSet()
                            scraper.lookFor(requests(held, step.games))
                            scraper.stop()
                            stopped = true
                        }
                        Step.Start -> scraper.start().also { stopped = false }
                        is Step.Wait -> scope.advanceTimeBy(step.millis)
                    }
                    scope.runCurrent()
                    // Downloads under way when it stops may end; none starts after.
                    if (stopped) {
                        askedWhileStopped +=
                            fetch.asked.drop(before).filter { it.substringAfter("art/").substringBefore('/') !in going }
                    }
                }
                askedWhileStopped.shouldBeEmpty()
                // Then the network is up and the app on screen, for as long as it takes.
                fetch.online = true
                scraper.start()
                scraper.lookFor(requests(held, held.size))
                // A server that keeps refusing is asked again for ever: time is let pass, not until nothing is left to do.
                scope.advanceTimeBy(3 * 60 * 60_000L)
                scope.runCurrent()
                fetch.served.entries
                    .filter { (url, _) -> url in imageUrls(held) }
                    .groupBy({ it.key.substringAfter("art/").substringBefore('/') }, { it.value })
                    .values
                    .forEach { it.sum() shouldBeLessThanOrEqual 1 }
                val all = requests(held, held.size)
                val absent = all.filter { store.isAbsent(it.game, it.version) }.map { it.game }.toSet()
                // At the next start, only the games neither stored nor absent are looked for.
                val restarted = FakeFetch(emptyMap())
                Scraper(ArtStore(folder), restarted, scope) { _, _ -> }.lookFor(all)
                scope.runCurrent()
                restarted.asked
                    .map { GameId("ps2/" + it.substringAfter("art/").substringBefore('/')) }
                    .filter { store.stored(it).isSome() || it in absent }
                    .shouldBeEmpty()
                held.forEachIndexed { game, candidates ->
                    val id = GameId("ps2/$game")
                    val reachable = candidates.takeWhile { it != Held.REFUSAL }
                    when {
                        Held.IMAGE in reachable -> store.stored(id).shouldBeSome().also { stored++ }
                        Held.REFUSAL in candidates -> {
                            store.stored(id).shouldBeNone()
                            (id in absent) shouldBe false
                        }
                        else -> (id in absent) shouldBe true
                    }
                }
            }
            stored shouldBeGreaterThan 100
        }

    @Test
    fun `INV-E4-06 stored images stay, and are found without waiting, whatever the network does`() {
        val store = ArtStore(folder)
        val art = store.save(GameId("ps2/0"), image).shouldBeRight()
        val scope = TestScope(StandardTestDispatcher())
        val fetch = FakeFetch(emptyMap()).apply { online = false }
        val changes = mutableListOf<Scraping>()
        Scraper(store, fetch, scope) { run, _ -> changes += run }.lookFor(requests(listOf(listOf(Held.IMAGE), listOf(Held.IMAGE)), 2))
        scope.runCurrent()
        store.stored(GameId("ps2/0")) shouldBe Some(art)
        ArtStore(folder).stored(GameId("ps2/0")) shouldBe Some(art)
        fetch.asked.map { it.substringAfter("art/").substringBefore('/') }.toSet() shouldBe setOf("1")
        changes.last().stall shouldBe Some(Stall.OFFLINE)
    }

    /** A scraper of [fetch] on a test clock, and the last run it told of. */
    private class Harness(store: ArtStore, fetch: FakeFetch) {
        val scope = TestScope(StandardTestDispatcher())
        var last = Scraping.NONE
        val scraper = Scraper(store, fetch, scope) { run, _ -> last = run }
    }

    private fun url(game: Int, candidate: Int) = "https://art/$game/$candidate.png"

    @Test
    fun `a stop during a download sets its game aside, asks none of its other scans, and looks for it first at the next start`() {
        val store = ArtStore(folder)
        val fetch = FakeFetch(mapOf(url(0, 1) to image))
        val harness = Harness(store, fetch)
        fetch.during = { if (it.value == url(0, 0)) harness.scraper.stop() }
        harness.scraper.lookFor(requests(listOf(listOf(Held.NOTHING, Held.IMAGE), listOf(Held.IMAGE)), 2))
        harness.scope.runCurrent()
        fetch.asked shouldBe listOf(url(0, 0))
        harness.last.waiting.map { it.game } shouldBe listOf(GameId("ps2/0"), GameId("ps2/1"))
        fetch.during = {}
        harness.scraper.start()
        harness.scope.runCurrent()
        fetch.asked.drop(1).first() shouldBe url(0, 0)
        store.stored(GameId("ps2/0")).shouldBeSome()
        requests(listOf(listOf(Held.NOTHING, Held.IMAGE)), 1).single().let { store.isAbsent(it.game, it.version) } shouldBe false
    }

    @Test
    fun `INV-E4-05 an offline run resumes as soon as the network is back, before its delay`() {
        val store = ArtStore(folder)
        val fetch = FakeFetch(mapOf(url(0, 0) to image)).apply { online = false }
        val harness = Harness(store, fetch)
        harness.scraper.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
        harness.scope.runCurrent()
        harness.last.stall shouldBe Some(Stall.OFFLINE)
        fetch.online = true
        harness.scraper.networkBack()
        harness.scope.runCurrent()
        store.stored(GameId("ps2/0")).shouldBeSome()
    }

    @Test
    fun `INV-E4-05 a busy server is asked again after 30 s, not when the network comes back`() {
        val store = ArtStore(folder)
        val fetch = FakeFetch(emptyMap(), mapOf(url(0, 0) to FetchFailure.Refused(429)))
        val harness = Harness(store, fetch)
        harness.scraper.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
        harness.scope.runCurrent()
        harness.last.stall shouldBe Some(Stall.REFUSED)
        fetch.images = mapOf(url(0, 0) to image)
        fetch.answers = emptyMap()
        harness.scraper.networkBack()
        harness.scope.advanceTimeBy(29_999)
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 1
        harness.scope.advanceTimeBy(2)
        harness.scope.runCurrent()
        store.stored(GameId("ps2/0")).shouldBeSome()
    }

    @Test
    fun `INV-E4-05 no room to store a scan stalls the run and never gives the game up`() {
        folder.deleteRecursively()
        folder.writeText("a file where the folder should be")
        val store = ArtStore(folder)
        val fetch = FakeFetch(mapOf(url(0, 0) to image))
        val harness = Harness(store, fetch)
        val request = requests(listOf(listOf(Held.IMAGE)), 1)
        harness.scraper.lookFor(request)
        harness.scope.runCurrent()
        harness.last.stall shouldBe Some(Stall.STORAGE)
        request.single().let { store.isAbsent(it.game, it.version) } shouldBe false
    }

    @Test
    fun `INV-E10-06 a cartridge's scan is stored as its label alone, a scan of no front's shape passed over for the next`() {
        val store = ArtStore(folder)
        val scope = TestScope(StandardTestDispatcher())
        val cartridge = requests(listOf(listOf(Held.IMAGE, Held.IMAGE)), 1).map { it.copy(cut = cartridgeLabel) }
        // A square photo first, of no shape the cartridge's front has.
        val fetch = FakeFetch(mapOf(url(0, 0) to png(300, 300), url(0, 1) to cartridgeFront()))
        Scraper(store, fetch, scope) { _, _ -> }.lookFor(cartridge)
        scope.runCurrent()
        val label = BitmapFactory.decodeFile(store.stored(GameId("ps2/0")).shouldBeSome().file.path)
        (label.width to label.height) shouldBe (280 to 120)
    }

    @Test
    fun `an image chosen by the user while its game's download runs stays`() {
        val store = ArtStore(folder)
        val chosen = byteArrayOf(7, 7, 7)
        val fetch = FakeFetch(mapOf(url(0, 0) to image))
        fetch.during = { store.save(GameId("ps2/0"), chosen).shouldBeRight() }
        val found = mutableListOf<FoundArt>()
        val scope = TestScope(StandardTestDispatcher())
        val scraper = Scraper(store, fetch, scope) { _, art -> found += art.toList() }
        scraper.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
        scope.runCurrent()
        val kept = store.stored(GameId("ps2/0")).shouldBeSome()
        kept.file.readBytes() shouldBe chosen
        found shouldBe listOf(FoundArt(GameId("ps2/0"), kept))
    }
}
