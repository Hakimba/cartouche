// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.toNonEmptyListOrNone

/**
 * Made-up libraries, for trying the carousel and measuring it at scale without game files. Their games cannot be
 * launched. Titles mix short and long ones, accents and Japanese, like a real collection.
 */
public object DemoLibrary {
    private val FIRST = listOf("Crystal", "Shadow", "Neon", "Iron", "Silent", "Solar", "Wild", "Ōkami no", "Étoile", "Last")
    private val SECOND = listOf("Knights", "Racer", "Tactics", "Legends of the Northern Seas", "Hunter", "Drift", "Saga", "ファンタジー")
    private val SUFFIX = listOf("", " II", ": Director's Cut", " 3", "")

    /**
     * [games] games spread in turn over [platforms] (none without platforms); the same arguments always give the same
     * library.
     */
    public fun of(games: Int, platforms: List<PlatformId>): Library = platforms.toNonEmptyListOrNone().fold({ Library() }) { cycle ->
        Library(games = (0 until games).flatMap { game(it, cycle[it % cycle.size]).toList() })
    }

    private fun game(index: Int, platform: PlatformId): Option<Game> {
        val title = "${FIRST[index % FIRST.size]} ${SECOND[index / FIRST.size % SECOND.size]}${SUFFIX[index % SUFFIX.size]} $index"
        return ContentUri.parse("content://demo/$index").map { uri ->
            val disc = Disc(None, ListedFile(FileName("$title.iso"), uri, None, Some(0L)))
            Game(GameId("demo/$index"), platform, title, emptyList(), emptyList(), None, emptyList(), None, nonEmptyListOf(disc))
        }
    }
}
