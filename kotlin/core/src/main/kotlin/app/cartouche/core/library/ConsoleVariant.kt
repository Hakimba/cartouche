// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
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

    @SerialName("psp")
    PSP(PlatformId("psp"), "psp"),

    @SerialName("switch")
    SWITCH(PlatformId("switch"), "switch"),

    @SerialName("switch_grey")
    SWITCH_GREY(PlatformId("switch"), "switch_grey"),

    @SerialName("dreamcast")
    DREAMCAST(PlatformId("dreamcast"), "dreamcast"),

    @SerialName("megadrive")
    MEGADRIVE(PlatformId("genesis"), "megadrive"),

    @SerialName("megadrive2")
    MEGADRIVE2(PlatformId("genesis"), "megadrive2"),

    @SerialName("mastersystem")
    MASTERSYSTEM(PlatformId("master"), "mastersystem"),
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

/**
 * The console models shown but not fully supported yet (their launch not designed, their medium not modelled): offered
 * greyed, never added nor chosen. A console is coming when its base model is.
 */
@JvmInline
public value class Coming(public val models: Set<ConsoleVariant>) {
    public operator fun contains(platform: PlatformId): Boolean = ConsoleVariant.base(platform).isSome { it in models }

    /** [variant] unless it is coming. */
    public fun ready(variant: ConsoleVariant): Either<VariantError, ConsoleVariant> = either {
        ensure(variant !in models) { VariantError.Coming(variant.platform, variant.wire) }
        variant
    }

    public companion object {
        public val NONE: Coming = Coming(emptySet())

        /** The models of the console folders named [folders]; a folder of no model is left out. */
        public fun of(folders: Collection<String>): Coming = Coming(ConsoleVariant.entries.filter { it.wire in folders }.toSet())
    }
}
