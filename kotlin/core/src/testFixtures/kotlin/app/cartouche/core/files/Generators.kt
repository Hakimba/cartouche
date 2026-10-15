// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import app.cartouche.core.platforms.PlatformId
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.byte
import io.kotest.property.arbitrary.byteArray
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map

/** The platforms whose files are read, and some whose files are not. */
val readPlatforms: Arb<PlatformId> = Arb.element("ps2 psx gc wii nes snes n64 gb gbc gba xbox nds".split(' ')).map(::PlatformId)

/** The extensions read on some platform, and some read on none. */
val readExtensions: Arb<String> = Arb.element("chd iso bin gcm rvz wia nes sfc smc z64 v64 n64 gb gbc gba zip cue cso".split(' '))

/** Bytes of any content, from none to a few sectors. */
fun bytes(sizes: IntRange = 0..4096): Arb<ByteArray> = Arb.byteArray(Arb.int(sizes), Arb.byte())

/**
 * A CHD as no tool writes it, whose header, map or metadata claims what a damaged or crafted file could: [bytes]
 * read as a file of [size] bytes (zeros after them), and the [sector] asked of it. [hunkBytes] and [hunks] are what
 * its header claims.
 */
class HostileChd(val bytes: ByteArray, val size: Long, val sector: Int, val hunkBytes: Long, val hunks: Long) {
    override fun toString(): String = "HostileChd(${bytes.size} bytes as $size, sector $sector, $hunks hunks of $hunkBytes)"
}

/**
 * Hostile CHDs, DVD images of 2048-byte hunks unless their header says otherwise: hunks repeating hunks that repeat
 * others, in chains of thousands; compressed hunks claiming gigabytes; maps and metadata entries claiming
 * gigabytes; headers claiming any number and size of hunks; all but the chains in a file of a terabyte.
 */
val hostileChds: Arb<HostileChd> =
    Arb.choice(
        Arb.bind(Arb.int(3..20_000), Arb.int(0..20_002), ::selfChain),
        Arb.bind(Arb.int(1..4), Arb.long(2049L..Int.MAX_VALUE), Arb.int(0..4)) { hunks, length, sector ->
            chd(hunks.toLong(), runLength(0, hunks), List(hunks) { listOf(length to 31, 0L to 16) }.flatten(), sector, size = TERABYTE)
        },
        Arb.long(0L..0xFFFFFFFFL).map { claimed -> chd(1, listOf(NONE), listOf(0L to 16), 0, size = TERABYTE, mapBytes = claimed) },
        Arb.long(0L..0xFFFFFFL).map { length -> chd(1, listOf(NONE), listOf(0L to 16), 0, size = TERABYTE, metadata = length) },
        Arb.bind(Arb.long(), Arb.long(0L..0xFFFFFFFFL), Arb.int(0..100)) { logical, hunkBytes, sector ->
            chd(1, listOf(NONE), listOf(0L to 16), sector, size = TERABYTE, logical = logical, hunkBytes = hunkBytes)
        },
        // Hunks a little larger than any chdman writes, in an image of their size: a reader without its bound would read them.
        Arb.bind(Arb.long(MAX_HUNK + 1L..64L * MAX_HUNK), Arb.int(0..100)) { hunkBytes, sector ->
            chd(1, listOf(NONE), listOf(0L to 16), sector, size = TERABYTE, logical = hunkBytes, hunkBytes = hunkBytes)
        },
    )

/**
 * A CHD of [hunks] hunks of 2048 bytes, asked for its [sector]: a stored hunk (bytes 0, 1, 2… 255, 0…), one
 * repeating it, then each repeating the one before.
 */
fun selfChain(hunks: Int, sector: Int = 0): HostileChd =
    chd(hunks.toLong(), listOf(NONE, SELF) + runLength(SELF_1, hunks - 2), listOf(0L to 16, 0L to 16), sector)

private const val NONE = 4
private const val SELF = 5
private const val RLE_SMALL = 7
private const val RLE_LARGE = 8
private const val SELF_1 = 10
private const val HUNK = 2048L
private const val TERABYTE = 1L shl 40

/** [count] hunks of [code], run-length coded as MAME's map writes them: the code, then runs repeating it. */
private fun runLength(code: Int, count: Int): List<Int> {
    fun repeats(left: Int): List<Int> = when {
        left >= 19 -> minOf(left - 19, 255).let { listOf(RLE_LARGE, it shr 4, it and 15) + repeats(left - 19 - it) }
        left >= 3 -> minOf(left - 3, 15).let { listOf(RLE_SMALL, it) + repeats(left - 3 - it) }
        else -> List(left) { code }
    }
    return listOf(code) + repeats(count - 1)
}

/**
 * A CHD of [hunks] hunks: its header, its map (every code 4 bits long: a Huffman tree of sixteen lengths of 4, then
 * [codes], then [entries] as values and their numbers of bits; lengths in 31 bits, repeated hunks in 16), then one
 * stored hunk, then a `CHT2` metadata entry claiming [metadata] bytes, if any. The header or the map can claim
 * another number of bytes ([logical], [hunkBytes], [mapBytes]) than the image has.
 */
private fun chd(
    hunks: Long,
    codes: List<Int>,
    entries: List<Pair<Long, Int>>,
    sector: Int,
    size: Long = 0,
    logical: Long = hunks * HUNK,
    hunkBytes: Long = HUNK,
    mapBytes: Long = -1,
    metadata: Long = -1,
): HostileChd {
    val bits =
        (List(16) { 4L to 4 } + codes.map { it.toLong() to 4 } + entries).flatMap { (value, count) ->
            (count - 1 downTo 0).map { (value shr it) and 1L }
        }
    val body =
        ByteArray((bits.size + 7) / 8) { byte ->
            (0 until 8)
                .fold(0) { value, i ->
                    (value shl 1) or
                        bits.getOrElse(byte * 8 + i) { 0L }.toInt()
                }.toByte()
        }
    val firstHunk = 124L + 16 + body.size
    val metadataAt = if (metadata < 0) 0L else firstHunk + HUNK
    val header =
        "MComprHD".toByteArray() + bigEndian(124, 4) + bigEndian(5, 4) + "lzmalzmalzmalzma".toByteArray() + bigEndian(logical, 8) +
            bigEndian(124, 8) + bigEndian(metadataAt, 8) + bigEndian(hunkBytes, 4) + bigEndian(HUNK, 4) + ByteArray(60)
    val mapHead =
        bigEndian(if (mapBytes < 0) body.size.toLong() else mapBytes, 4) + bigEndian(firstHunk, 6) + byteArrayOf(0, 0, 31, 16, 16, 0)
    val tail =
        if (metadata <
            0
        ) {
            ByteArray(0)
        } else {
            "CHT2".toByteArray() + byteArrayOf(0) + bigEndian(metadata, 3) + bigEndian(0, 8) + "TYPE:MODE1 ".toByteArray()
        }
    val bytes = header + mapHead + body + ByteArray(HUNK.toInt()) { it.toByte() } + tail
    return HostileChd(bytes, maxOf(size, bytes.size.toLong()), sector, hunkBytes, (logical + hunkBytes - 1) / maxOf(hunkBytes, 1))
}

private fun bigEndian(value: Long, count: Int): ByteArray = ByteArray(count) { (value shr (8 * (count - 1 - it))).toByte() }
