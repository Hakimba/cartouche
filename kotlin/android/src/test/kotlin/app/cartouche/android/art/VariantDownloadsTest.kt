// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.BitmapFactory
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelRegion
import arrow.core.Either
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import org.junit.Assume.assumeFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.GraphicsMode
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class VariantDownloadsTest {
    private val store = ArtStore(File(RuntimeEnvironment.getApplication().filesDir, "art"))
    private val game = GameId("ps2/Okage")
    private val scope = TestScope(StandardTestDispatcher())
    private val heard = mutableMapOf<String, Either<VariantFailure, StoredArt>>()

    private fun variant(region: String) = ArtVariant(LabelRegion(region), ArtUrl("https://art/$region.png"))

    private fun downloads(fetch: FakeFetch) =
        VariantDownloads(store, fetch, scope, StandardTestDispatcher(scope.testScheduler)) { _, variant, kept ->
            heard[variant.region.name] = kept
        }

    @Test
    fun `each image is kept and told, and why the others could not be`() {
        val fetch =
            FakeFetch(
                mapOf(
                    "https://art/Europe.png" to scan(diameter = 40, margin = 4),
                    "https://art/Japan.png" to "<html/>".encodeToByteArray(),
                ),
                answers = mapOf("https://art/Korea.png" to FetchFailure.Refused(429)),
            )
        downloads(fetch).download(game, listOf("Europe", "Japan", "World", "Korea").map(::variant), PS2_DISC)
        scope.runCurrent()
        heard.getValue("Europe").shouldBeRight() shouldBe store.variant(variant("Europe").url).shouldBeSome()
        heard.getValue("Japan").shouldBeLeft(VariantFailure.UNREADABLE)
        heard.getValue("World").shouldBeLeft(VariantFailure.NOT_FOUND)
        heard.getValue("Korea").shouldBeLeft(VariantFailure.REFUSED)
        fetch.online = false
        downloads(fetch).download(game, listOf(variant("Asia")), PS2_DISC)
        scope.runCurrent()
        heard.getValue("Asia").shouldBeLeft(VariantFailure.OFFLINE)
        fetch.online = true
        val variants = File(RuntimeEnvironment.getApplication().filesDir, "art/variants").apply { mkdirs() }
        variants.setWritable(false)
        try {
            assumeFalse(variants.canWrite())
            fetch.images = mapOf("https://art/Brazil.png" to scan(diameter = 40, margin = 4))
            downloads(fetch).download(game, listOf(variant("Brazil")), PS2_DISC)
            scope.runCurrent()
        } finally {
            variants.setWritable(true)
        }
        heard.getValue("Brazil").shouldBeLeft(VariantFailure.STORAGE)
    }

    @Test
    fun `INV-E10-06 a cartridge's image by region is kept as its label alone, cut by its platform's rule`() {
        downloads(FakeFetch(mapOf("https://art/Europe.png" to cartridgeFront()))).download(game, listOf(variant("Europe")), cartridgeLabel)
        scope.runCurrent()
        val label = BitmapFactory.decodeFile(heard.getValue("Europe").shouldBeRight().file.path)
        (label.width to label.height) shouldBe (280 to 120)
    }

    @Test
    fun `an image under way is not asked for again, and is once it is over`() {
        val fetch = FakeFetch(mapOf("https://art/Europe.png" to scan(diameter = 40, margin = 4)))
        val downloads = downloads(fetch)
        downloads.download(game, listOf(variant("Europe")), PS2_DISC)
        downloads.download(game, listOf(variant("Europe")), PS2_DISC)
        scope.runCurrent()
        fetch.asked shouldBe listOf("https://art/Europe.png")
        downloads.download(game, listOf(variant("Europe")), PS2_DISC)
        scope.runCurrent()
        fetch.asked.size shouldBe 2
    }
}
