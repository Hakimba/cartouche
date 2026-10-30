// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.art.ArtStore
import app.cartouche.core.art.ArtIndex
import app.cartouche.core.library.Game
import app.cartouche.core.library.Library
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.game
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import arrow.core.None
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import kotlin.random.Random
import kotlin.time.TimeSource

/**
 * Times what a library answer does at 5 000 games with real-length ids, fixed seed. Not part of the suite:
 * `CARTOUCHE_BENCH=1 ./gradlew :android:testDebugUnitTest --tests '*LibraryAnswerTimingTest*' -i`.
 */
@Config(sdk = [34])
@RunWith(RobolectricTestRunner::class)
class LibraryAnswerTimingTest {
    private val random = Random(42)

    private fun title(): String = (1..random.nextInt(3, 8)).joinToString(" ") { "Word${random.nextInt(0, 400)}" } + " (Europe) (En,Fr,De)"

    private val games: List<Game> =
        List(5_000) { at ->
            val title = title()
            game("$title $at", platform = "ps2").let {
                it.copy(
                    id =
                        app.cartouche.core.library.GameId(
                            "ps2/content://com.android.externalstorage.documents/tree/primary%3AROMs/document/primary%3AROMs%2FPS2%2F$title $at.chd",
                        ),
                )
            }
        }

    private fun ms(block: () -> Unit): Double {
        val start = TimeSource.Monotonic.markNow()
        block()
        return start.elapsedNow().inWholeMicroseconds / 1000.0
    }

    private fun median(runs: List<Double>) = runs.sorted()[runs.size / 2]

    @Test
    fun timings() {
        assumeTrue(System.getenv("CARTOUCHE_BENCH") != null)
        val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
        val seeded = ArtStore(folder)
        games.forEachIndexed { at, game ->
            if (at % 3 == 0) seeded.save(game.id, byteArrayOf(1))
            if (at % 5 == 0) seeded.markAbsent(game.id, None)
        }
        val ps2 = catalog(definition())
        val library = Library(games = games)
        library.toWireJson(None, ps2)
        library.toWireJsonTree(None, ps2)

        // The answer's lookups as the plugin made them before: stored, then stored again for the absent ones.
        val coldLookups =
            List(25) {
                val store = ArtStore(folder)
                ms { oldLookups(store) }
            }
        val coldSingle =
            List(25) {
                val store = ArtStore(folder)
                ms { store.labelsOf(games) { None } }
            }
        // The look's planning and the scraper's checks: wants for each game, three times.
        val coldWants =
            List(25) {
                val store = ArtStore(folder)
                ms { repeat(3) { games.forEach { store.wants(it.id, None) } } }
            }
        val json = List(15) { ms { library.toWireJson(None, ps2) } }
        val tree = List(15) { ms { library.toWireJsonTree(None, ps2) } }
        println("TIMING cold lookups, as before: ${median(coldLookups)} ms")
        println("TIMING cold lookups, single pass: ${median(coldSingle)} ms")
        val data = File(System.getProperty("cartouche.app"), "data")
        val titles = File(data, "titles/ps2.tsv").readText()
        val prints = File(data, "prints/ps2.tsv").takeIf { it.exists() }?.readText().orEmpty()
        val art = File(data, "art/ps2.tsv").readText()
        println("TIMING titles parse (ps2): ${median(List(9) { ms { TitleIndex.parse(titles, prints) } })} ms")
        println("TIMING art parse (ps2): ${median(List(9) { ms { ArtIndex.parse(art) } })} ms")
        println("TIMING cold wants x3: ${median(coldWants)} ms")
        println("TIMING json, direct writer: ${median(json)} ms, ${library.toWireJson(None, ps2).length} characters")
        println("TIMING json, tree of elements: ${median(tree)} ms")
    }

    private fun oldLookups(store: ArtStore) {
        games.flatMap { game -> store.stored(game.id).toList() }
        games.filter { store.stored(it.id).isNone() && store.isAbsent(it.id, None) }.map { it.id.value }
    }
}
