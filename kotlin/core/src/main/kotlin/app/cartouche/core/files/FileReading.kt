// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.Raise
import arrow.core.raise.either

private typealias Reader = Raise<ReadFailure>.(ByteSource) -> Option<FileFacts>

/**
 * What a game file tells about which game it is, read from its bytes. Its platform and extension say how it is
 * laid out and what to look for: PlayStation discs (`.chd`, `.iso`, `.bin`) give the serial SYSTEM.CNF boots;
 * GameCube and Wii discs (`.iso`, `.gcm`, `.rvz`, `.wia`) the game code of their ID (`GKYP` of `GKYP01`), the
 * part of the serial the reference lists write (`DL-DOL-GKYP-EUR`); cartridges the CRC32 of their ROM as No-Intro
 * counts it, a zip's as its archive records it.
 */
public object FileReading {
    /**
     * The facts [source] gives: [FileFacts.Silent] for a file of another platform or extension, a damaged one or one
     * in a format not decoded; a failure only when the port could not read it.
     */
    public fun facts(platform: PlatformId, name: FileName, source: ByteSource): Either<ReadFailure, FileFacts> = either {
        readerOf(platform, name).flatMap { it(source) }.getOrElse { FileFacts.Silent }
    }

    /** Whether [facts] looks into a file of [platform] named [name]: the others are [FileFacts.Silent] unopened. */
    public fun reads(platform: PlatformId, name: FileName): Boolean = readerOf(platform, name).isSome()

    private fun readerOf(platform: PlatformId, name: FileName): Option<Reader> =
        READERS.getOrNone(platform).flatMap { it.getOrNone(name.value.substringAfterLast('.', "").lowercase()) }

    private val playStation: Map<String, Reader> =
        mapOf("chd" to Raise<ReadFailure>::chdSerial, "iso" to Raise<ReadFailure>::isoSerial, "bin" to Raise<ReadFailure>::binSerial)

    private val nintendoDisc: Map<String, Reader> =
        mapOf(
            "iso" to Raise<ReadFailure>::discGameCode,
            "gcm" to Raise<ReadFailure>::discGameCode,
            "rvz" to Raise<ReadFailure>::compressedGameCode,
            "wia" to Raise<ReadFailure>::compressedGameCode,
        )

    private val READERS: Map<PlatformId, Map<String, Reader>> =
        mapOf(
            PlatformId("ps2") to playStation,
            PlatformId("psx") to playStation,
            PlatformId("gc") to nintendoDisc,
            PlatformId("wii") to nintendoDisc,
            PlatformId("nes") to cartridge(Rom.NES, "nes"),
            PlatformId("snes") to cartridge(Rom.SNES, "sfc", "smc"),
            PlatformId("n64") to cartridge(Rom.N64, "z64", "v64", "n64"),
            PlatformId("gb") to cartridge(Rom.WHOLE, "gb"),
            PlatformId("gbc") to cartridge(Rom.WHOLE, "gbc", "gb"),
            PlatformId("gba") to cartridge(Rom.WHOLE, "gba"),
        )

    private fun cartridge(rom: Rom, vararg extensions: String): Map<String, Reader> =
        extensions.associateWith<String, Reader> { { source -> cartridgePrint(rom, source) } } +
            ("zip" to Raise<ReadFailure>::zipEntryPrint)
}

private fun Raise<ReadFailure>.chdSerial(source: ByteSource): Option<FileFacts> =
    chdImage(source).flatMap { chd -> Iso9660.bootSerial { n -> with(chd) { sector(n) } } }

private fun Raise<ReadFailure>.isoSerial(source: ByteSource): Option<FileFacts> =
    Iso9660.bootSerial { n -> bytes(source, n * SECTOR.toLong(), SECTOR) }

/** A `.bin` image writes raw sectors, each telling its mode. */
private fun Raise<ReadFailure>.binSerial(source: ByteSource): Option<FileFacts> =
    Iso9660.bootSerial { n -> bytes(source, n * RAW_SECTOR.toLong(), RAW_SECTOR).flatMap { Layout.RAW.data(it, 0) } }

private val GAME_ID = Regex("[A-Z0-9]{6}")

/** The game code of the six-character disc ID at [at]. */
private fun Raise<ReadFailure>.gameCode(source: ByteSource, at: Long): Option<FileFacts> =
    bytes(source, at, 6).map { it.text(0, 6) }.filter(GAME_ID::matches).map { FileFacts.Serial(it.take(4)) }

private fun Raise<ReadFailure>.discGameCode(source: ByteSource): Option<FileFacts> = gameCode(source, 0)

/** RVZ and WIA files keep the disc's header after their own 0x58 bytes. */
private fun Raise<ReadFailure>.compressedGameCode(source: ByteSource): Option<FileFacts> =
    bytes(source, 0, 4).filter { it.text(0, 4) in setOf("RVZ\u0001", "WIA\u0001") }.flatMap { gameCode(source, 0x58) }
