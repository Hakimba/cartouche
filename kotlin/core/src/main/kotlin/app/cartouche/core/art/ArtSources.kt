// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.MediaRule
import app.cartouche.core.platforms.MediumId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.SerialScans
import arrow.core.None
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.toNonEmptyListOrNone

/**
 * Where one platform's scans are looked for: its LaunchBox extract by title, then its [bySerial]
 * source; each scan shows a medium of its [kind], read for a game of the medium its [media] give it
 * (see [cutOf]).
 */
public class ArtSources(
    private val kind: ArtKind,
    private val media: MediaRule,
    private val index: ArtIndex,
    private val bySerial: Option<SerialScans>,
) {
    /** The extract's version, which each request carries. */
    public val version: Option<ArtVersion> get() = index.version

    /** How many games the extract knows. */
    public val size: Int get() = index.size

    /**
     * Where to look for [game]'s scan: the scan of the region its label shows, if the user chose
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
            .map { ArtRequest(game.id, game.title, it, version, cutOf(game)) }
    }

    /** How [game]'s label is cut from a scan. */
    public fun cutOf(game: Game): LabelCut = LabelCut(kind, media.of(game.regions))

    /** The scans the extract has for [game], one per region, closest to its own first (see [ArtIndex.variantsOf]). */
    public fun variantsOf(game: Game): List<ArtVariant> = index.variantsOf(game.title, game.regions)

    private fun chosen(game: Game): List<ArtUrl> = when (val label = game.label) {
        LabelChoice.Automatic, LabelChoice.Own -> emptyList()
        is LabelChoice.Region -> variantsOf(game).filter { it.region == label.region }.map { it.url }
    }

    public companion object {
        /** A platform whose profile names no kind of scan: none of its games is looked for, no image of it offered. */
        public val NONE: ArtSources = ArtSources(ArtKind.Disc, MediaRule(MediumId.NONE), ArtIndex.EMPTY, None)

        /** [platform]'s sources: its profile's in [catalog], its extract the one [extracts] (texts by platform) holds for it. */
        public fun of(catalog: Catalog, extracts: Map<PlatformId, String>, platform: PlatformId): ArtSources = catalog
            .platform(platform)
            .flatMap { found ->
                found.profile.art.map {
                    val index = extracts.getOrNone(platform).fold({ ArtIndex.EMPTY }, ArtIndex::parse)
                    ArtSources(it, found.profile.medium, index, found.profile.scansBySerial)
                }
            }.getOrElse { NONE }

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

        /**
         * Which automatic labels of [games] are looked up again from scratch: those a source of their
         * platform's [sources] may have art for, and those none can, whose image goes; a label the user
         * chose, their own picture or a region's image, is neither, and stays.
         */
        public fun lookAgain(games: List<Game>, sources: (PlatformId) -> ArtSources): LookAgain {
            val automatic = games.filter { it.label == LabelChoice.Automatic }
            val (asked, unfound) = automatic.partition { sources(it.platform).requestFor(it).isSome() }
            return LookAgain(asked.mapTo(HashSet()) { it.id }, unfound.mapTo(HashSet()) { it.id })
        }
    }
}

/** The games whose label is looked up again ([asked]), and those no source can have art for ([unfound]). */
public data class LookAgain(public val asked: Set<GameId>, public val unfound: Set<GameId>)

/** The scans of [serials] (`SLPM-65688`) at this source, in order; serials of another form, as some lists hold, are left out. */
internal fun SerialScans.scansOf(serials: List<String>): List<ArtUrl> =
    serials.filter(serial::matches).distinct().map { ArtUrl(template.replace(SerialScans.PLACE, it)) }
