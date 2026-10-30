// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.CurtainTimes
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.regions.PreferredRegion
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.getOrNone
import java.util.concurrent.ConcurrentHashMap

/** Everything `loadCatalog` loads, as one immutable value: a call sees one load, never new lists with old indexes. */
internal class Reference(
    val catalog: Catalog = Catalog(),
    private val titleLists: Map<PlatformId, String> = emptyMap(),
    private val printLists: Map<PlatformId, String> = emptyMap(),
    val dataFolders: DataFolders = DataFolders.NONE,
    val curtainTimes: CurtainTimes = CurtainTimes.NONE,
    private val artLists: Map<PlatformId, String> = emptyMap(),
    private val textureLists: Map<PlatformId, String> = emptyMap(),
) {
    private val titleIndexes = ConcurrentHashMap<PlatformId, TitleIndex>()
    private val artSources = ConcurrentHashMap<PlatformId, ArtSources>()

    val titledPlatforms: Set<PlatformId> get() = titleLists.keys

    fun titles(platform: PlatformId): TitleIndex = titleIndexes.computeIfAbsent(platform) {
        timed(
            "titles",
            { index: TitleIndex, took -> "${platform.value}: ${index.size} indexed in ${took.inWholeMilliseconds} ms" },
        ) {
            titleLists.getOrNone(platform).fold({ TitleIndex.EMPTY }) { TitleIndex.parse(it, printLists.getOrElse(platform) { "" }) }
        }
    }

    fun sources(platform: PlatformId, preferred: Option<PreferredRegion>): ArtSources = artSources
        .computeIfAbsent(platform) {
            timed(
                "art",
                { sources: ArtSources, took ->
                    "${platform.value}: ${sources.size} games, ${sources.releases} releases indexed in ${took.inWholeMilliseconds} ms"
                },
            ) { ArtSources.of(catalog, artLists, textureLists, platform) }
        }.preferring(preferred)

    fun artVersion(platform: PlatformId): Option<ArtVersion> = ArtSources.versionOf(catalog, artLists, textureLists, platform)
}
