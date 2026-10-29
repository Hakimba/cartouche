// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.CartouchePlugin
import app.cartouche.android.storage.LibraryStore
import app.cartouche.core.art.ArtIndex
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.ExtractGame
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.PS2_MEDIA
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.TextureTable
import app.cartouche.core.art.extract
import app.cartouche.core.art.texture
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.game
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.ScreenScraperSystem
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import org.godotengine.godot.Godot
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.util.ReflectionHelpers
import java.io.File
import java.util.concurrent.Executor
import app.cartouche.core.settings.Settings as AppSettings

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class CartouchePluginArtTest {
    private val context = RuntimeEnvironment.getApplication()
    private val version = Some(ArtVersion("2026-10-18"))
    private val candidate = texture(58, 1, "support-texture(eu)", "Europe")

    /** The plugin keeps its real lazy composition; only IO and coroutine clocks are supplied. */
    private inner class Harness(member: Boolean = false, withKey: Boolean = true) {
        val scope = TestScope(StandardTestDispatcher())
        var quota = false
        val http =
            FakeHttp { url ->
                when {
                    quota -> Answer(430, None).right()
                    "ssuserInfos" in url ->
                        Answer(
                            200,
                            Some("""{"response":{"ssuser":{"maxthreads":"2","maxrequestspermin":"3"}}}""".encodeToByteArray()),
                        ).right()
                    else -> Answer(200, Some("NOMEDIA".encodeToByteArray())).right()
                }
            }.also { it.now = { scope.testScheduler.currentTime } }
        val store = ArtStore(File(context.filesDir, "art"))
        val gate =
            ScreenScraperFetch(
                http,
                Credentials("dev", "fake", "Cartouche", if (member) Some(Member("member", "fake")) else None),
                File(context.filesDir, "art/gate.json"),
                { scope.testScheduler.currentTime },
                { Day("2026-10-18") },
            ) {}
        val plugin = CartouchePlugin(Godot.getInstance(context))

        init {
            ReflectionHelpers.setField(plugin, "scope", scope)
            ReflectionHelpers.setField(plugin, "screenScraper\$delegate", lazy { if (withKey) Some(gate) else None })
            ReflectionHelpers.setField(plugin, "artStore\$delegate", lazy { store })
        }

        fun scraper(): Scraper = ReflectionHelpers.callInstanceMethod(plugin, "getScraper")

        fun variants(): VariantDownloads = ReflectionHelpers.callInstanceMethod<VariantDownloads>(plugin, "getVariantDownloads").also {
            ReflectionHelpers.setField(it, "downloads", StandardTestDispatcher(scope.testScheduler))
        }

        fun listed(at: Option<ArtVersion> = version): List<String> {
            val offered: (Candidate) -> Boolean =
                ReflectionHelpers.callInstanceMethod(
                    plugin,
                    "offered",
                    ReflectionHelpers.ClassParameter.from(Option::class.java, at),
                )
            val sources =
                ArtSources(
                    ArtKind.Disc,
                    PS2_MEDIA,
                    ArtIndex.parse("# 2026-10-18\nGame\t\tEurope=eu.png\n"),
                    None,
                    TextureTable.parse("# 2026-10-18\nGame (Europe)\t1\teu\n", ScreenScraperSystem(58)),
                )
            return sources
                .variantsOf(game("Game").copy(regions = listOf("Europe"), redumpName = Some("Game (Europe)")), offered)
                .map { it.candidate.source.wire }
        }
    }

    @Test
    fun `INV-E11-05 background and chooser downloads share the plugin gate and its quota closure`() {
        val h = Harness()
        val request = ArtRequest(GameId("ps2/a"), "A", nonEmptyListOf(candidate), version, PS2_DISC)
        h.scope.launch { h.scraper().lookFor(listOf(request)) }
        h.scope.runCurrent()
        h.variants().download(
            GameId("ps2/b"),
            listOf(
                app.cartouche.core.art.ArtVariant(
                    app.cartouche.core.library.LabelRegion("Europe"),
                    texture(58, 2, "support-texture(eu)", "Europe"),
                ),
            ),
            PS2_DISC,
            version,
        )
        h.scope.runCurrent()
        h.http.asked.size shouldBe 1
        h.scope.advanceUntilIdle()
        h.http.asked.size shouldBe 2
        h.http.mostAtOnce shouldBe 1
        h.quota = true
        h.variants().download(
            GameId("ps2/c"),
            listOf(
                app.cartouche.core.art.ArtVariant(
                    app.cartouche.core.library.LabelRegion("Europe"),
                    texture(58, 3, "support-texture(eu)", "Europe"),
                ),
            ),
            PS2_DISC,
            version,
        )
        h.scope.advanceUntilIdle()
        val before = h.http.asked.size
        h.scope.launch {
            h.scraper().lookFor(
                listOf(request.copy(game = GameId("ps2/d"), candidates = nonEmptyListOf(texture(58, 4, "support-texture(eu)", "Europe")))),
            )
        }
        h.scope.advanceUntilIdle()
        h.http.asked.size shouldBe before
        h.scope.cancel()
    }

    @Test
    fun `INV-E11-05 member limits count both plugin consumers together`() {
        val h = Harness(member = true)
        h.scope.launch { h.scraper().lookFor(listOf(ArtRequest(GameId("ps2/a"), "A", nonEmptyListOf(candidate), version, PS2_DISC))) }
        h.scope.runCurrent()
        val variants =
            (2..4).map {
                app.cartouche.core.art.ArtVariant(
                    app.cartouche.core.library.LabelRegion("Europe"),
                    texture(58, it, "support-texture(eu)", "Europe"),
                )
            }
        h.variants().download(GameId("ps2/b"), variants, PS2_DISC, version)
        h.scope.advanceUntilIdle()
        h.http.mostAtOnce shouldBeLessThanOrEqual 2
        h.http.startedAt.forEach { from -> h.http.startedAt.count { it in from..from + 59_999 } shouldBeLessThanOrEqual 3 }
        h.http.asked.count { "mediaJeu" in it } shouldBe 4
        h.scope.cancel()
    }

    @Test
    fun `the public art focus entry point reorders the real waiting scraper`() {
        val h = Harness()
        ReflectionHelpers.setField(h.plugin, "artPlanning", StandardTestDispatcher(h.scope.testScheduler))
        val scraper = h.scraper()
        scraper.stop()
        val requests = (0..5).map { i -> ArtRequest(GameId("ps2/$i"), "Game $i", nonEmptyListOf(candidate), version, PS2_DISC) }
        h.scope.launch { scraper.lookFor(requests) }
        h.scope.runCurrent()
        h.plugin.artFocus(arrayOf("ps2/4", "ps2/2"))
        h.scope.runCurrent()
        val run = ReflectionHelpers.getField<app.cartouche.core.art.Scraping>(scraper, "run")
        run.waiting.map { it.game.value } shouldBe listOf("ps2/4", "ps2/2", "ps2/0", "ps2/1", "ps2/3", "ps2/5")
        h.scope.cancel()
    }

    @Test
    fun `INV-E7-03 the real chooser filter omits missing closed and keyless textures and offers them after renewal`() {
        val h = Harness()
        h.listed() shouldBe listOf("launchbox", "screenscraper")
        h.store.markMissing(candidate, version).shouldBeRight()
        h.listed() shouldBe listOf("launchbox")
        h.listed(Some(ArtVersion("2026-10-19"))) shouldBe listOf("launchbox", "screenscraper")
        h.store.lookAgain(app.cartouche.core.art.LookAgain(emptySet(), emptySet())).shouldBeRight()
        h.listed() shouldBe listOf("launchbox", "screenscraper")
        h.quota = true
        h.scope.launch { h.gate.get(candidate, Progress.NONE) }
        h.scope.advanceUntilIdle()
        h.listed() shouldBe listOf("launchbox")
        Harness(withKey = false).listed() shouldBe listOf("launchbox")
        h.scope.cancel()
    }

    /**
     * The plugin over a library of [games] on a PS2 whose extract has Okage's American and Japanese
     * scans, its own art store, a stopped scraper telling [told], and a planning thread whose work
     * waits until [planned] lets it run.
     */
    private inner class Planned(vararg games: Game) {
        val scope = TestScope(StandardTestDispatcher())
        private val planning = ArrayDeque<Runnable>()
        private val godot = Godot.getInstance(context)
        val plugin = CartouchePlugin(godot)

        // Godot's instance, made once, keeps the context of the first test: the plugin's files are there.
        val files = godot.context.filesDir
        val store = ArtStore(File(files, "art"))
        val told = mutableListOf<LabelNews>()
        val scraper = Scraper(store, FakeFetch(emptyMap()), scope, Textures.NONE, { _, _ -> }) { _, news -> told += news.toList() }
        val extract = extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png"))), "2026-10-18")

        init {
            files.listFiles().orEmpty().forEach { it.deleteRecursively() }
            LibraryStore(File(files, "library.json")).save(Library(games = games.toList())).shouldBeRight()
            val profile = """{"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1, "art": {"kind": "disc"}}"""
            val catalog = Catalog.parse(listOf(definition(playerJson("p"))), DefinitionSource("profiles.json", """{"ps2": $profile}"""))
            ReflectionHelpers.setField(plugin, "scope", scope)
            ReflectionHelpers.setField(plugin, "libraryThread", StandardTestDispatcher(scope.testScheduler))
            ReflectionHelpers.setField(plugin, "artPlanning", Executor { planning += it }.asCoroutineDispatcher())
            ReflectionHelpers.setField(plugin, "catalog", catalog)
            ReflectionHelpers.setField(plugin, "artLists", mapOf(PlatformId("ps2") to extract))
            ReflectionHelpers.setField(plugin, "artStore\$delegate", lazy { store })
            ReflectionHelpers.setField(plugin, "scraper\$delegate", lazy { scraper })
            ReflectionHelpers.setField(plugin, "watchingNetwork", lazyOf(true))
            scraper.stop()
        }

        fun waiting(): List<GameId> = ReflectionHelpers.getField<Scraping>(scraper, "run").waiting.map { it.game }

        fun preferred(): Option<PreferredRegion> =
            ReflectionHelpers.callInstanceMethod<AppSettings>(plugin, "storedSettings").preferredRegion

        fun planned() {
            scope.runCurrent()
            while (planning.isNotEmpty()) planning.removeFirst().run()
            scope.runCurrent()
        }
    }

    private val okage = game("Okage")
    private val unknown = game("Unknown")

    @Test
    fun `INV-E11-08 a preferred region is answered once saved, and the labels it reorders are asked again on the planning thread`() {
        val h = Planned(okage, unknown)
        h.store.save(okage.id, byteArrayOf(1)).shouldBeRight()
        h.plugin.savePreferredRegion(1, "Japan")
        h.scope.runCurrent()
        h.preferred() shouldBe Some(PreferredRegion.JAPAN)
        h.store.asked(okage.id).shouldBeNone()
        h.planned()
        h.store.asked(okage.id).shouldBeSome()
        h.waiting() shouldContain okage.id
        h.scope.cancel()
    }

    @Test
    fun `a sound level is stored once saved, one out of range refused and the level kept`() {
        val h = Planned(okage)
        h.plugin.saveSoundLevel(1, 4)
        h.scope.runCurrent()
        ReflectionHelpers.callInstanceMethod<AppSettings>(h.plugin, "storedSettings").soundLevel.steps shouldBe 4
        h.plugin.saveSoundLevel(2, 11)
        h.scope.runCurrent()
        ReflectionHelpers.callInstanceMethod<AppSettings>(h.plugin, "storedSettings").soundLevel.steps shouldBe 4
        h.scope.cancel()
    }

    @Test
    fun `INV-E12-C1-02 games float is stored once saved, and read back with the settings`() {
        val h = Planned(okage)
        ReflectionHelpers.callInstanceMethod<AppSettings>(h.plugin, "storedSettings").gamesFloat shouldBe false
        h.plugin.saveGamesFloat(1, true)
        h.scope.runCurrent()
        ReflectionHelpers.callInstanceMethod<AppSettings>(h.plugin, "storedSettings").gamesFloat shouldBe true
        h.plugin.saveGamesFloat(2, false)
        h.scope.runCurrent()
        ReflectionHelpers.callInstanceMethod<AppSettings>(h.plugin, "storedSettings").gamesFloat shouldBe false
        h.scope.cancel()
    }

    @Test
    fun `INV-E12-C1-03 a console is placed once asked, kept after a restart, and a gap out of range changes nothing`() {
        val h = Planned(okage)
        val store = LibraryStore(File(h.files, "library.json"))
        val setUp = store.load().shouldBeRight().library.withSetup(PlatformId("ps2"), PlatformSetup())
        store.save(setUp).shouldBeRight()
        h.plugin.placeConsole(1, "ps2", 5)
        h.scope.runCurrent()
        store.load().shouldBeRight().library.consoleOrder.shouldBeEmpty()
        h.plugin.placeConsole(2, "ps2", 0)
        h.scope.runCurrent()
        store.load().shouldBeRight().library.consoleOrder shouldBe listOf(PlatformId("ps2"))
        h.scope.cancel()
    }

    @Test
    fun `INV-E11-08 an unknown region is refused, and a region chosen again asks nothing`() {
        val h = Planned(okage)
        h.store.save(okage.id, byteArrayOf(1)).shouldBeRight()
        h.plugin.savePreferredRegion(1, "Atlantis")
        h.planned()
        h.preferred().shouldBeNone()
        h.plugin.savePreferredRegion(2, "")
        h.planned()
        h.store.asked(okage.id).shouldBeNone()
        h.waiting().shouldBeEmpty()
        h.plugin.savePreferredRegion(3, "Japan")
        h.planned()
        h.store.asked(okage.id).shouldBeSome()
        h.store.saveIfAbsent(okage.id, byteArrayOf(2), None, h.store.asked(okage.id)).shouldBeRight()
        h.plugin.savePreferredRegion(4, "Japan")
        h.planned()
        h.store.asked(okage.id).shouldBeNone()
        h.scope.cancel()
    }

    @Test
    fun `INV-E11-09 a game no source can have art for is known absent at the look's planning, and listed so with the library`() {
        val h = Planned(okage, unknown, game("Stored"))
        h.store.save(GameId("ps2/Stored"), byteArrayOf(1)).shouldBeRight()
        val askedAgain: (List<Game>) -> Set<GameId> = { emptySet() }
        ReflectionHelpers.callInstanceMethod<Job>(
            h.plugin,
            "lookForArt",
            ReflectionHelpers.ClassParameter.from(Function1::class.java, askedAgain),
        )
        h.planned()
        h.told shouldBe listOf(AbsentArt(listOf(unknown.id)))
        h.waiting() shouldBe listOf(okage.id)
        val absent: List<String> =
            ReflectionHelpers.callInstanceMethod(
                h.plugin,
                "absentLabels",
                ReflectionHelpers.ClassParameter.from(List::class.java, listOf(okage, unknown, game("Stored"))),
            )
        absent shouldBe listOf(unknown.id.value)
        // Another version of the sources: looked for again, not absent meanwhile.
        ReflectionHelpers.setField(h.plugin, "artLists", mapOf(PlatformId("ps2") to h.extract.replace("2026-10-18", "2026-10-19")))
        ReflectionHelpers.callInstanceMethod<List<String>>(
            h.plugin,
            "absentLabels",
            ReflectionHelpers.ClassParameter.from(List::class.java, listOf(unknown)),
        ) shouldBe emptyList()
        h.scope.cancel()
    }
}
