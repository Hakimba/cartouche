// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.DemoLibrary
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import arrow.core.toOption
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
        val catalog =
            Catalog.parse(
                definitions,
                DefinitionSource("profiles.json", data.resolve("profiles.json").readText()),
                supportedPlatforms(),
            )
        val platforms = catalog.offered.map { it.platform }
        val desktopCatalog = catalog.copy(platforms = catalog.platforms.filter { it.id in catalog.supported })
        val library = DemoLibrary.of(DESKTOP_GAMES, platforms)
        val expected =
            buildJsonObject {
                put("catalog", desktopCatalog.toWire().toJson())
                put("library", Json.parseToJsonElement(library.toWireJson(Shelves.of(library, platforms, Selection()), catalog)))
                // What the desktop shows of the battery: full and charging, as the design draws it.
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

    /** The platforms of the console manifests, as the app passes them at catalog load. */
    private fun supportedPlatforms(): Set<PlatformId> = File(app, "carousel/consoles")
        .listFiles { file -> file.resolve("console.tres").exists() }
        .orEmpty()
        .map { folder ->
            val manifest = folder.resolve("console.tres").readText()
            PlatformId(checkNotNull(Regex("""^platform = "(.*)"$""", RegexOption.MULTILINE).find(manifest)).groupValues[1])
        }.toSet()

    @Test
    fun `INV-E12-C1-01 the desktop demo offers exactly the twelve supported consoles, as the catalog lists them`() {
        val data = File(app, "data/platforms")
        val definitions =
            listOf("daijishou", "cartouche")
                .flatMap { data.resolve(it).listFiles { file -> file.extension == "json" }.orEmpty().toList() }
                .map { DefinitionSource(it.name, it.readText()) }
        val profiles = DefinitionSource("profiles.json", data.resolve("profiles.json").readText())
        val expected = Catalog.parse(definitions, profiles, supportedPlatforms()).offered
        val demo = Json.parseToJsonElement(File(app, "dev/demo/desktop.json").readText()) as JsonObject
        val offered = ((demo["catalog"] as JsonObject)["offered"] as JsonArray).map { it as JsonObject }
        expected.size shouldBe 12
        offered.map { it["id"] } shouldBe expected.map { JsonPrimitive(it.platform.value) }
        offered.map { it["model"] } shouldBe expected.map { JsonPrimitive(it.model) }
        // As on the wire, a console with no maker has no key.
        offered.map { it["maker"].toOption() } shouldBe expected.map { console -> console.maker.map { JsonPrimitive(it) } }
    }

    @Test
    fun `INV-E12-D1-01 the desktop demo and the demo library hold games of supported consoles only`() {
        val supported = supportedPlatforms().map { it.value }.toSet()
        supported.size shouldBe 12
        val demo = Json.parseToJsonElement(File(app, "dev/demo/desktop.json").readText()) as JsonObject
        val games = (demo["library"] as JsonObject)["games"] as JsonArray
        val platforms =
            games.map {
                ((it as JsonObject)["platform_id"] as JsonPrimitive).content
            }
        platforms.size shouldBe DESKTOP_GAMES
        (platforms.toSet() - supported) shouldBe emptySet()
        platforms.toSet() shouldBe supported
        val catalog = demo["catalog"] as JsonObject
        val listed = (catalog["platforms"] as JsonArray).map { ((it as JsonObject)["id"] as JsonPrimitive).content }
        listed.size shouldBe supported.size
        listed.toSet() shouldBe supported
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
        /** Enough games for every shelf of a few of the supported consoles to be an endless row. */
        const val DESKTOP_GAMES = 30
        val PRETTY = Json { prettyPrint = true }
    }
}
