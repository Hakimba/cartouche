// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.Option
import arrow.core.getOrNone
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The games whose label came from a later image only because ScreenScraper was skipped, each with
 * the identity of the image shown: at a later run with ScreenScraper open, the game is asked again
 * for the images before that one, and its label replaced only by one of them.
 */
@Serializable
public data class ProvisionalArt(private val games: Map<GameId, Identity> = emptyMap()) {
    /** The identity of the image [game]'s label shows for want of a better one, if so. */
    public fun shown(game: GameId): Option<Identity> = games.getOrNone(game)

    /** Remembers that [game]'s label shows [identity] for want of a better one. */
    public fun with(game: GameId, identity: Identity): ProvisionalArt = copy(games = games + (game to identity))

    /** [game]'s label is settled: the images before it were asked with ScreenScraper open. */
    public fun without(game: GameId): ProvisionalArt = copy(games = games - game)

    /** Only what is remembered of [kept]. */
    public fun keeping(kept: Set<GameId>): ProvisionalArt = copy(games = games.filterKeys { it in kept })

    public companion object {
        /** Stored as JSON; an unreadable text is none, which only means no label is asked again. */
        public fun decode(text: String): Option<ProvisionalArt> = Option.catch { Json.decodeFromString(serializer(), text) }

        public fun encode(provisional: ProvisionalArt): String = Json.encodeToString(serializer(), provisional)
    }
}
