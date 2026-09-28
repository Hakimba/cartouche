// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.Option
import arrow.core.getOrNone
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The games none of their sources has art for, each with the version of those sources: a game is
 * looked for again once its platform's extract changes. Sources of no version are never remembered.
 */
@Serializable
public data class AbsentArt(private val games: Map<GameId, ArtVersion> = emptyMap()) {
    /** Whether [request]'s game is known to have no art in the sources it would be looked for in. */
    public fun covers(request: ArtRequest): Boolean = request.version.isSome { games.getOrNone(request.game) == Option(it) }

    /** Remembers that no source of [request] has art for its game. */
    public fun with(request: ArtRequest): AbsentArt = request.version.fold({ this }) { copy(games = games + (request.game to it)) }

    public companion object {
        /** Stored as JSON; an unreadable text is none, which only means looking for those games again. */
        public fun decode(text: String): Option<AbsentArt> = Option.catch { Json.decodeFromString(serializer(), text) }

        public fun encode(absent: AbsentArt): String = Json.encodeToString(serializer(), absent)
    }
}
