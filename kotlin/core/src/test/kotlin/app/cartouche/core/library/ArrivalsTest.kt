// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ArrivalsTest {
    private val gba = PlatformId("gba")
    private val other = game("X", platform = "gba", discs = nonEmptyListOf(Disc(None, listed("X.gba"))))

    private fun scan(files: List<ListedFile>) = Scan.of(ps2, contents(files), ps2Titles, DiscGrouping.GROUPED)

    private fun library(files: List<ListedFile>) =
        Library(setups = mapOf(ps2.id to PlatformSetup()), games = listOf(other)).withScan(ps2.id, scan(files))

    /** A folder re-read: some of its files kept, others gone, others new. */
    private fun reread(files: List<ListedFile>, added: List<ListedFile>) =
        files.filterIndexed { i, _ -> i % 2 == 0 } + added.map { it.copy(uri = uri(it.uri.value + "-new")) }

    @Test
    fun `INV-25 a re-read marks as new exactly the games it brought, keeps the marks of games still there, drops the others`() =
        runBlocking<Unit> {
            var marked = 0
            checkAll(folderFiles, folderFiles, folderFiles) { files, added, later ->
                val before = library(files)
                val after = before.withScan(ps2.id, scan(reread(files, added)))
                val brought = after.games.map { it.id }.toSet() - before.games.map { it.id }.toSet()
                val first = Arrivals().entered(gba).after(ps2.id, before, after)
                first.unseen shouldBe brought
                first.announced shouldBe if (brought.isEmpty()) emptyMap() else mapOf(ps2.id to brought)
                if (brought.isNotEmpty()) marked++
                val again = after.withScan(ps2.id, scan(reread(reread(files, added), later)))
                val second = first.after(ps2.id, after, again)
                val still = again.games.map { it.id }.toSet()
                second.unseen shouldBe (brought intersect still) + (still - after.games.map { it.id }.toSet())
                second.announced.getOrElse(ps2.id) { emptySet() } shouldBe second.unseen
                Arrivals().after(gba, before, after) shouldBe Arrivals()
            }
            marked shouldBeGreaterThan 100
        }

    @Test
    fun `INV-25 a re-read between a setup changed and its scan marks nothing, nor one of a console just added`() = runBlocking<Unit> {
        checkAll(folderFiles, folderFiles) { files, added ->
            val before = library(files)
            before.withSetup(ps2.id, before.setup(ps2.id)) shouldBe before
            val setUp = before.withSetup(ps2.id, PlatformSetup(Some(uri("content://cards/tree/other"))))
            val after = setUp.withScan(ps2.id, scan(reread(files, added)))
            Arrivals().after(ps2.id, setUp, after) shouldBe Arrivals()
            after.awaitingScan shouldBe emptySet()
            val again = after.withScan(ps2.id, scan(reread(reread(files, added), files)))
            Arrivals().after(ps2.id, after, again).unseen shouldBe again.games.map { it.id }.toSet() - after.games.map { it.id }.toSet()
            val fresh = Library().withSetup(ps2.id, PlatformSetup())
            Arrivals().after(ps2.id, fresh, fresh.withScan(ps2.id, scan(files))) shouldBe Arrivals()
        }
    }

    @Test
    fun `entering a console clears its count only, leaving a game its own mark only`() = runBlocking<Unit> {
        checkAll(folderFiles, folderFiles) { files, added ->
            val before = library(files)
            val after = before.withScan(ps2.id, scan(reread(files, added)))
            val marked = Arrivals(announced = mapOf(gba to setOf(other.id))).after(ps2.id, before, after)
            marked.entered(ps2.id) shouldBe marked.copy(announced = mapOf(gba to setOf(other.id)))
            marked.unseen.forEach { game ->
                marked.left(game) shouldBe marked.copy(unseen = marked.unseen - game)
            }
            marked.left(other.id) shouldBe marked
        }
    }

    @Test
    fun `INV-25 a console removed, or a folder read empty, leaves no mark of its games`() = runBlocking<Unit> {
        checkAll(folderFiles, folderFiles) { files, added ->
            val before = library(files)
            val after = before.withScan(ps2.id, scan(reread(files, added)))
            val marked = Arrivals().after(ps2.id, before, after)
            marked.within(after.without(ps2.id)) shouldBe Arrivals()
            marked.after(ps2.id, after, after.withScan(ps2.id, scan(emptyList()))) shouldBe Arrivals()
        }
    }
}
