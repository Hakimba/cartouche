// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.shelves

import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Some
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.flatMap
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map

/** The catalog's platforms in the shelves' tests; libraries also hold games of a platform outside it. */
val shelfPlatforms: List<PlatformId> = listOf("ps2", "gc", "gba").map(::PlatformId)

// Titles a reader and a plain string comparison sort differently: case, accents, digits, Japanese.
private val titles = Arb.element("ape escape", "Ape Escape 2", "Élan", "Elan", "Zelda", "0 Story", "ドラゴン", "a", "B", "b")

private val platformNames = Arb.element(shelfPlatforms.map { it.value } + "other")

/** Libraries of up to a dozen games over the platforms, titles often shared, ids all distinct. */
private val shelfLibraries: Arb<Library> =
    Arb.list(Arb.bind(titles, platformNames, ::Pair), 0..12).map { games ->
        Library(games = games.mapIndexed { i, (title, platform) -> game(title, platform).copy(id = GameId("$platform/$i")) })
    }

/**
 * What a selection may remember of [library]: its games, some since renamed (a rescan identified
 * them), games gone since, other platforms, nothing.
 */
private fun selections(library: Library): Arb<Selection> {
    val kept = library.games.map(SelectedGame::of)
    val gone = Arb.bind(titles, Arb.int(100..199)) { title, i -> SelectedGame(GameId("gone/$i"), title) }
    val remembered =
        if (kept.isEmpty()) {
            gone
        } else {
            Arb.choice(Arb.element(kept), Arb.bind(Arb.element(kept), titles) { game, title -> game.copy(title = title) }, gone)
        }
    val platform = Arb.choice(platformNames.map { Some(PlatformId(it)) }, Arb.constant(None))
    return Arb.bind(platform, Arb.list(Arb.bind(platformNames, remembered, ::Pair), 0..4)) { shown, games ->
        Selection(shown, games.associate { (platform, game) -> PlatformId(platform) to game })
    }
}

/** A library and a selection of it. */
val selectedLibraries: Arb<Pair<Library, Selection>> = shelfLibraries.flatMap { library -> selections(library).map { library to it } }
