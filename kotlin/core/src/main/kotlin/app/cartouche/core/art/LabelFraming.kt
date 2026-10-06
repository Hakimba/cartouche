// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

/** A square of a picture, in pixels from its top left corner. */
public data class PixelSquare(public val left: Int, public val top: Int, public val side: Int)

/**
 * How the user framed a picture of their own on a label: [zoom] times closer than the largest square
 * that fits in it (1 to [MAX_ZOOM]), centred at [centreX] and [centreY], fractions of its width and
 * height from its top left corner. Values out of range are brought back into it, so that any framing
 * stands for a square of the picture.
 */
public data class LabelFraming(public val zoom: Double, public val centreX: Double, public val centreY: Double) {
    /**
     * The square of a picture [width] by [height] pixels (at least 1 each) the label shows: always
     * whole, inside the picture and at least one pixel wide, so the label is never stretched nor
     * shows what is not in the picture. Its centre is the one asked, moved in as little as the
     * square needs.
     */
    public fun square(width: Int, height: Int): PixelSquare {
        val (w, h) = width.coerceAtLeast(1) to height.coerceAtLeast(1)
        val side = (minOf(w, h) / zoom.finiteOr(1.0).coerceIn(1.0, MAX_ZOOM)).toInt().coerceIn(1, minOf(w, h))

        fun start(centre: Double, length: Int): Int = (centre.finiteOr(0.5) * length - side / 2.0).toInt().coerceIn(0, length - side)
        return PixelSquare(start(centreX, w), start(centreY, h), side)
    }

    public companion object {
        /** The closest a picture can be framed: a sixth of its shorter side across the label. */
        public const val MAX_ZOOM: Double = 6.0

        private fun Double.finiteOr(fallback: Double): Double = if (isFinite()) this else fallback
    }
}
