// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.BitmapFactory
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Closure
import app.cartouche.core.art.Identity
import app.cartouche.core.art.LookAgain
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.ScreenScraperGame
import app.cartouche.core.art.ScreenScraperState
import app.cartouche.core.art.Stall
import app.cartouche.core.art.TextureMedia
import app.cartouche.core.art.TextureTable
import app.cartouche.core.art.web
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.ScreenScraperSystem
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.nonEmptyListOf
import arrow.core.toNonEmptyListOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldBeIn
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldNotContain
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
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
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
import org.robolectric.shadows.ShadowLog
import java.io.File
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScraperTest {
    /** What the server holds at a URL. */
    private enum class Held { IMAGE, NOT_AN_IMAGE, NOTHING, REFUSAL, SKIPPED }

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
        val artwork = candidates.indices.map { web("https://art/$game/$it.png") }
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
            answers =
                urls.filter { it.second == Held.REFUSAL }.associate { it.first to FetchFailure.Refused(429) } +
                    urls.filter { it.second == Held.SKIPPED }.associate { it.first to skipped },
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
                        is Step.LookFor -> scope.launch { scraper.lookFor(requests(held, step.games)) }
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
                            scope.launch { scraper.lookFor(requests(held, step.games)) }
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
                scope.launch { scraper.lookFor(requests(held, held.size)) }
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
                val again = Scraper(ArtStore(folder), restarted, scope) { _, _ -> }
                scope.launch { again.lookFor(all) }
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
        val scraper = Scraper(store, fetch, scope) { run, _ -> changes += run }
        scope.launch { scraper.lookFor(requests(listOf(listOf(Held.IMAGE), listOf(Held.IMAGE)), 2)) }
        scope.runCurrent()
        store.stored(GameId("ps2/0")) shouldBe Some(art)
        ArtStore(folder).stored(GameId("ps2/0")) shouldBe Some(art)
        fetch.asked.map { it.substringAfter("art/").substringBefore('/') }.toSet() shouldBe setOf("1")
        changes.last().stall shouldBe Some(Stall.OFFLINE)
    }

    /** ScreenScraper as the tests stage it: open or not. */
    private class FakeTextures(override var open: Boolean) : Textures {
        var runs = 0

        override suspend fun newRun() {
            runs++
        }
    }

    /** A scraper of [fetch] on a test clock, and the last run it told of. */
    private class Harness(store: ArtStore, fetch: FakeFetch, textures: Textures = Textures.NONE) {
        val scope = TestScope(StandardTestDispatcher())
        var last = Scraping.NONE
        val scraper = Scraper(store, fetch, scope, textures) { run, _ -> last = run }

        fun lookFor(requests: List<ArtRequest>) = scope.launch { scraper.lookFor(requests) }
    }

    private val ps2 = ScreenScraperSystem(58)

    private fun texture(game: Int, region: String): Candidate.Texture =
        Candidate.Texture(ps2, ScreenScraperGame(game), TextureMedia("support-texture($region)"), region)

    private val skipped = FetchFailure.Skipped(ScreenScraperState.ClosedForRun(Closure.BUSY))

    /** A disc whose texture comes before its scan, as a request lists them. */
    private fun withTexture(game: Int) =
        ArtRequest(GameId("ps2/$game"), "Game $game", nonEmptyListOf(texture(game, "eu"), web(url(game, 0))), Some(version), PS2_DISC)

    @Test
    fun `a label found after a skipped texture is provisional, asked again once ScreenScraper is open, replaced by the texture only`() {
        val store = ArtStore(folder)
        val textures = FakeTextures(open = false)
        val fetch = FakeFetch(mapOf(url(0, 0) to image), mapOf(texture(0, "eu").identity.value to skipped))
        val harness = Harness(store, fetch, textures)
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        val label = store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes()
        store.provisional(GameId("ps2/0")) shouldBe Some(Identity(url(0, 0)))
        textures.runs shouldBe 1
        // Closed still: not asked again, the label stays.
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 2
        // Open, the texture still skipped: asked, the label kept, still provisional.
        textures.open = true
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 3
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldBe label
        store.provisional(GameId("ps2/0")) shouldBe Some(Identity(url(0, 0)))
        // Open, the texture found: it replaces the label, which is settled.
        fetch.answers = emptyMap()
        fetch.images =
            mapOf(
                texture(0, "eu").identity.value to scan(diameter = 20, margin = 2, colour = android.graphics.Color.BLUE),
                url(0, 0) to image,
            )
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.last() shouldBe texture(0, "eu").identity.value
        store.provisional(GameId("ps2/0")).shouldBeNone()
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldNotBe label
        // Settled: not asked again.
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 4
    }

    @Test
    fun `a label chosen by the user while a skipped texture's next image downloads is never marked provisional`() {
        val store = ArtStore(folder)
        val chosen = byteArrayOf(7, 7, 7)
        val fetch = FakeFetch(mapOf(url(0, 0) to image), mapOf(texture(0, "eu").identity.value to skipped))
        fetch.during = { if (it is Candidate.Web) store.save(GameId("ps2/0"), chosen).shouldBeRight() }
        val harness = Harness(store, fetch, FakeTextures(open = false))
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldBe chosen
        store.provisional(GameId("ps2/0")).shouldBeNone()
        // ScreenScraper open later: the chosen label is not asked again.
        val again = Harness(store, fetch, FakeTextures(open = true))
        again.lookFor(listOf(withTexture(0)))
        again.scope.runCurrent()
        fetch.asked.size shouldBe 2
    }

    @Test
    fun `a provisional label whose better images turn out missing is settled as it is, and stays`() {
        val store = ArtStore(folder)
        val textures = FakeTextures(open = false)
        val fetch = FakeFetch(mapOf(url(0, 0) to image), mapOf(texture(0, "eu").identity.value to skipped))
        val harness = Harness(store, fetch, textures)
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        textures.open = true
        fetch.answers = emptyMap()
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked shouldBe listOf(texture(0, "eu").identity.value, url(0, 0), texture(0, "eu").identity.value)
        store.provisional(GameId("ps2/0")).shouldBeNone()
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldBe
            ArtStore(folder).stored(GameId("ps2/0")).shouldBeSome().file.readBytes()
        store.wants(GameId("ps2/0"), Some(version)) shouldBe false
    }

    @Test
    fun `INV-E11-04 only listed textures are asked for, an image or no image once per sources' version, stalls and skips not kept`() =
        runBlocking<Unit> {
            val table = TextureTable.parse("# 2026-10-18\nGame 0\t100\tus jp\nGame 1\t101\teu\nGame 2\t102\tjp[2] eu[2]\n", ps2)
            val listed = (0..2).associate { GameId("ps2/$it") to table.texturesOf("Game $it").map { it.identity.value }.toSet() }
            val newer = ArtVersion("2026-11-01")
            var found = 0
            var askedAnew = 0
            checkAll(60, Arb.list(Arb.element(Held.entries), 8..8), Arb.list(Arb.int(0..2), 1..6)) { held, scans ->
                folder.deleteRecursively()
                val store = ArtStore(folder)

                fun requests(version: ArtVersion) = (0..2).map { game ->
                    val candidates = table.texturesOf("Game $game") + web(url(game, 0))
                    ArtRequest(GameId("ps2/$game"), "Game $game", candidates.toNonEmptyListOrNone().shouldBeSome(), Some(version), PS2_DISC)
                }
                val requests = requests(version)
                val all = requests.flatMap { it.candidates }
                val at = all.mapIndexed { i, candidate -> candidate.identity.value to held[i] }.toMap()

                fun held(what: Held) = all.map { it.identity.value }.filter { at.getValue(it) == what }
                val fetch =
                    FakeFetch(
                        held(Held.IMAGE).associateWith { image } + held(Held.NOT_AN_IMAGE).associateWith { "<html/>".encodeToByteArray() },
                        held(Held.REFUSAL).associateWith { FetchFailure.Refused(429) } + held(Held.SKIPPED).associateWith { skipped },
                    )

                fun asked() = fetch.asked.filter { it.startsWith("ss:") }.groupingBy { it }.eachCount()
                val harness = Harness(store, fetch, FakeTextures(open = true))
                scans.forEach { count ->
                    harness.lookFor(requests.take(count + 1))
                    harness.scope.runCurrent()
                    // A stalled game is tried again after the longest delay: its textures answered are not asked again.
                    harness.scope.advanceTimeBy(16 * 60_000L)
                    harness.scope.runCurrent()
                }
                asked().keys.forEach { identity ->
                    identity shouldBeIn
                        listed.getValue(GameId("ps2/" + (identity.split(':')[2].toInt() - 100)))
                }
                // An image, or no image, is kept: never asked twice in the sources' version, whatever stalls or skips around it.
                val kept = (held(Held.IMAGE) + held(Held.NOTHING)).filter { it.startsWith("ss:") }
                kept.forEach { asked().getOrDefault(it, 0) shouldBeLessThanOrEqual 1 }
                found += requests.count { store.stored(it.game).isSome() }
                // Looked up again: each may be asked once more.
                store.lookAgain(LookAgain(requests.map { it.game }.toSet(), emptySet())).shouldBeRight()
                val again = Harness(store, fetch, FakeTextures(open = true))
                again.lookFor(requests)
                again.scope.runCurrent()
                kept.forEach { asked().getOrDefault(it, 0) shouldBeLessThanOrEqual 2 }
                // A new table: a texture answered as none is asked again for a game still without art.
                val before = asked()
                val renewed = Harness(store, fetch, FakeTextures(open = true))
                renewed.lookFor(requests(newer))
                renewed.scope.runCurrent()
                // Past the stalls' retries: every game is walked at least once, each texture answered as none once more at most.
                renewed.scope.advanceTimeBy(16 * 60_000L)
                renewed.scope.runCurrent()
                requests.filter { store.stored(it.game).isNone() }.forEach { request ->
                    val first = request.candidates.head.identity.value
                    if (at.getValue(first) == Held.NOTHING) {
                        asked().getOrDefault(first, 0) shouldBe before.getOrDefault(first, 0) + 1
                        askedAnew++
                    }
                }
            }
            found shouldBeGreaterThan 40
            askedAnew shouldBeGreaterThan 10
        }

    private fun url(game: Int, candidate: Int) = "https://art/$game/$candidate.png"

    @Test
    fun `a stop during a download sets its game aside, asks none of its other scans, and looks for it first at the next start`() {
        val store = ArtStore(folder)
        val fetch = FakeFetch(mapOf(url(0, 1) to image))
        val harness = Harness(store, fetch)
        fetch.during = { if (it.identity.value == url(0, 0)) harness.scraper.stop() }
        harness.lookFor(requests(listOf(listOf(Held.NOTHING, Held.IMAGE), listOf(Held.IMAGE)), 2))
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
        harness.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
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
        harness.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
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
        harness.lookFor(request)
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
        val scraper = Scraper(store, fetch, scope) { _, _ -> }
        scope.launch { scraper.lookFor(cartridge) }
        scope.runCurrent()
        val label = BitmapFactory.decodeFile(store.stored(GameId("ps2/0")).shouldBeSome().file.path)
        (label.width to label.height) shouldBe (280 to 120)
    }

    @Test
    fun `a cartridge's texture is stored whole, at its own proportions, where a scan of that shape is passed over`() {
        val store = ArtStore(folder)
        val scope = TestScope(StandardTestDispatcher())
        // The label as printed, about twice as wide as tall: no front of the cartridge has that shape.
        val printed = png(392, 200)
        val fetch = FakeFetch(mapOf(texture(0, "eu").identity.value to printed, url(0, 0) to printed))
        val request =
            ArtRequest(GameId("ps2/0"), "Game 0", nonEmptyListOf(texture(0, "eu"), web(url(0, 0))), Some(version), cartridgeLabel)
        val scraper = Scraper(store, fetch, scope, FakeTextures(open = true)) { _, _ -> }
        scope.launch { scraper.lookFor(listOf(request)) }
        scope.runCurrent()
        fetch.asked shouldBe listOf(texture(0, "eu").identity.value)
        val label = BitmapFactory.decodeFile(store.stored(GameId("ps2/0")).shouldBeSome().file.path)
        (label.width to label.height) shouldBe (392 to 200)
    }

    @Test
    fun `INV-E11-06 a download that fails with the URL in its message skips the image, and no trace holds the password`() {
        ShadowLog.clear()
        val store = ArtStore(folder)
        val scope = TestScope(StandardTestDispatcher())
        val fetch = FakeFetch(mapOf(url(0, 0) to image))
        fetch.during = { candidate ->
            if (candidate is Candidate.Texture) {
                throw IOException(
                    "https://api.screenscraper.fr/api2/mediaJeu.php?devid=dev&devpassword=DEVSECRET42&sspassword=MEMBERSECRET42",
                )
            }
        }
        val scraper = Scraper(store, fetch, scope, FakeTextures(open = true)) { _, _ -> }
        scope.launch { scraper.lookFor(listOf(withTexture(0))) }
        scope.runCurrent()
        store.stored(GameId("ps2/0")).shouldBeSome()
        val logged = ShadowLog.getLogs().map { "${it.msg} ${Option.fromNullable(it.throwable).map(Throwable::toString).getOrElse { "" }}" }
        logged.filter { "skipped" in it }.shouldNotBeEmpty()
        logged.forEach { line ->
            line shouldNotContain "DEVSECRET42"
            line shouldNotContain "MEMBERSECRET42"
            line shouldNotContain "devpassword"
        }
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
        scope.launch { scraper.lookFor(requests(listOf(listOf(Held.IMAGE)), 1)) }
        scope.runCurrent()
        val kept = store.stored(GameId("ps2/0")).shouldBeSome()
        kept.file.readBytes() shouldBe chosen
        found shouldBe listOf(FoundArt(GameId("ps2/0"), kept))
    }

    @Test
    fun `the games on screen go first, stay first through a new plan, and a focus that moves nothing is not told`() {
        val scope = TestScope(StandardTestDispatcher())
        val changes = mutableListOf<Scraping>()
        val scraper = Scraper(ArtStore(folder), FakeFetch(emptyMap()), scope) { run, _ -> changes += run }
        // Stopped: nothing downloads, the waiting requests keep their order.
        scraper.stop()
        val held = List(6) { listOf(Held.IMAGE) }
        scope.launch { scraper.lookFor(requests(held, 6)) }
        scope.runCurrent()
        val onScreen = listOf(GameId("ps2/4"), GameId("ps2/2"))
        scope.launch { scraper.focus(onScreen) }
        scope.runCurrent()
        changes.last().waiting.map { it.game.value } shouldBe listOf("ps2/4", "ps2/2", "ps2/0", "ps2/1", "ps2/3", "ps2/5")
        val told = changes.size
        scope.launch { scraper.focus(onScreen) }
        scope.runCurrent()
        changes.size shouldBe told
        scope.launch { scraper.lookFor(requests(held, 6).reversed()) }
        scope.runCurrent()
        changes.last().waiting.map { it.game.value } shouldBe listOf("ps2/4", "ps2/2", "ps2/5", "ps2/3", "ps2/1", "ps2/0")
    }

    @Test
    fun `waiting for the run to be over ends once every game was looked for, not while one waits for the network`() {
        val held = listOf(listOf(Held.IMAGE), listOf(Held.NOTHING))
        val scope = TestScope(StandardTestDispatcher())
        val fetch = server(held).apply { online = false }
        val scraper = Scraper(ArtStore(folder), fetch, scope) { _, _ -> }
        scope.launch { scraper.lookFor(requests(held, 2)) }
        scope.runCurrent()
        val waiting = scope.async { scraper.awaitOver() }
        scope.runCurrent()
        waiting.isCompleted shouldBe false
        fetch.online = true
        scraper.networkBack()
        scope.runCurrent()
        waiting.isCompleted shouldBe true
    }
}
