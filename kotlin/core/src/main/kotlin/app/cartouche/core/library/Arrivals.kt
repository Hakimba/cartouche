// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import kotlinx.serialization.Serializable

/**
 * The games a re-read of their folder brought, which the user has not seen yet: each one is [unseen] on its shelf
 * until the user leaves it there, and [announced] on its console until the user enters that console. Only a re-read
 * the user did not ask for marks games ([after]); marks only ever name games of the library ([within]).
 */
@Serializable
public data class Arrivals(public val unseen: Set<GameId> = emptySet(), public val announced: Map<PlatformId, Set<GameId>> = emptyMap()) {
    /**
     * [platform]'s games in [after] that [before] did not have are marked, and the marks of games gone dropped. None is
     * marked while [before]'s games of [platform] are those of a setup the user changed since ([Library.awaitingScan]):
     * the new setup's games are other games, all of them new.
     */
    public fun after(platform: PlatformId, before: Library, after: Library): Arrivals {
        val known = before.games.mapTo(HashSet()) { it.id }
        val came =
            if (platform in before.awaitingScan) {
                emptySet()
            } else {
                after.games.filter { it.platform == platform && it.id !in known }.mapTo(HashSet()) { it.id }
            }
        val marks = Arrivals(unseen + came, announced + (platform to announced.getOrElse(platform) { emptySet() } + came))
        return marks.within(after)
    }

    /** The user entered [platform]'s console: it announces nothing any more. */
    public fun entered(platform: PlatformId): Arrivals = copy(announced = announced - platform)

    /** The user left [game] on its shelf: it is not new any more. */
    public fun left(game: GameId): Arrivals = copy(unseen = unseen - game)

    /** Only the marks of [library]'s games. */
    public fun within(library: Library): Arrivals {
        val games = library.games.mapTo(HashSet()) { it.id }
        return Arrivals(
            unseen.filterTo(HashSet()) { it in games },
            announced.mapValues { (_, ids) -> ids.filterTo(HashSet()) { it in games } }.filterValues { it.isNotEmpty() },
        )
    }
}
