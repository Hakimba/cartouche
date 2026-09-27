// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.random.Random

class ScanTest {
    private fun scan(vararg files: ListedFile, discs: DiscGrouping = DiscGrouping.GROUPED) =
        Scan.of(ps2, contents(files.toList()), ps2Titles, discs)

    @Test
    fun `games get their reference title, regions and serials`() {
        val game = scan(listed("Punisher, The (Europe) (En,Fr).chd")).games.single()
        game.title shouldBe "The Punisher"
        game.regions shouldBe listOf("Europe")
        game.serials shouldBe listOf("SLES-53047")
        game.redumpName shouldBe Some("Punisher, The (Europe) (En,Fr)")
    }

    @Test
    fun `unknown games keep their file name's title`() {
        val game = scan(listed("Homebrew Racer (World) (v0.3).iso")).games.single()
        game.title shouldBe "Homebrew Racer"
        game.redumpName shouldBe None
        game.version shouldBe Some("v0.3")
    }

    @Test
    fun `discs of one game make one game, unless grouping is off`() {
        val discs = arrayOf(listed("0 Story (Japan) (Disc 2).chd"), listed("0 Story (Japan) (Disc 1).chd"))
        val game = scan(*discs).games.single()
        game.discs.map { it.number } shouldBe listOf(Some(1), Some(2))
        game.serials shouldBe listOf("SLPM-65002", "SLPM-65003")
        scan(*discs, discs = DiscGrouping.SEPARATE).games.size shouldBe 2
    }

    @Test
    fun `copies and other formats of a game stay separate games`() {
        val copy = listed("Dark Cloud (Europe).chd", id = "backup")
        scan(listed("Dark Cloud (Europe).chd"), copy).games.map { it.discs.size } shouldBe listOf(1, 1)
        scan(listed("Dark Cloud (Europe).chd"), listed("Dark Cloud (Europe).iso")).games.size shouldBe 2
        scan(listed("0 Story (Japan) (Disc 1).chd"), listed("0 Story (Japan) (Disc 1).iso")).games.size shouldBe 2
    }

    @Test
    fun `files that are not games are set aside with a reason`() {
        scan(
            listed("._Game.chd"),
            listed("armsx2-settings.json"),
            listed("scph39001.bin"),
            listed("SCPH-70012_BIOS_V12_USA_200.BIN", size = Some(4_194_304)),
            listed("ps2_bios.bin", size = Some(4_194_304)),
            listed("Tiny Unknown (World).iso", size = Some(20_000)),
            listed("Garouden - Breakblow (Japan).chd", size = Some(20_000)),
        ).let { scan ->
            scan.ignored.map { it.file.name.value to it.reason } shouldBe
                listOf(
                    "._Game.chd" to IgnoreReason.HIDDEN,
                    "SCPH-70012_BIOS_V12_USA_200.BIN" to IgnoreReason.NOT_A_GAME,
                    "Tiny Unknown (World).iso" to IgnoreReason.NOT_A_GAME,
                    "armsx2-settings.json" to IgnoreReason.UNSUPPORTED,
                    "ps2_bios.bin" to IgnoreReason.NOT_A_GAME,
                    "scph39001.bin" to IgnoreReason.NOT_A_GAME,
                )
            // A known game is kept whatever its size: a truncated copy is still that game.
            scan.games.map { it.title } shouldBe listOf("Garouden - Breakblow")
        }
        // Known games are kept even when their title names a SCPH accessory.
        scan(listed("One Piece - Pirates Carnival (Japan) (Multi Tap (SCPH-10090) Doukonban).chd")).games.single().let {
            it.title shouldBe "One Piece - Pirates Carnival"
            it.redumpName.shouldBeSome()
        }
    }

    @Test
    fun `INV-E1-04 a game shows what its file name states, and names a reference disc only when it is exactly that disc`() =
        runBlocking<Unit> {
            val names = Shipped.ps2Names
            // Reference names as they are, or reduced to their title with one tag of another kind.
            val fileNames =
                Arb.choice(
                    Arb.element(names),
                    Arb.bind(Arb.element(names), Arb.element("", " (Beta)", " (v9.99)", " (En)", " (Korea)")) { name, tag ->
                        name.substringBefore(" (") + tag
                    },
                )
            checkAll(fileNames) { fileName ->
                val stated = GameName.parse(fileName)
                Scan.of(ps2, contents(listOf(listed("$fileName.iso"))), ps2Titles, DiscGrouping.GROUPED).games.forEach { game ->
                    listOf(game.regions, game.languages, game.version) shouldBe listOf(stated.regions, stated.languages, stated.version)
                    game.redumpName.onSome { reference ->
                        GameName.parse(reference).let { listOf(it.regions, it.languages, it.version, it.otherTags) } shouldBe
                            listOf(stated.regions, stated.languages, stated.version, stated.otherTags)
                    }
                }
            }
        }

    @Test
    fun `INV-E1-01 every file ends up in exactly one game or among the ignored files`() = runBlocking<Unit> {
        checkAll(folderFiles) { files ->
            val scan = Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED)
            (scan.games.flatMap { game -> game.discs.map { it.file } } + scan.ignored.map { it.file }) shouldContainExactlyInAnyOrder files
        }
    }

    @Test
    fun `INV-E1-02 a scan does not depend on the order the folder lists its files and sub-folders in`() = runBlocking<Unit> {
        checkAll(folderFiles, skippedFolders, Arb.enum<DiscGrouping>(), Arb.long()) { files, skipped, grouping, seed ->
            val random = Random(seed)
            Scan.of(ps2, FolderContents(files.shuffled(random), skipped.shuffled(random)), ps2Titles, grouping) shouldBe
                Scan.of(ps2, FolderContents(files, skipped), ps2Titles, grouping)
        }
    }

    @Test
    fun `INV-E1-07 only files a player of the platform accepts become games, never hidden files or a BIOS`() = runBlocking<Unit> {
        val bios = listOf("SCPH-70012_BIOS_V12_USA_200.BIN", "scph39001.bin", "ps2_bios.bin", "PS2 Bios 30004R V6 Pal.bin", "bios.bin")
        // Game-sized or of unknown size: only their name tells they are not games.
        val files = bios.flatMap { listOf(listed(it, id = "$it-sized"), listed(it, id = "$it-unsized", size = None)) }
        scan(*files.toTypedArray()).ignored.map { it.reason }.toSet() shouldBe setOf(IgnoreReason.NOT_A_GAME)
        checkAll(folderFiles) { files ->
            Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED).games.flatMap { it.discs }.forEach { disc ->
                ps2.players.any { it.accepts.matches(disc.file.name) } shouldBe true
                disc.file.name.isHidden shouldBe false
            }
        }
    }
}
