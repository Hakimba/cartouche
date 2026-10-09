// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.shelves.Shelves
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.maps.shouldContainExactly
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.text.Normalizer

class FinderTest {
    private val shelf =
        listOf("Ace Combat - Distant Thunder", "Ace Combat 5 - The Unsung War", "Combat Ace", "The Bouncer", "Distant Water", "Ōkami")
            .mapIndexed { i, title -> game(title).copy(id = GameId("ps2/$i")) }
    private val finder = Finder.of(shelf)

    private fun search(typed: String) = finder.search(Query.of(typed).shouldBeSome())

    private fun titles(view: View) = view.games.map { shelf[it].title }

    @Test
    fun `each word typed starts another word of the title, in any order`() {
        titles(search("ace dist")) shouldBe listOf("Ace Combat - Distant Thunder")
        titles(search("dist ace")) shouldBe listOf("Ace Combat - Distant Thunder")
        titles(search("ace c")) shouldBe listOf("Ace Combat - Distant Thunder", "Ace Combat 5 - The Unsung War", "Combat Ace")
        // "Ace" once: a second "a" word is needed for "ace a".
        titles(search("ace a")) shouldBe emptyList()
        titles(search("OKA")) shouldBe listOf("Ōkami")
        // "The" is no word to the search.
        titles(search("the")) shouldBe emptyList()
        titles(search("bou")) shouldBe listOf("The Bouncer")
    }

    @Test
    fun `the keys lit are those that still find a game, each on the first game it finds`() {
        search("ace").keys shouldContainExactly mapOf(' ' to 0)
        // After "ace ", the other words' first letters.
        search("ace ").keys shouldContainExactly mapOf('c' to 0, 'd' to 0, 't' to 0, '5' to 1, 'u' to 1, 'w' to 1)
        search("dist").keys shouldContainExactly mapOf('a' to 0, ' ' to 0)
    }

    @Test
    fun `a word typed may go back on its choice to leave room for the next one`() {
        val games = listOf("Distant Dist", "Acer Ace").map(::game)
        val finder = Finder.of(games)
        finder.search(Query.of("di distant").shouldBeSome()).games shouldBe listOf(0)
        finder.marks(0, Query.of("di distant").shouldBeSome()) shouldBe listOf(Mark(0, 7), Mark(8, 2))
        finder.search(Query.of("ac acer").shouldBeSome()).games shouldBe listOf(1)
        finder.marks(1, Query.of("ac acer").shouldBeSome()) shouldBe listOf(Mark(0, 4), Mark(5, 2))
    }

    @Test
    fun `nothing but signs typed is no query`() {
        Query.of("  -- ").shouldBeNone()
        Query.of("").shouldBeNone()
    }

    @Test
    fun `the index by title groups the shelf by letter and sends each key to its letter, or the next one`() {
        val games = listOf("Ace", "Bouncer", "Distant", "Zone", "007", "ドラゴン").map(::game)
        val index = Finder.of(games).index(Order.TITLE)
        index.games shouldBe games.indices.toList()
        index.groups shouldBe listOf(Group("A", 0), Group("B", 1), Group("D", 2), Group("Z", 3), Group("#", 4))
        // Every first letter is lit; "C" has no title, so its key goes on to "D", "0" to "#".
        index.keys shouldContainExactly mapOf('a' to 0, 'b' to 1, 'd' to 2, 'z' to 3, '0' to 4)
        // Past the last letter, round to the first.
        Finder.of(listOf("Ace Zone", "Bouncer").map(::game)).index(Order.TITLE).keys shouldContainExactly
            mapOf('a' to 0, 'z' to 0, 'b' to 1)
    }

