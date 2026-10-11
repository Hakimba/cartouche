// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.ParsedSerializer
import arrow.core.Option
import arrow.core.Some
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonClassDiscriminator

/**
 * What a platform's scans show, and so what of them its labels show (`art` in its profile, with the
 * type of image its extract holds): a disc's printed face, or a cartridge's front, of which only the
 * label is kept.
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
@JsonClassDiscriminator("kind")
public sealed interface ArtKind {
    /** A disc's printed face: the label is the whole disc. */
    @Serializable
    @SerialName("disc")
    public data object Disc : ArtKind

    /**
     * A cartridge's front: the [fronts] of the platform's cartridges, by medium, in the profile's
     * order (`app.cartouche.core.art.LabelCut` reads a scan as the one of its shape).
     */
    @Serializable
    @SerialName("cartridge_front")
    public data class CartridgeFront(public val fronts: Map<MediumId, Front>) : ArtKind
}

/**
 * A cartridge's front as its scans show it: [proportion] its width over its height, its label at
 * [label]. Always of some width and height.
 */
@Serializable(with = FrontSerializer::class)
@ConsistentCopyVisibility
public data class Front private constructor(public val proportion: Double, public val label: LabelCrop) {
    public companion object {
        /** The front of this proportion with its label at [label]; none unless the proportion is a finite positive number. */
        public fun of(proportion: Double, label: LabelCrop): Option<Front> =
            Some(Front(proportion, label)).filter { proportion.isFinite() && proportion > 0 }
    }
}

/**
 * Where the label sits on a scan of a cartridge's front: its [left] and [top] edges from the
 * cartridge's top left corner, its [width] and [height], all fractions of the cartridge's width and
 * height. Always inside the cartridge, and of some size.
 */
@Serializable(with = LabelCropSerializer::class)
@ConsistentCopyVisibility
public data class LabelCrop private constructor(
    public val left: Double,
    public val top: Double,
    public val width: Double,
    public val height: Double,
) {
    public companion object {
        /** The label at these fractions of the cartridge; none unless it lies inside it and has a width and a height. */
        public fun of(left: Double, top: Double, width: Double, height: Double): Option<LabelCrop> =
            Some(LabelCrop(left, top, width, height)).filter {
                minOf(left, top) >= 0 && minOf(width, height) > 0 && left + width <= 1 && top + height <= 1
            }
    }
}

@Serializable
private data class FrontFields(val proportion: Double, val label: LabelCrop)

private object FrontSerializer : KSerializer<Front> by ParsedSerializer(
    "cartridge front of some proportion",
    FrontFields.serializer(),
    { Front.of(it.proportion, it.label) },
    { FrontFields(it.proportion, it.label) },
)

@Serializable
private data class Fractions(val left: Double, val top: Double, val width: Double, val height: Double)

private object LabelCropSerializer : KSerializer<LabelCrop> by ParsedSerializer(
    "label inside its cartridge",
    Fractions.serializer(),
    { LabelCrop.of(it.left, it.top, it.width, it.height) },
    { Fractions(it.left, it.top, it.width, it.height) },
)
