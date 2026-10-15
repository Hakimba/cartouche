// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.set

/** Region names as Redump and LaunchBox write them, known or not, and none. */
val regionNames: Arb<String> =
    Arb.element(
        "Europe",
        "France",
        "Germany",
        "United Kingdom",
        "UK",
        "Australia",
        "Oceania",
        "USA",
        "United States",
        "North America",
        "Canada",
        "Brazil",
        "Japan",
        "Korea",
        "The Netherlands",
        "Netherlands",
        "Asia",
        "China",
        "World",
        "",
        "Atlantis",
    )

/**
 * Titles that meet once reduced (case, accents, punctuation, spaces), titles that do not, and titles
 * of no Latin letter or digit, which reduce to nothing.
 */
val artTitles: Arb<String> =
    Arb.element(
        "Chain Dive",
        "ChainDive",
        "CHAIN-DIVE",
        "Pokémon",
        "Pokemon",
        "Po\u0301kemon",
        "Dr. Muto",
        "Dr Muto",
        "Okage",
        "Okage 2",
        "Okage [Demo]",
        "Straße",
        "Strasse",
        "ゼロ",
        "Ωmega",
        "!!!",
        "",
    )

/** Alternate names: titles, and titles written with a country (`Okage (Japan)`), as LaunchBox names a game's release in it. */
val artAlternates: Arb<String> = Arb.choice(artTitles, Arb.bind(artTitles, regionNames) { title, country -> "$title ($country)" })

/** A region under the one name Redump and LaunchBox share for it, as the tests know it. */
fun sameRegion(region: String): String =
    mapOf("USA" to "North America", "United States" to "North America", "UK" to "United Kingdom", "The Netherlands" to "Netherlands")
        .getOrElse(region) { region }

/** One game of an extract: its name, alternate names, and disc scans as `region=file` pairs. */
data class ExtractGame(val name: String, val alternates: Set<String>, val discs: List<String>) {
    val line: String get() = listOf(name, alternates.joinToString("|"), discs.joinToString(";")).joinToString("\t")
}

/**
 * Extracts of a few games whose names and alternate names, plain or with a country, often collide. Every scan's file names
 * its game (`g3-disc-1.png` is the second scan of the fourth game), so that where a scan comes from
 * can be told.
 */
val extracts: Arb<List<ExtractGame>> =
    Arb
        .list(Arb.bind(artTitles, Arb.set(artAlternates, 0..2), Arb.list(regionNames, 0..4), ::Triple), 1..6)
        .map { games ->
            games.mapIndexed { game, (name, alternates, discs) ->
                ExtractGame(name, alternates - name, discs.mapIndexed { i, region -> "$region=g$game-disc-$i.png" })
            }
        }

/** The extract file of [games], from the database of [date]. */
fun extract(games: List<ExtractGame>, date: String = "2026-09-28"): String = (listOf("# $date") + games.map { it.line }).joinToString("\n")
