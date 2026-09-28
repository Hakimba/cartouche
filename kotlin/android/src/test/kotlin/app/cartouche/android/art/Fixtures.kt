// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import java.io.ByteArrayOutputStream

/** A PNG of [width] by [height] pixels, transparent, with [draw] painted on it. */
fun png(width: Int, height: Int, draw: Canvas.() -> Unit = { drawColor(Color.RED) }): ByteArray {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    Canvas(bitmap).draw()
    return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
}

/** A disc scan: an opaque disc of [diameter] pixels, whose centre is [colour], in a transparent margin. */
fun scan(diameter: Int, margin: Int, colour: Int = Color.RED): ByteArray = png(diameter + 2 * margin, diameter + 2 * margin) {
    drawCircle(margin + diameter / 2f, margin + diameter / 2f, diameter / 2f, Paint().apply { color = colour })
}
