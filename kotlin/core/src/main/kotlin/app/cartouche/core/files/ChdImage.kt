// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.Raise
import arrow.core.raise.option
import arrow.core.toOption
import org.tukaani.xz.LZMAInputStream
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.util.zip.Inflater
import java.util.zip.InflaterInputStream

/** A disc's sector of data, as a file system sees it. */
internal const val SECTOR: Int = 2048

/** A CD's sector as the disc writes it: sync and headers around the data, error codes after. */
internal const val RAW_SECTOR: Int = 2352

/** A CD's frame as a CHD holds it: the raw sector and its 96 bytes of subcode. */
internal const val FRAME: Int = 2448

/**
 * A CHD (MAME's compressed hunks of data, version 5), read on demand: the header, the map of its hunks, then any
 * sector of the disc it holds. CD images (frames, the track's type in the `CHT2` metadata) in the `cdlz` and `cdzl`
 * codecs and DVD images (sectors) in `lzma` and `zlib` are decoded, as are hunks stored as they are and hunks
 * repeating an earlier one; any other codec (`cdfl`, `huff`, `zstd`…), hunks taken from a parent image and
 * uncompressed images are not readable. Checksums are not verified: a damaged hunk reads as any other.
 *
 * What a reading holds is bounded whatever the file claims: the map's codes (a byte per hunk, at most [MAX_HUNKS]),
 * the map itself (at most 9 bytes per hunk), one hunk and its compressed bytes (at most [MAX_HUNK] each), and a
 * metadata entry's text (at most [MAX_METADATA_TEXT]); a hunk repeating another is resolved once, never in a chain.
 */
internal class ChdImage(
    private val source: ByteSource,
    private val codecs: List<Codec>,
    private val hunkBytes: Int,
    private val map: HunkMap,
    private val layout: Layout,
) {
    /** Sector [n]'s 2048 bytes of data; none past the image or when its hunk cannot be decoded. */
    fun Raise<ReadFailure>.sector(n: Int): Option<ByteArray> = option {
        val perHunk = hunkBytes / layout.stride
        ensure(n >= 0 && perHunk > 0)
        layout.data(hunk(n / perHunk).bind(), n % perHunk * layout.stride).bind()
    }

    /** MAME's writer makes a hunk repeat the first copy of its bytes, which is held in the file, never another repetition. */
    private fun Raise<ReadFailure>.hunk(n: Int): Option<ByteArray> = option {
        val entry = map.entry(n).bind()
        when (val held = if (entry is Hunk.Self) map.entry(entry.hunk).bind() else entry) {
            is Hunk.Compressed -> codecs[held.codec].decode(bytes(source, held.offset, held.length).bind(), hunkBytes).bind()
            is Hunk.Stored -> bytes(source, held.offset, hunkBytes).bind()
            is Hunk.Self, Hunk.Parent -> raise(None)
        }
    }
}

/** The largest hunk chdman writes. */
internal const val MAX_HUNK = 1 shl 20

/** Enough for a dual-layer DVD at chdman's smallest hunk. */
internal const val MAX_HUNKS = 1 shl 22

/** Far above the few dozen characters of a track's description. */
internal const val MAX_METADATA_TEXT = 4096

/** The CHD [source] holds; none for another file, an image this reader does not decode or a damaged one. */
internal fun Raise<ReadFailure>.chdImage(source: ByteSource): Option<ChdImage> = option {
    val header = bytes(source, 0, 124).bind()
    ensure(header.text(0, 8) == "MComprHD" && header.bigEndian(12, 4) == 5L)
    // An uncompressed image names no codec and keeps another map, four bytes per hunk; chdman writes one only when asked.
    ensure(header.bigEndian(16, 4) != 0L)
    val hunkBytes = header.bigEndian(56, 4)
    ensure(hunkBytes in 1..MAX_HUNK)
    val hunks = (header.bigEndian(32, 8) + hunkBytes - 1) / hunkBytes
    ensure(hunks in 0..MAX_HUNKS)
    ChdImage(
        source,
        (0 until 4).map { Codec.of(header.text(16 + 4 * it, 4)) },
        hunkBytes.toInt(),
        hunkMap(source, header.bigEndian(40, 8), hunks.toInt(), hunkBytes.toInt()).bind(),
        layout(source, header.bigEndian(48, 8)).bind(),
    )
}

