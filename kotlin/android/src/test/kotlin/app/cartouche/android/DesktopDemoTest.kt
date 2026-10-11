// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.DemoLibrary
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import io.kotest.assertions.withClue
import io.kotest.matchers.shouldBe
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import org.godotengine.godot.Dictionary
import org.junit.Test
import java.io.File

/**
 * Without the plugin (the Godot editor, a desktop run), the GDScript adapter answers with
 * `app/dev/demo/desktop.json`: the catalog and a demo library exactly as the plugin sends them.
 */
class DesktopDemoTest {
    private val app = File(checkNotNull(System.getProperty("cartouche.app")) { "Run the tests through Gradle" })

    @Test
    fun `INV-E2_5-01 the desktop demo is the catalog and the demo library as the plugin sends them`() {
        val data = File(app, "data/platforms")
        // In name order, as the plugin reads them.
        val files =
            listOf("daijishou", "cartouche")
                .flatMap { data.resolve(it).listFiles { file -> file.extension == "json" }.orEmpty().toList() }
                .sortedBy { it.name }
        val definitions = files.map { DefinitionSource(it.name, it.readText()) }
        val catalog = Catalog.parse(definitions, DefinitionSource("profiles.json", data.resolve("profiles.json").readText()))
        val platforms = catalog.platforms.map { it.id }
        val library = DemoLibrary.of(DESKTOP_GAMES, platforms)
        val expected =
            buildJsonObject {
                put("catalog", catalog.toWire().toJson())
                put("library", Json.parseToJsonElement(library.toWireJson(Shelves.of(library, platforms, Selection()), catalog)))
            }
        val fixture = File(app, "dev/demo/desktop.json")
        val found = if (fixture.exists()) Json.parseToJsonElement(fixture.readText()) else JsonObject(emptyMap())
        val update = File(checkNotNull(System.getProperty("cartouche.build")), "desktop.json")
        if (found != expected) update.writeText(PRETTY.encodeToString(JsonElement.serializer(), expected) + "\n")
        withClue("Out of date: copy $update to app/dev/demo/desktop.json") { found shouldBe expected }
    }

    private fun Any?.toJson(): JsonElement = when (this) {
        is Dictionary -> JsonObject(entries.associate { it.key to it.value.toJson() })
        is Array<*> -> JsonArray(map { it.toJson() })
        is String -> JsonPrimitive(this)
        is Number -> JsonPrimitive(this)
        is Boolean -> JsonPrimitive(this)
        else -> error("Not a wire value: $this")
    }

    private companion object {
        /** Enough games for every shelf of the three platforms to be an endless row. */
        const val DESKTOP_GAMES = 30
        val PRETTY = Json { prettyPrint = true }
    }
}
