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
import app.cartouche.core.art.ScreenScraperState
import app.cartouche.core.art.Stall
import app.cartouche.core.art.TextureTable
import app.cartouche.core.art.texture
import app.cartouche.core.art.web
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.ScreenScraperSystem
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.nonEmptyListOf
import arrow.core.right
import arrow.core.toNonEmptyListOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldBeIn
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.longs.shouldBeLessThanOrEqual
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
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
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

/** Where the downloads of the games on screen are told when a test does not look. */
private val unseen: (GameId, LabelDownload) -> Unit = { _, _ -> }

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
    fun `INV-17 whatever the network and the app do, an image is downloaded once, and only art no source has is given up`() =
        runBlocking<Unit> {
            var stored = 0
            checkAll(150, games, Arb.list(steps, 1..14)) { held, script ->
                folder.deleteRecursively()
                val scope = TestScope(StandardTestDispatcher())
                val store = ArtStore(folder)
                val fetch = server(held)
                var stopped = false
                var going = emptySet<String>()
                val askedWhileStopped = mutableListOf<String>()
                var last = Scraping.NONE
                val scraper = Scraper(store, fetch, scope, downloading = unseen) { run, _ -> last = run }
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
                    if (stopped) {
                        askedWhileStopped +=
                            fetch.asked.drop(before).filter { it.substringAfter("art/").substringBefore('/') !in going }
                    }
                }
                askedWhileStopped.shouldBeEmpty()
                fetch.online = true
                scraper.start()
                scope.launch { scraper.lookFor(requests(held, held.size)) }
                scope.advanceTimeBy(3 * 60 * 60_000L)
                scope.runCurrent()
                fetch.served.entries
                    .filter { (url, _) -> url in imageUrls(held) }
                    .groupBy({ it.key.substringAfter("art/").substringBefore('/') }, { it.value })
                    .values
                    .forEach { it.sum() shouldBeLessThanOrEqual 1 }
                val all = requests(held, held.size)
                val absent = all.filter { store.isAbsent(it.game, it.version) }.map { it.game }.toSet()
                val restarted = FakeFetch(emptyMap())
                val again = Scraper(ArtStore(folder), restarted, scope, downloading = unseen) { _, _ -> }
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
                        Held.REFUSAL in candidates || Held.SKIPPED in candidates -> {
                            store.stored(id).shouldBeNone()
                            (id in absent) shouldBe false
                        }
                        else -> (id in absent) shouldBe true
                    }
                }
            }
            stored shouldBeGreaterThan 100
        }

    /** ScreenScraper as the tests stage it: open or not. */
    private class FakeTextures(override var open: Boolean) : Textures {
        var runs = 0
        var reconnections = 0

        override suspend fun newRun() {
            runs++
        }

        override suspend fun networkBack() {
            reconnections++
        }
    }

    /** A scraper of [fetch] on a test clock, and the last run it told of. */
    private class Harness(store: ArtStore, fetch: FakeFetch, textures: Textures = Textures.NONE) {
        val scope = TestScope(StandardTestDispatcher())
        var last = Scraping.NONE
        val scraper = Scraper(store, fetch, scope, textures, downloading = unseen) { run, _ -> last = run }

        fun lookFor(requests: List<ArtRequest>) = scope.launch { scraper.lookFor(requests) }
    }

    private val skipped = FetchFailure.Skipped(ScreenScraperState.ClosedForRun(Closure.BUSY))

    /** A disc whose texture comes before its scan, as a request lists them. */
    private fun withTexture(game: Int) =
        ArtRequest(GameId("ps2/$game"), "Game $game", nonEmptyListOf(texture(game), web(url(game, 0))), Some(version), PS2_DISC)

    @Test
    fun `a label found after a skipped texture is provisional, asked again once ScreenScraper is open, replaced by the texture only`() {
        val store = ArtStore(folder)
        val textures = FakeTextures(open = false)
        val fetch = FakeFetch(mapOf(url(0, 0) to image), mapOf(texture(0).identity.value to skipped))
        val harness = Harness(store, fetch, textures)
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        val label = store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes()
        store.provisional(GameId("ps2/0")) shouldBe Some(Identity(url(0, 0)))
        textures.runs shouldBe 1
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 2
        textures.open = true
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 3
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldBe label
        store.provisional(GameId("ps2/0")) shouldBe Some(Identity(url(0, 0)))
        fetch.answers = emptyMap()
        fetch.images =
            mapOf(
                texture(0).identity.value to scan(diameter = 20, margin = 2, colour = android.graphics.Color.BLUE),
                url(0, 0) to image,
            )
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.last() shouldBe texture(0).identity.value
        store.provisional(GameId("ps2/0")).shouldBeNone()
        store.stored(GameId("ps2/0")).shouldBeSome().file.readBytes() shouldNotBe label
        harness.lookFor(listOf(withTexture(0)))
        harness.scope.runCurrent()
        fetch.asked.size shouldBe 4
    }

    @Test
    fun `INV-17 only listed textures are asked for, an image or no image once per sources' version, stalls and skips not kept`() =
        runBlocking<Unit> {
            val table =
                TextureTable.parse(
                    "# 2026-10-18\nGame 0\t100\tus jp\nGame 1\t101\teu\nGame 2\t102\tjp[2] eu[2]\n",
                    ScreenScraperSystem(58),
                )
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
                    harness.scope.advanceTimeBy(16 * 60_000L)
                    harness.scope.runCurrent()
                }
                asked().keys.forEach { identity ->
                    identity shouldBeIn
                        listed.getValue(GameId("ps2/" + (identity.split(':')[2].toInt() - 100)))
                }
                val kept = (held(Held.IMAGE) + held(Held.NOTHING)).filter { it.startsWith("ss:") }
                kept.forEach { asked().getOrDefault(it, 0) shouldBeLessThanOrEqual 1 }
                found += requests.count { store.stored(it.game).isSome() }
                store.lookAgain(LookAgain(requests.map { it.game }.toSet(), emptySet())).shouldBeRight()
                val again = Harness(store, fetch, FakeTextures(open = true))
                again.lookFor(requests)
                again.scope.runCurrent()
                kept.forEach { asked().getOrDefault(it, 0) shouldBeLessThanOrEqual 2 }
                val before = asked()
                val renewed = Harness(store, fetch, FakeTextures(open = true))
                renewed.lookFor(requests(newer))
                renewed.scope.runCurrent()
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
    fun `a run resumed after an offline stall tells ScreenScraper the network is back, one resumed after a busy server never`() {
        val textures = FakeTextures(open = true)
        val fetch = FakeFetch(mapOf(url(0, 0) to image)).apply { online = false }
        val harness = Harness(ArtStore(folder), fetch, textures)
        harness.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
        harness.scope.runCurrent()
        harness.last.stall shouldBe Some(Stall.OFFLINE)
        textures.reconnections shouldBe 0
        fetch.online = true
        harness.scraper.networkBack()
        harness.scope.runCurrent()
        textures.reconnections shouldBe 1
        val busy = FakeTextures(open = true)
        val refused = Harness(ArtStore(File(folder, "busy")), FakeFetch(emptyMap(), mapOf(url(0, 0) to FetchFailure.Refused(429))), busy)
        refused.lookFor(requests(listOf(listOf(Held.IMAGE)), 1))
        refused.scope.advanceTimeBy(31_000)
        refused.scope.runCurrent()
        busy.reconnections shouldBe 0
    }

    @Test
    fun `INV-17 no room to store a scan stalls the run and never gives the game up`() {
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
    fun `INV-16 a cartridge's scan is stored as its label alone, a scan of no front's shape passed over for the next`() {
        val store = ArtStore(folder)
        val scope = TestScope(StandardTestDispatcher())
        val cartridge = requests(listOf(listOf(Held.IMAGE, Held.IMAGE)), 1).map { it.copy(cut = cartridgeLabel) }
        val fetch = FakeFetch(mapOf(url(0, 0) to png(300, 300), url(0, 1) to cartridgeFront()))
        val scraper = Scraper(store, fetch, scope, downloading = unseen) { _, _ -> }
        scope.launch { scraper.lookFor(cartridge) }
        scope.runCurrent()
        val label = BitmapFactory.decodeFile(store.stored(GameId("ps2/0")).shouldBeSome().file.path)
        (label.width to label.height) shouldBe (280 to 120)
    }

    @Test
    fun `INV-19 a download that fails with the URL in its message skips the image, and no trace holds the password`() {
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
        val scraper = Scraper(store, fetch, scope, FakeTextures(open = true), downloading = unseen) { _, _ -> }
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
    fun `INV-16 an image chosen by the user while its game's download runs stays`() {
        val store = ArtStore(folder)
        val chosen = byteArrayOf(7, 7, 7)
        val fetch = FakeFetch(mapOf(url(0, 0) to image))
        fetch.during = { store.save(GameId("ps2/0"), chosen).shouldBeRight() }
        val found = mutableListOf<LabelNews>()
        val scope = TestScope(StandardTestDispatcher())
        val scraper = Scraper(store, fetch, scope, downloading = unseen) { _, news -> found += news.toList() }
        scope.launch { scraper.lookFor(requests(listOf(listOf(Held.IMAGE)), 1)) }
        scope.runCurrent()
        val kept = store.stored(GameId("ps2/0")).shouldBeSome()
        kept.file.readBytes() shouldBe chosen
        found shouldBe listOf(FoundArt(GameId("ps2/0"), kept))
    }

    @Test
    fun `a game none of whose images is found is told absent once remembered so, a game found or stalled never`() {
        val store = ArtStore(folder)
        val fetch = FakeFetch(mapOf(url(1, 0) to image))
        val news = mutableListOf<LabelNews>()
        val scope = TestScope(StandardTestDispatcher())
        val scraper = Scraper(store, fetch, scope, downloading = unseen) { _, told -> news += told.toList() }
        scope.launch { scraper.lookFor(requests(listOf(listOf(Held.NOTHING, Held.NOTHING), listOf(Held.IMAGE)), 2)) }
        scope.runCurrent()
        news.map { if (it is FoundArt) listOf(it.game) else (it as AbsentArt).games } shouldContainExactlyInAnyOrder
            listOf(listOf(GameId("ps2/0")), listOf(GameId("ps2/1")))
        news.filterIsInstance<AbsentArt>().single().games shouldBe listOf(GameId("ps2/0"))
        store.isAbsent(GameId("ps2/0"), Some(version)) shouldBe true
        news.clear()
        fetch.online = false
        store.lookAgain(LookAgain(setOf(GameId("ps2/0")), emptySet())).shouldBeRight()
        scope.launch { scraper.lookFor(requests(listOf(listOf(Held.NOTHING)), 1)) }
        scope.runCurrent()
        news.shouldBeEmpty()
        scope.cancel()
    }

    @Test
    fun `only the downloads of the games on screen are told, each once over, and a look that downloaded nothing never`() {
        val scope = TestScope(StandardTestDispatcher())
        val downloads = mutableListOf<Pair<GameId, LabelDownload>>()
        val fetch = FakeFetch(mapOf(url(0, 1) to image, url(1, 0) to image))
        val scraper = Scraper(ArtStore(folder), fetch, scope, downloading = { game, download -> downloads += game to download }) { _, _ -> }
        scope.launch {
            scraper.focus(listOf(GameId("ps2/0"), GameId("ps2/2")))
            scraper.lookFor(requests(listOf(listOf(Held.NOTHING, Held.IMAGE), listOf(Held.IMAGE), listOf(Held.NOTHING)), 3))
        }
        scope.runCurrent()
        downloads shouldContainExactlyInAnyOrder
            listOf(GameId("ps2/0") to LabelDownload.Running(Some(1.0)), GameId("ps2/0") to LabelDownload.Over)
        downloads.last() shouldBe (GameId("ps2/0") to LabelDownload.Over)
        scope.cancel()
    }

    @Test
    fun `the games on screen go first, stay first through a new plan, and a focus that moves nothing is not told`() {
        val scope = TestScope(StandardTestDispatcher())
        val changes = mutableListOf<Scraping>()
        val scraper = Scraper(ArtStore(folder), FakeFetch(emptyMap()), scope, downloading = unseen) { run, _ -> changes += run }
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
    fun `a label asked again while its old look downloads is looked for again once that look ends, in the new order`() {
        val store = ArtStore(folder)
        val scope = TestScope(StandardTestDispatcher())
        val first = CompletableDeferred<Unit>()
        val asked = mutableListOf<String>()
        val fetch =
            Fetch { candidate, _ ->
                asked += candidate.identity.value
                if (asked.size == 1) first.await()
                image.right()
            }
        val scraper = Scraper(store, fetch, scope, downloading = unseen) { _, _ -> }
        val old = requests(listOf(listOf(Held.IMAGE, Held.IMAGE)), 1).single()
        val reordered = old.copy(candidates = old.candidates.reversed().toNonEmptyListOrNone().shouldBeSome())
        scope.launch { scraper.lookFor(listOf(old)) }
        scope.runCurrent()
        scope.launch { scraper.lookFor(listOf(reordered), setOf(old.game)) }
        scope.runCurrent()
        first.complete(Unit)
        scope.runCurrent()
        asked shouldBe listOf(url(0, 0), url(0, 1))
        store.wants(old.game, old.version) shouldBe false
        scope.cancel()
    }

    @Test
    fun `the games no source can have art for are remembered absent and told in one message, those with a label never`() {
        val store = ArtStore(folder)
        val news = mutableListOf<LabelNews>()
        val scope = TestScope(StandardTestDispatcher())
        val scraper = Scraper(store, FakeFetch(emptyMap()), scope, downloading = unseen) { _, told -> news += told.toList() }
        val (blank, chosen, unversioned) = listOf("blank", "chosen", "unversioned").map { GameId("ps2/$it") }
        store.save(chosen, image).shouldBeRight()
        scope.launch { scraper.absent(mapOf(blank to Some(version), chosen to Some(version), unversioned to None)) }
        scope.runCurrent()
        news shouldBe listOf(AbsentArt(listOf(blank, unversioned)))
        store.isAbsent(blank, Some(version)) shouldBe true
        store.stored(chosen).shouldBeSome()
        scope.cancel()
    }
}