private fun Raise<ReadFailure>.hunkMap(source: ByteSource, at: Long, hunks: Int, hunkBytes: Int): Option<HunkMap> = option {
    val head = bytes(source, at, 16).bind()
    // A hunk takes at most an 8-bit code and a 63-bit entry; the Huffman tree a few bytes more.
    ensure(head.bigEndian(0, 4) <= hunks * 9L + 64)
    HunkMap.decode(head, bytes(source, at + 16, head.bigEndian(0, 4).toInt()).bind(), hunks, hunkBytes).bind()
}

/**
 * The layout the image's metadata gives, from the entry at [at] on: a CD's by its first track's type, a DVD's when
 * no track is written. Each entry: its tag, flags, a 3-byte length, the offset of the next, then its text.
 */
private tailrec fun Raise<ReadFailure>.layout(source: ByteSource, at: Long, left: Int = MAX_METADATA): Option<Layout> {
    if (at == 0L || left == 0) return Some(Layout.DVD)
    val head = bytes(source, at, 16).getOrElse { return None }
    if (head.text(0, 4) != "CHT2" && head.text(0, 4) != "CHTR") return layout(source, head.bigEndian(8, 8), left - 1)
    return option {
        val length = head.bigEndian(5, 3).toInt()
        ensure(length <= MAX_METADATA_TEXT)
        Layout.ofTrack(TRACK_TYPE.find(bytes(source, at + 16, length).bind().text(0, length)).toOption().bind().groupValues[1])
    }
}

private val TRACK_TYPE = Regex("""TYPE:(\S+)""")

/** The metadata entries walked before an image is taken for a DVD. */
private const val MAX_METADATA = 32

/**
 * Where a sector's data lies in the image's units: a DVD's sectors are the data; a CD's frames hold a raw sector,
 * whose data starts after its headers, by the track's type. [stride] is a unit's length in a hunk, [length] what
 * a unit at least holds.
 */
internal enum class Layout(val stride: Int, private val length: Int) {
    DVD(SECTOR, SECTOR),
    COOKED(FRAME, SECTOR),
    RAW(FRAME, RAW_SECTOR),
    MODE2(FRAME, RAW_SECTOR),
    ;

    /** The data of the unit at [at] in [units]. */
    fun data(units: ByteArray, at: Int): Option<ByteArray> = option {
        ensure(at >= 0 && at + length <= units.size)
        val start = at + headerLength(units, at)
        units.copyOfRange(start, start + SECTOR)
    }

    /** Before the data: nothing, a mode 2 subheader, or a raw sector's sync and header, whose mode byte says whether a subheader follows. */
    private fun headerLength(units: ByteArray, at: Int): Int = when (this) {
        DVD, COOKED -> 0
        MODE2 -> 8
        RAW -> if (units.unsignedByte(at + 15) == 1) 16 else 24
    }

    companion object {
        /** A CD track's layout by its type as chdman writes it: `MODE1`, `MODE2_RAW`, `MODE2_FORM_MIX`… */
        fun ofTrack(type: String): Layout = when {
            type.endsWith("_RAW") -> RAW
            // Both keep each sector's 8-byte subheader before its data.
            type == "MODE2" || type == "MODE2_FORM_MIX" -> MODE2
            else -> COOKED
        }
    }
}

/** A hunk of the image: where its bytes are and how they are held. */
internal sealed interface Hunk {
    data class Compressed(val codec: Int, val offset: Long, val length: Int) : Hunk

    data class Stored(val offset: Long) : Hunk

    data class Self(val hunk: Int) : Hunk

    data object Parent : Hunk
}

/**
 * The map of a CHD, as MAME compresses it: a Huffman tree, then one code per hunk telling how it is held
 * (run-length coded), then for each hunk its length and checksum, or the hunk it repeats, in the numbers of bits
 * the map's header gives. The codes are decoded once, a byte per hunk; a hunk's entry is read by walking the second
 * part up to it, a pass over the hunks before it for each of the few an image is asked for.
 */
