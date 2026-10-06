// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import arrow.core.Option
import arrow.core.toOption
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

/**
 * Turns a downloaded disc scan into what a model's label shows: a square JPEG of at most [LARGEST]
 * pixels covering the disc's whole face, cut to the disc (the transparent margin round it removed).
 * What was transparent becomes black.
 */
internal object ArtImages {
    const val LARGEST = 1024

    private const val QUALITY = 90

    /** An alpha under this is taken for the margin round a scan. */
    private const val MARGIN_ALPHA = 32

    /** The label for the scan [image]; none when it is not an image Android can read. */
    fun label(image: ByteArray): Option<ByteArray> = decoded(image).map { bitmap ->
        try {
            val part = opaquePart(bitmap)
            val longest = maxOf(part.width(), part.height())
            val scale = minOf(1f, LARGEST.toFloat() / longest)
            val side = maxOf(1, (longest * scale).roundToInt())
            val width = (part.width() * scale).roundToInt()
            val height = (part.height() * scale).roundToInt()
            val square = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
            try {
                Canvas(square).apply {
                    drawColor(Color.BLACK)
                    val left = (side - width) / 2
                    val top = (side - height) / 2
                    drawBitmap(bitmap, part, Rect(left, top, left + width, top + height), Paint(Paint.FILTER_BITMAP_FLAG))
                }
                jpeg(square)
            } finally {
                square.recycle()
            }
        } finally {
            bitmap.recycle()
        }
    }

    /** [bitmap] as a JPEG, as labels are stored. */
    fun jpeg(bitmap: Bitmap): ByteArray =
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, QUALITY, it) }.toByteArray()

    /**
     * [image] decoded, halved as often as its longer side stays at least twice [LARGEST]: a decoded
     * image then takes 64 MB at most, whatever was downloaded.
     */
    private fun decoded(image: ByteArray): Option<Bitmap> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(image, 0, image.size, bounds)
        val longest = maxOf(bounds.outWidth, bounds.outHeight)
        val options =
            BitmapFactory.Options().apply {
                inSampleSize = generateSequence(1) { it * 2 }.first { longest / (it * 2) < 2 * LARGEST }
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        return BitmapFactory.decodeByteArray(image, 0, image.size, options).toOption()
    }

    /** The smallest rectangle holding every pixel of [bitmap] that is not transparent; all of it when none is. */
    private fun opaquePart(bitmap: Bitmap): Rect {
        val row = IntArray(bitmap.width)
        var left = bitmap.width
        var top = bitmap.height
        var right = -1
        var bottom = -1
        // Plain loops, row by row: a scan has millions of pixels.
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width) {
                if (Color.alpha(row[x]) >= MARGIN_ALPHA) {
                    left = minOf(left, x)
                    right = maxOf(right, x)
                    top = minOf(top, y)
                    bottom = y
                }
            }
        }
        return if (right < 0) Rect(0, 0, bitmap.width, bitmap.height) else Rect(left, top, right + 1, bottom + 1)
    }
}
