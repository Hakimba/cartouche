// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.LabelCut
import app.cartouche.core.platforms.ArtKind
import arrow.core.Option
import arrow.core.toOption
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

/**
 * Turns a downloaded image into what a model's label shows: a JPEG of at most [LARGEST] pixels on its longer side, cut to the medium first
 * (the transparent margin removed). A disc is a square covering its face, transparent turned black; a cartridge's front is its label
 * alone, cut by [LabelCut]; a texture is the label as printed.
 */
internal object ArtImages {
    const val LARGEST = 1024

    private const val QUALITY = 90

    /** An alpha under this is taken for the margin round a scan. */
    private const val MARGIN_ALPHA = 32

    /**
     * The label [cut] gives of [image], [candidate]'s; none when it is not an image Android can read, or a scan of no
     * shape [cut] knows.
     */
    fun label(image: ByteArray, candidate: Candidate, cut: LabelCut): Option<ByteArray> = decoded(image).flatMap { bitmap ->
        try {
            val medium = opaquePart(bitmap)
            cut.on(candidate, medium.width(), medium.height()).map { label ->
                drawn(bitmap, Rect(label.left, label.top, label.right, label.bottom).apply { offset(medium.left, medium.top) }, cut.kind)
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun drawn(bitmap: Bitmap, part: Rect, kind: ArtKind): ByteArray {
        val longest = maxOf(part.width(), part.height())
        val scale = minOf(1f, LARGEST.toFloat() / longest)
        val width = maxOf(1, (part.width() * scale).roundToInt())
        val height = maxOf(1, (part.height() * scale).roundToInt())
        // A disc's face is shown on a square; a cartridge's label fills its own rectangle.
        val (labelWidth, labelHeight) = if (kind == ArtKind.Disc) maxOf(width, height).let { it to it } else width to height
        val label = Bitmap.createBitmap(labelWidth, labelHeight, Bitmap.Config.ARGB_8888)
        try {
            Canvas(label).apply {
                drawColor(Color.BLACK)
                val left = (labelWidth - width) / 2
                val top = (labelHeight - height) / 2
                drawBitmap(bitmap, part, Rect(left, top, left + width, top + height), Paint(Paint.FILTER_BITMAP_FLAG))
            }
            return jpeg(label)
        } finally {
            label.recycle()
        }
    }

    fun jpeg(bitmap: Bitmap): ByteArray =
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, QUALITY, it) }.toByteArray()

    /** Halved as often as the longer side stays at least twice [LARGEST]: a decoded image takes 64 MB at most. */
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
