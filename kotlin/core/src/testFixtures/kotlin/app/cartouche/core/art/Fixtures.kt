// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Front
import app.cartouche.core.platforms.LabelCrop
import app.cartouche.core.platforms.MediaRule
import app.cartouche.core.platforms.mediumId
import arrow.core.getOrElse

/** The form of a PlayStation serial (`SLES-53047`), as the PS2's profile gives it. */
const val PLAYSTATION_SERIAL: String = """[A-Z]{4}-\d{5}"""

/** The PS2's media: one disc for all its games. */
val PS2_MEDIA: MediaRule = MediaRule(mediumId("ps2_dvd"))

/** How a PS2 game's label is cut from a scan: its disc's whole face. */
val PS2_DISC: LabelCut = LabelCut(ArtKind.Disc, mediumId("ps2_dvd"))

/** A label crop written by hand in a test. */
fun crop(left: Double, top: Double, width: Double, height: Double): LabelCrop =
    LabelCrop.of(left, top, width, height).getOrElse { error("Not a label inside its cartridge: $left, $top, $width, $height") }

/** A cartridge front written by hand in a test. */
fun front(proportion: Double, label: LabelCrop): Front = Front.of(proportion, label).getOrElse { error("Not a front: $proportion") }

/** The art of a platform of one cartridge, [medium], of this front, as written by hand in a test. */
fun cartridge(medium: String, proportion: Double, label: LabelCrop): ArtKind.CartridgeFront =
    ArtKind.CartridgeFront(mapOf(mediumId(medium) to front(proportion, label)))
