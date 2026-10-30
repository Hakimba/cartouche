// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.net.ConnectivityManager
import app.cartouche.android.DebugOptions
import app.cartouche.android.Reference
import app.cartouche.android.Threads
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Day
import app.cartouche.core.art.ExtractGame
import app.cartouche.core.art.extract
import app.cartouche.core.library.Game
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import org.godotengine.godot.Dictionary
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.util.concurrent.Executor

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ArtServiceTest {
    private val context = RuntimeEnvironment.getApplication()
    private val version = Some(ArtVersion("2026-10-18"))
    private val ps2 = PlatformId("ps2")
    private val profile =
        """{"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1, "art": {"kind": "disc"}, "screenScraperSystem": 58}"""
    private val catalog = Catalog.parse(listOf(definition(playerJson("p"))), DefinitionSource("profiles.json", """{"ps2": $profile}"""))

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
        fetch: Fetch = FakeFetch(emptyMap()),
        textures: Textures = Textures.NONE,
        planning: CoroutineDispatcher? = null,
    ) {
        val store = ArtStore(File(context.filesDir, "art"))
        val signals = mutableListOf<Pair<String, Dictionary>>()
        var reference = Reference(catalog, artLists = mapOf(ps2 to extract), textureLists = mapOf(ps2 to textureTable))
        var preferred: Option<PreferredRegion> = None

        init {
            LibraryStore(File(context.filesDir, "library.json")).save(Library(games = games.toList())).shouldBeRight()
        }

        private val library =
            LibraryService(
                LibraryStore(File(context.filesDir, "library.json")),
                SelectionStore(File(context.filesDir, "selection.json")),
                Folders(context),
                FactsStore(File(context.filesDir, "facts")),
            )
        private val scheduled = StandardTestDispatcher(scope.testScheduler)
        val art =
            ArtService(
                Threads(scope, scheduled, planning ?: scheduled, scheduled),
                store,
                { library },
                { reference },
                { preferred },
                fetch,
                textures,
                { context.getSystemService(ConnectivityManager::class.java) },
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
                    quota -> Answer(430, None).right()
                    "ssuserInfos" in url ->
                        Answer(
                            200,
                            Some("""{"response":{"ssuser":{"maxthreads":"2","maxrequestspermin":"3"}}}""".encodeToByteArray()),
                        ).right()
                    else -> Answer(200, Some("NOMEDIA".encodeToByteArray())).right()
                }
            }.also { it.now = { scope.testScheduler.currentTime } }
        val fetch =
            ScreenScraperFetch(
                http,
                Credentials("dev", "fake", "Cartouche", if (member) Some(Member("member", "fake")) else None),
                File(context.filesDir, "art/gate.json"),
                { scope.testScheduler.currentTime },
                { Day("2026-10-18") },
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

    @Test
    fun `a game no source can have art for is known absent at the look's planning, and listed so with the library`() {
        val stored = game("Stored")
        val rig = Rig(okage, unknown, stored, extract = okageExtract)
        rig.art.stop()
        rig.store.save(stored.id, byteArrayOf(1)).shouldBeRight()
        rig.art.lookForArt()
        rig.run()
        rig.signals.mapNotNull { (_, payload) -> (payload["absent"] as? Array<*>)?.toList() } shouldBe listOf(listOf(unknown.id.value))
        rig.store.labelsOf(listOf(okage, unknown, stored)) { rig.reference.artVersion(it) }.second shouldBe listOf(unknown.id.value)
        rig.reference = Reference(catalog, artLists = mapOf(ps2 to okageExtract.replace("2026-10-18", "2026-10-19")))
        rig.store.labelsOf(listOf(unknown)) { rig.reference.artVersion(it) }.second shouldBe emptyList()
        rig.scope.cancel()
    }

    @Test
    fun `the library's stored and absent art is what looking each game up twice gave, in the same order`() {
        val games = (0 until 90).map { game("G$it", platform = if (it % 4 == 0) "gba" else "ps2") }
        val rig = Rig(*games.toTypedArray(), extract = okageExtract)
        rig.art.stop()
        games.forEachIndexed { at, game ->
            if (at % 3 == 0) rig.store.save(game.id, byteArrayOf(at.toByte())).shouldBeRight()
            if (at % 5 == 0) rig.store.markAbsent(game.id, rig.reference.artVersion(game.platform)).shouldBeRight()
        }
        val (stored, absent) = rig.store.labelsOf(games) { rig.reference.artVersion(it) }
        stored shouldBe games.flatMap { game -> rig.store.stored(game.id).map { FoundArt(game.id, it) }.toList() }
        absent shouldBe
            games.groupBy { it.platform }.flatMap { (platform, ofPlatform) ->
                val version = rig.reference.artVersion(platform)
                ofPlatform.filter { rig.store.stored(it.id).isNone() && rig.store.isAbsent(it.id, version) }.map { it.id.value }
            }
        stored.size shouldBe 30
        (absent.isNotEmpty()) shouldBe true
        rig.scope.cancel()
    }
}
