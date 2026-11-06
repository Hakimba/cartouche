// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.serialName
import arrow.core.Either
import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The models a supported console can show. The first of each platform is its base model. */
@Serializable
public enum class ConsoleVariant(public val platform: PlatformId) {
    @SerialName("ps2_slim")
    PS2_SLIM(PlatformId("ps2")),

    @SerialName("ps2_fat")
    PS2_FAT(PlatformId("ps2")),

    @SerialName("gba")
    GBA(PlatformId("gba")),

    @SerialName("gba_sp")
    GBA_SP(PlatformId("gba")),

    @SerialName("gb")
    GB(PlatformId("gb")),

    @SerialName("gbc")
    GBC(PlatformId("gbc")),

    @SerialName("gc")
    GC(PlatformId("gc")),

    @SerialName("n64")
    N64(PlatformId("n64")),

    @SerialName("nes")
    NES(PlatformId("nes")),

    @SerialName("snes")
    SNES(PlatformId("snes")),

    @SerialName("psx")
    PSX(PlatformId("psx")),

    @SerialName("wii")
    WII(PlatformId("wii")),

    @SerialName("xbox")
    XBOX(PlatformId("xbox")),

    @SerialName("xbox360")
    XBOX360(PlatformId("xbox360")),

    @SerialName("psp")
    PSP(PlatformId("psp")),

    @SerialName("switch")
    SWITCH(PlatformId("switch")),

    @SerialName("switch_grey")
    SWITCH_GREY(PlatformId("switch")),

    @SerialName("dreamcast")
    DREAMCAST(PlatformId("dreamcast")),

    @SerialName("megadrive")
    MEGADRIVE(PlatformId("genesis")),

    @SerialName("megadrive2")
    MEGADRIVE2(PlatformId("genesis")),

    @SerialName("mastersystem")
    MASTERSYSTEM(PlatformId("master")),

    @SerialName("psvita")
    PSVITA(PlatformId("psvita")),

    @SerialName("ds_lite")
    DS_LITE(PlatformId("nds")),
    ;

    public companion object {
        public fun base(platform: PlatformId): Option<ConsoleVariant> = entries.firstOrNone { it.platform == platform }

        public fun of(platform: PlatformId, id: String): Either<VariantError, ConsoleVariant> = either {
            entries
                .firstOrNone { it.platform == platform && it.serialName == id }
                .getOrElse { raise(VariantError.Unknown(platform, id)) }
        }
    }
}

/**
 * The console models shown but not fully supported yet (their launch not designed, their medium not modelled): offered
 * greyed, never added nor chosen. A console is coming when its base model is.
 */
@JvmInline
public value class Coming(public val models: Set<ConsoleVariant>) {
    public operator fun contains(platform: PlatformId): Boolean = ConsoleVariant.base(platform).isSome { it in models }

    /** [variant] unless it is coming. */
    public fun ready(variant: ConsoleVariant): Either<VariantError, ConsoleVariant> = either {
        ensure(variant !in models) { VariantError.Coming(variant.platform, variant.serialName) }
        variant
    }

    public companion object {
        public val NONE: Coming = Coming(emptySet())

        /** The models of the console folders named [folders]; a folder of no model is left out. */
        public fun of(folders: Collection<String>): Coming = Coming(ConsoleVariant.entries.filter { it.serialName in folders }.toSet())
    }
}
