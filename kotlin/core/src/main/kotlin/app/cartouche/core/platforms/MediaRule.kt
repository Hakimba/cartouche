// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.platforms

import app.cartouche.core.ParsedSerializer
import app.cartouche.core.regions.Regions
import app.cartouche.core.regions.Regions.Group
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.builtins.serializer

/** A physical medium a game is shown in, such as `sfc_cart` or `ps1_cd`: never blank. */
@Serializable(with = MediumIdSerializer::class)
@JvmInline
public value class MediumId private constructor(public val value: String) {
    public companion object {
        /** The medium of a platform whose games are never looked for. */
        internal val NONE: MediumId = MediumId("none")

        /** [text] as a medium; none when it is blank. */
        public fun of(text: String): Option<MediumId> = Some(text).filter(String::isNotBlank).map(::MediumId)
    }
}

private object MediumIdSerializer : KSerializer<MediumId> by ParsedSerializer("medium", String.serializer(), MediumId::of, MediumId::value)

/**
 * The media a platform's games come in, by where they were sold: [default] for PAL games and games of no known
 * region, as Cartouche's references are PAL models; [ntscU] and [ntscJ], when declared, for games of the Americas and
 * of East Asia (a Japanese NES game is a Famicom cartridge).
 */
@Serializable
public data class MediaRule(
    public val default: MediumId,
    @SerialName("ntsc_u") public val ntscU: Option<MediumId> = None,
    @SerialName("ntsc_j") public val ntscJ: Option<MediumId> = None,
) {
    /**
     * The medium of a game of [regions]: that of the first of PAL, NTSC-U and NTSC-J the game was sold in, so a
     * `(Japan, USA)` game takes the American one; the default when that group declares none or no region is known.
     * Total.
     */
    public fun of(regions: List<String>): MediumId {
        val sold = Regions.groupsOf(regions)
        return ORDER.firstOrNone { it in sold }.flatMap(::declared).getOrElse { default }
    }

    private fun declared(group: Group): Option<MediumId> = when (group) {
        Group.PAL -> None
        Group.NTSC_U -> ntscU
        Group.NTSC_J -> ntscJ
    }

    private companion object {
        val ORDER = listOf(Group.PAL, Group.NTSC_U, Group.NTSC_J)
    }
}
