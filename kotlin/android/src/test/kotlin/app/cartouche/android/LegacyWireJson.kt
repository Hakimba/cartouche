// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.Disc
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.SkippedFolder
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.MediumId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.shelves.Shelves
import arrow.core.Option
import arrow.core.getOrNone
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** The library's wire JSON as first written, a tree of elements: the oracle the direct writer must equal character for character. */
internal fun Library.toWireJsonTree(shelves: Option<Shelves>, catalog: Catalog): String = buildJsonObject {
    val media = catalog.platforms.associate { it.id to it.profile.medium }
    put("setups", setups.toJson(PlatformId::value) { it.toJson() })
    put("games", games.toJson { game -> game.toJson(media.getOrNone(game.platform).map { it.of(game.regions) }) })
    put("not_games", notGames.toJson(PlatformId::value) { files -> files.toJson { JsonPrimitive(it.name.value) } })
    put("ignored_counts", ignoredCounts.toJson(PlatformId::value) { counts -> counts.toJson({ it.wire }) { it.toJson() } })
    put("skipped_folders", skippedFolders.toJson(PlatformId::value) { folders -> folders.toJson { it.toJson() } })
    put(
        "console_variants",
        buildJsonObject {
            setups.keys.forEach { platform -> variantOf(platform).onSome { put(platform.value, it.wire) } }
        },
    )
    shelves.onSome { put("shelves", it.toJson(games.withIndex().associate { (at, game) -> game.id to at })) }
}.toString()

private fun PlatformSetup.toJson(): JsonObject = buildJsonObject {
    put("disc_grouping", discs.wire)
    put("folder_depth", depth.wire)
    putSome("folder_uri", folder.map { it.value })
    putSome("player_id", player.map { it.value })
}

private fun Game.toJson(medium: Option<MediumId>): JsonObject = buildJsonObject {
    put("id", id.value)
    put("platform_id", platform.value)
    put("title", shownTitle)
    putSome("original_title", displayName.map { title })
    put("regions", regions.toJson(::JsonPrimitive))
    putSome("medium", medium.map { it.value })
    put("languages", languages.toJson(::JsonPrimitive))
    put("serials", serials.toJson(::JsonPrimitive))
    put("discs", discs.toJson { it.toJson() })
    put("last_disc", lastDisc)
    put("identified", identified)
    putSome("version", version)
    putSome("redump_name", redumpName)
    when (val chosen = label) {
        LabelChoice.Automatic -> Unit
        is LabelChoice.Region -> {
            put("label_region", chosen.region.name)
            put("label_source", chosen.source.wire)
        }
        LabelChoice.Own -> put("label_own", true)
    }
}

private fun Disc.toJson(): JsonObject = buildJsonObject {
    put("name", file.name.value)
    number.onSome { put("number", it) }
}

private fun IgnoredCount.toJson(): JsonObject = buildJsonObject {
    put("count", count)
    put("examples", examples.toJson { JsonPrimitive(it.value) })
}

/** [indexes] places each game in the library's games. */
private fun Shelves.toJson(indexes: Map<GameId, Int>): JsonObject = buildJsonObject {
    put(
        "shelves",
        shelves.toJson { shelf ->
            buildJsonObject {
                put("platform", shelf.platform.value)
                put("games", shelf.games.toJson { JsonPrimitive(indexes.getValue(it.id)) })
                put("selected", shelf.selected)
            }
        },
    )
    put("selected", selected)
}

private fun SkippedFolder.toJson(): JsonObject = buildJsonObject {
    put("path", path.value)
    put("reason", reason.wire)
}

private fun <K, V> Map<K, V>.toJson(key: (K) -> String, value: (V) -> JsonElement): JsonObject =
    JsonObject(entries.associate { key(it.key) to value(it.value) })

private fun <T> List<T>.toJson(item: (T) -> JsonElement): JsonArray = JsonArray(map(item))

private fun JsonObjectBuilder.putSome(key: String, value: Option<String>) = value.onSome { put(key, it) }
