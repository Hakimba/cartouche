// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.Rect
import android.util.AtomicFile
import app.cartouche.android.storage.write
import app.cartouche.core.art.LabelFraming
import arrow.core.Either
import arrow.core.flatMap
import arrow.core.raise.either
import arrow.core.raise.ensure
import java.io.File
import java.io.IOException

/** A picture of the user's own being framed: the app's copy of it, [width] by [height] pixels. */
internal data class OwnPicture(val file: File, val width: Int, val height: Int)

/**
 * The pictures of their own the user puts on labels, once picked: copied upright and at most
 * [LONGEST] pixels long into [folder] while they are framed, then cut to the framed square at the
 * labels' size ([ArtImages.LARGEST]).
 */
internal class OwnPictures(private val folder: File) {
    private val picked = File(folder, "picked.jpg")

    /** Copies the picture [source] reads (the one picked) as the one being framed, replacing the previous one. */
    fun keep(source: ImageDecoder.Source): Either<LabelFailure, OwnPicture> = decode(source).flatMap { bitmap ->
        try {
            folder.mkdirs()
            AtomicFile(picked).write(ArtImages.jpeg(bitmap)).mapLeft(LabelFailure::Storage).map {
                OwnPicture(picked, bitmap.width, bitmap.height)
            }
        } finally {
            bitmap.recycle()
        }
    }

    /** The square [framing] shows of the picture being framed, at the labels' size, as a JPEG. */
    fun framed(framing: LabelFraming): Either<LabelFailure, ByteArray> = either {
        ensure(picked.isFile) { LabelFailure.NotPicked }
        val picture = decode(ImageDecoder.createSource(picked)).bind()
        val label = Bitmap.createBitmap(ArtImages.LARGEST, ArtImages.LARGEST, Bitmap.Config.ARGB_8888)
        try {
            val square = framing.square(picture.width, picture.height)
            val from = Rect(square.left, square.top, square.left + square.side, square.top + square.side)
            Canvas(label).drawBitmap(picture, from, Rect(0, 0, label.width, label.height), Paint(Paint.FILTER_BITMAP_FLAG))
            ArtImages.jpeg(label)
        } finally {
            label.recycle()
            picture.recycle()
        }
    }

    /** Decodes [source] upright, scaled down to [LONGEST] pixels on its longer side when it is longer. */
    private fun decode(source: ImageDecoder.Source): Either<LabelFailure, Bitmap> = Either
        .catch {
            ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                // Software pixels, so that the picture can be drawn from and compressed.
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val scale = minOf(1.0, LONGEST.toDouble() / maxOf(info.size.width, info.size.height))
                decoder.setTargetSize(
                    (info.size.width * scale).toInt().coerceAtLeast(1),
                    (info.size.height * scale).toInt().coerceAtLeast(1),
                )
            }
        }.mapLeft { e ->
            when (e) {
                is IOException, is SecurityException, is IllegalArgumentException -> LabelFailure.Unreadable(e.toString())
                else -> throw e
            }
        }

    companion object {
        /** Enough to frame closely without the copy weighing much. */
        const val LONGEST = 2048
    }
}
