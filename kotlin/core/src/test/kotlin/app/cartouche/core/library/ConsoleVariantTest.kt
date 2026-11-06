// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import arrow.core.Either
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import kotlinx.serialization.json.Json
import org.junit.Test

class ConsoleVariantTest {
    /** The models whose console folder is still to be made: each folder made takes its model off. */
    private val awaiting = emptySet<ConsoleVariant>()

    @Test
    fun `every console model plays a shipped platform and is found back by the id it is stored and sent under`() {
        ConsoleVariant.entries.forEach { variant ->
            Shipped.catalog.platform(variant.platform).shouldBeSome()
            ConsoleVariant.of(variant.platform, variant.wire) shouldBe Either.Right(variant)
            Json.encodeToString(variant) shouldBe "\"${variant.wire}\""
        }
    }

    @Test
    fun `every console model has its folder in the app, playing its platform, and every folder is a model`() {
        val models = (ConsoleVariant.entries - awaiting).associate { it.wire to it.platform }
        Shipped.consoleFolders shouldBe models
    }
}