    @Test
    fun `the index by region puts North America, Europe, Japan, then the rest, each in shelf order`() {
        val games =
            listOf(
                listOf("Japan"),
                listOf("Europe"),
                emptyList(),
                listOf("USA", "Europe"),
                listOf("Korea"),
                listOf("Atlantis"),
                listOf("Europe"),
            ).mapIndexed { i, regions -> game("$i").copy(regions = regions) }
        val index = Finder.of(games).index(Order.REGION)
        index.games shouldBe listOf(3, 1, 6, 0, 4, 2, 5)
        index.groups shouldBe listOf(Group("North America", 0), Group("Europe", 1), Group("Japan", 3), Group(Finder.WORLD, 5))
        index.keys shouldBe emptyMap()
    }

    @Test
    fun `the words typed are underlined where they are in the title, accents and ligatures included`() {
        finder.marks(0, Query.of("dist ace").shouldBeSome()) shouldBe listOf(Mark(0, 3), Mark(13, 4))
        val accents = Finder.of(listOf("Pokémon", "Pokémon Ruby", "ﬁnal ﬁght").map(::game))
        accents.marks(0, Query.of("poke").shouldBeSome()) shouldBe listOf(Mark(0, 4))
        accents.marks(1, Query.of("pokem r").shouldBeSome()) shouldBe listOf(Mark(0, 6), Mark(9, 1))
        accents.marks(2, Query.of("f fi").shouldBeSome()) shouldBe listOf(Mark(0, 1), Mark(5, 1))
        // Not found, or no such game: nothing to underline.
        finder.marks(3, Query.of("ace").shouldBeSome()) shouldBe emptyList()
        finder.marks(99, Query.of("ace").shouldBeSome()) shouldBe emptyList()
    }

    @Test
    fun `INV-E9-01 a game is found exactly when each word typed starts another word of its title, in shelf order`() = runBlocking<Unit> {
        var found = 0
        checkAll(searchShelves, typedQueries) { games, typed ->
            val view = Finder.of(games).search(Query.of(typed).shouldBeSome())
            view.games shouldBe games.indices.filter { matches(games[it], typed) }
            found += view.games.size
        }
        found shouldBeGreaterThan 200
    }

    @Test
    fun `typing key by key, then erasing, finds what a finder new to each query finds`() = runBlocking<Unit> {
        checkAll(searchShelves, typedQueries, Arb.int(0..6)) { games, typed, erased ->
            val finder = Finder.of(games)
            val steps = (1..typed.length).map { typed.take(it) } + (1..minOf(erased, typed.length - 1)).map { typed.dropLast(it) }
            steps.forEach { step ->
                Query.of(step).onSome { query -> finder.search(query) shouldBe Finder.of(games).search(query) }
            }
        }
    }

    @Test
    fun `INV-E9-02 a key is lit exactly when typing it still finds a game, and leads to the first game it finds`() = runBlocking<Unit> {
        var lit = 0
        var spaces = 0
        checkAll(searchShelves, typedQueries) { games, typed ->
            val view = Finder.of(games).search(Query.of(typed).shouldBeSome())
            val expected =
                KEYS.associateWith { key -> games.indices.filter { matches(games[it], typed + key) } }.filterValues { it.isNotEmpty() }
            // A space leads somewhere when a key typed after it does.
            val afterSpace = KEYS.flatMap { key -> games.indices.filter { matches(games[it], "$typed $key") } }
            val space = if (afterSpace.isNotEmpty() && !typed.endsWith(' ')) mapOf(' ' to afterSpace.min()) else emptyMap()
            view.keys shouldContainExactly expected.mapValues { (_, at) -> view.games.indexOf(at.first()) } +
                space.mapValues { (_, at) -> view.games.indexOf(at) }
            lit += view.keys.size
            spaces += space.size
        }
        lit shouldBeGreaterThan 200
        spaces shouldBeGreaterThan 30
    }

