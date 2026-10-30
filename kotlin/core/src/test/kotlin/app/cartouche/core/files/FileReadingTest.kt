// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.files

import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.withClue
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.byte
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.flatMap
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class FileReadingTest {
    /** [source] read as a file of [platform] named `game.<extension>`; [fixture] holds its bytes when it is a fixture, damaged or not. */
    private data class Reading(
        val platform: PlatformId,
        val extension: String,
        val source: InMemoryBytes,
        val fixture: Option<ByteArray> = None,
    )

    @Test
    fun `a PlayStation disc in any image format gives the serial SYSTEM CNF boots, compared on its letters and digits`() {
        (READABLE_CHDS + "disc.iso" + "disc.bin").forEach { name ->
            listOf("ps2", "psx").forEach { platform ->
                withClue("$platform $name") {
                    facts(platform, "Game.${name.substringAfterLast('.').uppercase()}", image(name)) shouldBe
                        FileFacts.Serial(FIXTURE_SERIAL)
                }
            }
        }
        FileFacts.Serial(FIXTURE_SERIAL).key shouldBe "SLES52495"
    }

    @Test
    fun `a CHD in a codec not decoded, or a file of another extension or platform, gives nothing`() {
        facts("ps2", "game.chd", image("cd-cdfl.chd")) shouldBe FileFacts.Silent
        facts("ps2", "game.cso", disc) shouldBe FileFacts.Silent
        facts("ps2", "game", disc) shouldBe FileFacts.Silent
        facts("xbox", "game.iso", disc) shouldBe FileFacts.Silent
    }

    @Test
    fun `a file the port cannot read is a failure, not a file that says nothing`() {
        val failure = ReadFailure("not readable")
        listOf(Triple("ps2", "game.iso", disc), Triple("ps2", "game.chd", image("cd-cdlz.chd")), Triple("gba", "game.gba", ByteArray(4096)))
            .forEach { (platform, name, bytes) ->
                FileReading.facts(PlatformId(platform), FileName(name), InMemoryBytes(bytes, readable = false)) shouldBeLeft failure
            }
        // Nothing is asked of a file whose name says it is not read.
        FileReading.facts(PlatformId("ps2"), FileName("game.cso"), InMemoryBytes(disc, readable = false)) shouldBeRight FileFacts.Silent
    }

    @Test
    fun `a GameCube or Wii disc gives the game code of its ID, from the image or from an RVZ or WIA file`() {
        val id = "GKYP01".toByteArray()
        val rvz = "RVZ\u0001".toByteArray(Charsets.ISO_8859_1) + ByteArray(0x58 - 4) + "RMCP01".toByteArray() + ByteArray(1000)
        facts("gc", "game.iso", id + ByteArray(1000)) shouldBe FileFacts.Serial("GKYP")
        facts("gc", "game.gcm", id + ByteArray(1000)) shouldBe FileFacts.Serial("GKYP")
        facts("wii", "game.rvz", rvz) shouldBe FileFacts.Serial("RMCP")
        facts("wii", "game.wia", "WIA".toByteArray() + rvz.copyOfRange(3, rvz.size)) shouldBe FileFacts.Serial("RMCP")
        facts("gc", "game.rvz", "RVZ\u0002".toByteArray(Charsets.ISO_8859_1) + rvz.copyOfRange(4, rvz.size)) shouldBe FileFacts.Silent
        facts("gc", "game.iso", disc) shouldBe FileFacts.Silent
        facts("ps2", "game.iso", id + ByteArray(1000)) shouldBe FileFacts.Silent
    }

    @Test
    fun `a file it does not look into is never read`() = runBlocking<Unit> {
        var skipped = 0
        checkAll(500, readPlatforms, readExtensions, bytes()) { platform, extension, bytes ->
            val source = InMemoryBytes(bytes)
            val name = FileName("game.$extension")
            FileReading.facts(platform, name, source)
            if (!FileReading.reads(platform, name)) {
                skipped++
                source.requests shouldBe emptyList()
            }
        }
        skipped shouldBeGreaterThan 100
        FileReading.reads(PlatformId("ps2"), FileName("Game.CHD")) shouldBe true
        FileReading.reads(PlatformId("ps2"), FileName("Game.cso")) shouldBe false
    }

    @Test
    fun `INV-03 reading never fails, never asks for bytes outside the file, and has no way to write`() = runBlocking<Unit> {
        val fixtures =
            (READABLE_CHDS + "dvd-runs.chd" + "cd-cdfl.chd" + "disc.iso" + "disc-crowded.iso" + "disc.bin").associateWith(
                ::image,
            )
        // A fixture read as what it is, damaged in a few places or cut short, mostly kept whole; a CHD claiming anything; or
        // any bytes read as anything.
        val damaged =
            Arb.element(fixtures.keys.toList()).flatMap { name ->
                val whole = fixtures.getValue(name)
                Arb.bind(
                    Arb.element("ps2", "psx"),
                    Arb.list(Arb.bind(Arb.int(whole.indices), Arb.byte(), ::Pair), 0..8),
                    Arb.choice(Arb.constant(whole.size), Arb.constant(whole.size), Arb.int(0..whole.size)),
                ) { platform, changes, cut ->
                    val bytes = whole.copyOf(cut)
                    changes.forEach { (at, value) -> if (at < cut) bytes[at] = value }
                    Reading(PlatformId(platform), name.substringAfterLast('.'), InMemoryBytes(bytes), Some(bytes))
                }
            }
        val hostile =
            Arb.bind(
                Arb.element("ps2", "psx"),
                hostileChds,
            ) { platform, chd -> Reading(PlatformId(platform), "chd", InMemoryBytes(chd.bytes, size = chd.size)) }
        val any =
            Arb.bind(
                readPlatforms,
                readExtensions,
                bytes(),
            ) { platform, extension, bytes -> Reading(platform, extension, InMemoryBytes(bytes)) }
        var decoded = 0
        var damagedHunks = 0
        checkAll(2000, Arb.choice(damaged, damaged, hostile, any)) { (platform, extension, source, fixture) ->
            FileReading.facts(platform, FileName("game.$extension"), source).shouldBeRight()
            if (source.requests.size > 1) decoded++
            fixture.onSome { bytes -> if (extension == "chd" && chdOf(bytes).isSome { it.sectorOf(16).isSome() }) damagedHunks++ }
            source.withinFile shouldBe true
        }
        // Enough damaged images went past their header into the decoders, and enough CHDs as far as a hunk.
        decoded shouldBeGreaterThan 600
        damagedHunks shouldBeGreaterThan 100
    }
}
