// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import app.cartouche.core.library.TitleIndex
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import java.io.File

/** The data files shipped in `app/data`: tests check them, not copies. */
object Shipped {
    private val data = File(checkNotNull(System.getProperty("cartouche.data")) { "Run the tests through Gradle" })

    fun text(path: String): String = File(data, path).readText()

    val definitions: List<DefinitionSource> =
        File(data, "platforms/daijishou")
            .listFiles { file -> file.extension == "json" }
            .orEmpty()
            .map { DefinitionSource(it.name, it.readText()) }

    val profiles = DefinitionSource("profiles.json", text("platforms/profiles.json"))

    val catalog: Catalog = Catalog.parse(definitions, profiles)

    val ps2: Platform = catalog.platforms.single { it.id == PlatformId("ps2") }

    /** The names of the PS2 reference list, such as `Punisher, The (Europe) (En,Fr)`. */
    val ps2Names: List<String> by lazy { text("redump/ps2.tsv").lines().filter { it.isNotBlank() }.map { it.substringBefore('\t') } }

    /** The PS2 reference list, indexed once for every test. */
    val ps2Titles: TitleIndex by lazy { TitleIndex.parse(text("redump/ps2.tsv")) }
}