internal class HunkMap(
    private val kinds: ByteArray,
    private val bits: ByteArray,
    private val entriesAt: Long,
    private val firstOffset: Long,
    private val lengthBits: Int,
    private val selfBits: Int,
    private val parentBits: Int,
    private val hunkBytes: Int,
) {
    fun entry(n: Int): Option<Hunk> = option {
        ensure(n in kinds.indices)
        val reader = BitReader(bits, entriesAt)
        // Local to the walk: the offset the next stored or compressed hunk starts at, and the hunk last repeated.
        var offset = firstOffset
        var lastSelf = 0L
        var start = 0L
        var length = 0L
        for (hunk in 0..n) {
            start = offset
            when (kinds[hunk].toInt()) {
                in CODECS -> {
                    length = reader.read(lengthBits)
                    reader.read(CRC_BITS)
                    offset += length
                }
                NONE -> {
                    reader.read(CRC_BITS)
                    offset += hunkBytes
                }
                SELF -> lastSelf = reader.read(selfBits)
                SELF_1 -> lastSelf++
                PARENT -> reader.read(parentBits)
            }
        }
        when (val kind = kinds[n].toInt()) {
            in CODECS -> {
                // A hunk that does not compress is stored as it is: a compressed one is never longer.
                ensure(length <= hunkBytes)
                Hunk.Compressed(kind, start, length.toInt())
            }
            NONE -> Hunk.Stored(start)
            SELF, SELF_0, SELF_1 -> Hunk.Self(lastSelf.toInt())
            else -> Hunk.Parent
        }
    }

    companion object {
        private val CODECS = 0..3
        private const val NONE = 4
        private const val SELF = 5
        private const val PARENT = 6
        private const val RLE_SMALL = 7
        private const val RLE_LARGE = 8
        private const val SELF_0 = 9
        private const val SELF_1 = 10
        private const val CRC_BITS = 16

        /** The map from its 16-byte [head] and its [bits]. */
        fun decode(head: ByteArray, bits: ByteArray, hunks: Int, hunkBytes: Int): Option<HunkMap> = option {
            val lengthBits = head.unsignedByte(12)
            val selfBits = head.unsignedByte(13)
            val parentBits = head.unsignedByte(14)
            ensure(lengthBits < 32 && selfBits < 32 && parentBits < 64)
            val reader = BitReader(bits, 0)
            val tree = Huffman.read(reader).bind()
            val kinds = ByteArray(hunks)
            // Local to the decoding: the code last given and how many more hunks repeat it.
            var last = 0
            var repeat = 0
            for (hunk in 0 until hunks) {
                if (repeat > 0) {
                    kinds[hunk] = last.toByte()
                    repeat--
                    continue
                }
                when (val code = tree.decode(reader).bind()) {
                    RLE_SMALL, RLE_LARGE -> {
                        kinds[hunk] = last.toByte()
                        val count = tree.decode(reader).bind()
                        repeat = 2 + if (code == RLE_SMALL) count else 16 + (count shl 4) + tree.decode(reader).bind()
                    }
                    else -> {
                        kinds[hunk] = code.toByte()
                        last = code
                    }
                }
            }
            HunkMap(kinds, bits, reader.position, head.bigEndian(4, 6), lengthBits, selfBits, parentBits, hunkBytes)
        }
    }
}

/** Bits read most significant first from [data], zeros past its end; [position] counts them. */
private class BitReader(private val data: ByteArray, var position: Long) {
    fun read(count: Int): Long {
        var value = 0L
        var left = count
        while (left > 0) {
            val index = (position ushr 3).toInt()
            val byte = if (index < data.size) data.unsignedByte(index) else 0
            val taken = minOf(8 - (position and 7).toInt(), left)
            value = (value shl taken) or (byte shr (8 - (position and 7).toInt() - taken) and ((1 shl taken) - 1)).toLong()
            position += taken
            left -= taken
        }
        return value
    }
}

/** MAME's Huffman tree as the map stores it: each code's length, run-length coded; then canonical codes. */
private class Huffman private constructor(private val symbols: IntArray) {
    /** The next symbol, none when no code of at most [MAX_BITS] bits matches. */
    fun decode(reader: BitReader): Option<Int> {
        var code = 1
        repeat(MAX_BITS) {
            code = (code shl 1) or reader.read(1).toInt()
            if (symbols[code] >= 0) return Some(symbols[code])
        }
        return None
    }

