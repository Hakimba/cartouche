// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.shelves

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.platforms.PlatformId
import arrow.core.NonEmptyList
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.serialization.OptionSerializer
import arrow.core.toNonEmptyListOrNone
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.text.Collator
import java.util.Locale

/** A game as the selection remembers it: its [title] still places it on its shelf once it is gone. */
@Serializable
public data class SelectedGame(public val id: GameId, public val title: String) {
    public companion object {
        public fun of(game: Game): SelectedGame = SelectedGame(game.id, game.title)
    }
}

/** Where the user was: the platform shown last and, for each platform, the game selected last. */
@Serializable
public data class Selection(public val platform: Option<PlatformId> = None, public val games: Map<PlatformId, SelectedGame> = emptyMap()) {
    /** [game] selected, and its platform shown. */
    public fun with(game: Game): Selection = copy(platform = Some(game.platform), games = games + (game.platform to SelectedGame.of(game)))

    /** Nothing remembered of [platform]: its game, and that it was shown. */
    public fun without(platform: PlatformId): Selection = Selection(this.platform.filter { it != platform }, games - platform)
}

/** The games of one platform, in title order, and the index of the one shown first. */
public data class Shelf(public val platform: PlatformId, public val games: NonEmptyList<Game>, public val selected: Int)

/** One shelf per platform that has games, in catalog order, and the index of the shelf shown first. */
public data class Shelves(public val shelves: NonEmptyList<Shelf>, public val selected: Int) {
    public companion object {
        /**
         * The shelves of [library] for [platforms] (in the catalog's order), where [selection] left
         * the user: on each shelf the remembered game, else the one that followed it in title
         * order, else the first; the remembered platform, else the first. None when no platform
         * has games. Pure and total.
         */
        public fun of(library: Library, platforms: List<PlatformId>, selection: Selection): Option<Shelves> {
            val order = titleOrder()
            val byPlatform = library.games.groupBy { it.platform }
            val shelves =
                platforms.flatMap { platform ->
                    val games = byPlatform.getOrElse(platform) { emptyList() }.sortedWith(compareBy(order, SelectedGame::of))
                    games
                        .toNonEmptyListOrNone()
                        .map { shelf ->
                            Shelf(platform, shelf, selection.games.getOrNone(platform).fold({ 0 }) { shelf.indexOf(it, order) })
                        }.toList()
                }
            return shelves.toNonEmptyListOrNone().map { found ->
                Shelves(found, found.indexOfFirst { Some(it.platform) == selection.platform }.coerceAtLeast(0))
            }
        }

        /** Titles as a reader sorts them (case and accents count last), then ids: a total order. */
        private fun titleOrder(): Comparator<SelectedGame> {
            // A collator is not thread-safe: one per call.
            val collator = Collator.getInstance(Locale.ROOT)
            return compareBy<SelectedGame, String>(collator) { it.title }.thenBy { it.id.value }
        }

        private fun NonEmptyList<Game>.indexOf(remembered: SelectedGame, order: Comparator<SelectedGame>): Int {
            val here = indexOfFirst { it.id == remembered.id }
            val next = indexOfFirst { order.compare(SelectedGame.of(it), remembered) > 0 }
            return if (here >= 0) here else next.coerceAtLeast(0)
        }
    }
}
