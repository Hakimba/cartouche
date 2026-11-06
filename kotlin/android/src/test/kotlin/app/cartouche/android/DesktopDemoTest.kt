// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.Coming
import app.cartouche.core.library.DemoLibrary
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.settings.Settings
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
 * `app/dev/demo/desktop.json`: the catalog, a demo library and a fresh install's settings exactly as the plugin sends them.
 */
class DesktopDemoTest {
    private val app = File(checkNotNull(System.getProperty("cartouche.app")) { "Run the tests through Gradle" })

    @Test
    fun `_5-01 the desktop demo is the catalog and the demo library as the plugin sends them`() {
        val data = File(app, "data/platforms")
        // By file name, as the app sends them: one of Cartouche's replaces Daijishō's of its name.
        val files =
            listOf("daijishou", "cartouche")
                .flatMap { data.resolve(it).listFiles { file -> file.extension == "json" }.orEmpty().toList() }
                .associateBy { it.name }
                .toSortedMap()
                .values
        val definitions = files.map { DefinitionSource(it.name, it.readText()) }
        val catalog =
            Catalog.parse(
                definitions,
                DefinitionSource("profiles.json", data.resolve("profiles.json").readText()),
                supportedPlatforms(),
            )
        // A model without a launch animation of its own is coming (`ConsoleManifest.is_coming`).
        val coming = Coming.of(consoleFolders().filterNot { LAUNCH.containsMatchIn(it.resolve("console.tres").readText()) }.map { it.name })
        val desktopCatalog = catalog.copy(platforms = catalog.platforms.filter { it.id in catalog.supported })

        fun library(platforms: List<PlatformId>): JsonElement = DemoLibrary.of(DESKTOP_GAMES, platforms).let {
            Json.parseToJsonElement(it.toWireJson(Shelves.of(it, platforms, Selection()), catalog))
        }
        val expected =
            buildJsonObject {
                put("catalog", desktopCatalog.toWire(coming).toJson())
                put("library", library(catalog.offered.map { it.platform }.filter { it !in coming }))
                put("library_with_coming", library(catalog.offered.map { it.platform }))
                // The settings of a fresh install, as the plugin sends them: the desktop's until changed.
                put("settings", Settings().toWire(firstLaunch = false).toJson())
                put(
                    "battery",
                    buildJsonObject {
                        put("level_percent", JsonPrimitive(100))
                        put("plugged", JsonPrimitive(true))
                    },
                )
            }
        val fixture = File(app, "dev/demo/desktop.json")
        val found = if (fixture.exists()) Json.parseToJsonElement(fixture.readText()) else JsonObject(emptyMap())
        val update = File(checkNotNull(System.getProperty("cartouche.build")), "desktop.json")
        if (found != expected) update.writeText(PRETTY.encodeToString(JsonElement.serializer(), expected) + "\n")
        withClue("Out of date: copy $update to app/dev/demo/desktop.json") { found shouldBe expected }
    }

    private fun consoleFolders(): List<File> =
        File(app, "carousel/consoles").listFiles { file -> file.resolve("console.tres").exists() }.orEmpty().toList()

    /** The platforms of the console manifests, as the app passes them at catalog load. */
    private fun supportedPlatforms(): Set<PlatformId> = consoleFolders()
        .map { folder ->
            val manifest = folder.resolve("console.tres").readText()
            PlatformId(checkNotNull(Regex("""^platform = "(.*)"$""", RegexOption.MULTILINE).find(manifest)).groupValues[1])
        }.toSet()

    private fun Any?.toJson(): JsonElement = when (this) {
        is Dictionary -> JsonObject(entries.associate { it.key to it.value.toJson() })
        is Array<*> -> JsonArray(map { it.toJson() })
        is String -> JsonPrimitive(this)
        is Number -> JsonPrimitive(this)
        is Boolean -> JsonPrimitive(this)
        else -> error("Not a wire value: $this")
    }

    private companion object {
        /** Enough games for every shelf of a few of the supported consoles to be an endless row. */
        const val DESKTOP_GAMES = 30
        val LAUNCH = Regex("""^launch = ".+"$""", RegexOption.MULTILINE)
        val PRETTY = Json { prettyPrint = true }
    }
}
