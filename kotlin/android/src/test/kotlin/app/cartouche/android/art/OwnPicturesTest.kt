// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Paint
import app.cartouche.core.art.LabelFraming
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OwnPicturesTest {
    private val pictures = OwnPictures(File(RuntimeEnvironment.getApplication().cacheDir, "own-label"))

    /** Red on its left half, blue on its right. */
    private val redThenBlue =
        png(400, 200) {
            drawColor(Color.RED)
            drawRect(200f, 0f, 400f, 200f, Paint().apply { color = Color.BLUE })
        }

    private fun source(image: ByteArray) = ImageDecoder.createSource(ByteBuffer.wrap(image))

    private fun decoded(image: ByteArray): Bitmap = BitmapFactory.decodeByteArray(image, 0, image.size)

    @Test
    fun `a picture picked is kept whole to be framed`() {
        val picture = pictures.keep(source(redThenBlue)).shouldBeRight()
        (picture.width to picture.height) shouldBe (400 to 200)
        decoded(picture.file.readBytes()).width shouldBe 400
    }

    @Test
    fun `a picture longer than the copies are is kept at that length`() {
        val picture = pictures.keep(source(png(4096, 1024))).shouldBeRight()
        (picture.width to picture.height) shouldBe (OwnPictures.LONGEST to OwnPictures.LONGEST / 4)
    }

    @Test
    fun `the label is the framed square of the picture, at the labels' size`() {
        pictures.keep(source(redThenBlue)).shouldBeRight()
        val left = decoded(pictures.framed(LabelFraming(1.0, 0.0, 0.5)).shouldBeRight())
        (left.width to left.height) shouldBe (ArtImages.LARGEST to ArtImages.LARGEST)
        Color.red(left.getPixel(512, 512)) shouldBeGreaterThan 200
        Color.blue(left.getPixel(512, 512)) shouldBeLessThan 60
        val right = decoded(pictures.framed(LabelFraming(1.0, 1.0, 0.5)).shouldBeRight())
        Color.blue(right.getPixel(512, 512)) shouldBeGreaterThan 200
    }

    @Test
    fun `a closer framing cuts its square on both axes and fills the whole label with it`() {
        // Red, green, blue and white quarters; the framing takes the middle of the bottom right one.
        val quarters =
            png(400, 400) {
                drawColor(Color.RED)
                drawRect(200f, 0f, 400f, 200f, Paint().apply { color = Color.GREEN })
                drawRect(0f, 200f, 200f, 400f, Paint().apply { color = Color.BLUE })
                drawRect(200f, 200f, 400f, 400f, Paint().apply { color = Color.WHITE })
            }
        pictures.keep(source(quarters)).shouldBeRight()
        val label = decoded(pictures.framed(LabelFraming(2.0, 0.75, 0.75)).shouldBeRight())
        val edge = ArtImages.LARGEST - 4
        for ((x, y) in listOf(4 to 4, edge to 4, 4 to edge, edge to edge, 512 to 512)) {
            val pixel = label.getPixel(x, y)
            (Color.red(pixel) > 200 && Color.green(pixel) > 200 && Color.blue(pixel) > 200) shouldBe true
        }
    }

    @Test
    fun `what is not an image is not kept`() {
        pictures.keep(source("not an image".encodeToByteArray())).shouldBeLeft().shouldBeInstanceOf<LabelFailure.Unreadable>()
    }

    @Test
    fun `nothing is framed before a picture is picked`() {
        OwnPictures(File(RuntimeEnvironment.getApplication().cacheDir, "never-picked"))
            .framed(LabelFraming(1.0, 0.5, 0.5))
            .shouldBeLeft(LabelFailure.NotPicked)
    }
}
