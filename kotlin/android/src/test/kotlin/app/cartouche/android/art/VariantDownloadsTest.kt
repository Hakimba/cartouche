// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.BitmapFactory
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.web
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelRegion
import arrow.core.Either
import arrow.core.Some
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
import app.cartouche.core.art.texture as candidateTexture

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class VariantDownloadsTest {
    private val store = ArtStore(File(RuntimeEnvironment.getApplication().filesDir, "art"))
    private val game = GameId("ps2/Okage")
    private val scope = TestScope(StandardTestDispatcher())
    private val heard = mutableMapOf<String, Either<VariantFailure, StoredArt>>()
    private val version = Some(ArtVersion("2026-09-28 2026-10-18"))

    private fun variant(region: String) = ArtVariant(LabelRegion(region), web("https://art/$region.png", region))

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
        downloads(fetch).download(game, listOf("Europe", "Japan", "World", "Korea").map(::variant), PS2_DISC, version)
        scope.runCurrent()
        heard.getValue("Europe").shouldBeRight() shouldBe store.variant(variant("Europe").candidate).shouldBeSome()
        heard.getValue("Japan").shouldBeLeft(VariantFailure.UNREADABLE)
        heard.getValue("World").shouldBeLeft(VariantFailure.NOT_FOUND)
        heard.getValue("Korea").shouldBeLeft(VariantFailure.REFUSED)
        fetch.online = false
        downloads(fetch).download(game, listOf(variant("Asia")), PS2_DISC, version)
        scope.runCurrent()
        heard.getValue("Asia").shouldBeLeft(VariantFailure.OFFLINE)
        fetch.online = true
        val variants = File(RuntimeEnvironment.getApplication().filesDir, "art/variants").apply { mkdirs() }
        variants.setWritable(false)
        try {
            assumeFalse(variants.canWrite())
            fetch.images = mapOf("https://art/Brazil.png" to scan(diameter = 40, margin = 4))
            downloads(fetch).download(game, listOf(variant("Brazil")), PS2_DISC, version)
            scope.runCurrent()
        } finally {
            variants.setWritable(true)
        }
        heard.getValue("Brazil").shouldBeLeft(VariantFailure.STORAGE)
    }

    @Test
    fun `a texture by region is kept whole, a disc's on a square and a cartridge's at its own proportions`() {
        val disc = ArtVariant(LabelRegion("Europe"), candidateTexture(58, 1, "support-texture(eu)", "Europe"))
        val cartridge = ArtVariant(LabelRegion("Japan"), candidateTexture(12, 1, "support-texture(jp)", "Japan"))
        val fetch =
            FakeFetch(
                mapOf(
                    disc.candidate.identity.value to scan(diameter = 40, margin = 4),
                    cartridge.candidate.identity.value to png(392, 200),
                ),
            )
        downloads(fetch).download(game, listOf(disc), PS2_DISC, version)
        downloads(fetch).download(game, listOf(cartridge), cartridgeLabel, version)
        scope.runCurrent()
        val square = BitmapFactory.decodeFile(heard.getValue("Europe").shouldBeRight().file.path)
        (square.width to square.height) shouldBe (40 to 40)
        val label = BitmapFactory.decodeFile(heard.getValue("Japan").shouldBeRight().file.path)
        (label.width to label.height) shouldBe (392 to 200)
    }

    @Test
    fun `INV-17 a texture ScreenScraper has none of is remembered so for the sources' version, a scan's absence is not`() {
        val texture = ArtVariant(LabelRegion("Europe"), candidateTexture(58, 1, "support-texture(eu)", "Europe"))
        downloads(FakeFetch(emptyMap())).download(game, listOf(texture, variant("Japan")), PS2_DISC, version)
        scope.runCurrent()
        heard.getValue("Europe").shouldBeLeft(VariantFailure.NOT_FOUND)
        heard.getValue("Japan").shouldBeLeft(VariantFailure.NOT_FOUND)
        store.isMissing(texture.candidate, version) shouldBe true
        store.isMissing(texture.candidate, Some(ArtVersion("2026-09-28 2026-11-01"))) shouldBe false
        store.isMissing(variant("Japan").candidate, version) shouldBe false
    }

    @Test
    fun `an image under way is not asked for again, and is once it is over`() {
        val fetch = FakeFetch(mapOf("https://art/Europe.png" to scan(diameter = 40, margin = 4)))
        val downloads = downloads(fetch)
        downloads.download(game, listOf(variant("Europe")), PS2_DISC, version)
        downloads.download(game, listOf(variant("Europe")), PS2_DISC, version)
        scope.runCurrent()
        fetch.asked shouldBe listOf("https://art/Europe.png")
        downloads.download(game, listOf(variant("Europe")), PS2_DISC, version)
        scope.runCurrent()
        fetch.asked.size shouldBe 2
    }
}
