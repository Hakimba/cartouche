// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.files.Shell
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Front
import app.cartouche.core.platforms.LabelCrop
import app.cartouche.core.platforms.MediumId
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrNone
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * How a game's label is cut from a scan: by its platform's [kind] of scan, for a game that comes in [medium] and
 * whose ROM says it was sold in a [shell].
 */
public data class LabelCut(public val kind: ArtKind, public val medium: MediumId, public val shell: Shell = Shell.UNKNOWN) {
    /**
     * The label on [candidate]'s image whose medium (its opaque part) is [width] by [height] pixels: a texture whole,
     * it is the label as printed (a disc's drawn on a square, a cartridge's at its own proportions, by [kind]); a
     * scan as [on] reads it.
     */
    public fun on(candidate: Candidate, width: Int, height: Int): Option<PixelRect> = when (candidate) {
        is Candidate.Texture -> Some(whole(width, height))
        is Candidate.Web -> on(width, height)
    }

    /**
     * The label on a scan whose medium (its opaque part) is [width] by [height] pixels (at least 1
     * each): a disc's whole face; on a cartridge's front, the label where the crop of the front of
     * the scan's shape puts it, the nearest whole pixels, inside the scan and at least one each way.
     * The scan's shape is the first front, [medium]'s then the others in the profile's order, whose
     * proportion is within [TOLERANCE] of the scan's; none when no front's is, as for a photo taken at
     * an angle or a cartridge of a shape no medium has: its label would show something else.
     */
    public fun on(width: Int, height: Int): Option<PixelRect> {
        val scan = whole(width, height)
        return when (kind) {
            ArtKind.Disc -> Some(scan)
            is ArtKind.CartridgeFront ->
                frontOf(
                    kind.fronts + kind.exclusives.takeIf { shell == Shell.EXCLUSIVE }.orEmpty(),
                    scan.width.toDouble() / scan.height,
                ).map { it.label.on(scan.width, scan.height) }
        }
    }

    /**
     * Whether the same scan is cut as [other] cuts it: the shell only counts for a front the profile gives exclusives
     * of.
     */
    public fun cutsAs(other: LabelCut): Boolean = kind == other.kind && medium == other.medium && exclusive == other.exclusive

    private val exclusive: Boolean get() = shell == Shell.EXCLUSIVE && kind is ArtKind.CartridgeFront && medium in kind.exclusives

    private fun whole(width: Int, height: Int): PixelRect = PixelRect(0, 0, width.coerceAtLeast(1), height.coerceAtLeast(1))

    private fun frontOf(fronts: Map<MediumId, Front>, proportion: Double): Option<Front> =
        (fronts.getOrNone(medium).toList() + (fronts - medium).values).firstOrNone { abs(proportion / it.proportion - 1) <= TOLERANCE }

    public companion object {
        /**
         * How far, as a fraction of a front's proportion, a straight scan of it may be: scans cut close or with a
         * shadow stay within 5 %, while the fronts of one platform's cartridges differ by 10 % at least.
         */
        public const val TOLERANCE: Double = 0.06
    }
}

private fun LabelCrop.on(scanWidth: Int, scanHeight: Int): PixelRect {
    val x = (left * scanWidth).roundToInt().coerceIn(0, scanWidth - 1)
    val y = (top * scanHeight).roundToInt().coerceIn(0, scanHeight - 1)
    val w = (width * scanWidth).roundToInt().coerceIn(1, scanWidth - x)
    return PixelRect(x, y, w, (height * scanHeight).roundToInt().coerceIn(1, scanHeight - y))
}
