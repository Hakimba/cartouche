// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.library.Coming
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.CurtainTimes
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlatformTables
import app.cartouche.core.regions.PreferredRegion
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.toOption
import java.io.FileNotFoundException
import java.io.InputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.time.TimeSource

/** A table of the bundled data, one file per platform: `data/<folder>/<platform>.tsv`. */
internal enum class Table(private val folder: String) {
    TITLES("titles"),
    PRINTS("prints"),
    ART("art"),
    TEXTURES("screenscraper"),
    ;

    /** Where [platform]'s file is, under the project's root (`res://`). */
    fun path(platform: PlatformId): String = "data/$folder/${platform.value}.tsv"
}

/** Opens a platform's file of a [Table]; none when the app has no such file. */
internal fun interface TableFiles {
    fun open(table: Table, platform: PlatformId): Option<InputStream>

    companion object {
        val NONE = TableFiles { _, _ -> None }

        /** The files [open] finds under the project's root: one not found is none, any other failure fails the ask. */
        fun at(open: (String) -> InputStream): TableFiles = TableFiles { table, platform ->
            Either.catchOrThrow<FileNotFoundException, InputStream> { open(table.path(platform)) }.getOrNone()
        }
    }
}

/**
 * Everything `loadCatalog` loads, as one immutable value: a call sees one load, never new lists with old indexes. A
 * platform's tables are read from [files] and indexed on its first need, on the thread needing them (never Godot's:
 * only operations and the art's threads ask), once: a scan or a look for art gets them by asking, so none runs
 * without them.
 */
internal class Reference(
    val catalog: Catalog = Catalog(),
    /** The console models offered but not added yet. */
    val coming: Coming = Coming.NONE,
    val dataFolders: DataFolders = DataFolders.NONE,
    val curtainTimes: CurtainTimes = CurtainTimes.NONE,
    private val files: TableFiles = TableFiles.NONE,
) {
    private val titleIndexes = ConcurrentHashMap<PlatformId, Lazy<TitleIndex>>()
    private val artSources = ConcurrentHashMap<PlatformId, Lazy<ArtSources>>()
    private val versions = ConcurrentHashMap<PlatformId, Lazy<Option<ArtVersion>>>()

    fun titles(platform: PlatformId): TitleIndex = titleIndexes.once(platform) {
        loaded(platform, "title", setOf(Table.TITLES, Table.PRINTS)) { tables ->
            timed("titles", { index: TitleIndex, took -> "${platform.value}: ${index.size} indexed in ${took.inWholeMilliseconds} ms" }) {
                tables.titles.fold({ TitleIndex.EMPTY }) { TitleIndex.parse(it, tables.prints.getOrElse { "" }) }
            }
        }
    }

    fun sources(platform: PlatformId, preferred: Option<PreferredRegion>): ArtSources = artSources
        .once(platform) {
            loaded(platform, "art", setOf(Table.ART, Table.TEXTURES)) { tables ->
                timed(
                    "art",
                    { sources: ArtSources, took ->
                        "${platform.value}: ${sources.size} games, ${sources.releases} releases indexed in ${took.inWholeMilliseconds} ms"
                    },
                ) { ArtSources.of(catalog, platform, tables) }
            }
        }.preferring(preferred)

    /** Read from the first lines of the platform's art tables alone: asked for each game, it indexes nothing. */
    fun artVersion(platform: PlatformId): Option<ArtVersion> = versions.once(platform) {
        fun firstLine(table: Table) = files.open(table, platform).flatMap { file -> file.bufferedReader().use { it.readLine().toOption() } }
        ArtSources.versionOf(catalog, platform, PlatformTables(art = firstLine(Table.ART), textures = firstLine(Table.TEXTURES)))
    }

    /**
     * [make]'s value for [platform], made once by the first thread asking, others waiting on it alone, not on the map;
     * one that failed is made again on the next ask.
     */
    private fun <T> ConcurrentHashMap<PlatformId, Lazy<T>>.once(platform: PlatformId, make: () -> T): T =
        computeIfAbsent(platform) { lazy(make) }.value

    /** What [index] makes of [platform]'s [wanted] tables, read now. */
    private fun <T> loaded(platform: PlatformId, kind: String, wanted: Set<Table>, index: (PlatformTables) -> T): T {
        val started = TimeSource.Monotonic.markNow()

        fun text(table: Table) =
            if (table in wanted) files.open(table, platform).map { file -> file.bufferedReader().use { it.readText() } } else None
        val tables = PlatformTables(text(Table.TITLES), text(Table.PRINTS), text(Table.ART), text(Table.TEXTURES))
        val read = started.elapsedNow()
        return index(tables).also {
            trace("catalog") {
                "${platform.value} $kind tables read in ${read.inWholeMilliseconds} ms, loaded in ${(started.elapsedNow() - read).inWholeMilliseconds} ms"
            }
        }
    }
}
