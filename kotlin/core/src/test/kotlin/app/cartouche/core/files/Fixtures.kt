// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlatformId
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.raise.Raise
import arrow.core.raise.either
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** The serial the fixture discs boot, as `dev/file_fixtures.py` writes it. */
const val FIXTURE_SERIAL = "SLES_524.95"

/** The CHD images of the fixture disc the readers decode, by codec and track type. */
val READABLE_CHDS =
    listOf(
        "cd-cdlz.chd",
        "cd-cdzl.chd",
        "cd-mode1-raw.chd",
        "cd-mode2-raw.chd",
        "cd-mode2.chd",
        "cd-mode2-form-mix.chd",
        "dvd-lzma.chd",
        "dvd-zlib.chd",
    )

/** A disc image of `src/test/resources/files`, made by `dev/file_fixtures.py`. */
fun image(name: String): ByteArray =
    checkNotNull(InMemoryBytes::class.java.getResourceAsStream("/files/$name")) { "No fixture $name" }.use { it.readBytes() }

/** The fixture disc as a plain image, and as the sector function the ISO 9660 reader takes. */
val disc: ByteArray by lazy { image("disc.iso") }

fun sectorsOf(bytes: ByteArray): (Int) -> Option<ByteArray> = { n -> readable { bytes(InMemoryBytes(bytes), n * SECTOR.toLong(), SECTOR) } }

/** What [bytes] tell, read as a file of [platform] named [name]: held in memory, they never fail to be read. */
fun facts(platform: String, name: String, bytes: ByteArray): FileFacts = readable {
    FileReading.facts(PlatformId(platform), FileName(name), InMemoryBytes(bytes)).bind()
}

/** What [read] gives of files held in memory, which never fail to be read. */
fun <A> readable(read: Raise<ReadFailure>.() -> A): A = either(read).getOrElse { error("Read failed: $it") }

/** The sector [n] of a CHD: none past the image or when it cannot be decoded. */
internal fun ChdImage.sectorOf(n: Int): Option<ByteArray> = readable { sector(n) }

/** The CHD [bytes] hold, if any. */
internal fun chdOf(bytes: ByteArray): Option<ChdImage> = readable { chdImage(InMemoryBytes(bytes)) }

/**
 * The sectors `dvd-runs.chd` holds, as `dev/file_fixtures.py` writes them: the disc padded with zeros to 32 sectors,
 * 40 sectors each filled with its number from 1, then 4 sectors of hashes.
 */
val runsDisc: ByteArray by lazy {
    val sha256 = MessageDigest.getInstance("SHA-256")
    disc.copyOf(32 * SECTOR) +
        (1..40).fold(ByteArray(0)) { bytes, n -> bytes + ByteArray(SECTOR) { n.toByte() } } +
        (0 until 4).fold(ByteArray(0)) { bytes, n -> (0 until 64).fold(bytes) { all, i -> all + sha256.digest("$n.$i".toByteArray()) } }
}

/** [bytes] with [replacement] written at the first place [text] is found, which must be at least as long. */
fun ByteArray.patched(text: String, replacement: String): ByteArray {
    val at = String(this, Charsets.ISO_8859_1).indexOf(text).also { check(it >= 0) { "$text is not in the image" } }
    return copyOf().also { replacement.padEnd(text.length).toByteArray(Charsets.ISO_8859_1).copyInto(it, at) }
}

fun crc32(bytes: ByteArray): UInt = CRC32().apply { update(bytes) }.value.toUInt()

/** A zip archive of [entries], each named and with its bytes, stored or deflated, with a [comment] after its end record. */
fun zip(vararg entries: Pair<String, ByteArray>, stored: Boolean = false, comment: String = ""): ByteArray {
    val out = ByteArrayOutputStream()
    ZipOutputStream(out).use { zip ->
        zip.setComment(comment)
        entries.forEach { (name, bytes) ->
            val entry = ZipEntry(name)
            if (stored) {
                entry.method = ZipEntry.STORED
                entry.size = bytes.size.toLong()
                entry.crc = crc32(bytes).toLong()
            }
            zip.putNextEntry(entry)
            zip.write(bytes)
            zip.closeEntry()
        }
    }
    return out.toByteArray()
}
