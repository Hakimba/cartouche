// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import app.cartouche.core.art.LabelCut
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.art.cartridge
import app.cartouche.core.art.crop
import app.cartouche.core.art.front
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.mediumId
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ArtImagesTest {
    private fun decoded(label: ByteArray): Bitmap = BitmapFactory.decodeByteArray(label, 0, label.size)

    private fun Bitmap.red(x: Int, y: Int) = Color.red(getPixel(x, y))

    @Test
    fun `a disc scan is cut to the disc, whatever its margin, and what was transparent turns black`() {
        val label = decoded(ArtImages.label(scan(diameter = 300, margin = 70), PS2_DISC).shouldBeSome())
        label.width shouldBe 300
        label.height shouldBe 300
        label.red(150, 150) shouldBeGreaterThan 200
        label.red(2, 2) shouldBeLessThan 40
    }

    @Test
    fun `a scan off the centre of its margin is cut to it, and one wider than tall is centred in a square`() {
        val offCentre = png(500, 400) { drawRect(20f, 150f, 220f, 250f, Paint().apply { color = Color.RED }) }
        val label = decoded(ArtImages.label(offCentre, PS2_DISC).shouldBeSome())
        label.width shouldBe 200
        label.height shouldBe 200
        label.red(100, 100) shouldBeGreaterThan 200
        label.red(100, 20) shouldBeLessThan 40
    }

    @Test
    fun `INV-E10-06 a cartridge's front is cut to its label by its platform's rule, at the label's own proportions`() {
        val label = decoded(ArtImages.label(cartridgeFront(), cartridgeLabel).shouldBeSome())
        label.width shouldBe 280
        label.height shouldBe 120
        listOf(1 to 1, 278 to 1, 1 to 118, 278 to 118, 140 to 60).forEach { (x, y) -> label.red(x, y) shouldBeGreaterThan 200 }
        listOf(1 to 1, 140 to 60).forEach { (x, y) -> Color.green(label.getPixel(x, y)) shouldBeLessThan 40 }
    }

    @Test
    fun `INV-E10-06 a scan of another front's shape is cut by that front, one of no front's shape gives no label`() {
        val other = front(400.0 / 240, crop(0.15, 0.25, 0.7, 0.5))
        val both =
            LabelCut(
                ArtKind.CartridgeFront(mapOf(mediumId("c") to front(0.9, crop(0.0, 0.0, 1.0, 1.0)), mediumId("d") to other)),
                mediumId("c"),
            )
        val label = decoded(ArtImages.label(cartridgeFront(), both).shouldBeSome())
        (label.width to label.height) shouldBe (280 to 120)
        ArtImages.label(cartridgeFront(), LabelCut(cartridge("c", 0.9, crop(0.15, 0.25, 0.7, 0.5)), mediumId("c"))).shouldBeNone()
    }

    @Test
    fun `a large cartridge front is brought down to the largest label on its longer side`() {
        val label =
            decoded(
                ArtImages
                    .label(
                        png(4000, 2400),
                        LabelCut(cartridge("c", 4000.0 / 2400, crop(0.0, 0.0, 1.0, 0.5)), mediumId("c")),
                    ).shouldBeSome(),
            )
        label.width shouldBe ArtImages.LARGEST
        label.height shouldBe ArtImages.LARGEST * 1200 / 4000
    }

    @Test
    fun `a scan with no transparent margin, or wholly transparent, is kept whole`() {
        decoded(ArtImages.label(png(320, 320), PS2_DISC).shouldBeSome()).width shouldBe 320
        decoded(ArtImages.label(png(240, 240) { drawColor(Color.TRANSPARENT) }, PS2_DISC).shouldBeSome()).width shouldBe 240
    }

    @Test
    fun `a large image is brought down to the largest label, a very large one decoded at a fraction of its size`() {
        decoded(ArtImages.label(png(3000, 2000), PS2_DISC).shouldBeSome()).width shouldBe ArtImages.LARGEST
        decoded(ArtImages.label(png(8192, 512), PS2_DISC).shouldBeSome()).width shouldBe ArtImages.LARGEST
    }

    @Test
    fun `what is not an image gives no label`() {
        ArtImages.label("<html>Not found</html>".encodeToByteArray(), PS2_DISC).shouldBeNone()
        ArtImages.label(ByteArray(0), PS2_DISC).shouldBeNone()
    }
}
