// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

/** What a game file itself tells about which game it is, read from its bytes rather than its name. */
public sealed interface FileFacts {
    /**
     * A disc's serial as the disc writes it (`SLES_524.95` in SYSTEM.CNF, `GKYP` of a GameCube ID `GKYP01`); the
     * reference lists write the same serial otherwise (`SLES-52495`, `SLES---52495`), so serials compare on [key].
     */
    public data class Serial(public val code: String) : FileFacts {
        public val key: String get() = code.filter(Char::isLetterOrDigit).uppercase()
    }

    /** A cartridge's CRC32 as No-Intro counts it: of the ROM alone, without a copier's or an emulator's header. */
    public data class Print(public val crc32: UInt) : FileFacts {
        /** As the prints lists write it: eight upper-case hexadecimal digits. */
        public val hex: String get() = "%08X".format(crc32.toLong())
    }

    /** Nothing readable: an unknown format, a damaged file, or one this reader does not decode. */
    public data object Silent : FileFacts
}
