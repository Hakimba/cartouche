// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.raise.either
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The models a supported console can show. The first of each platform is its base model. */
@Serializable
public enum class ConsoleVariant(public val platform: PlatformId, public val wire: String) {
    @SerialName("ps2_slim")
    PS2_SLIM(PlatformId("ps2"), "ps2_slim"),

    @SerialName("ps2_fat")
    PS2_FAT(PlatformId("ps2"), "ps2_fat"),

    @SerialName("gba")
    GBA(PlatformId("gba"), "gba"),

    @SerialName("gba_sp")
    GBA_SP(PlatformId("gba"), "gba_sp"),

    @SerialName("gb")
    GB(PlatformId("gb"), "gb"),

    @SerialName("gbc")
    GBC(PlatformId("gbc"), "gbc"),

    @SerialName("gc")
    GC(PlatformId("gc"), "gc"),

    @SerialName("n64")
    N64(PlatformId("n64"), "n64"),

    @SerialName("nes")
    NES(PlatformId("nes"), "nes"),

    @SerialName("snes")
    SNES(PlatformId("snes"), "snes"),

    @SerialName("psx")
    PSX(PlatformId("psx"), "psx"),

    @SerialName("wii")
    WII(PlatformId("wii"), "wii"),

    @SerialName("xbox")
    XBOX(PlatformId("xbox"), "xbox"),

    @SerialName("xbox360")
    XBOX360(PlatformId("xbox360"), "xbox360"),
    ;

    public companion object {
        public fun base(platform: PlatformId): Option<ConsoleVariant> = entries.firstOrNone { it.platform == platform }

        public fun of(platform: PlatformId, id: String): Either<VariantError, ConsoleVariant> = either {
            entries
                .firstOrNone { it.platform == platform && it.wire == id }
                .getOrElse { raise(VariantError.Unknown(platform, id)) }
        }
    }
}
