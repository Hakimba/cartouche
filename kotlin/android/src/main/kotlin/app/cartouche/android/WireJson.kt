// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.art.FoundArt
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.MediumId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.search.Mark
import app.cartouche.core.search.View
import app.cartouche.core.shelves.Shelves
import arrow.core.Option
import arrow.core.getOrNone
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * As JSON text, which crosses the JNI bridge in milliseconds where a few hundred games as Dictionaries take about a second.
 * Shape: `{"setups": {platform id: setup}, "games": [game], "not_games": {platform id: [file name]}, "ignored_counts": {platform id:
 * {"hidden" or "unsupported": {"count", "examples"}}}, "skipped_folders": {platform id: [{"path", "reason"}]}, "shelves"?:
 * {"shelves": [{"platform", "games": [index into games], "selected"}], "selected"}}`; a missing value is an absent key.
 * Each game carries its platform's medium from [catalog], absent when the platform is unknown.
 */
internal fun Library.toWireJson(shelves: Option<Shelves>, catalog: Catalog): String {
    val media = catalog.platforms.associate { it.id to it.profile.medium }
    return StringBuilder(games.size * GAME_JSON_ESTIMATE)
        .obj {
            field("setups") { map(setups, PlatformId::value) { setup(it) } }
            field("games") { array(games) { each -> obj { game(each, media.getOrNone(each.platform).map { it.of(each.regions) }) } } }
            field("not_games") { map(notGames, PlatformId::value) { files -> array(files) { text(it.name.value) } } }
            field("ignored_counts") {
                map(ignoredCounts, PlatformId::value) { counts ->
                    map(counts, { it.wire }) { count ->
                        obj {
                            field("count") { append(count.count) }
                            field("examples") { array(count.examples) { text(it.value) } }
                        }
                    }
                }
            }
            field("skipped_folders") {
                map(skippedFolders, PlatformId::value) { folders ->
                    array(folders) { folder ->
                        obj {
                            field("path") { text(folder.path.value) }
                            field("reason") { text(folder.reason.wire) }
                        }
                    }
                }
            }
            field("console_variants") {
                obj { setups.keys.forEach { platform -> variantOf(platform).onSome { field(platform.value) { text(it.wire) } } } }
            }
            shelves.onSome { field("shelves") { shelves(it, games.withIndex().associate { (at, game) -> game.id to at }) } }
        }.toString()
}

// A few hundred characters a game carries; sizing the buffer once avoids regrowing it a dozen times.
private const val GAME_JSON_ESTIMATE = 250

/** What `JsonObject.toString` writes, built in one buffer: the same text without a tree of elements to allocate. */
private class Fields(val out: StringBuilder) {
    private var first = true

    inline fun field(key: String, value: StringBuilder.() -> Unit) {
        if (!first) out.append(',')
        first = false
        out.text(key).append(':').value()
    }

    fun some(key: String, value: Option<String>) = value.onSome { field(key) { text(it) } }
}

private inline fun StringBuilder.obj(fields: Fields.() -> Unit): StringBuilder {
    append('{')
    Fields(this).fields()
    return append('}')
}

private inline fun <T> StringBuilder.array(items: Iterable<T>, item: StringBuilder.(T) -> Unit) {
    append('[')
    var first = true
    for (each in items) {
        if (!first) append(',')
        first = false
        item(each)
    }
    append(']')
}

private inline fun <K, V> StringBuilder.map(entries: Map<K, V>, key: (K) -> String, value: StringBuilder.(V) -> Unit) = obj {
    entries.forEach { (k, v) -> field(key(k)) { value(v) } }
}

/** Quoted as `JsonPrimitive` does; only what needs escaping goes through it. */
private fun StringBuilder.text(value: String): StringBuilder {
    if (value.all { it >= ' ' && it != '"' && it != '\\' }) append('"').append(value).append('"') else append(JsonPrimitive(value))
    return this
}

private fun StringBuilder.setup(setup: PlatformSetup) = obj {
    field("disc_grouping") { text(setup.discs.wire) }
    field("folder_depth") { text(setup.depth.wire) }
    setup.folder.onSome { field("folder_uri") { text(it.value) } }
    setup.player.onSome { field("player_id") { text(it.value) } }
}

private fun Fields.game(game: Game, medium: Option<MediumId>) = with(game) {
    field("id") { text(id.value) }
    field("platform_id") { text(platform.value) }
    field("title") { text(shownTitle) }
    some("original_title", displayName.map { title })
    field("regions") { array(regions) { text(it) } }
    some("medium", medium.map { it.value })
    field("languages") { array(languages) { text(it) } }
    field("serials") { array(serials) { text(it) } }
    field("discs") {
        array(discs) { disc ->
            obj {
                field("name") { text(disc.file.name.value) }
                disc.number.onSome { field("number") { append(it) } }
            }
        }
    }
    field("last_disc") { append(lastDisc) }
    field("identified") { append(identified) }
    some("version", version)
    some("redump_name", redumpName)
    when (val chosen = label) {
        LabelChoice.Automatic -> Unit
        is LabelChoice.Region -> {
            field("label_region") { text(chosen.region.name) }
            field("label_source") { text(chosen.source.wire) }
        }
        LabelChoice.Own -> field("label_own") { append(true) }
    }
}

/** [indexes] places each game in the library's games. */
private fun StringBuilder.shelves(shelves: Shelves, indexes: Map<GameId, Int>) = obj {
    field("shelves") {
        array(shelves.shelves) { shelf ->
            obj {
                field("platform") { text(shelf.platform.value) }
                field("games") { array(shelf.games) { append(indexes.getValue(it.id)) } }
                field("selected") { append(shelf.selected) }
            }
        }
    }
    field("selected") { append(shelves.selected) }
}

private fun <K, V> Map<K, V>.toJson(key: (K) -> String, value: (V) -> JsonElement): JsonObject =
    JsonObject(entries.associate { key(it.key) to value(it.value) })

private fun <T> List<T>.toJson(item: (T) -> JsonElement): JsonArray = JsonArray(map(item))

/**
 * What the carousel shows of a shelf of [count] games, as JSON text: `{"count", "games": [position in the shelf],
 * "groups": [{"label", "start"}], "keys": {key: position in games}}`, a key being a lowercase letter, a digit or a
 * space. Thousands of positions cost a few milliseconds this way.
 */
internal fun View.toWireJson(count: Int): String {
    // Answered at each key typed: thousands of positions written straight, not as a tree of elements.
    val groups =
        groups.toJson {
            buildJsonObject {
                put("label", it.label)
                put("start", it.start)
            }
        }
    val keys = keys.toJson(Char::toString, ::JsonPrimitive)
    return """{"count":$count,"games":[${games.joinToString(",")}],"groups":$groups,"keys":$keys}"""
}

/** Where to underline a title, as JSON text: `[[start, length]]`, in characters. */
internal fun List<Mark>.toWireJson(): String = toJson { JsonArray(listOf(JsonPrimitive(it.start), JsonPrimitive(it.length))) }.toString()

/**
 * Stored art as JSON text, `[{"game_id", "path"}]`: a library's worth of Dictionaries would cost as much as its games
 * (see [toWireJson]).
 */
internal fun List<FoundArt>.artWireJson(): String = toJson { found ->
    buildJsonObject {
        put("game_id", found.game.value)
        put("path", found.art.file.path)
    }
}.toString()
