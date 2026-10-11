// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Front
import app.cartouche.core.platforms.LabelCrop
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.mediumId
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.doubles.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.double
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.math.abs

class LabelCutTest {
    private val fractions = Arb.choice(Arb.double(0.0..1.0, includeNonFiniteEdgeCases = false), Arb.element(0.0, 0.5, 1.0))

    private val sides = Arb.choice(Arb.int(1..4000), Arb.element(1, 2, 3, 0, -5))

    private fun shipped(platform: String): ArtKind.CartridgeFront =
        Shipped.catalog.platforms.single { it.id == PlatformId(platform) }.profile.art.shouldBeSome().shouldBeInstanceOf()

    private fun cut(platform: String, medium: String) = LabelCut(shipped(platform), mediumId(medium))

    /** The label [medium]'s front cuts from a scan of [platform] [width] by [height] pixels, as if it were of its very shape. */
    private fun labelOf(platform: String, medium: String, width: Int, height: Int): PixelRect {
        val label = shipped(platform).fronts.getValue(mediumId(medium)).label
        return LabelCut(cartridge(medium, width.toDouble() / height, label), mediumId(medium)).on(width, height).shouldBeSome()
    }

    @Test
    fun `a GBA cartridge's label is cut from the middle of its front, below its top ridge`() {
        LabelCut(cartridge("gba_cart", 1.74, crop(0.15, 0.23, 0.72, 0.62)), mediumId("gba_cart")).on(1000, 574) shouldBe
            Some(PixelRect(150, 132, 720, 356))
    }

    @Test
    fun `a disc's label is its whole face, whatever its shape`() {
        LabelCut(ArtKind.Disc, mediumId("ps2_dvd")).on(900, 1000) shouldBe Some(PixelRect(0, 0, 900, 1000))
    }

    @Test
    fun `a scan is cut by the front of its shape, a Famicom's or a US Super Nintendo's onto the console's own cartridge`() {
        // Shapes measured on the shipped extracts' scans: an NES front 0.89, a Famicom 1.55; a PAL
        // Super Nintendo 1.41, a US one 1.57.
        cut("nes", "nes_cart").on(893, 1000) shouldBe Some(labelOf("nes", "nes_cart", 893, 1000))
        cut("nes", "nes_cart").on(1550, 1000) shouldBe Some(labelOf("nes", "famicom_cart", 1550, 1000))
        cut("snes", "snes_pal_cart").on(1410, 1000) shouldBe Some(labelOf("snes", "snes_pal_cart", 1410, 1000))
        cut("snes", "snes_pal_cart").on(1570, 1000) shouldBe Some(labelOf("snes", "snes_us_cart", 1570, 1000))
    }

    @Test
    fun `a scan that could be either of two fronts is read as the game's own medium's`() {
        // 1.49 lies within reach of both Super Nintendo fronts.
        cut("snes", "snes_pal_cart").on(1490, 1000) shouldBe Some(labelOf("snes", "snes_pal_cart", 1490, 1000))
        cut("snes", "snes_us_cart").on(1490, 1000) shouldBe Some(labelOf("snes", "snes_us_cart", 1490, 1000))
    }

    @Test
    fun `a scan of no front's shape, as a photo taken at an angle or an odd cartridge, gives no label`() {
        cut("nes", "nes_cart").on(1239, 1000).shouldBeNone()
        cut("nes", "nes_cart").on(995, 1000).shouldBeNone()
        cut("gbc", "gbc_cart").on(983, 1000).shouldBeNone()
        cut("snes", "snes_pal_cart").on(756, 1000).shouldBeNone()
        // A GBA front is 1.74 wide for 1 high: 1.84 lies within 6 % of it, 1.85 beyond.
        cut("gba", "gba_cart").on(1840, 1000).shouldBeSome()
        cut("gba", "gba_cart").on(1850, 1000).shouldBeNone()
        LabelCut(ArtKind.CartridgeFront(emptyMap()), mediumId("gba_cart")).on(1720, 1000).shouldBeNone()
    }

    @Test
    fun `a label outside its cartridge, or of no size, and a front of no proportion are none`() {
        LabelCrop.of(0.5, 0.2, 0.6, 0.5).shouldBeNone()
        LabelCrop.of(0.1, 0.6, 0.5, 0.5).shouldBeNone()
        LabelCrop.of(-0.1, 0.2, 0.5, 0.5).shouldBeNone()
        LabelCrop.of(0.1, 0.2, 0.0, 0.5).shouldBeNone()
        LabelCrop.of(0.1, Double.NaN, 0.5, 0.5).shouldBeNone()
        LabelCrop.of(0.0, 0.0, 1.0, 1.0).shouldBeSome()
        listOf(0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY).forEach { Front.of(it, crop(0.1, 0.1, 0.5, 0.5)).shouldBeNone() }
    }

