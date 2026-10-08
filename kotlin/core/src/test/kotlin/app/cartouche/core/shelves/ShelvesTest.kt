// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.shelves

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryFormat
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.long
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.text.Collator
import java.util.Locale
import kotlin.random.Random

class ShelvesTest {
    private val ps2 = PlatformId("ps2")

    /** The order the carousel promises: titles as a reader sorts them, then ids. */
    private val readerOrder: Comparator<SelectedGame> =
        compareBy<SelectedGame, String>(Collator.getInstance(Locale.ROOT)) { it.title }.thenBy { it.id.value }

    @Test
    fun `titles are in the order a reader expects, case and accents counting last, then ids`() {
        val titles = listOf("Zelda" to "1", "ape escape" to "2", "Élan" to "3", "0 Story" to "4", "Ape Escape" to "5", "Elan" to "6")
        val library = Library(games = (titles + ("Elan" to "0")).map { (title, id) -> game(title).copy(id = GameId(id)) })
        val shelf = Shelves.of(library, listOf(ps2), Selection()).shouldBeSome().shelves.single()
        shelf.games.map { it.id.value } shouldBe listOf("4", "2", "5", "0", "6", "3", "1")
    }

    @Test
    fun `INV-E2-01 every platform with games has a shelf of exactly its games in title order, in catalog order`() = runBlocking<Unit> {
        checkAll(selectedLibraries, Arb.long()) { (library, selection), seed ->
            val catalog = shelfPlatforms.shuffled(Random(seed))
            val found = Shelves.of(library, catalog, selection)
            val withGames = catalog.filter { platform -> library.games.any { it.platform == platform } }
            if (withGames.isEmpty()) {
                found.shouldBeNone()
            } else {
                val shelves = found.shouldBeSome()
                shelves.shelves.map { it.platform } shouldBe withGames
                shelves.shelves.forEach { shelf ->
                    shelf.games shouldContainExactlyInAnyOrder library.games.filter { it.platform == shelf.platform }
                    shelf.games.zipWithNext().forEach { (a, b) ->
                        readerOrder.compare(SelectedGame.of(a), SelectedGame.of(b)) shouldBeLessThan 0
                    }
                }
            }
        }
    }

    @Test
    fun `INV-E2-01 the carousel starts on the remembered platform, else the first`() = runBlocking<Unit> {
        checkAll(selectedLibraries) { (library, selection) ->
            Shelves.of(library, shelfPlatforms, selection).onSome { shelves ->
                val shown = shelves.shelves[shelves.selected].platform
                selection.platform.filter { remembered -> shelves.shelves.any { it.platform == remembered } }.fold(
                    { shown shouldBe shelves.shelves.first().platform },
                    { shown shouldBe it },
                )
            }
        }
    }

    @Test
    fun `INV-E2-01 a shelf shows the remembered game, else the one that followed it, else the first`() = runBlocking<Unit> {
        var found = 0
        var followed = 0
        var wrapped = 0
        checkAll(selectedLibraries) { (library, selection) ->
            Shelves.of(library, shelfPlatforms, selection).onSome { shelves ->
                shelves.shelves.forEach { shelf ->
                    val expected =
                        selection.games.getOrNone(shelf.platform).fold({ 0 }) { remembered ->
                            val here = shelf.games.indexOfFirst { it.id == remembered.id }
                            val before = shelf.games.count { readerOrder.compare(SelectedGame.of(it), remembered) < 0 }
                            when {
                                here >= 0 -> here.also { found++ }
                                before < shelf.games.size -> before.also { followed++ }
                                else -> 0.also { wrapped++ }
                            }
                        }
                    shelf.selected shouldBe expected
                }
            }
        }
        // Each case is reached often.
        found shouldBeGreaterThan 100
        followed shouldBeGreaterThan 100
        wrapped shouldBeGreaterThan 10
    }

    @Test
    fun `INV-E7-08 the consoles show in the order the user put them in, the others after them in catalog order`() = runBlocking<Unit> {
        var reordered = 0
        var partly = 0
        var moved = 0
        // A stored order may also name a console the catalog no longer has: it never shows.
        val other = PlatformId("other")
        checkAll(selectedLibraries, Arb.long(), Arb.int(0..4), Arb.int(0..4)) { (library, selection), seed, count, again ->
            val random = Random(seed)
            val catalog = shelfPlatforms.shuffled(random)
            val placed = (catalog + other).shuffled(random).take(count)
            val ordered = library.withConsoleOrder(placed)

            fun shown(of: Library) = Shelves.of(of, catalog, selection).map { found -> found.shelves.map { it.platform } }

            fun withGames(platforms: List<PlatformId>) = platforms.filter { platform -> library.games.any { it.platform == platform } }
            Shelves.of(ordered, catalog, selection).onSome { found ->
                val platforms = found.shelves.map { it.platform }
                platforms shouldBe withGames(placed - other) + withGames(catalog - placed.toSet())
                if (platforms != withGames(catalog)) reordered++
                if (count in 1..2) partly++
                // The remembered platform is still the one shown first, wherever it is.
                selection.platform.filter { remembered -> platforms.contains(remembered) }.onSome {
                    platforms[found.selected] shouldBe it
                    if (found.selected != withGames(catalog).indexOf(it)) moved++
                }
            }
            LibraryFormat.decode(LibraryFormat.encode(ordered)).shouldBeRight().library shouldBe ordered
            // Put in another order later, those left out keep their place after the new ones.
            val later = (catalog + other).shuffled(random).take(again)
            shown(ordered.withConsoleOrder(later)).onSome { platforms ->
                platforms shouldBe withGames(later - other) + withGames(placed - later.toSet() - other) +
                    withGames(catalog - (placed + later).toSet())
            }
            // A console removed leaves the others in their order.
            placed.firstOrNone().onSome { first ->
                shown(ordered.without(first)) shouldBe shown(ordered).map { it - first }.filter { it.isNotEmpty() }
            }
        }
        reordered shouldBeGreaterThan 100
        partly shouldBeGreaterThan 100
        moved shouldBeGreaterThan 50
    }

    @Test
    fun `INV-E7-08 a console stored twice in the order shows once`() {
        val gc = PlatformId("gc")
        val library = Library(games = listOf(game("Okage", "ps2"), game("Pikmin", "gc")), consoleOrder = listOf(gc, ps2, gc))
        Shelves.of(library, shelfPlatforms, Selection()).shouldBeSome().shelves.map { it.platform } shouldBe listOf(gc, ps2)
    }

    @Test
    fun `the shelves do not depend on the order of the library`() = runBlocking<Unit> {
        checkAll(selectedLibraries, Arb.long()) { (library, selection), seed ->
            val shuffled = library.copy(games = library.games.shuffled(Random(seed)))
            Shelves.of(shuffled, shelfPlatforms, selection) shouldBe Shelves.of(library, shelfPlatforms, selection)
        }
    }

    @Test
    fun `selecting a game remembers it for its platform and shows that platform, and changes nothing else`() = runBlocking<Unit> {
        checkAll(selectedLibraries) { (library, selection) ->
            library.games.forEach { game: Game ->
                val selected = selection.with(game)
                selected.platform shouldBe Some(game.platform)
                selected.games shouldBe selection.games + (game.platform to SelectedGame(game.id, game.title))
            }
        }
    }
}
