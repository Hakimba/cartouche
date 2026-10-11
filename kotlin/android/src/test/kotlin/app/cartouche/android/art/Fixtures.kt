// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import app.cartouche.core.art.LabelCut
import app.cartouche.core.art.cartridge
import app.cartouche.core.art.crop
import app.cartouche.core.platforms.mediumId
import java.io.ByteArrayOutputStream

/** A PNG of [width] by [height] pixels, transparent, with [draw] painted on it. */
fun png(width: Int, height: Int, draw: Canvas.() -> Unit = { drawColor(Color.RED) }): ByteArray {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    Canvas(bitmap).draw()
    return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
}

/** A cartridge's front: grey, 400 by 240 pixels in a transparent margin, its label red where [cartridgeLabel] cuts, 280 by 120. */
fun cartridgeFront(): ByteArray = png(500, 340) {
    drawRect(50f, 50f, 450f, 290f, Paint().apply { color = Color.GRAY })
    drawRect(110f, 110f, 390f, 230f, Paint().apply { color = Color.RED })
}

/** How the label of a [cartridgeFront] is cut: a front of its shape, its label where it sits. */
val cartridgeLabel: LabelCut = LabelCut(cartridge("c", 400.0 / 240, crop(0.15, 0.25, 0.7, 0.5)), mediumId("c"))

/** A disc scan: an opaque disc of [diameter] pixels, whose centre is [colour], in a transparent margin. */
fun scan(diameter: Int, margin: Int, colour: Int = Color.RED): ByteArray = png(diameter + 2 * margin, diameter + 2 * margin) {
    drawCircle(margin + diameter / 2f, margin + diameter / 2f, diameter / 2f, Paint().apply { color = colour })
}
