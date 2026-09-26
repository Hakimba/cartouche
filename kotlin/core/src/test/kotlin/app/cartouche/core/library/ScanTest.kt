// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.Shipped
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.toOption
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.orNull
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ScanTest {
    private val ps2 = Shipped.catalog.platforms.single { it.id == PlatformId("ps2") }
    private val titles = TitleIndex.parse(Shipped.text("redump/ps2.tsv"))

    private fun scan(vararg files: ListedFile, discs: DiscGrouping = DiscGrouping.GROUPED) = Scan.of(ps2, files.toList(), titles, discs)

    @Test
    fun `games get their reference title, regions and serials`() {
        val game = scan(file("Punisher, The (Europe) (En,Fr).chd")).games.single()
        game.title shouldBe "The Punisher"
        game.regions shouldBe listOf("Europe")
        game.serials shouldBe listOf("SLES-53047")
        game.redumpName shouldBe Some("Punisher, The (Europe) (En,Fr)")
    }

    @Test
    fun `unknown games keep their file name's title`() {
        val game = scan(file("Homebrew Racer (World) (v0.3).iso")).games.single()
        game.title shouldBe "Homebrew Racer"
        game.redumpName shouldBe None
        game.version shouldBe Some("v0.3")
    }

    @Test
    fun `discs of one game make one game, unless grouping is off`() {
        val discs = arrayOf(file("0 Story (Japan) (Disc 2).chd"), file("0 Story (Japan) (Disc 1).chd"))
        val game = scan(*discs).games.single()
        game.discs.map { it.number } shouldBe listOf(Some(1), Some(2))
        game.serials shouldBe listOf("SLPM-65002", "SLPM-65003")
        scan(*discs, discs = DiscGrouping.SEPARATE).games.size shouldBe 2
    }

    @Test
    fun `copies and other formats of a game stay separate games`() {
        val copy = file("Dark Cloud (Europe).chd").copy(uri = ContentUri.parse("content://p/document/backup").shouldBeSome())
        scan(file("Dark Cloud (Europe).chd"), copy).games.map { it.discs.size } shouldBe listOf(1, 1)
        scan(file("Dark Cloud (Europe).chd"), file("Dark Cloud (Europe).iso")).games.size shouldBe 2
        scan(file("0 Story (Japan) (Disc 1).chd"), file("0 Story (Japan) (Disc 1).iso")).games.size shouldBe 2
    }

    @Test
    fun `files that are not games are set aside with a reason`() {
        scan(
            file("._Game.chd"),
            file("armsx2-settings.json"),
            file("scph39001.bin"),
            file("SCPH-70012_BIOS_V12_USA_200.BIN", size = 4_194_304),
            file("ps2_bios.bin", size = 4_194_304),
            file("Tiny Unknown (World).iso", size = 20_000),
            file("Garouden - Breakblow (Japan).chd", size = 20_000),
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
        scan(file("One Piece - Pirates Carnival (Japan) (Multi Tap (SCPH-10090) Doukonban).chd")).games.single().let {
            it.title shouldBe "One Piece - Pirates Carnival"
            it.redumpName.shouldBeSome()
        }
    }

    @Test
    fun `the chosen player opens games when installed, else the first installed one`() {
        val chd = FileName("Game.chd")
        val armsx2 = ps2.players.single { it.id.value == "ps2.com.armsx2" }
        val chosen = PlatformSetup(player = Some(armsx2.id))
        chosen.playerFor(ps2, chd) { true } shouldBe Some(armsx2)
        chosen.playerFor(ps2, chd) { it != armsx2 } shouldBe Some(ps2.players.first { it != armsx2 && it.accepts.matches(chd) })
        PlatformSetup().playerFor(ps2, chd) { false } shouldBe None
    }

    @Test
    fun `INV-E1-04 a game shows what its file name states, and names a reference disc only when it is exactly that disc`() =
        runBlocking<Unit> {
            val names = Shipped.text("redump/ps2.tsv").lines().filter { it.isNotBlank() }.map { it.substringBefore('\t') }
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
                Scan.of(ps2, listOf(file("$fileName.iso")), titles, DiscGrouping.GROUPED).games.forEach { game ->
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
        checkAll(folders) { files ->
            val scan = Scan.of(ps2, files, titles, DiscGrouping.GROUPED)
            (scan.games.flatMap { game -> game.discs.map { it.file } } + scan.ignored.map { it.file }) shouldContainExactlyInAnyOrder files
        }
    }

    @Test
    fun `INV-E1-02 a scan does not depend on the order files are listed in`() = runBlocking<Unit> {
        checkAll(folders, Arb.enum<DiscGrouping>()) { files, grouping ->
            Scan.of(ps2, files.shuffled(), titles, grouping) shouldBe Scan.of(ps2, files, titles, grouping)
        }
    }

    @Test
    fun `INV-E1-07 only files a player of the platform accepts become games, never hidden files or a BIOS`() = runBlocking<Unit> {
        checkAll(folders) { files ->
            Scan.of(ps2, files, titles, DiscGrouping.GROUPED).games.flatMap { it.discs }.forEach { disc ->
                val name = disc.file.name
                ps2.players.any { it.accepts.matches(name) } shouldBe true
                name.isHidden shouldBe false
                if (disc.file.name.value.contains(Regex("(?i)(?<![a-z0-9])(bios|scph-?\\d+)(?![a-z0-9])"))) {
                    Scan.of(ps2, listOf(disc.file), titles, DiscGrouping.GROUPED).games.single().redumpName.shouldBeSome()
                }
            }
        }
    }

    @Test
    fun `INV-E1-06 a rescan keeps the choices made for games still there, and only touches its platform`() = runBlocking<Unit> {
        checkAll(folders, folders, Arb.int(0..3)) { before, after, lastDisc ->
            val disc = Disc(None, file("X.gba"))
            val other =
                Game(GameId("gba/x"), PlatformId("gba"), "X", emptyList(), emptyList(), None, emptyList(), None, nonEmptyListOf(disc))
            val first = Scan.of(ps2, before, titles, DiscGrouping.GROUPED)
            val library =
                Library(games = listOf(other)).withScan(ps2.id, first).let { lib ->
                    lib.games.fold(lib) { acc, game -> acc.withLastDisc(game.id, lastDisc) }
                }
            val second = Scan.of(ps2, after, titles, DiscGrouping.GROUPED)
            val rescanned = library.withScan(ps2.id, second)
            val ps2Games = rescanned.games.filter { it.platform == ps2.id }
            ps2Games.map { it.id } shouldBe second.games.map { it.id }
            rescanned.game(other.id) shouldBe Some(other)
            ps2Games.forEach { game ->
                library.game(game.id).onSome { old -> game.lastDisc shouldBe old.lastDisc.coerceAtMost(game.discs.lastIndex) }
            }
        }
    }

    @Test
    fun `stored libraries of another version, or with invalid values, are reported`() {
        val stored = LibraryFormat.encode(Library().withSetup(ps2.id, PlatformSetup(ContentUri.parse("content://p/tree/x"))))
        LibraryFormat.decode(stored.replace("\"version\":1", "\"version\":2")).shouldBeLeft() shouldBe LibraryError.UnsupportedVersion(2)
        LibraryFormat.decode(stored.replace("content://p/tree/x", "file:///x")).shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
        LibraryFormat.decode("{").shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
    }

    @Test
    fun `a stored last disc past the game's discs reads back as the first disc`() {
        val library = Library().withScan(ps2.id, scan(file("0 Story (Japan) (Disc 1).chd"), file("0 Story (Japan) (Disc 2).chd")))
        val edited = LibraryFormat.encode(library.withLastDisc(library.games.single().id, 1)).replace("\"lastDisc\":1", "\"lastDisc\":9")
        LibraryFormat.decode(edited).shouldBeRight().games.single().lastDisc shouldBe 0
    }

    @Test
    fun `INV-E1-05 a stored library reads back identical`() = runBlocking<Unit> {
        checkAll(folders, Arb.enum<DiscGrouping>(), Arb.enum<FolderDepth>(), Arb.string()) { files, grouping, depth, folderName ->
            val setup = PlatformSetup(ContentUri.parse("content://p/tree/$folderName"), None, grouping, depth)
            val library = Library().withSetup(ps2.id, setup).withScan(ps2.id, Scan.of(ps2, files, titles, grouping))
            LibraryFormat.decode(LibraryFormat.encode(library)).shouldBeRight() shouldBe library
        }
    }

    private companion object {
        private val titleWords =
            Arb.element(
                "0 Story",
                "Punisher, The",
                "Dragon Quest V",
                "Bleach - Blade Battlers",
                "Homebrew",
                "Dr. Muto",
            )
        private val tags = Arb.list(Arb.element("(Japan)", "(Europe)", "(EU)", "(En,Fr)", "(Disc 1)", "(Disc 2)", "(v1.1)", "(Beta)"), 0..3)
        private val extensions = Arb.element(".chd", ".iso", ".cso", ".bin", ".json", ".txt", "")
        private val names: Arb<String> =
            Arb.choice(
                Arb.bind(Arb.element("", "", "", "._", "."), titleWords, tags, extensions) { hidden, title, t, ext ->
                    "$hidden$title ${t.joinToString(" ")}".trim() + ext
                },
                Arb.element("scph39001.bin", "bios.bin", "ps2_bios.bin", "SCPH-70012_BIOS_V12_USA_200.BIN", "armsx2-settings.json"),
                Arb.string(1..20).map { it.replace('/', '_') },
            )

        /** Folders with realistic names, many discs of the same games, sizes known or not. */
        val folders: Arb<List<ListedFile>> =
            Arb.list(Arb.bind(names, Arb.long(0L..2_000_000_000L).orNull(0.2)) { name, size -> name to size }, 0..12).map { entries ->
                // Distinct documents; names may repeat (copies in sub-folders, other formats).
                entries.mapIndexed {
                    i,
                    (name, size),
                    ->
                    file(name, size).copy(uri = ContentUri.parse("content://p/document/$i").shouldBeSome())
                }
            }

        fun file(name: String, size: Long? = 1_000_000_000L) =
            ListedFile(FileName(name), ContentUri.parse("content://p/document/$name").shouldBeSome(), None, size.toOption())
    }
}
