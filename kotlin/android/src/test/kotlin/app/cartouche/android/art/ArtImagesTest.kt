// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import app.cartouche.android.Threads
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.LabelCut
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.cartridge
import app.cartouche.core.art.crop
import app.cartouche.core.art.front
import app.cartouche.core.art.web
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.mediumId
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Semaphore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode
import java.io.File
import app.cartouche.core.art.texture as candidateTexture

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ArtImagesTest {
    private val scan = web("https://art/scan.png")

    private val texture = candidateTexture(12, 1, "support-texture(eu)", "Europe")

    private val gate = Semaphore(Threads.VARIANT_DOWNLOADS)

    private fun label(image: ByteArray, candidate: Candidate, cut: LabelCut) = runBlocking {
        val file = File.createTempFile("image", ".part").apply { writeBytes(image) }
        try {
            ArtImages.label(file, candidate, cut, gate)
        } finally {
            file.delete()
        }
    }

    private fun decoded(label: ByteArray): Bitmap = BitmapFactory.decodeByteArray(label, 0, label.size)

    private fun Bitmap.red(x: Int, y: Int) = Color.red(getPixel(x, y))

    @Test
    fun `a texture is the label whole, a cartridge's at its own proportions, where a scan of that shape is of no front`() {
        val printed = png(560, 300) { drawRect(30f, 22f, 530f, 277f, Paint().apply { color = Color.RED }) }
        val label = decoded(label(printed, texture, cartridgeLabel).shouldBeRight())
        (label.width to label.height) shouldBe (500 to 255)
        label.red(250, 127) shouldBeGreaterThan 200
        label(printed, scan, cartridgeLabel).shouldBeLeft(Unusable.NO_SHAPE)
        val disc = decoded(label(scan(diameter = 300, margin = 70), texture, PS2_DISC).shouldBeRight())
        (disc.width to disc.height) shouldBe (300 to 300)
    }

    @Test
    fun `a scan off the centre of its margin is cut to it, and one wider than tall is centred in a square`() {
        val offCentre = png(500, 400) { drawRect(20f, 150f, 220f, 250f, Paint().apply { color = Color.RED }) }
        val label = decoded(label(offCentre, scan, PS2_DISC).shouldBeRight())
        label.width shouldBe 200
        label.height shouldBe 200
        label.red(100, 100) shouldBeGreaterThan 200
        label.red(100, 20) shouldBeLessThan 40
    }

    @Test
    fun `INV-16 a cartridge's front is cut to its label by its platform's rule, at the label's own proportions`() {
        val label = decoded(label(cartridgeFront(), scan, cartridgeLabel).shouldBeRight())
        label.width shouldBe 280
        label.height shouldBe 120
        listOf(1 to 1, 278 to 1, 1 to 118, 278 to 118, 140 to 60).forEach { (x, y) -> label.red(x, y) shouldBeGreaterThan 200 }
        listOf(1 to 1, 140 to 60).forEach { (x, y) -> Color.green(label.getPixel(x, y)) shouldBeLessThan 40 }
    }

    @Test
    fun `INV-16 a scan of another front's shape is cut by that front, one of no front's shape gives no label`() {
        val other = front(400.0 / 240, crop(0.15, 0.25, 0.7, 0.5))
        val both =
            LabelCut(
                ArtKind.CartridgeFront(mapOf(mediumId("c") to front(0.9, crop(0.0, 0.0, 1.0, 1.0)), mediumId("d") to other)),
                mediumId("c"),
            )
        val label = decoded(label(cartridgeFront(), scan, both).shouldBeRight())
        (label.width to label.height) shouldBe (280 to 120)
        label(cartridgeFront(), scan, LabelCut(cartridge("c", 0.9, crop(0.15, 0.25, 0.7, 0.5)), mediumId("c")))
            .shouldBeLeft(Unusable.NO_SHAPE)
    }

    @Test
    fun `a scan with no transparent margin, or wholly transparent, is kept whole`() {
        decoded(label(png(320, 320), scan, PS2_DISC).shouldBeRight()).width shouldBe 320
        decoded(label(png(240, 240) { drawColor(Color.TRANSPARENT) }, scan, PS2_DISC).shouldBeRight()).width shouldBe 240
    }

    @Test
    fun `a large image is brought down to the largest label, a very large one decoded at a fraction of its size`() {
        decoded(label(png(3000, 2000), scan, PS2_DISC).shouldBeRight()).width shouldBe ArtImages.LARGEST
        decoded(label(png(8192, 512), scan, PS2_DISC).shouldBeRight()).width shouldBe ArtImages.LARGEST
    }
}
