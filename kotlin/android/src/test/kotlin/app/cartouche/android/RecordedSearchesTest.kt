// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.search.Finders
import app.cartouche.core.search.Order
import io.kotest.assertions.withClue
import io.kotest.matchers.shouldBe
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Test
import java.io.File

/**
 * The GDScript tests of the games search answer with what the core answers: every query a ribbon can reach on the shelves
 * of `app/test/carousel/search/recorded_searches.json`, as the plugin sends it, and where each is marked in a title.
 */
class RecordedSearchesTest {
    private val app = File(checkNotNull(System.getProperty("cartouche.app")) { "Run the tests through Gradle" })

    @Test
    fun `the searches the games screen tests read are the core's answers`() {
        val expected =
            buildJsonObject {
                SHELVES.forEach { (name, titles) -> put(name, record(titles)) }
            }
        val fixture = File(app, "test/carousel/search/recorded_searches.json")
        val found = if (fixture.exists()) Json.parseToJsonElement(fixture.readText()) else JsonObject(emptyMap())
        val update = File(checkNotNull(System.getProperty("cartouche.build")), "recorded_searches.json")
        if (found != expected) update.writeText(Json.encodeToString(JsonElement.serializer(), expected) + "\n")
        withClue("Out of date: copy $update to app/test/carousel/search/recorded_searches.json") { found shouldBe expected }
    }

    /** Each region of the shelf's games in turn, as the GDScript tests give them. */
    private fun record(titles: List<String>): JsonObject {
        val platform = PlatformId("ps2")
        val games = titles.mapIndexed { at, title -> game(title).copy(regions = listOf(REGIONS[at % REGIONS.size])) }
        val finders = Finders(Library(games = games))

        fun browse(order: Order, typed: String): JsonElement =
            Json.parseToJsonElement(jsonOf(finders.view(platform, order, typed).sent(finders.size(platform))))
        // The keys a ribbon offers after what is typed lead to every query it can reach.
        val reached = mutableMapOf<String, JsonElement>()
        val marks = mutableMapOf<String, JsonElement>()
        val queue = ArrayDeque(listOf("") + NAMED.flatMap { named -> named.indices.map { named.substring(0, it + 1) } })
        while (queue.isNotEmpty()) {
            val typed = queue.removeFirst()
            if (typed in reached) continue
            val view = finders.view(platform, Order.TITLE, typed)
            reached[typed] = browse(Order.TITLE, typed)
            if (typed.isNotEmpty()) {
                marks[typed] =
                    buildJsonObject {
                        view.games.forEach {
                            put(
                                it.toString(),
                                Json.parseToJsonElement(jsonOf(finders.marks(platform, it, typed).sent())),
                            )
                        }
                    }
            }
            if (typed.length < DEPTH) view.keys.keys.forEach { queue.addLast(typed + it) }
        }
        return buildJsonObject {
            put("titles", Json.parseToJsonElement(Json.encodeToString(titles)))
            put("regions", Json.parseToJsonElement(Json.encodeToString(games.map { it.regions.first() })))
            put("by_region", browse(Order.REGION, ""))
            put("browse", JsonObject(reached))
            put("marks", JsonObject(marks))
        }
    }

    private companion object {
        /**
         * How many keys a ribbon is followed for from nothing typed, and the longer queries the tests type or their seeded walk
         * reaches, with their beginnings: a query it asks that is not here stops the test.
         */
        const val DEPTH = 3
        val NAMED = listOf("dist ace", "ace", "c", "n", "s", "z co", "z of")
        val REGIONS = listOf("Europe", "USA", "Japan")
        val SHELVES =
            mapOf(
                "main" to
                    listOf(
                        "Ace Combat Distant Thunder",
                        "Ace Combat Zero",
                        "Bouncer",
                        "Burnout Takedown",
                        "Combat Ace",
                        "Dark Cloud",
                        "Distant Water",
                        "Ico",
                        "Katamari Damacy",
                        "Nights into Dreams",
                        "Nuages",
                        "Nuit Blanche",
                        "Okami",
                        "Shadow Hearts",
                        "Silent Hill",
                        "Zone of the Enders",
                    ),
                "next" to listOf("Rez", "Rygar", "Wild Arms"),
                "small" to listOf("Ace Combat Zero", "Bouncer", "Combat Ace"),
            )
    }
}
