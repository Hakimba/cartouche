// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.PixelRect
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.Shell
import app.cartouche.core.files.facts
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.list
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

    /** A scan of [files], each holding what it is paired with. */
    private fun read(vararg files: Pair<ListedFile, FileFacts>) =
        Scan.of(ps2, contents(files.map { it.first }), ps2Titles, DiscGrouping.GROUPED, files.associate { it.first.uri to it.second })

    @Test
    fun `a game keeps the shell its first file's header says`() {
        Shell.entries.forEach { shell ->
            val file = listed("Rayman.gbc", size = Some(1_000_000))
            val scan =
                Scan.of(
                    gbc,
                    contents(listOf(file)),
                    TitleIndex.EMPTY,
                    DiscGrouping.GROUPED,
                    mapOf(
                        file.uri to FileFacts.Print(1u, shell),
                    ),
                )
            scan.games.single().shell shouldBe shell
        }
        Scan
            .of(
                gbc,
                contents(listOf(listed("Rayman.gbc", size = Some(1_000_000)))),
                TitleIndex.EMPTY,
                DiscGrouping.GROUPED,
            ).games
            .single()
            .shell shouldBe
            Shell.UNKNOWN
    }

    private val gbc = Shipped.catalog.platforms.single { it.id == PlatformId("gbc") }

    /** The rectangle cut from a 663 by 755 scan for a game of [gbc] whose only file, a ROM with [flag] in its header, is read as the app reads it. */
    private fun cutFromRom(flag: Int): PixelRect {
        val rom = ByteArray(32768).also { it[0x143] = flag.toByte() }
        val file = listed("Rayman.gbc", size = Some(rom.size.toLong()))
        val game =
            Scan
                .of(
                    gbc,
                    contents(listOf(file)),
                    TitleIndex.EMPTY,
                    DiscGrouping.GROUPED,
                    mapOf(file.uri to facts("gbc", "Rayman.gbc", rom)),
                ).games
                .single()
        return ArtSources.of(Shipped.catalog, emptyMap(), emptyMap(), gbc.id).cutOf(game).on(663, 755).shouldBeSome()
    }

    @Test
    fun `a Game Boy Color ROM's colour flag reaches the cut of its label, the exclusives' lower, any other today's`() {
        cutFromRom(0xC0) shouldBe PixelRect(82, 254, 499, 436)
        listOf(0x80, 0x00, 0xC1).forEach { cutFromRom(it) shouldBe PixelRect(82, 215, 499, 436) }
    }

    @Test
    fun `the first disc's shell is taken, however the files sort by name and by address`() {
        // By name disc 1's file comes first, by address disc 2's.
        val disc1 = listed("Rayman (Disc 1).gbc", id = "b", size = Some(1_000_000))
        val disc2 = listed("Rayman (Disc 2).gbc", id = "a", size = Some(1_000_000))
        val told = mapOf(disc1.uri to FileFacts.Print(1u, Shell.EXCLUSIVE), disc2.uri to FileFacts.Print(2u, Shell.COMPATIBLE))
        Scan.of(gbc, contents(listOf(disc2, disc1)), TitleIndex.EMPTY, DiscGrouping.GROUPED, told).games.single().shell shouldBe
            Shell.EXCLUSIVE
        val swapped = mapOf(disc1.uri to FileFacts.Print(1u, Shell.COMPATIBLE), disc2.uri to FileFacts.Print(2u, Shell.EXCLUSIVE))
        Scan.of(gbc, contents(listOf(disc2, disc1)), TitleIndex.EMPTY, DiscGrouping.GROUPED, swapped).games.single().shell shouldBe
            Shell.COMPATIBLE
    }

    @Test
    fun `a label cut while the shell was unknown is cut again once it is known, and only then`() {
        val file = listed("Rayman.gbc", size = Some(1_000_000))
        val game = { shell: Shell, label: LabelChoice ->
            Scan
                .of(
                    gbc,
                    contents(listOf(file)),
                    TitleIndex.EMPTY,
                    DiscGrouping.GROUPED,
                    mapOf(file.uri to FileFacts.Print(1u, shell)),
                ).games
                .single()
                .copy(label = label)
        }
        val sources = ArtSources.of(Shipped.catalog, emptyMap(), emptyMap(), gbc.id)
        val recut = { before: Game, after: Game -> ArtSources.recut(listOf(before), listOf(after)) { sources } }
        val unknown = game(Shell.UNKNOWN, LabelChoice.Automatic)
        recut(unknown, game(Shell.EXCLUSIVE, LabelChoice.Automatic)) shouldBe setOf(unknown.id)
        recut(unknown, game(Shell.COMPATIBLE, LabelChoice.Automatic)) shouldBe emptySet()
        recut(unknown, game(Shell.UNKNOWN, LabelChoice.Automatic)) shouldBe emptySet()
        recut(game(Shell.EXCLUSIVE, LabelChoice.Automatic), game(Shell.EXCLUSIVE, LabelChoice.Automatic)) shouldBe emptySet()
        recut(unknown, game(Shell.EXCLUSIVE, LabelChoice.Own)) shouldBe emptySet()
        ArtSources.recut(emptyList(), listOf(game(Shell.EXCLUSIVE, LabelChoice.Automatic))) { sources } shouldBe emptySet()
    }

    @Test
    fun `a stored game keeps its shell, and one stored without it has none`() {
        val file = listed("Rayman.gbc", size = Some(1_000_000))
        val told = mapOf(file.uri to FileFacts.Print(1u, Shell.EXCLUSIVE))
        val exclusive = Scan.of(gbc, contents(listOf(file)), TitleIndex.EMPTY, DiscGrouping.GROUPED, told).games.single()
        val library = Library(games = listOf(exclusive))
        val stored = LibraryFormat.encode(library)
        stored.contains("\"shell\":\"exclusive\"") shouldBe true
        LibraryFormat.decode(stored).shouldBeRight().library.games.single().shell shouldBe Shell.EXCLUSIVE
        val without = LibraryFormat.encode(Library(games = listOf(exclusive.copy(shell = Shell.UNKNOWN))))
        without.contains("shell") shouldBe false
        LibraryFormat.decode(without).shouldBeRight().library.games.single().shell shouldBe Shell.UNKNOWN
    }

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
    fun `INV-10 a game shows what its file name states, and names a reference disc only when it is exactly that disc`() =
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
    fun `INV-03 a file that tells nothing, or nothing the list knows, is identified by its name as before`() = runBlocking<Unit> {
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
    fun `INV-08 every file ends up in exactly one game or among the ignored files`() = runBlocking<Unit> {
        checkAll(folderFiles) { files ->
            val scan = Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED)
            (scan.games.flatMap { game -> game.discs.map { it.file } } + scan.ignored.map { it.file }) shouldContainExactlyInAnyOrder files
        }
    }

    @Test
    fun `INV-08 a scan does not depend on the order the folder lists its files and sub-folders in`() = runBlocking<Unit> {
        checkAll(folderFiles, skippedFolders, Arb.enum<DiscGrouping>(), Arb.long()) { files, skipped, grouping, seed ->
            val random = Random(seed)
            Scan.of(ps2, FolderContents(files.shuffled(random), skipped.shuffled(random)), ps2Titles, grouping) shouldBe
                Scan.of(ps2, FolderContents(files, skipped), ps2Titles, grouping)
        }
    }

    @Test
    fun `only files a player of the platform accepts become games, never hidden files or a BIOS`() = runBlocking<Unit> {
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
