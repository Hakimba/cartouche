// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
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
        val label = decoded(ArtImages.label(scan(diameter = 300, margin = 70)).shouldBeSome())
        label.width shouldBe 300
        label.height shouldBe 300
        label.red(150, 150) shouldBeGreaterThan 200
        label.red(2, 2) shouldBeLessThan 40
    }

    @Test
    fun `a scan off the centre of its margin is cut to it, and one wider than tall is centred in a square`() {
        val offCentre = png(500, 400) { drawRect(20f, 150f, 220f, 250f, Paint().apply { color = Color.RED }) }
        val label = decoded(ArtImages.label(offCentre).shouldBeSome())
        label.width shouldBe 200
        label.height shouldBe 200
        label.red(100, 100) shouldBeGreaterThan 200
        label.red(100, 20) shouldBeLessThan 40
    }

    @Test
    fun `a scan with no transparent margin, or wholly transparent, is kept whole`() {
        decoded(ArtImages.label(png(320, 320)).shouldBeSome()).width shouldBe 320
        decoded(ArtImages.label(png(240, 240) { drawColor(Color.TRANSPARENT) }).shouldBeSome()).width shouldBe 240
    }

    @Test
    fun `a large image is brought down to the largest label, a very large one decoded at a fraction of its size`() {
        decoded(ArtImages.label(png(3000, 2000)).shouldBeSome()).width shouldBe ArtImages.LARGEST
        decoded(ArtImages.label(png(8192, 512)).shouldBeSome()).width shouldBe ArtImages.LARGEST
    }

    @Test
    fun `what is not an image gives no label`() {
        ArtImages.label("<html>Not found</html>".encodeToByteArray()).shouldBeNone()
        ArtImages.label(ByteArray(0)).shouldBeNone()
    }
}
