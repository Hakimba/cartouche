// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.double
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.math.abs

class LabelFramingTest {
    // Every double, the impossible ones and those far out of range included.
    private val anyDouble =
        Arb.choice(
            Arb.double(-3.0, 10.0),
            Arb.element(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, 0.0, -0.0, Double.MAX_VALUE, -Double.MAX_VALUE),
            Arb.element(Double.MIN_VALUE, 1e300),
        )
    private val sides = Arb.choice(Arb.int(1..4000), Arb.element(1, 2, 3, Int.MAX_VALUE))
    private val zooms = Arb.double(1.0, LabelFraming.MAX_ZOOM)
    private val centres = Arb.double(0.0, 1.0)

    // The labels' own: a disc's, an NES cartridge's (portrait), a Super Nintendo cartridge's (wide), and any.
    private val proportions =
        Arb.choice(Arb.element(1.0, 0.62, 2.89), Arb.double(LabelFraming.MIN_PROPORTION, LabelFraming.MAX_PROPORTION))

    @Test
    fun `a picture first framed on a disc shows the largest square in its middle`() {
        LabelFraming(1.0, 0.5, 0.5, 1.0).framed(1600, 1200) shouldBe PixelRect(200, 0, 1200, 1200)
        LabelFraming(1.0, 0.5, 0.5, 1.0).framed(900, 1600) shouldBe PixelRect(0, 350, 900, 900)
    }

    @Test
    fun `a picture first framed on a cartridge shows the largest rectangle of its label's proportions in its middle`() {
        LabelFraming(1.0, 0.5, 0.5, 2.0).framed(1600, 1200) shouldBe PixelRect(0, 200, 1600, 800)
        LabelFraming(1.0, 0.5, 0.5, 0.5).framed(1600, 1200) shouldBe PixelRect(500, 0, 600, 1200)
    }

    @Test
    fun `a closer framing shows a smaller rectangle round the centre asked`() {
        LabelFraming(2.0, 0.25, 0.5, 1.0).framed(1600, 1200) shouldBe PixelRect(100, 300, 600, 600)
        LabelFraming(2.0, 0.25, 0.5, 2.0).framed(1600, 1200) shouldBe PixelRect(0, 400, 800, 400)
    }

    @Test
    fun `a centre too close to an edge is moved in as little as the rectangle needs`() {
        LabelFraming(2.0, 1.0, 0.0, 1.0).framed(1600, 1200) shouldBe PixelRect(1000, 0, 600, 600)
    }

    @Test
    fun `INV-E7-05 any framing shows a whole rectangle of the picture of the label's proportions, so the label is never stretched`() =
        runBlocking<Unit> {
            var shaped = 0
            checkAll(sides, sides, anyDouble, anyDouble, anyDouble, anyDouble) { width, height, zoom, x, y, proportion ->
                val framed = LabelFraming(zoom, x, y, proportion).framed(width, height)
                (framed.width >= 1 && framed.height >= 1) shouldBe true
                (framed.left >= 0 && framed.top >= 0 && framed.right <= width && framed.bottom <= height) shouldBe true
            }
            checkAll(Arb.int(64..4000), Arb.int(64..4000), zooms, centres, proportions) { width, height, zoom, x, shape ->
                val framed = LabelFraming(zoom, x, 0.5, shape).framed(width, height)
                // Each side cut to whole pixels on its own: the proportion holds within a pixel of either.
                if (minOf(framed.width, framed.height) >= 8) {
                    (abs(framed.width - framed.height * shape) <= 1 + shape) shouldBe true
                    shaped++
                }
            }
            shaped shouldBeGreaterThan 500
        }

    @Test
    fun `a rectangle that fits round the centre asked is centred on it, within a pixel`() = runBlocking<Unit> {
        var centred = 0
        checkAll(Arb.int(16..4000), Arb.int(16..4000), zooms, centres, centres, proportions) { width, height, zoom, x, y, shape ->
            val framed = LabelFraming(zoom, x, y, shape).framed(width, height)
            val (halfW, halfH) = framed.width / 2.0 to framed.height / 2.0
            if (x * width in halfW..width - halfW) {
                (abs(framed.left + halfW - x * width) <= 1.0) shouldBe true
                centred++
            }
            if (y * height in halfH..height - halfH) (abs(framed.top + halfH - y * height) <= 1.0) shouldBe true
        }
        // Most framings fit round their centre: the law is not checked on a handful of cases only.
        centred shouldBeGreaterThan 400
    }

    @Test
    fun `a closer framing never shows a larger rectangle`() = runBlocking<Unit> {
        checkAll(Arb.int(1..4000), Arb.int(1..4000), zooms, zooms, proportions) { width, height, one, other, shape ->
            val near = LabelFraming(maxOf(one, other), 0.5, 0.5, shape).framed(width, height)
            val far = LabelFraming(minOf(one, other), 0.5, 0.5, shape).framed(width, height)
            (near.width <= far.width && near.height <= far.height) shouldBe true
        }
    }
}
