// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.random.Random

class LibraryTest {
    @Test
    fun `an unknown or foreign variant is a typed error`() = runBlocking<Unit> {
        checkAll(Arb.int(0..100000)) { suffix ->
            val library = Library().withSetup(ps2.id, PlatformSetup())
            library.withVariant(ps2.id, "unknown-$suffix").shouldBeLeft(VariantError.Unknown(ps2.id, "unknown-$suffix"))
            library.withVariant(ps2.id, "gba_sp").shouldBeLeft(VariantError.Unknown(ps2.id, "gba_sp"))
            Library().withVariant(ps2.id, "ps2_fat").shouldBeLeft(VariantError.NotInLibrary(ps2.id))
        }
    }

    @Test
    fun `INV-15 a chosen variant survives saving reading and rescanning without changing other choices`() = runBlocking<Unit> {
        checkAll(folderFiles, setups) { files, setup ->
            val other = PlatformId("gba")
            val library = Library().withSetup(ps2.id, setup).withSetup(other, setup).withScan(ps2.id, scan(files))
            val chosen = library.withVariant(ps2.id, "ps2_fat").shouldBeRight()
            chosen.variantOf(ps2.id) shouldBe Some(ConsoleVariant.PS2_FAT)
            chosen.copy(consoleVariants = emptyMap()) shouldBe library
            val restored = LibraryFormat.decode(LibraryFormat.encode(chosen)).shouldBeRight().library
            restored shouldBe chosen
            restored.withScan(ps2.id, scan(files)).variantOf(ps2.id) shouldBe Some(ConsoleVariant.PS2_FAT)
            restored.withSetup(ps2.id, setup).variantOf(ps2.id) shouldBe Some(ConsoleVariant.PS2_FAT)
            restored.without(ps2.id).consoleVariants shouldBe emptyMap()
            restored.without(ps2.id).variantOf(other) shouldBe Some(ConsoleVariant.GBA)
        }
    }

    @Test
    fun `a library stored without variants reads with the base`() = runBlocking<Unit> {
        checkAll(folderFiles, setups) { files, setup ->
            val library = Library().withSetup(ps2.id, setup).withScan(ps2.id, scan(files))
            val old = LibraryFormat.encode(library)
            old.contains("consoleVariants") shouldBe false
            val read = LibraryFormat.decode(old).shouldBeRight().library
            read shouldBe library
            read.variantOf(ps2.id) shouldBe Some(ConsoleVariant.PS2_SLIM)
        }
    }

