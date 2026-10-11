// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

/** A rectangle of a picture, in pixels from its top left corner. */
public data class PixelRect(public val left: Int, public val top: Int, public val width: Int, public val height: Int) {
    public val right: Int get() = left + width
    public val bottom: Int get() = top + height
}

/**
 * How the user framed a picture of their own on a label whose width is [proportion] times its height
 * (1 on a disc, from [MIN_PROPORTION] to [MAX_PROPORTION]): [zoom] times closer than the largest
 * rectangle of the label's proportions that fits in it (1 to [MAX_ZOOM]), centred at [centreX] and
 * [centreY], fractions of its width and height from its top left corner. Values out of range are
 * brought back into it, so that any framing stands for a rectangle of the picture.
 */
public data class LabelFraming(
    public val zoom: Double,
    public val centreX: Double,
    public val centreY: Double,
    public val proportion: Double,
) {
    /**
     * The rectangle of a picture [width] by [height] pixels (at least 1 each) the label shows: of the
     * label's proportions within a pixel, whole, inside the picture and at least one pixel each way,
     * so the label is never stretched nor shows what is not in the picture. Its centre is the one
     * asked, moved in as little as the rectangle needs.
     */
    public fun framed(width: Int, height: Int): PixelRect {
        val (w, h) = width.coerceAtLeast(1) to height.coerceAtLeast(1)
        val shape = proportion.finiteOr(1.0).coerceIn(MIN_PROPORTION, MAX_PROPORTION)
        val closer = zoom.finiteOr(1.0).coerceIn(1.0, MAX_ZOOM)
        val (fitW, fitH) = if (w.toDouble() / h > shape) h * shape to h.toDouble() else w.toDouble() to w / shape
        val (sideW, sideH) = (fitW / closer).toInt().coerceIn(1, w) to (fitH / closer).toInt().coerceIn(1, h)

        fun start(centre: Double, length: Int, side: Int): Int = (centre.finiteOr(0.5) * length - side / 2.0).toInt().coerceIn(
            0,
            length - side,
        )
        return PixelRect(start(centreX, w, sideW), start(centreY, h, sideH), sideW, sideH)
    }

    public companion object {
        /** The closest a picture can be framed: a sixth of the largest rectangle that fits across the label. */
        public const val MAX_ZOOM: Double = 6.0

        /** The narrowest and the widest labels framed: no medium's label is longer than five times its width. */
        public const val MIN_PROPORTION: Double = 0.2
        public const val MAX_PROPORTION: Double = 5.0

        private fun Double.finiteOr(fallback: Double): Double = if (isFinite()) this else fallback
    }
}