    companion object {
        private const val CODES = 16
        private const val MAX_BITS = 8
        private const val LENGTH_BITS = 4

        fun read(reader: BitReader): Option<Huffman> = option {
            val lengths = IntArray(CODES)
            var node = 0
            while (node < CODES) {
                val length = reader.read(LENGTH_BITS).toInt()
                if (length != 1) {
                    lengths[node++] = length
                    continue
                }
                val repeated = reader.read(LENGTH_BITS).toInt()
                val count = if (repeated == 1) 1 else reader.read(LENGTH_BITS).toInt() + 3
                ensure(node + count <= CODES)
                repeat(count) { lengths[node++] = repeated }
            }
            val starts = IntArray(33)
            lengths.forEach { starts[it]++ }
            var start = 0
            for (length in 32 downTo 1) {
                val next = (start + starts[length]) shr 1
                starts[length] = start
                start = next
            }
            // A code of n bits is filed with a leading 1, so that codes of every length share one table.
            val symbols = IntArray(2 shl MAX_BITS) { -1 }
            lengths.forEachIndexed { symbol, length ->
                if (length in 1..MAX_BITS && starts[length] < 1 shl length) symbols[(1 shl length) or starts[length]++] = symbol
            }
            Huffman(symbols)
        }
    }
}

/** A codec a hunk is compressed with; the four an image names decode its hunks of each kind. */
internal enum class Codec {
    CD_LZMA,
    CD_ZLIB,
    LZMA,
    ZLIB,
    OTHER,
    ;

    /** [compressed] decoded into a hunk of [hunkBytes]; none for a codec not decoded or a damaged hunk. */
    fun decode(compressed: ByteArray, hunkBytes: Int): Option<ByteArray> = when (this) {
        CD_LZMA -> cd(compressed, hunkBytes, ::lzma)
        CD_ZLIB -> cd(compressed, hunkBytes, ::inflate)
        LZMA -> lzma(compressed, hunkBytes)
        ZLIB -> inflate(compressed, hunkBytes)
        OTHER -> None
    }

    companion object {
        fun of(tag: String): Codec = when (tag) {
            "cdlz" -> CD_LZMA
            "cdzl" -> CD_ZLIB
            "lzma" -> LZMA
            "zlib" -> ZLIB
            else -> OTHER
        }
    }
}

/**
 * A CD hunk: a bit per frame telling whose error codes were dropped, the compressed length of the frames' raw
 * sectors, those, then the compressed subcodes. The subcodes and error codes are left zero: only the mode bytes and
 * the data are read.
 */
private fun cd(compressed: ByteArray, hunkBytes: Int, decompress: (ByteArray, Int) -> Option<ByteArray>): Option<ByteArray> = option {
    val frames = hunkBytes / FRAME
    val flags = (frames + 7) / 8
    val header = flags + if (hunkBytes < 65536) 2 else 3
    ensure(header <= compressed.size)
    val length = compressed.bigEndian(flags, header - flags).toInt()
    ensure(length <= compressed.size - header)
    val sectors = decompress(compressed.copyOfRange(header, header + length), frames * RAW_SECTOR).bind()
    ByteArray(hunkBytes).also { hunk -> repeat(frames) { sectors.copyInto(hunk, it * FRAME, it * RAW_SECTOR, (it + 1) * RAW_SECTOR) } }
}

/** MAME's LZMA: raw, lc 3, lp 0, pb 2 (as one byte, (pb * 5 + lp) * 9 + lc), the dictionary its encoder settles on for the hunk's size. */
private const val LZMA_PROPERTIES: Byte = 93

private fun lzma(compressed: ByteArray, size: Int): Option<ByteArray> =
    decoded(size) { LZMAInputStream(ByteArrayInputStream(compressed), size.toLong(), LZMA_PROPERTIES, dictionary(size)) }

/** MAME's zlib: raw deflate. An inflater holds native memory until it is ended. */
private fun inflate(compressed: ByteArray, size: Int): Option<ByteArray> {
    val inflater = Inflater(true)
    return try {
        decoded(size) { InflaterInputStream(ByteArrayInputStream(compressed), inflater) }
    } finally {
        inflater.end()
    }
}

/** The dictionary MAME's encoder rounds a hunk's size up to: the first of 4096, 6144, 8192, 12288… at or above it. */
private fun dictionary(size: Int): Int =
    generateSequence(1 shl 12) { if (it.countOneBits() == 1) it / 2 * 3 else it / 3 * 4 }.first { size <= it }

/** The [size] bytes [stream] gives; none when it ends before or is damaged. */
private fun decoded(size: Int, stream: () -> InputStream): Option<ByteArray> = option {
    val out = ByteArray(size)
    ensure(Either.catch { stream().use { it.fill(out) } }.getOrNone().bind() == size)
    out
}

private fun InputStream.fill(out: ByteArray): Int {
    var done = 0
    while (done < out.size) {
        val count = read(out, done, out.size - done)
        if (count < 0) break
        done += count
    }
    return done
}
