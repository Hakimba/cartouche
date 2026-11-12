// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import app.cartouche.core.art.LabelFraming
import app.cartouche.core.art.PixelRect
import app.cartouche.core.library.DisplayName
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.withClue
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.shouldBe
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Test
import java.io.File

/** The cases the GDScript tests of the app read from the same files: the two languages hold one rule, not two copies. */
class SharedVectorsTest {
    private fun vectors(name: String): JsonObject =
        Json.parseToJsonElement(File(checkNotNull(System.getProperty("cartouche.vectors")), name).readText()).jsonObject

    @Test
    fun `framings are the largest rectangle of the label's proportions round the centre asked, moved in only as far as needed`() {
        vectors("label_framing.json").getValue("cases").jsonArray.map { it.jsonObject }.shouldNotBeEmpty().forEach { case ->
            val (width, height) = case.getValue("picture").jsonArray.map { it.jsonPrimitive.int }
            val (x, y) = case.getValue("centre").jsonArray.map { it.jsonPrimitive.double }
            val (left, top, framedWidth, framedHeight) = case.getValue("framed").jsonArray.map { it.jsonPrimitive.int }
            val framing = LabelFraming(case.getValue("zoom").jsonPrimitive.double, x, y, case.getValue("proportion").jsonPrimitive.double)
            withClue("$case") { framing.framed(width, height) shouldBe PixelRect(left, top, framedWidth, framedHeight) }
        }
    }

    @Test
    fun `the names of display_name json are the ones a game keeps, at most the longest`() {
        val file = vectors("display_name.json")
        file.getValue("longest").jsonPrimitive.int shouldBe DisplayName.LONGEST
        file.getValue("cases").jsonArray.map { it.jsonObject }.shouldNotBeEmpty().forEach { case ->
            val kept = case.getValue("kept").jsonPrimitive.content
            withClue("$case") {
                DisplayName.of(case.getValue("typed").jsonPrimitive.content).map { it.text } shouldBe
                    if (kept.isEmpty()) None else Some(kept)
            }
        }
    }
}