    @Test
    fun `each word typed is underlined once, on letters of the title that start with it`() = runBlocking<Unit> {
        var marked = 0
        checkAll(searchShelves, typedQueries) { games, typed ->
            val query = Query.of(typed).shouldBeSome()
            val finder = Finder.of(games)
            finder.search(query).games.forEach { at ->
                val title = games[at].shownTitle.codePoints().toArray()
                val marks = finder.marks(at, query)
                val parts = marks.map { fold(String(title, it.start, it.length)) }
                parts.forEach { it.size shouldBe 1 }
                // Typed words and marks pair one to one, each mark starting with its word, no longer
                // than it but for the letters a ligature or a plain-written letter brings.
                assignments(parts.indices.toList(), parts.size).any { order ->
                    order.zip(fold(typed)).all { (mark, word) ->
                        parts[mark][0].startsWith(word) && parts[mark][0].length <= word.length + 1
                    }
                } shouldBe true
                marked += marks.size
            }
        }
        marked shouldBeGreaterThan 200
    }

    @Test
    fun `INV-E9-02 with nothing typed, a key is lit exactly when typing it finds a game, and leads to its letter or the next one`() =
        runBlocking<Unit> {
            var crowded = 0
            checkAll(searchShelves) { shuffled ->
                val games = inShelfOrder(shuffled)
                val finder = Finder.of(games)
                val index = finder.index(Order.TITLE)
                index.keys.keys shouldBe KEYS.filter { key -> finder.search(Query.of("$key").shouldBeSome()).games.isNotEmpty() }.toSet()
                val letters = games.map { TitleLetter.of(it.title) }
                index.keys.forEach { (key, at) ->
                    val first =
                        if (key in 'a'..'z') {
                            letters.indexOfFirst { it != TitleLetter.OTHERS && it >= key.uppercaseChar() }
                        } else {
                            letters.indexOf(TitleLetter.OTHERS)
                        }
                    at shouldBe if (first < 0) 0 else first
                }
                if (index.groups.size < games.size) crowded++
            }
            crowded shouldBeGreaterThan 300
        }

    @Test
    fun `the index by title holds every game once in shelf order, each under its own letter`() = runBlocking<Unit> {
        checkAll(searchShelves) { shuffled ->
            val games = inShelfOrder(shuffled)
            val index = Finder.of(games).index(Order.TITLE)
            index.games shouldBe games.indices.toList()
            index.groups.zipWithNext().forEach { (a, b) -> (a.label != b.label && a.start < b.start) shouldBe true }
            index.groups.forEachIndexed { i, group ->
                val end = index.groups.getOrElse(i + 1) { Group("", games.size) }.start
                (group.start until end).forEach { TitleLetter.of(games[it].title).toString() shouldBe group.label }
            }
        }
    }

    private companion object {
        val KEYS = ('a'..'z') + ('0'..'9')

        /** [games] as their shelf orders them. */
        fun inShelfOrder(games: List<Game>): List<Game> = Shelves.gamesByPlatform(Library(games = games)).values.flatten()

        /** The oracle: the title's words and the words typed, read on their own; every way of giving each typed word its own title word. */
        fun matches(game: Game, typed: String): Boolean {
            val words = fold(game.shownTitle).filter { it != "the" }
            val typedWords = fold(typed)
            return assignments(words.indices.toList(), typedWords.size).any { chosen ->
                chosen.zip(typedWords).all { (word, start) -> words[word].startsWith(start) }
            }
        }

        /** Letters that do not decompose, written plainly. */
        val PLAIN = mapOf("æ" to "ae", "œ" to "oe", "ø" to "o", "ß" to "ss")

        fun fold(text: String): List<String> = PLAIN.entries
            .fold(
                Normalizer.normalize(text, Normalizer.Form.NFKD).lowercase(),
            ) { folded, (letter, plain) -> folded.replace(letter, plain) }
            .replace(Regex("""\p{M}"""), "")
            .split(Regex("[^a-z0-9]+"))
            .filter(String::isNotEmpty)

        /** Every ordered choice of [count] distinct items of [items]. */
        fun assignments(items: List<Int>, count: Int): List<List<Int>> = if (count ==
            0
        ) {
            listOf(emptyList())
        } else {
            items.flatMap { item -> assignments(items - item, count - 1).map { listOf(item) + it } }
        }
    }
}
