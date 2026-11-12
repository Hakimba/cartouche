// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import app.cartouche.core.serialName
import arrow.core.Either
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.junit.Test

class ConsoleVariantTest {
    @Test
    fun `every console model plays a shipped platform and is found back by the id it is stored and sent under`() {
        ConsoleVariant.entries.forEach { variant ->
            Shipped.catalog.platform(variant.platform).shouldBeSome()
            ConsoleVariant.of(variant.platform, variant.serialName) shouldBe Either.Right(variant)
        }
    }

    @Test
    fun `every console model has its folder in the app, playing its platform, and every folder is a model`() {
        val models = ConsoleVariant.entries.associate { it.serialName to it.platform }
        Shipped.consoleFolders shouldBe models
    }
}
