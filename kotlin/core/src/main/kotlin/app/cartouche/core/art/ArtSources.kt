// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.toNonEmptyListOrNone

/** Where one platform's disc scans are looked for: its LaunchBox extract by title, then its [bySerial] source. */
public class ArtSources(private val index: ArtIndex, private val bySerial: Option<SerialScans>) {
    /** The extract's version, which each request carries. */
    public val version: Option<ArtVersion> get() = index.version

    /** How many games the extract knows. */
    public val size: Int get() = index.size

    /**
     * Where to look for [game]'s disc scan: the scan of the region its label shows, if the user chose
     * one the extract has, then the extract's, closest to its regions first, then the scans of its
     * serials; none when no source can have one, or when its label is a picture of the user's own,
     * which no scan ever replaces.
     */
    public fun requestFor(game: Game): Option<ArtRequest> = if (game.label == LabelChoice.Own) {
        None
    } else {
        (chosen(game) + index.scansOf(game.title, game.regions) + bySerial.fold({ emptyList() }) { it.scansOf(game.serials) })
            .distinct()
            .toNonEmptyListOrNone()
            .map { ArtRequest(game.id, game.title, it, version) }
    }

    /** The scans the extract has for [game], one per region, closest to its own first (see [ArtIndex.variantsOf]). */
    public fun variantsOf(game: Game): List<ArtVariant> = index.variantsOf(game.title, game.regions)

    private fun chosen(game: Game): List<ArtUrl> = when (val label = game.label) {
        LabelChoice.Automatic, LabelChoice.Own -> emptyList()
        is LabelChoice.Region -> variantsOf(game).filter { it.region == label.region }.map { it.url }
    }

    public companion object {
        /**
         * Where to look for the art of [games] that still want it in their sources' version ([wants],
         * told what [versionOf] their platform's extract states), in their order, each from its
         * platform's [sources], asked for only for those games: when none wants art, as at most
         * starts, no extract is indexed.
         */
        public fun requests(
            games: List<Game>,
            wants: (GameId, Option<ArtVersion>) -> Boolean,
            versionOf: (PlatformId) -> Option<ArtVersion>,
            sources: (PlatformId) -> ArtSources,
        ): List<ArtRequest> = games.filter { wants(it.id, versionOf(it.platform)) }.flatMap { sources(it.platform).requestFor(it).toList() }
    }
}
