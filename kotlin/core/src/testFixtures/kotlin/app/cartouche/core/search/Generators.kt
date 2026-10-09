// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.game
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.az
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string

// Words that start one another, repeat within a title, carry accents (composed or not), ligatures,
// digits, "the", and a script the search does not read.
private val vocabulary =
    listOf(
        "Ace",
        "Acer",
        "Combat",
        "C",
        "Distant",
        "Dist",
        "Thunder",
        "Water",
        "The",
        "the",
        "Élan",
        "Elan",
        "Pokémon",
        "ﬁnal",
        "Na",
        "Nu",
        "Night",
        "nuit",
        "2",
        "007",
        "ドラゴン",
        "Ōkami",
        "Æon",
    )
private val separators = Arb.element(" ", " - ", ": ", "-", "'", ", ", " (", ") ")

/** Titles of one to five words of [vocabulary], joined as titles are. */
val searchTitles: Arb<String> =
    Arb.list(Arb.bind(Arb.element(vocabulary), separators, ::Pair), 1..5).map { words ->
        words.joinToString("") { (word, separator) -> word + separator }.trim()
    }

/** A shelf of up to fifteen such games, titles often shared, ids all distinct, regions of any kind. */
val searchShelves: Arb<List<Game>> =
    Arb
        .list(Arb.bind(searchTitles, Arb.list(Arb.element("Europe", "USA", "Japan", "Korea", "World", "Atlantis"), 0..2), ::Pair), 0..15)
        .map { games -> games.mapIndexed { i, (title, regions) -> game(title).copy(id = GameId("ps2/$i"), regions = regions) } }

// The vocabulary as the ribbon types it: lowercase, without accents.
private val typedWords =
    listOf(
        "ace",
        "acer",
        "combat",
        "c",
        "distant",
        "dist",
        "thunder",
        "water",
        "the",
        "elan",
        "pokemon",
        "final",
        "na",
        "nu",
        "night",
        "nuit",
        "2",
        "007",
        "okami",
        "aeon",
    )

/**
 * What can be typed on the ribbon: starts of the vocabulary's words in any order, or any letters,
 * one to three words, a space after the last one or not.
 */
val typedQueries: Arb<String> =
    Arb.bind(
        Arb.list(Arb.choice(Arb.bind(Arb.element(typedWords), Arb.int(1..6), String::take), Arb.string(1..3, Codepoint.az())), 1..3),
        Arb.boolean(),
    ) { words, space -> words.joinToString(" ") + if (space) " " else "" }
