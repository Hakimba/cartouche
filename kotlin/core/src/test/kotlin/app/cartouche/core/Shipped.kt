// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import java.io.File

/** The data files shipped in `app/data`: tests check them, not copies. */
object Shipped {
    private val data = File(checkNotNull(System.getProperty("cartouche.data")) { "Run the tests through Gradle" })

    fun text(path: String): String = File(data, path).readText()

    val definitions: List<DefinitionSource> =
        File(data, "platforms/daijishou")
            .listFiles { file ->
                file.extension == "json"
            }.orEmpty()
            .map { DefinitionSource(it.name, it.readText()) }

    val profiles = DefinitionSource("profiles.json", text("platforms/profiles.json"))

    val catalog: Catalog = Catalog.parse(definitions, profiles)
}
