// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.MediaRule
import app.cartouche.core.platforms.MediumId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlatformProfile
import app.cartouche.core.platforms.ScreenScraperSystem
import app.cartouche.core.platforms.SerialScans
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.regions.Regions
import arrow.core.None
import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.toNonEmptyListOrNone

/**
 * Where one platform's images are looked for: its LaunchBox extract by title, ScreenScraper's
 * texture table by reference name, and its [bySerial] source; each image shows a medium of its
 * [kind], read for a game of the medium its [media] give it (see [cutOf]), and they are tried in
 * the order of [order], for a user who prefers [preferred]'s images.
 */
public class ArtSources(
    private val kind: ArtKind,
    private val media: MediaRule,
    private val index: ArtIndex,
    private val bySerial: Option<SerialScans>,
    private val textures: TextureTable,
    private val preferred: Option<PreferredRegion> = None,
) {
    /** The sources' version, which each request carries: the extract's and the table's dates. */
    public val version: Option<ArtVersion> get() = ArtVersion.of(index.version, textures.version)

    /** How many games the extract knows. */
    public val size: Int get() = index.size

    /** How many releases the texture table knows. */
    public val releases: Int get() = textures.size

    /**
     * Where to look for [game]'s image: the image of the region its label shows, if the user chose
     * one the sources have, then every image the sources have in the order of [order]; none when no
     * source can have one, or when its label is a picture of the user's own, which no image ever
     * replaces.
     */
    public fun requestFor(game: Game): Option<ArtRequest> = if (game.label == LabelChoice.Own) {
        None
    } else {
        (chosen(game) + ordered(game, bySerial.fold({ emptyList() }) { it.scansOf(game.serials) }))
            .distinct()
            .toNonEmptyListOrNone()
            .map { ArtRequest(game.id, game.title, it, version, cutOf(game)) }
    }

    /** The same sources, for a user who prefers [region]'s images: nothing is indexed again. */
    public fun preferring(region: Option<PreferredRegion>): ArtSources = ArtSources(kind, media, index, bySerial, textures, region)

    /** How [game]'s label is cut from a scan. */
    public fun cutOf(game: Game): LabelCut = LabelCut(kind, media.of(game.regions))

    /**
     * The images the extract and the table have for [game] among those [offered] (the others left
     * out, as textures while ScreenScraper is not open, or a texture it answered it has none of):
     * every image of both sources, the first of [order] for each region (whichever name a source
     * gives it: `USA` and `North America` are one) and source, in that order (INV-E7-03).
     */
    public fun variantsOf(game: Game, offered: (Candidate) -> Boolean): List<ArtVariant> = ordered(game, emptyList())
        .filter(offered)
        .map { ArtVariant(LabelRegion(Regions.same(it.region)), it) }
        .distinctBy { it.region to it.candidate.source }

    private fun ordered(game: Game, serial: List<Candidate.Web>): List<Candidate> = order(
        kind,
        game.regions,
        index.scansOf(game.title, game.regions),
        game.redumpName.fold({ emptyList() }, textures::texturesOf),
        serial,
        preferred,
    )

    private fun chosen(game: Game): List<Candidate> = when (val label = game.label) {
        LabelChoice.Automatic, LabelChoice.Own -> emptyList()
        is LabelChoice.Region ->
            variantsOf(game) { true }.filter { it.region == label.region && it.candidate.source == label.source }.map { it.candidate }
    }

    public companion object {
        /** A platform whose profile names no kind of scan: none of its games is looked for, no image of it offered. */
        public val NONE: ArtSources = ArtSources(ArtKind.Disc, MediaRule(MediumId.NONE), ArtIndex.EMPTY, None, TextureTable.EMPTY)

        /**
         * [platform]'s sources: its profile's in [catalog], its extract and its texture table the
         * ones [extracts] and [tables] (texts by platform) hold for it, the table read only when the
         * profile names the platform's ScreenScraper system.
         */
        public fun of(
            catalog: Catalog,
            extracts: Map<PlatformId, String>,
            tables: Map<PlatformId, String>,
            platform: PlatformId,
        ): ArtSources = catalog
            .platform(platform)
            .flatMap { found ->
                found.profile.art.map { kind ->
                    val index = extracts.getOrNone(platform).fold({ ArtIndex.EMPTY }, ArtIndex::parse)
                    val textures =
                        tableOf(
                            found.profile,
                            tables,
                            platform,
                        ).fold({ TextureTable.EMPTY }) { (text, system) -> TextureTable.parse(text, system) }
                    ArtSources(kind, found.profile.medium, index, found.profile.scansBySerial, textures)
                }
            }.getOrElse { NONE }

        /** The version [of] gives [platform]'s sources, read from their first lines alone: no extract or table is indexed. */
        public fun versionOf(
            catalog: Catalog,
            extracts: Map<PlatformId, String>,
            tables: Map<PlatformId, String>,
            platform: PlatformId,
        ): Option<ArtVersion> = catalog.platform(platform).flatMap { found ->
            found.profile.art.flatMap {
                ArtVersion.of(
                    extracts.getOrNone(platform).flatMap(ArtIndex::versionOf),
                    tableOf(found.profile, tables, platform).flatMap { (text, _) -> ArtIndex.versionOf(text) },
                )
            }
        }

        private fun tableOf(
            profile: PlatformProfile,
            tables: Map<PlatformId, String>,
            platform: PlatformId,
        ): Option<Pair<String, ScreenScraperSystem>> =
            profile.screenScraperSystem.flatMap { system -> tables.getOrNone(platform).map { it to system } }

        /**
         * INV-E11-07: the order a game of [regions] tries its images in. An image is of the game's
         * region when its region is one of the game's or the zone holding one of them
         * ([Regions.isOwn]: a French game's are France's and Europe's, not Germany's; a world
         * release's the world's). A cartridge ([ArtKind.CartridgeFront]) takes ScreenScraper's
         * [textures] of its region first (the label as printed), then LaunchBox's [scans] of its
         * region, each closest first (France before Europe), then its [bySerial] scans, then every
         * other image closest first ([Regions.closestTo]), a texture before a scan when equally close; a disc
         * takes the scans of its region first, then the textures of its region, then its serial
         * scans, then the rest, a scan before a texture. A game of no region has no image of its
         * region: its serial scans, then the ranked list. INV-E11-08: with a [preferred] region, when
         * the images hold no or several regions surely the game's ([Regions.rank] 0 or 1), the rest
         * comes by [Regions.preferredFirst] before it is ranked.
         */
        public fun order(
            kind: ArtKind,
            regions: List<String>,
            scans: List<Candidate.Web>,
            textures: List<Candidate.Texture>,
            bySerial: List<Candidate.Web>,
            preferred: Option<PreferredRegion> = None,
        ): List<Candidate> {
            val (first, second) =
                when (kind) {
                    ArtKind.Disc -> scans to textures
                    is ArtKind.CartridgeFront -> textures to scans
                }
            val own = { candidate: Candidate -> Regions.isOwn(regions, candidate.region) }
            val closest = compareBy<Candidate, String>(Regions.closestTo(regions)) { it.region }
            val certain = (first + second).filter { Regions.rank(regions, it.region) <= 1 }.map { Regions.same(it.region) }.toSet()
            val rest =
                preferred.filter { certain.size != 1 }.fold({ closest }) { region ->
                    compareBy<Candidate> { Regions.preferredFirst(region, it.region) }.then(closest)
                }
            return first.filter(own).sortedWith(closest) + second.filter(own).sortedWith(closest) + bySerial +
                (first + second).filterNot(own).sortedWith(rest)
        }

        /**
         * Where to look for the art of [games] that still want it in their sources' version ([wants],
         * told what [versionOf] their platform's sources state), and of those whose label is
         * [provisional] while still automatic (a region the user chose or their own picture is never
         * asked again), in their order, each from its platform's [sources], asked for only for those
         * games: when none wants art, as at most starts, no extract or table is indexed. The
         * automatic labels among them that no source can have art for are [ArtPlan.unfound].
         */
        public fun requests(
            games: List<Game>,
            wants: (GameId, Option<ArtVersion>) -> Boolean,
            provisional: (GameId) -> Boolean,
            versionOf: (PlatformId) -> Option<ArtVersion>,
            sources: (PlatformId) -> ArtSources,
        ): ArtPlan {
            val planned =
                games
                    .filter { wants(it.id, versionOf(it.platform)) || it.label == LabelChoice.Automatic && provisional(it.id) }
                    .map { it to sources(it.platform).requestFor(it) }
            return ArtPlan(
                planned.flatMap { it.second.toList() },
                planned
                    .filter { (game, request) -> request.isNone() && game.label == LabelChoice.Automatic }
                    .associate { (game, _) -> game.id to versionOf(game.platform) },
            )
        }

        /**
         * The automatic labels of [games] whose first image [tried] (not a texture remembered
         * missing in the request's version) is another in [after] than in [before] (their platforms'
         * sources for one preferred region and another): those a change of the preference looks up
         * again; a label the user chose, or their own picture, is never one.
         */
        public fun reordered(
            games: List<Game>,
            before: (PlatformId) -> ArtSources,
            after: (PlatformId) -> ArtSources,
            tried: (Candidate, Option<ArtVersion>) -> Boolean,
        ): Set<GameId> {
            fun first(sources: ArtSources, game: Game) =
                sources.requestFor(game).flatMap { request -> request.candidates.firstOrNone { tried(it, request.version) } }
            return games
                .filter { it.label == LabelChoice.Automatic && first(before(it.platform), it) != first(after(it.platform), it) }
                .mapTo(HashSet()) { it.id }
        }

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

/**
 * A look's [requests], and the games of an automatic label wanting art that no source can have any
 * for ([unfound]), with their sources' version: known absent at once, they show their title.
 */
public data class ArtPlan(public val requests: List<ArtRequest>, public val unfound: Map<GameId, Option<ArtVersion>>)

/** The games whose label is looked up again ([asked]), and those no source can have art for ([unfound]). */
public data class LookAgain(public val asked: Set<GameId>, public val unfound: Set<GameId>)

/** The scans of [serials] (`SLPM-65688`) at this source, in order, of no stated region; serials of another form, as some lists hold, are left out. */
internal fun SerialScans.scansOf(serials: List<String>): List<Candidate.Web> = serials.filter(serial::matches).distinct().map {
    Candidate.Web(ArtUrl(template.replace(SerialScans.PLACE, it)), "", ArtSource.PSXDATACENTER)
}
