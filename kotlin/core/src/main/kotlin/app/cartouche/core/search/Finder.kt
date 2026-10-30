// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.Game
import app.cartouche.core.library.Library
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.regions.Regions
import app.cartouche.core.shelves.Shelves
import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone

/** How the index orders a shelf: by the letters of its titles, or by region. */
public enum class Order { TITLE, REGION }

/** The shown games from position [start] on that share a [label]: a letter, [TitleLetter.OTHERS], a region. */
public data class Group(public val label: String, public val start: Int)

/** Part of a shown title to underline: [length] code points from [start]. */
public data class Mark(public val start: Int, public val length: Int)

/**
 * What the carousel shows: [games], as positions in the shelf's order; the index's [groups] of them (none while
 * searching); and each key of the ribbon that leads to a game (a letter, a digit, a space) with the position among
 * [games] it brings the carousel to.
 */
public data class View(public val games: List<Int>, public val groups: List<Group>, public val keys: Map<Char, Int>)

/**
 * The index and the search of one shelf's games, given in the shelf's order: each title is read once, when the finder
 * is made. Total; what it found for the words typed lately is kept to answer the next keys sooner, which changes no
 * answer.
 */
public class Finder private constructor(private val titles: List<Title>) {
    /** How many games the shelf has. */
    public val size: Int get() = titles.size

    private class Title(val words: List<Word>, val letter: Char, val region: String)

    @Volatile private var recent: Map<String, View> = emptyMap()

    private val byTitle: View by lazy {
        val groups = groups(titles.map { it.letter.toString() })
        // Every first letter of a word: a search could start with any.
        val keys = search(emptyList(), "").keys.mapValues { letterStart(groups, it.key) }
        View(titles.indices.toList(), groups, keys)
    }

    private val byRegion: View by lazy {
        val regions = REGIONS.flatMap { region -> titles.indices.filter { titles[it].region == region } }
        View(regions, groups(regions.map { titles[it].region }), emptyMap())
    }

    /**
     * The whole shelf, in [order], with its groups. By title (the shelf's order: titles that start
     * with a digit or a sign before the A, other scripts after the Z, both under
     * [TitleLetter.OTHERS]), the keys are those a search could start with; a letter brings the
     * carousel to its first game, or to the next letter's, or round to the first game; a digit, to
     * the first game under [TitleLetter.OTHERS]. By region, no key: nothing is typed.
     */
    public fun index(order: Order): View = when (order) {
        Order.TITLE -> byTitle
        Order.REGION -> byRegion
    }

    /**
     * The games whose title has, for each word of [query], another word starting with it, in shelf order; and each
     * key that, typed next, still finds a game, with the first game it finds.
     */
    public fun search(query: Query): View {
        val text = query.text
        // What was found for the words typed lately, each the start of the last: typing on narrows
        // what was found, and erasing finds it again, rather than reading every title at each key.
        val kept = recent.filterKeys(text::startsWith)
        val narrowed = kept.entries.sortedByDescending { it.key.length }.firstOrNone()
        val view = kept.getOrElse(text) { search(query.done, query.typing, narrowed.fold({ titles.indices.toList() }) { it.value.games }) }
        recent = kept + (text to view)
        return view
    }

    /** Where [query]'s words are in the title of the game at shelf [position]; none when it is not found. */
    public fun marks(position: Int, query: Query): List<Mark> {
        if (position !in titles.indices) return emptyList()
        val words = titles[position].words
        return Words.taking(words, query.prefixes).fold({ emptyList() }) { taken ->
            words.indices.filter { taken[it] > 0 }.map { word ->
                words[word].let { found -> Mark(found.start, found.ends.getOrElse(taken[word] - 1) { found.start } - found.start) }
            }
        }
    }