    private fun scan(files: List<ListedFile>) = Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED)

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
    fun `INV-12 a rescan keeps the choices made for games still there, and only touches its platform`() = runBlocking<Unit> {
        var keptLaterDiscs = 0
        // A game of two discs in both scans, some files kept and others new.
        val story = listOf(listed("0 Story (Japan) (Disc 1).chd", id = "d1"), listed("0 Story (Japan) (Disc 2).chd", id = "d2"))
        checkAll(folderFiles, folderFiles, setups, Arb.int(0..3)) { files, added, setup, lastDisc ->
            val before = story + files
            val after = story + files.filterIndexed { i, _ -> i % 2 == 0 } + added.map { it.copy(uri = uri(it.uri.value + "-new")) }
            val other = game("X", platform = "gba", discs = nonEmptyListOf(Disc(None, listed("X.gba"))))
            val first = scan(before)
            val library =
                Library(
                    games = listOf(other),
                    notGames = mapOf(other.platform to listOf(listed("bios.gba"))),
                    ignoredCounts = mapOf(other.platform to mapOf(CountedReason.UNSUPPORTED to IgnoredCount(1, listOf(FileName("x.txt"))))),
                    skippedFolders = mapOf(other.platform to listOf(SkippedFolder(FolderPath(".x"), SkipReason.HIDDEN))),
                ).withSetup(ps2.id, setup)
                    .withSetup(other.platform, setup)
                    .withScan(ps2.id, first)
                    .let { lib -> lib.games.fold(lib) { acc, game -> acc.withLastDisc(game.id, lastDisc) } }
            val second = scan(after)
            val rescanned = library.withScan(ps2.id, second)
            val ps2Games = rescanned.games.filter { it.platform == ps2.id }
            ps2Games.map { it.id } shouldBe second.games.map { it.id }
            rescanned.setups shouldBe library.setups
            rescanned.game(other.id) shouldBe Some(other)
            listOf(rescanned.notGames, rescanned.ignoredCounts, rescanned.skippedFolders).map { it - ps2.id } shouldBe
                listOf(library.notGames, library.ignoredCounts, library.skippedFolders).map { it - ps2.id }
            val (notGames, counted) = second.ignored.partition { it.reason == IgnoreReason.NOT_A_GAME }
            rescanned.notGames[ps2.id] shouldBe notGames.map { it.file }
            rescanned.ignoredCounts[ps2.id].orEmpty().values.sumOf { it.count } shouldBe counted.size
            rescanned.skippedFolders[ps2.id] shouldBe second.skippedFolders
            ps2Games.forEach { game ->
                library.game(game.id).onSome { old ->
                    game.lastDisc shouldBe old.lastDisc.coerceAtMost(game.discs.lastIndex)
                    if (game.lastDisc > 0) keptLaterDiscs++
                }
            }
        }
        // Games of several discs reach the rescan with a later disc chosen.
        keptLaterDiscs shouldBeGreaterThan 500
    }

    @Test
    fun `choosing a game's label changes that game only, and nothing for a game not in the library`() {
        val library = Library(games = listOf(game("Okage"), game("Ico")))
        val chosen = LabelChoice.Region(LabelRegion("Japan"))
        library.withLabel(GameId("ps2/Okage"), chosen).games.map { it.label } shouldBe listOf(chosen, LabelChoice.Automatic)
        library.withLabel(GameId("ps2/Unknown"), chosen) shouldBe library
    }

    @Test
    fun `INV-15 a game's label choice stays through saving, reading back and rescans that keep its file, and goes with the game`() =
        runBlocking<Unit> {
            var kept = 0
            var gone = 0
            val japan = LabelChoice.Region(LabelRegion("Japan"))
            val other = game("X", platform = "gba", discs = nonEmptyListOf(Disc(None, listed("X.gba")))).copy(label = japan)
            checkAll(folderFiles, Arb.list(labelChoices, 0..20)) { files, labels ->
                val scanned = Library(games = listOf(other)).withScan(ps2.id, scan(files))
                val ps2Games = scanned.games.filter { it.platform == ps2.id }
                val chosen = ps2Games.zip(labels).fold(scanned) { library, (game, label) -> library.withLabel(game.id, label) }
                val stored = LibraryFormat.encode(chosen)
                LibraryFormat.decode(stored).shouldBeRight().library shouldBe chosen
                // Only chosen labels are stored.
                Regex("\"label\"").findAll(stored).count() shouldBe chosen.games.count { it.label != LabelChoice.Automatic }
                val rescanned = chosen.withScan(ps2.id, scan(files.filterIndexed { i, _ -> i % 2 == 0 }))
                rescanned.games.forEach { game ->
                    game.label shouldBe chosen.game(game.id).fold({ LabelChoice.Automatic }) { it.label }
                    if (game.platform == ps2.id && game.label != LabelChoice.Automatic) kept++
                }
                rescanned.game(other.id) shouldBe Some(other)
                // Games gone and back, or a platform removed and added again, start automatic.
                val back = rescanned.withScan(ps2.id, scan(files))
                back.games.filter { it.id !in rescanned.games.map(Game::id) }.forEach { game ->
                    game.label shouldBe LabelChoice.Automatic
                    gone++
                }
                chosen.without(ps2.id).withScan(ps2.id, scan(files)).games.filter { it.platform == ps2.id }.forEach {
                    it.label shouldBe LabelChoice.Automatic
                }
            }
            kept shouldBeGreaterThan 48
            gone shouldBeGreaterThan 100
        }

    @Test
    fun `INV-15 a game's name stays through saving and rescans that keep its file, goes with the game, changes only what is shown`() =
        runBlocking<Unit> {
            var kept = 0
            var gone = 0
            val other =
                game(
                    "X",
                    platform = "gba",
                    discs = nonEmptyListOf(Disc(None, listed("X.gba"))),
                ).copy(displayName = DisplayName.of("Mine"))
            checkAll(folderFiles, Arb.list(typedNames, 0..20)) { files, typed ->
                val scanned = Library(games = listOf(other)).withScan(ps2.id, scan(files))
                val ps2Games = scanned.games.filter { it.platform == ps2.id }
                val renamed =
                    ps2Games.zip(typed).fold(scanned) { library, (game, text) -> library.withDisplayName(game.id, DisplayName.of(text)) }
                LibraryFormat.decode(LibraryFormat.encode(renamed)).shouldBeRight().library shouldBe renamed
                renamed.games.forEach { game ->
                    // Only the name changes: the title, which identification and art look for, stays.
                    game shouldBe scanned.game(game.id).shouldBeSome().copy(displayName = game.displayName)
                    game.shownTitle shouldBe game.displayName.fold({ game.title }) { it.text }
                }
                val rescanned = renamed.withScan(ps2.id, scan(files.filterIndexed { i, _ -> i % 2 == 0 }))
                rescanned.games.forEach { game ->
                    game.displayName shouldBe renamed.game(game.id).shouldBeSome().displayName
                    if (game.platform == ps2.id && game.displayName.isSome()) kept++
                }
                rescanned.game(other.id) shouldBe Some(other)
                // Games gone and back start with their title again.
                rescanned.withScan(ps2.id, scan(files)).games.filter { it.id !in rescanned.games.map(Game::id) }.forEach { game ->
                    game.displayName shouldBe None
                    gone++
                }
            }
            kept shouldBeGreaterThan 100
            gone shouldBeGreaterThan 50
        }

    @Test
    fun `a name typed is kept on one line, trimmed and at most so long, and a blank one gives the title back`() = runBlocking<Unit> {
        checkAll(typedNames) { text ->
            DisplayName.of(text).fold({ text.isBlank() shouldBe true }) { name ->
                val single = text.replace(Regex("[\\s\\p{Z}\\p{Cc}]+"), " ").trim()
                // The text typed, its spaces single, cut only when longer than allowed.
                single.startsWith(name.text) shouldBe true
                (name.text.codePointCount(0, name.text.length) in 1..DisplayName.LONGEST) shouldBe true
                (name.text == single || single.codePointCount(0, single.length) > DisplayName.LONGEST) shouldBe true
                DisplayName.of(name.text) shouldBe Some(name)
            }
        }
    }

    @Test
    fun `a game given its own title as a name keeps no name`() {
        val okage = game("Okage")
        Library(games = listOf(okage)).withDisplayName(okage.id, DisplayName.of(" Okage ")).games.single().displayName shouldBe None
    }

    @Test
    fun `INV-11 old console names survive reading and rescans`() = runBlocking<Unit> {
        var named = 0
        checkAll(folderFiles, typedNames, typedNames) { files, ps2Name, gbaName ->
            val gba = PlatformId("gba")
            val names =
                DisplayName.of(ps2Name).fold({ emptyMap() }) { mapOf(ps2.id to it) } +
                    DisplayName.of(gbaName).fold({ emptyMap() }) { mapOf(gba to it) }
            val library = Library(consoleNames = names).withScan(ps2.id, scan(files))
            LibraryFormat.decode(LibraryFormat.encode(library)).shouldBeRight().library shouldBe library
            library.withScan(ps2.id, scan(files.drop(1))).consoleNames shouldBe names
            library.without(ps2.id).consoleNames shouldBe names - ps2.id
            val ordered = library.withConsoleOrder(listOf(gba, ps2.id))
            ordered.withScan(ps2.id, scan(files.drop(1))).consoleOrder shouldBe ordered.consoleOrder
            if (names.isNotEmpty()) named++
        }
        named shouldBeGreaterThan 60
    }

    @Test
    fun `INV-15 placing at gap g puts the console between the consoles at g-1 and g, keeps the others in order and is total`() =
        runBlocking<Unit> {
            var placed = 0
            checkAll(Arb.int(1..12), Arb.int(0..11), Arb.long()) { count, chosenAt, seed ->
                val all = (0 until count).map { PlatformId("p$it") }
                val random = Random(seed)
                val console = all[chosenAt % count]
                // Some consoles have games, the others are set up and empty; the console placed has games.
                val withGames = all.filter { it == console || random.nextBoolean() }.toSet()
                val ghost = PlatformId("ghost")
                // The catalog's order may repeat a platform; the stored order may hold repeats and a platform the catalog lacks.
                val catalogOrder = (all + all.filter { random.nextBoolean() } + ghost).shuffled(random)
                val known = (all + all.filter { random.nextBoolean() } + ghost).filter { random.nextBoolean() }.shuffled(random)
                val library =
                    all.fold(Library().withConsoleOrder(known)) { lib, id ->
                        val setUp = lib.withSetup(id, PlatformSetup())
                        if (id in withGames) setUp.copy(games = setUp.games + game("g", platform = id.value)) else setUp
                    }

                // Written from the rule, not from `shown`: the stored order first, then the catalog's, those with games.
                fun shownBy(order: List<PlatformId>): List<PlatformId> =
                    (order.filter { it in catalogOrder && it in withGames } + catalogOrder.filter { it in withGames }).distinct()
                val before = shownBy(known) - console
                (0..before.size).forEach { gap ->
                    val saved = library.withConsoleAt(console, gap, catalogOrder).shouldBeRight()
                    val expected = before.take(gap) + console + before.drop(gap)
                    saved.shown(catalogOrder) shouldBe expected
                    // The order is saved whole, and the positions stored for consoles hidden or without games stay, after it.
                    saved.consoleOrder.take(expected.size) shouldBe expected
                    saved.consoleOrder.drop(expected.size) shouldBe known.distinct().filter { it !in expected }
                    placed++
                }
                library.withConsoleAt(console, -1, catalogOrder) shouldBeLeft PlacementError.GapOutOfRange(-1, before.size)
                library.withConsoleAt(console, before.size + 1, catalogOrder) shouldBeLeft
                    PlacementError.GapOutOfRange(before.size + 1, before.size)
                all.filter { it !in withGames }.forEach {
                    library.withConsoleAt(it, 0, catalogOrder) shouldBeLeft PlacementError.NotInLibrary(it)
                }
                val unset = PlatformId("unset")
                library
                    .copy(
                        games = library.games + game("g", platform = "unset"),
                    ).withConsoleAt(unset, 0, catalogOrder + unset) shouldBeLeft
                    PlacementError.NotInLibrary(unset)
                library.withConsoleAt(console, 0, catalogOrder.filter { it != console }) shouldBeLeft PlacementError.NotInLibrary(console)
                library.withConsoleAt(PlatformId("absent"), 0, catalogOrder) shouldBeLeft PlacementError.NotInLibrary(PlatformId("absent"))
            }
            placed shouldBeGreaterThan 229
        }
}
