// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.net.ConnectivityManager
import app.cartouche.android.DebugOptions
import app.cartouche.android.Reference
import app.cartouche.android.Table
import app.cartouche.android.TableFiles
import app.cartouche.android.Threads
import app.cartouche.android.VARIANT_SIGNAL
import app.cartouche.android.library.LibraryService
import app.cartouche.android.library.Shown
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.tableTexts
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.ExtractGame
import app.cartouche.core.art.extract
import app.cartouche.core.art.web
import app.cartouche.core.library.Game
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.serialName
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.time.LocalDate
import java.util.concurrent.Executor

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ArtServiceTest {
    private val context = RuntimeEnvironment.getApplication()
    private val version = Some(ArtVersion("2026-10-18"))
    private val ps2 = PlatformId("ps2")
    private val profile =
        """{"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1, "art": {"kind": "disc"}, "screenScraperSystem": 58}"""
    private val catalog =
        Catalog.parse(
            listOf(definition(playerJson("p")), definition(playerJson("p"), platform = "psx", name = "psx.json")),
            DefinitionSource("profiles.json", """{"ps2": $profile, "psx": $profile}"""),
        )

    /** A European game whose release ScreenScraper has a texture for. */
    private fun european(title: String) = game(title).copy(regions = listOf("Europe"), redumpName = Some("$title (Europe)"))

    private fun textures(vararg titles: String) =
        "# 2026-10-18\n" + titles.withIndex().joinToString("") { (n, title) -> "$title (Europe)\t${n + 1}\teu\n" }

    private fun extractOf(vararg games: ExtractGame) = extract(games.toList(), "2026-10-18")

    /**
     * An [ArtService] over a library of [games] on a PS2 whose sources are [extract] and [textureTable],
     * downloading through [fetch]: every thread is one of the test's scheduler, but the planning
     * thread when [planning] is given.
     */
    private inner class Rig(
        vararg games: Game,
        val scope: TestScope = TestScope(StandardTestDispatcher()),
        extract: String = "",
        textureTable: String = "",
        val fetch: Fetch = FakeFetch(emptyMap()),
        textures: Textures = Textures.NONE,
        planning: CoroutineDispatcher? = null,
        scraperDecoding: Semaphore = Semaphore(ArtImages.SCRAPER_DECODES),
    ) {
        val store = ArtStore(File(context.filesDir, "art"))
        val signals = mutableListOf<Pair<String, String>>()
        var reference = Reference(catalog, files = tableTexts(Table.ART to ps2 to extract, Table.TEXTURES to ps2 to textureTable))
        var preferred: Option<PreferredRegion> = None

        init {
            LibraryStore(File(context.filesDir, "library.json")).save(Library(games = games.toList())).shouldBeRight()
        }

        val library =
            LibraryService(
                LibraryStore(File(context.filesDir, "library.json")),
                File(context.filesDir, "selection.json"),
                File(context.filesDir, "arrivals.json"),
                Folders(context),
                FactsStore(File(context.filesDir, "facts")),
                Dispatchers.IO,
            )
        private val scheduled = StandardTestDispatcher(scope.testScheduler)
        val art =
            ArtService(
                Threads(scope, scheduled, planning ?: scheduled, scheduled, Dispatchers.IO, scheduled),
                store,
                { Shown.Users(lazyOf(library)) },
                { reference },
                { preferred },
                fetch,
                textures,
                { context.getSystemService(ConnectivityManager::class.java) },
                scraperDecoding,
            ) { signal, payload -> signals += signal to payload }

        fun run() = scope.advanceUntilIdle()
    }

    /** A planning thread that only runs its work when [drain] says so. */
    private class Waiting {
        private val queue = ArrayDeque<Runnable>()
        val dispatcher: CoroutineDispatcher = Executor { queue += it }.asCoroutineDispatcher()

        fun drain() {
            while (queue.isNotEmpty()) queue.removeFirst().run()
        }
    }

    /** ScreenScraper as the app composes it: one gate, over [http], for every texture asked. */
    private inner class Gate(member: Boolean = false, scope: TestScope) {
        var quota = false
        val http =
            FakeHttp { url ->
                when {
                    quota -> Served(430, None).right()
                    "ssuserInfos" in url ->
                        Served(
                            200,
                            Some("""{"response":{"ssuser":{"maxthreads":"2","maxrequestspermin":"3"}}}""".encodeToByteArray()),
                        ).right()
                    else -> Served(200, Some("NOMEDIA".encodeToByteArray())).right()
                }
            }.also { it.now = { scope.testScheduler.currentTime } }
        val fetch =
            ScreenScraperFetch(
                http,
                Credentials("dev", Secret("fake"), "Cartouche", if (member) Some(Member("member", Secret("fake"))) else None),
                File(context.filesDir, "art/gate.json"),
                { scope.testScheduler.currentTime },
                { Day.of(LocalDate.of(2026, 10, 18)) },
            ) {}
    }

    private val a = european("A")
    private val b = european("B")
    private val c = european("C")
    private val d = european("D")

    @Test
    fun `INV-17 background and chooser downloads share one ScreenScraper gate and its quota closure`() {
        val scope = TestScope(StandardTestDispatcher())
        val gate = Gate(scope = scope)
        val rig =
            Rig(
                a,
                b,
                c,
                d,
                scope = scope,
                textureTable = textures("A", "B", "C", "D"),
                fetch = artFetch(DebugOptions.NONE, Some(gate.fetch)),
                textures = gate.fetch,
            )
        listOf(b, c, d).forEach { rig.store.save(it.id, byteArrayOf(1)).shouldBeRight() }
        rig.art.lookForArt()
        rig.art.labelVariants(b)
        rig.run()
        gate.http.asked.count { "mediaJeu" in it } shouldBe 2
        gate.http.mostAtOnce shouldBe 1
        gate.quota = true
        rig.art.labelVariants(c)
        rig.run()
        val before = gate.http.asked.size
        rig.art.lookForArt { setOf(d.id) }
        rig.run()
        gate.http.asked.size shouldBe before
        scope.cancel()
    }

    private val okage = game("Okage")
    private val unknown = game("Unknown")
    private val okageExtract = extractOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png")))

    @Test
    fun `a region preferred after the labels were found asks again the labels it reorders, on the planning thread`() {
        val planning = Waiting()
        val fetch = FakeFetch(emptyMap())
        val rig = Rig(okage, unknown, extract = okageExtract, fetch = fetch, planning = planning.dispatcher)
        rig.art.stop()
        rig.store.save(okage.id, byteArrayOf(1)).shouldBeRight()
        rig.preferred = Some(PreferredRegion.JAPAN)
        rig.art.preferredRegionChanged(None, Some(PreferredRegion.JAPAN))
        rig.run()
        rig.store.asked(okage.id).shouldBeNone()
        planning.drain()
        rig.run()
        rig.store.asked(okage.id).shouldBeSome()
        rig.art.start()
        rig.run()
        ("jp.png" in fetch.asked.first()) shouldBe true
        rig.scope.cancel()
    }

    /**
     * Okage's downloaded label, reordered by a region preferred, is planned to be looked up again, but the plan waits on the planning
     * thread while the user [chooses] its image, [9, 9, 9]: the image stays theirs, whether a source has one ([found]) or none.
     */
    private fun chosenWhileThePlanWaits(found: Boolean, chooses: (Rig) -> Either<LabelFailure, StoredArt>) {
        File(context.filesDir, "art").deleteRecursively()
        val planning = Waiting()
        val fetch = FakeFetch(emptyMap())
        val rig = Rig(okage, extract = okageExtract, fetch = fetch, planning = planning.dispatcher)
        if (found) fetch.images = variants(rig).associate { it.candidate.identity.value to scan(diameter = 40, margin = 4) }
        rig.art.stop()
        rig.store.saveIfAbsent(okage.id, byteArrayOf(1), None, None).shouldBeRight()
        rig.preferred = Some(PreferredRegion.JAPAN)
        rig.art.preferredRegionChanged(None, Some(PreferredRegion.JAPAN))
        rig.run()
        chooses(rig).shouldBeRight()
        planning.drain()
        rig.art.start()
        rig.run()
        rig.store.stored(okage.id).shouldBeSome().file.readBytes() shouldBe byteArrayOf(9, 9, 9)
        rig.scope.cancel()
    }

    private fun variants(rig: Rig) = rig.reference.sources(ps2, None).variantsOf(okage) { true }

    @Test
    fun `INV-16 INV-18 a picture of the user's own kept while a look is planned is neither replaced nor deleted by that look`() {
        listOf(true, false).forEach { found ->
            chosenWhileThePlanWaits(found) { rig -> LabelChoices(rig.library, rig.store).keepOwn(okage, byteArrayOf(9, 9, 9)) }
        }
    }

    @Test
    fun `INV-16 INV-18 a region's image chosen while a look is planned is neither replaced nor deleted by that look`() {
        listOf(true, false).forEach { found ->
            chosenWhileThePlanWaits(found) { rig ->
                val chosen = variants(rig).first()
                rig.store.saveVariant(chosen.candidate, byteArrayOf(9, 9, 9)).shouldBeRight()
                LabelChoices(rig.library, rig.store).choose(okage, chosen)
            }
        }
    }

    @Test
    fun `a variant card's images are decoded while the scraper's decodes are all taken`() {
        val scraperDecoding = Semaphore(ArtImages.SCRAPER_DECODES)
        val rig = Rig(okage, extract = okageExtract, scraperDecoding = scraperDecoding)
        rig.art.stop()
        val images = variants(rig)
        (rig.fetch as FakeFetch).images = images.associate { it.candidate.identity.value to scan(diameter = 40, margin = 4) }
        repeat(ArtImages.SCRAPER_DECODES) { scraperDecoding.tryAcquire() shouldBe true }
        rig.art.labelVariants(okage)
        rig.run()
        rig.signals.count { it.first == VARIANT_SIGNAL } shouldBe 0
        rig.art.start()
        rig.run()
        rig.signals.count { it.first == VARIANT_SIGNAL } shouldBe images.size
        images.forEach { rig.store.variant(it.candidate).shouldBeSome() }
        rig.scope.cancel()
    }

    @Test
    fun `the chooser's images not yet downloaded when the app leaves the screen wait for it to come back`() {
        val rig = Rig(okage, extract = okageExtract)
        val images = variants(rig)
        val fetch = rig.fetch as FakeFetch
        fetch.images = images.associate { it.candidate.identity.value to scan(diameter = 40, margin = 4) }
        rig.art.labelVariants(okage)
        rig.art.stop()
        rig.run()
        fetch.asked shouldBe emptyList()
        rig.art.start()
        rig.run()
        images.forEach { rig.store.variant(it.candidate).shouldBeSome() }
        rig.scope.cancel()
    }

    @Test
    fun `a game no source can have art for is known absent at the look's planning, and listed so with the library`() {
        val stored = game("Stored")
        val rig = Rig(okage, unknown, stored, extract = okageExtract)
        rig.art.stop()
        rig.store.save(stored.id, byteArrayOf(1)).shouldBeRight()
        rig.art.lookForArt()
        rig.run()
        rig.signals
            .flatMap { (_, payload) -> Option.fromNullable(Json.parseToJsonElement(payload).jsonObject["absent"]).toList() }
            .map { absent -> absent.jsonArray.map { it.jsonPrimitive.content } } shouldBe listOf(listOf(unknown.id.value))
        val (labels, absent) = rig.store.labelsOf(listOf(okage, unknown, stored)) { rig.reference.artVersion(it) }
        labels.map { it.game } shouldBe listOf(stored.id)
        absent shouldBe listOf(unknown.id.value)
        rig.reference = Reference(catalog, files = tableTexts(Table.ART to ps2 to okageExtract.replace("2026-10-18", "2026-10-19")))
        rig.store.labelsOf(listOf(unknown)) { rig.reference.artVersion(it) }.second shouldBe emptyList()
        rig.scope.cancel()
    }

    private val psx = PlatformId("psx")
    private val ape = game("Ape", platform = "psx")
    private val apeExtract = extractOf(ExtractGame("Ape", emptySet(), listOf("USA=na.png")))

    /** Points [rig] at the ps2 and psx art tables, and counts each open of one: its version's first line once, then each indexing. */
    private fun countedArt(rig: Rig): Map<PlatformId, Int> {
        val files = tableTexts(Table.ART to ps2 to okageExtract, Table.ART to psx to apeExtract)
        val opened = mutableMapOf<PlatformId, Int>()
        val counted = TableFiles { table, platform -> files.open(table, platform).onSome { opened.merge(platform, 1, Int::plus) } }
        rig.reference = Reference(catalog, files = counted)
        return opened
    }

    @Test
    fun `once the run is over every art table but the open chooser's is forgotten, and indexed again when next needed`() {
        val rig = Rig(okage, ape)
        val opened = countedArt(rig)
        rig.art.lookForArt()
        rig.run()
        opened shouldBe mapOf(ps2 to 2, psx to 2)
        rig.art.labelVariants(okage)
        opened[ps2] shouldBe 3
        rig.art.lookForArt()
        rig.run()
        val psxPlanned = opened.getValue(psx)
        rig.art.labelVariants(okage)
        opened[ps2] shouldBe 3
        rig.art.labelVariants(ape)
        opened[psx] shouldBe psxPlanned + 1
        rig.art.stop()
        rig.run()
        rig.art.labelVariants(okage)
        opened[ps2] shouldBe 4
        rig.scope.cancel()
    }

    @Test
    fun `no art table is forgotten while the run is under way`() {
        val rig = Rig(okage, ape)
        val opened = countedArt(rig)
        rig.art.stop()
        rig.art.lookForArt()
        rig.run()
        rig.art.labelVariants(ape)
        opened shouldBe mapOf(ps2 to 2, psx to 2)
        rig.scope.cancel()
    }

    @Test
    fun `a re-read after the run indexes no art table of a console whose labels are all there`() {
        val rig = Rig(okage, ape)
        listOf(okage, ape).forEach { rig.store.save(it.id, byteArrayOf(1)).shouldBeRight() }
        val opened = countedArt(rig)
        rig.art.lookForArt()
        rig.run()
        rig.art.recutAfterScan(listOf(okage, ape))
        rig.run()
        opened shouldBe mapOf(ps2 to 1, psx to 1)
        rig.scope.cancel()
    }

    /** ScreenScraper open or closed as the test says. */
    private class Switched(override var open: Boolean) : Textures {
        override suspend fun newRun() = Unit

        override suspend fun networkBack() = Unit
    }

    @Test
    fun `a texture shown in the chooser can be chosen after ScreenScraper closed`() {
        File(context.filesDir, "art").deleteRecursively()
        val textures = Switched(open = true)
        val rig = Rig(a, textureTable = textures("A"), textures = textures)
        rig.art.stop()
        val texture = rig.reference.sources(ps2, None).variantsOf(a) { true }.first { it.candidate is Candidate.Texture }
        rig.store.saveVariant(texture.candidate, scan(diameter = 40, margin = 4)).shouldBeRight()
        rig.art.labelVariants(a).variants.map { it.region } shouldContain texture.region.name
        textures.open = false
        rig.art.chooseLabel(a, texture.region.name, texture.candidate.source.serialName).shouldBeRight()
        rig.store.stored(a.id).shouldBeSome()
        rig.scope.cancel()
    }

    @Test
    fun `the images of the chooser just opened are kept however many images are downloaded after them`() {
        File(context.filesDir, "art").deleteRecursively()
        val rig = Rig(okage, extract = okageExtract)
        rig.art.stop()
        val shown = variants(rig).map { it.candidate }
        shown.forEach { rig.store.saveVariant(it, byteArrayOf(1)).shouldBeRight() }
        val others = (1 until ArtStore.VARIANTS_KEPT - shown.size + 1).map { web("https://art/other/$it.png") }
        others.forEach { rig.store.saveVariant(it, byteArrayOf(2)).shouldBeRight() }
        // The chooser's images are the oldest kept.
        val day = 24 * 60 * 60 * 1000L
        shown.forEach { rig.store.variant(it).shouldBeSome().file.setLastModified(System.currentTimeMillis() - 2 * day) shouldBe true }
        rig.art.labelVariants(okage)
        rig.store.saveVariant(web("https://art/other/new.png"), byteArrayOf(3)).shouldBeRight()
        shown.forEach { rig.store.variant(it).shouldBeSome() }
        rig.scope.cancel()
    }
}
