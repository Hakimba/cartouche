// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.CartouchePlugin
import app.cartouche.core.art.ArtIndex
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.PS2_MEDIA
import app.cartouche.core.art.TextureTable
import app.cartouche.core.art.texture
import app.cartouche.core.library.GameId
import app.cartouche.core.library.game
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.ScreenScraperSystem
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
        h.scope.launch { h.gate.get(candidate) }
        h.scope.advanceUntilIdle()
        h.listed() shouldBe listOf("launchbox")
        Harness(withKey = false).listed() shouldBe listOf("launchbox")
        h.scope.cancel()
    }
}