    @Test
    fun `INV-E10-06 any label is cut whole from any scan of its shape, inside it, within a pixel of where its front puts it`() =
        runBlocking<Unit> {
            var cut = 0
            checkAll(fractions, fractions, fractions, fractions, sides, sides) { left, top, right, bottom, width, height ->
                LabelCrop.of(minOf(left, right), minOf(top, bottom), abs(right - left), abs(bottom - top)).onSome { crop ->
                    val (w, h) = width.coerceAtLeast(1) to height.coerceAtLeast(1)
                    val label = LabelCut(cartridge("c", w.toDouble() / h, crop), mediumId("c")).on(width, height).shouldBeSome()
                    (label.width >= 1 && label.height >= 1) shouldBe true
                    (label.left >= 0 && label.top >= 0 && label.right <= w && label.bottom <= h) shouldBe true
                    // Where the label has a pixel of its own, it is where the crop says.
                    if (crop.width * w >= 1 && crop.height * h >= 1) {
                        (abs(label.left - crop.left * w) <= 1 && abs(label.top - crop.top * h) <= 1) shouldBe true
                        (abs(label.right - (crop.left + crop.width) * w) <= 1) shouldBe true
                        (abs(label.bottom - (crop.top + crop.height) * h) <= 1) shouldBe true
                        cut++
                    }
                }
            }
            // Most crops are labels of some size on scans of some size: the law is not checked on a handful only.
            cut shouldBeGreaterThan 300
        }

    @Test
    fun `INV-E10-06 a game's label never comes from a scan of another shape than the front it is cut by, its own medium's first`() =
        runBlocking<Unit> {
            // Shapes often close to one another, and scans often close to them, so that scans two
            // fronts could take are met; each front's crop a distinct width, so the label's width
            // tells which front cut it.
            val shapes = Arb.choice(Arb.element(1.0, 1.04, 1.08, 1.5), Arb.double(0.5, 2.5))
            var cut = 0
            var refused = 0
            var ownWhenBoth = 0
            var firstWhenBoth = 0
            // A scan within 7 % of a shape, at times on the 6 % tolerance's edges.
            val factors = Arb.choice(Arb.double(0.93..1.07), Arb.element(0.94, 1.06))
            checkAll(Arb.list(shapes, 1..4), Arb.int(0..4), Arb.int(500..2000), shapes, factors) { proportions, own, height, near, factor ->
                val fronts =
                    proportions
                        .mapIndexed {
                            i,
                            shape,
                            ->
                            mediumId("m$i") to front(shape, crop(0.0, 0.0, (i + 1) / 10.0, 0.5))
                        }.toMap()
                val medium = mediumId("m$own")
                val width = (height * near * factor).toInt()
                val scan = width.toDouble() / height
                val fits = fronts.filterValues { abs(scan / it.proportion - 1) <= 0.06 }
                val label = LabelCut(ArtKind.CartridgeFront(fronts), medium).on(width, height)
                label.fold({ refused++ }) { cut++ }
                label.isSome() shouldBe fits.isNotEmpty()
                label.onSome { rect ->
                    val by = fronts.entries.filter { (_, front) -> abs(rect.width - front.label.width * width) <= 1 }.map { it.key }
                    // The game's own medium's front if the scan is of its shape, else the first of the profile's that is.
                    by shouldBe listOf(if (medium in fits) medium else fits.keys.first())
                    if (fits.size > 1) {
                        if (medium in fits) {
                            ownWhenBoth++
                        } else {
                            firstWhenBoth++
                        }
                    }
                }
            }
            // Scans of a front's shape and of none, and scans two fronts could take, are all met.
            cut shouldBeGreaterThan 100
            refused shouldBeGreaterThan 100
            ownWhenBoth shouldBeGreaterThan 10
            firstWhenBoth shouldBeGreaterThan 10
        }

    @Test
    fun `every shipped front is further than the tolerance from its platform's others, so a scan of its very shape is read as it`() {
        Shipped.catalog.platforms.forEach { platform ->
            platform.profile.art.onSome { art ->
                if (art is ArtKind.CartridgeFront) {
                    val shapes = art.fronts.values.map { it.proportion }.distinct()
                    shapes.forEach { one ->
                        shapes.filter { it != one }.forEach { other -> abs(other / one - 1) shouldBeGreaterThan 0.06 }
                    }
                }
            }
        }
    }
}
