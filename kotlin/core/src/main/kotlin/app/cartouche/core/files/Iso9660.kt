// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import arrow.core.None
import arrow.core.Option
import arrow.core.getOrNone
import arrow.core.raise.SingletonRaise
import arrow.core.raise.option
import arrow.core.toOption

/**
 * The ISO 9660 file system of a disc image, read one [SECTOR] at a time: enough to find a PlayStation's SYSTEM.CNF
 * at the root and the serial it boots.
 */
internal object Iso9660 {
    /** A file's place: its first sector and its size in bytes. */
    private data class Extent(val sector: Int, val size: Int)

    private const val VOLUME_SECTOR = 16

    /** The root directory record lies in the volume descriptor; a record's name follows its fixed fields. */
    private const val ROOT_RECORD = 156
    private const val RECORD_FIELDS = 33

    /** Bounds on what is read of a disc: far above any root directory or SYSTEM.CNF. */
    private const val MAX_DIRECTORY = 1 shl 20
    private const val MAX_CNF = 1 shl 16

    /** `BOOT2 = cdrom0:\SLES_524.95;1` (PlayStation 2) or `BOOT = cdrom:\SLES_012.34;1` (PlayStation). */
    private val BOOT = Regex("""BOOT2?\s*=\s*cdrom0?:\\?\\?([A-Z]{4}[_-]\d{3}\.\d{2})""", RegexOption.IGNORE_CASE)

    /**
     * The serial SYSTEM.CNF boots, as the disc writes it (`SLES_524.95`); none without an ISO 9660 volume, the file
     * at the root, or a boot line naming a serial.
     */
    fun bootSerial(sector: (Int) -> Option<ByteArray>): Option<FileFacts.Serial> = option {
        val volume = sector(VOLUME_SECTOR).bind()
        ensure(volume.text(1, 5) == "CD001")
        val root = records(file(sector, extent(volume, ROOT_RECORD), MAX_DIRECTORY).bind())
        val cnf = file(sector, root.getOrNone("SYSTEM.CNF").bind(), MAX_CNF).bind()
        FileFacts.Serial(BOOT.find(cnf.text(0, cnf.size)).toOption().bind().groupValues[1])
    }

    private fun extent(record: ByteArray, at: Int): Extent =
        Extent(record.littleEndian(at + 2, 4).toInt(), record.littleEndian(at + 10, 4).toInt())

    /** The bytes of a file: its sectors, the last cut to its size. */
    private fun file(sector: (Int) -> Option<ByteArray>, extent: Extent, limit: Int): Option<ByteArray> = option {
        ensure(extent.sector >= 0 && extent.size in 0..limit)
        val sectors = (0 until (extent.size + SECTOR - 1) / SECTOR).map { sector(extent.sector + it).bind() }
        ByteArray(extent.size) { sectors[it / SECTOR][it % SECTOR] }
    }

    /** A directory's records by name, the version (`;1`) dropped. */
    private fun SingletonRaise<None>.records(directory: ByteArray): Map<String, Extent> =
        generateSequence(0) { at -> nextRecord(directory, at) }
            .takeWhile { it < directory.size }
            .filter { directory.unsignedByte(it) != 0 }
            .associate { at ->
                ensure(at + RECORD_FIELDS <= directory.size)
                val nameLength = directory.unsignedByte(at + RECORD_FIELDS - 1)
                ensure(at + RECORD_FIELDS + nameLength <= directory.size)
                directory.text(at + RECORD_FIELDS, nameLength).substringBefore(';').uppercase() to extent(directory, at)
            }

    /** Each record starts with its length; a zero length ends a sector's records. */
    private fun nextRecord(directory: ByteArray, at: Int): Int =
        directory.unsignedByte(at).let { length -> if (length == 0) (at / SECTOR + 1) * SECTOR else at + length }
}