    private fun search(done: List<String>, typing: String, among: List<Int> = titles.indices.toList()): View {
        val prefixes = if (typing.isEmpty()) done else done + typing
        val found = mutableListOf<Int>()
        // The first game each key finds, by its code (keys are ASCII letters, digits and the space).
        val firsts = IntArray(KEY_CODES) { -1 }
        // One pass over thousands of titles at each key typed, local buffers rather than copies; a
        // key found already is not looked for again.
        for (position in among) {
            val words = titles[position].words
            val fits = if (prefixes.size == 1) words.any { it.text.startsWith(prefixes[0]) } else Words.taking(words, prefixes).isSome()
            if (!fits) continue
            for (word in words.indices) {
                val text = words[word].text
                if (text.length <= typing.length || !text.startsWith(typing)) continue
                val key = text[typing.length].code
                // The word typed so far goes on with this key only where the other words typed still fit.
                if (firsts[key] < 0 && (done.isEmpty() || Words.taking(words, done, skip = word).isSome())) firsts[key] = found.size
            }
            // A space starts another word: the title must have one left once the others are taken.
            if (typing.isNotEmpty() && words.size > prefixes.size && firsts[SPACE.code] < 0) firsts[SPACE.code] = found.size
            found += position
        }
        return View(found, emptyList(), firsts.indices.filter { firsts[it] >= 0 }.associate { it.toChar() to firsts[it] })
    }

    public companion object {
        /** The world, and regions the art sources do not know, come last. */
        public const val WORLD: String = "World"
        private val REGIONS = Regions.umbrellas + WORLD
        private val LETTERS = ('A'..'Z').map(Char::toString)
        private const val SPACE = ' '
        private const val KEY_CODES = 128

        /** The finder of [games], in their shelf's order. */
        public fun of(games: List<Game>): Finder = Finder(
            games.map { game ->
                Title(Words.of(game.shownTitle), TitleLetter.of(game.title), Regions.umbrellaOf(game.regions).getOrElse { WORLD })
            },
        )

        private fun letterStart(groups: List<Group>, key: Char): Int {
            val letter = key.uppercaseChar().toString()
            val starts =
                if (letter in
                    LETTERS
                ) {
                    groups.filter { it.label in LETTERS && it.label >= letter }
                } else {
                    groups.filter { it.label !in LETTERS }
                }
            return starts.firstOrNone().fold({ 0 }, Group::start)
        }

        private fun groups(labels: List<String>): List<Group> =
            labels.withIndex().filter { (at, label) -> labels.getOrElse(at - 1) { "" } != label }.map { (at, label) -> Group(label, at) }
    }
}

/**
 * The finders of [library]'s shelves, made all at once when one is first asked for, or by [prepare]. Safe to ask from
 * any thread; asked for while [prepare] makes them, they wait for it.
 */
public class Finders(private val library: Library) {
    private val byPlatform: Map<PlatformId, Finder> by lazy {
        Shelves.gamesByPlatform(library).mapValues { Finder.of(it.value) }
    }

    /** The finder of [platform]'s shelf; none when it has no game. */
    public fun of(platform: PlatformId): Option<Finder> = byPlatform.getOrNone(platform)

    /** How many games [platform]'s shelf has. */
    public fun size(platform: PlatformId): Int = of(platform).fold({ 0 }, Finder::size)

    /**
     * What the carousel shows of [platform]'s shelf: the games found for [typed], or with nothing typed (or only
     * signs) the index in [order]; nothing for a platform without games.
     */
    public fun view(platform: PlatformId, order: Order, typed: String): View = of(platform).fold({
        View(emptyList(), emptyList(), emptyMap())
    }) { finder -> Query.of(typed).fold({ finder.index(order) }, finder::search) }

    /** Where [typed] is in the title of the game at [position] of [platform]'s shelf (see [Finder.marks]). */
    public fun marks(platform: PlatformId, position: Int, typed: String): List<Mark> =
        of(platform).flatMap { finder -> Query.of(typed).map { finder.marks(position, it) } }.getOrElse { emptyList() }

    /** Makes every finder and its index by title now, on the caller's thread, rather than at the first search. */
    public fun prepare() {
        byPlatform.values.forEach { it.index(Order.TITLE) }
    }

    /**
     * These finders if [kept] searches the same (a game launched, a label chosen: the same titles, names, regions and
     * consoles), else new ones for it.
     */
    public fun after(kept: Library): Finders {
        val same = kept.games.size == library.games.size && kept.games.zip(library.games).all { (a, b) -> searchSame(a, b) }
        return if (same) this else Finders(kept)
    }

    public companion object {
        public val NONE: Finders = Finders(Library())

        private fun searchSame(a: Game, b: Game): Boolean =
            a.id == b.id && a.platform == b.platform && a.title == b.title && a.shownTitle == b.shownTitle && a.regions == b.regions
    }
}
