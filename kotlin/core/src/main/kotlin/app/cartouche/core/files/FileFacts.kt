// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** What a game file itself tells about which game it is, read from its bytes rather than its name. */
public sealed interface FileFacts {
    /**
     * A disc's serial as the disc writes it (`SLES_524.95` in SYSTEM.CNF, `GKYP` of a GameCube ID `GKYP01`); the
     * reference lists write the same serial otherwise (`SLES-52495`, `SLES---52495`), so serials compare on [key].
     */
    public data class Serial(public val code: String) : FileFacts {
        public val key: String get() = code.filter(Char::isLetterOrDigit).uppercase()
    }

    /**
     * A cartridge's CRC32 as No-Intro counts it: of the ROM alone, without a copier's or an emulator's header; and, for a
     * Game Boy ROM, the [shell] its header's colour flag says it was sold in.
     */
    public data class Print(public val crc32: UInt, public val shell: Shell = Shell.UNKNOWN) : FileFacts {
        /** As the prints lists write it: eight upper-case hexadecimal digits. */
        public val hex: String get() = "%08X".format(crc32.toLong())
    }

    /** Nothing readable: an unknown format, a damaged file, or one this reader does not decode. */
    public data object Silent : FileFacts
}

/** The kind of Game Boy Color cartridge a ROM's colour flag (header byte 0x143) says: its sticker sits lower on an exclusive's. */
@Serializable
public enum class Shell {
    /** Flag `0xC0`: runs on a Game Boy Color only. */
    @SerialName("exclusive")
    EXCLUSIVE,

    /** Flag `0x80`: also runs on a Game Boy. */
    @SerialName("compatible")
    COMPATIBLE,

    /** Any other flag, no header, or a file read without one. */
    @SerialName("unknown")
    UNKNOWN,
    ;

    /** How a stored file and a trace write it, as the serial name does. */
    public val key: String get() = name.lowercase()

    public companion object {
        public fun of(flag: Int): Shell = when (flag) {
            0xC0 -> EXCLUSIVE
            0x80 -> COMPATIBLE
            else -> UNKNOWN
        }
    }
}
