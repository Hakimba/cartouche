// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class LibraryTest {
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
    fun `INV-E1-06 a rescan keeps the choices made for games still there, and only touches its platform`() = runBlocking<Unit> {
        var keptLaterDiscs = 0
        // A game of two discs in both scans, some files kept and others new.
        val story = listOf(listed("0 Story (Japan) (Disc 1).chd", id = "d1"), listed("0 Story (Japan) (Disc 2).chd", id = "d2"))
        checkAll(folderFiles, folderFiles, setups, Arb.int(0..3)) { files, added, setup, lastDisc ->
            val before = story + files
            val after = story + files.filterIndexed { i, _ -> i % 2 == 0 } + added.map { it.copy(uri = uri(it.uri.value + "-new")) }
            val other = game("X", platform = "gba", discs = nonEmptyListOf(Disc(None, listed("X.gba"))))
            val first = Scan.of(ps2, contents(before), ps2Titles, DiscGrouping.GROUPED)
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
            val second = Scan.of(ps2, contents(after), ps2Titles, DiscGrouping.GROUPED)
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
}
