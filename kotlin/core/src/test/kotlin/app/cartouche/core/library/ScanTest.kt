// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.files.FileFacts
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
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

    /** A scan of [files], each holding what it is paired with. */
    private fun read(vararg files: Pair<ListedFile, FileFacts>) =
        Scan.of(ps2, contents(files.map { it.first }), ps2Titles, DiscGrouping.GROUPED, files.associate { it.first.uri to it.second })

    @Test
    fun `a file holding a known disc is that disc whatever its name, with that disc's regions, languages and version`() {
        // Small: kept for a game since what it holds is one.
        val game = read(listed("unknown game 1.chd", size = Some(20_000)) to FileFacts.Serial("SLES_524.95")).games.single()
        listOf(game.title, game.regions, game.languages, game.version, game.serials, game.redumpName) shouldBe
            listOf(
                "Bujingai - Swordmaster",
                listOf("Europe"),
                listOf("En", "Fr", "De", "Es", "It"),
                None,
                listOf("SLES-52495"),
                Some("Bujingai - Swordmaster (Europe) (En,Fr,De,Es,It)"),
            )
    }

    @Test
    fun `a game known by its content without its version takes the countries its versions share`() {
        val game = read(listed("Avatar.chd") to FileFacts.Serial("SLES_541.88")).games.single()
        listOf(game.title, game.regions, game.serials, game.redumpName) shouldBe
            listOf("Nickelodeon Avatar - The Legend of Aang", listOf("Europe"), listOf("SLES-54188"), None)
    }

    @Test
    fun `each disc gives its own serials by what it holds, a disc 2 that tells nothing none`() {
        val one = listed("0 Story (Japan) (Disc 1).chd")
        val two = listed("0 Story (Japan) (Disc 2).chd")
        read(one to FileFacts.Serial("SLPM_650.02"), two to FileFacts.Silent).games.single().serials shouldBe listOf("SLPM-65002")
        read(one to FileFacts.Serial("SLPM_650.02"), two to FileFacts.Serial("SLPM_650.03")).games.single().serials shouldBe
            listOf("SLPM-65002", "SLPM-65003")
        // The first disc telling nothing, both discs are found by their names.
        read(one to FileFacts.Silent, two to FileFacts.Silent).games.single().serials shouldBe listOf("SLPM-65002", "SLPM-65003")
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
                    Arb.bind(Arb.element(names), Arb.element("", " (Beta)", " (v9.99)", " (En)", " (Korea)", " (Disc 2)")) { name, tag ->
                        name.substringBefore(" (") + tag
                    },
                )
            checkAll(fileNames) { fileName ->
                val stated = GameName.parse(fileName)
                Scan.of(ps2, contents(listOf(listed("$fileName.iso"))), ps2Titles, DiscGrouping.GROUPED).games.forEach { game ->
                    listOf(game.regions, game.languages, game.version) shouldBe listOf(stated.regions, stated.languages, stated.version)
                    game.redumpName.onSome { reference ->
                        GameName.parse(reference).let { listOf(it.regions, it.languages, it.version, it.disc, it.otherTags) } shouldBe
                            listOf(stated.regions, stated.languages, stated.version, stated.disc, stated.otherTags)
                    }
                }
            }
        }

    @Test
    fun `INV-E11-01 a file whose content names one game is given that game, whatever its name says`() = runBlocking<Unit> {
        // Each entry's serials, and the list's serials as discs write them (`SLES_524.95`) with the entries having each: read
        // from the list, not the index.
        val serialsOf =
            Shipped.text("titles/ps2.tsv").lines().filter(String::isNotBlank).associate { line ->
                line.substringBefore('\t') to line.substringAfter('\t').split(',').filter(String::isNotBlank)
            }
        val oneGame =
            serialsOf.entries
                .flatMap { (name, serials) -> serials.map { it.replace('-', '_') to name } }
                .groupBy { FileFacts.Serial(it.first).key }
                .values
                .map { pairs -> pairs.first().first to pairs.map { it.second }.distinct() }
                .filter { (_, names) -> names.map { GameName.parse(it).displayTitle }.distinct().size == 1 }
        val fileNames = Arb.choice(Arb.element(Shipped.ps2Names), Arb.string(1..20, Codepoint.alphanumeric()))
        var shared = 0
        // As often a serial several versions share.
        val serials = Arb.choice(Arb.element(oneGame), Arb.element(oneGame.filter { it.second.size > 1 }))
        checkAll(serials, fileNames) { (serial, names), fileName ->
            val game = read(listed("$fileName.iso") to FileFacts.Serial(serial)).games.single()
            game.title shouldBe GameName.parse(names.first()).displayTitle
            val versions = names.map { serialsOf.getValue(it).toSet() }
            when {
                names.size == 1 -> game.redumpName shouldBe Some(names.single())
                // A name of no tag tells no version apart: the game keeps the serials all its versions share.
                fileName !in serialsOf -> game.serials.toSet() shouldBe versions.reduce(Set<String>::intersect).also { shared++ }
                else -> (game.serials.toSet() in versions + setOf(versions.reduce(Set<String>::intersect))) shouldBe true
            }
        }
        shared shouldBeGreaterThan 100
    }

    @Test
    fun `INV-E11-03 a file that tells nothing, or nothing the list knows, is identified by its name as before`() = runBlocking<Unit> {
        // Crazy Taxi and an Xploder disc share SLES-50215: a serial naming two games names none.
        val untold =
            Arb.element(FileFacts.Silent, FileFacts.Serial("XXXX_999.99"), FileFacts.Print(0x03048DE6u), FileFacts.Serial("SLES_502.15"))
        checkAll(folderFiles, Arb.list(untold, 12..12)) { files, facts ->
            val read = files.zip(facts) { file, told -> file.uri to told }.toMap()
            Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED, read) shouldBe
                Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED)
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
