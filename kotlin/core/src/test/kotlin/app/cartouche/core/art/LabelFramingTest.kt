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

class LabelFramingTest {
    // Every double, the impossible ones and those far out of range included.
    private val anyDouble =
        Arb.choice(
            Arb.double(-3.0, 10.0),
            Arb.element(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, 0.0, -0.0, Double.MAX_VALUE, -Double.MAX_VALUE),
            Arb.element(Double.MIN_VALUE, 1e300),
        )
    private val sides = Arb.choice(Arb.int(1..4000), Arb.element(1, 2, 3, Int.MAX_VALUE))

    @Test
    fun `a picture first framed shows the largest square in its middle`() {
        LabelFraming(1.0, 0.5, 0.5).square(1600, 1200) shouldBe PixelSquare(200, 0, 1200)
        LabelFraming(1.0, 0.5, 0.5).square(900, 1600) shouldBe PixelSquare(0, 350, 900)
    }

    @Test
    fun `a closer framing shows a smaller square round the centre asked`() {
        LabelFraming(2.0, 0.25, 0.5).square(1600, 1200) shouldBe PixelSquare(100, 300, 600)
    }

    @Test
    fun `a centre too close to an edge is moved in as little as the square needs`() {
        LabelFraming(2.0, 1.0, 0.0).square(1600, 1200) shouldBe PixelSquare(1000, 0, 600)
    }

    @Test
    fun `INV-E7-05 any framing shows a whole square of the picture, inside it, so the label is never stretched`() = runBlocking<Unit> {
        checkAll(sides, sides, anyDouble, anyDouble, anyDouble) { width, height, zoom, x, y ->
            val square = LabelFraming(zoom, x, y).square(width, height)
            (square.side >= 1) shouldBe true
            (square.left >= 0 && square.top >= 0) shouldBe true
            (square.left + square.side <= width && square.top + square.side <= height) shouldBe true
        }
    }

    @Test
    fun `a square that fits round the centre asked is centred on it, within a pixel`() = runBlocking<Unit> {
        var centred = 0
        checkAll(Arb.int(16..4000), Arb.int(16..4000), Arb.double(1.0, LabelFraming.MAX_ZOOM), Arb.double(0.0, 1.0), Arb.double(0.0, 1.0)) {
            width,
            height,
            zoom,
            x,
            y,
            ->
            val square = LabelFraming(zoom, x, y).square(width, height)
            val half = square.side / 2.0
            if (x * width in half..width - half) {
                (kotlin.math.abs(square.left + half - x * width) <= 1.0) shouldBe true
                centred++
            }
            if (y * height in half..height - half) (kotlin.math.abs(square.top + half - y * height) <= 1.0) shouldBe true
        }
        // Most framings fit round their centre: the law is not checked on a handful of cases only.
        centred shouldBeGreaterThan 400
    }

    @Test
    fun `a closer framing never shows a larger square`() = runBlocking<Unit> {
        checkAll(Arb.int(1..4000), Arb.int(1..4000), Arb.double(1.0, LabelFraming.MAX_ZOOM), Arb.double(1.0, LabelFraming.MAX_ZOOM)) {
            width,
            height,
            one,
            other,
            ->
            val near = LabelFraming(maxOf(one, other), 0.5, 0.5).square(width, height)
            val far = LabelFraming(minOf(one, other), 0.5, 0.5).square(width, height)
            (near.side <= far.side) shouldBe true
        }
    }
}
