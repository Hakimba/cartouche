// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.raise.Raise
import arrow.core.raise.option
import java.util.zip.CRC32

/** How a platform's ROM files are read for the print No-Intro lists: the CRC32 of the ROM alone, in its own byte order. */
internal enum class Rom {
    /** Without the 16-byte iNES header, when the file starts with one. */
    NES,

    /** Without the 512-byte header copiers add, told by the size. */
    SNES,

    /** In big-endian order, as dumped: byte-swapped (`.v64`) and word-swapped (`.n64`) files are put back, told by their first word. */
    N64,

    /** The whole file, which also tells its [Shell] by its header's colour flag. */
    GAME_BOY,

    /** The whole file. */
    WHOLE,
}

/** Reads of a ROM, which can be tens of megabytes; a multiple of 4 for the Nintendo 64's word order. */
internal const val CHUNK = 1 shl 20

private const val COLOUR_FLAG = 0x143L
private const val INES = 0x4E45531AL
private const val N64_BYTE_SWAPPED = 0x37804012L
private const val N64_WORD_SWAPPED = 0x40123780L

/** The print of a ROM read by [rom]'s rule; none for a file too small to start with a header. */
internal fun Raise<ReadFailure>.cartridgePrint(rom: Rom, source: ByteSource): Option<FileFacts.Print> = option {
    val head = bytes(source, 0, 16).bind()
    val skipped =
        when (rom) {
            Rom.NES -> if (head.bigEndian(0, 4) == INES) 16L else 0L
            Rom.SNES -> if (source.size % 1024 == 512L) 512L else 0L
            Rom.N64, Rom.GAME_BOY, Rom.WHOLE -> 0L
        }
    val reorder: (ByteArray) -> ByteArray =
        when (if (rom == Rom.N64) head.bigEndian(0, 4) else 0L) {
            N64_BYTE_SWAPPED -> swapped(1)
            N64_WORD_SWAPPED -> swapped(3)
            else -> { chunk -> chunk }
        }
    val crc = CRC32()
    generateSequence(skipped) { it + CHUNK }.takeWhile { it < source.size }.forEach { at ->
        crc.update(reorder(bytes(source, at, minOf(CHUNK.toLong(), source.size - at).toInt()).bind()))
    }
    val shell = if (rom == Rom.GAME_BOY) gameBoyShell(source) else Shell.UNKNOWN
    FileFacts.Print(crc.value.toUInt(), shell)
}

private fun Raise<ReadFailure>.gameBoyShell(source: ByteSource): Shell =
    bytes(source, COLOUR_FLAG, 1).fold({ Shell.UNKNOWN }) { Shell.of(it.unsignedByte(0)) }

/** Each byte exchanged with the one at its index xor [mask], within groups of mask + 1 bytes; a last, partial group left as is. */
private fun swapped(mask: Int): (ByteArray) -> ByteArray = { chunk ->
    // In place: each chunk is read anew, megabytes of a ROM, and only hashed once reordered.
    for (at in chunk.indices) {
        val other = at xor mask
        if (other > at && (at or mask) < chunk.size) chunk[at] = chunk[other].also { chunk[other] = chunk[at] }
    }
    chunk
}

private const val END_RECORD = 22
private const val MAX_COMMENT = 65535
private const val END_SIGNATURE = 0x504B0506L
private const val ENTRY_SIGNATURE = 0x504B0102L
private const val ENTRY_HEADER = 46

/**
 * The print a zip archive records for its only entry, in its central directory (found from the end record,
 * which a comment may follow); none for an archive of several entries, or in the zip64 format.
 */
internal fun Raise<ReadFailure>.zipEntryPrint(source: ByteSource): Option<FileFacts> = option {
    val tailLength = minOf(source.size, (END_RECORD + MAX_COMMENT).toLong()).toInt()
    val tail = bytes(source, source.size - tailLength, tailLength).bind()
    val end = (tail.size - END_RECORD downTo 0).firstOrNone { tail.bigEndian(it, 4) == END_SIGNATURE }.bind()
    ensure(tail.littleEndian(end + 10, 2) == 1L)
    val entry = bytes(source, tail.littleEndian(end + 16, 4), ENTRY_HEADER).bind()
    ensure(entry.bigEndian(0, 4) == ENTRY_SIGNATURE)
    FileFacts.Print(entry.littleEndian(16, 4).toUInt())
}
