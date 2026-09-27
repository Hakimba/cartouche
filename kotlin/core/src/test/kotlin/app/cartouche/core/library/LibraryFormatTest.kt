// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.uri
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class LibraryFormatTest {
    @Test
    fun `INV-E1-13 a stored library grows with games and files a player opens, not with hidden or unsupported files`() = runBlocking<Unit> {
        checkAll(folderFiles, Arb.int(0..500)) { files, extra ->
            val junk = (1..extra).flatMap { listOf(listed("texture-%05d.dds".format(it)), listed("._Game %05d.chd".format(it))) }

            fun stored(listed: List<ListedFile>) =
                LibraryFormat.encode(Library().withScan(ps2.id, Scan.of(ps2, contents(listed), ps2Titles, DiscGrouping.GROUPED))).length
            // At most the first examples of two more reasons, and their counts.
            stored(files + junk) shouldBeLessThanOrEqual stored(files) + 2 * (IgnoredCount.EXAMPLES * 25 + 40)
        }
    }

    @Test
    fun `stored libraries of another version, or with invalid values, are reported`() {
        val stored = LibraryFormat.encode(Library().withSetup(ps2.id, PlatformSetup(Some(uri("content://p/tree/x")))))
        LibraryFormat.decode(stored.replace("\"version\":2", "\"version\":3")).shouldBeLeft() shouldBe LibraryError.UnsupportedVersion(3)
        LibraryFormat.decode(stored.replace("content://p/tree/x", "file:///x")).shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
        LibraryFormat.decode("{").shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
    }

    @Test
    fun `a library of format 1 reads, its hidden and unsupported files counted`() {
        val stored =
            """{"version":1,"library":{"setups":{"ps2":{"folder":"content://p/tree/x","player":null,"discs":"grouped",""" +
                """"depth":"top_level"}},"games":[{"id":"ps2/content://p/document/Dark Cloud (Europe).chd","platform":"ps2",""" +
                """"title":"Dark Cloud","regions":["Europe"],"languages":[],"version":null,"serials":["SCES-50295"],""" +
                """"redumpName":null,"discs":[{"number":null,"file":{"name":"Dark Cloud (Europe).chd",""" +
                """"uri":"content://p/document/Dark Cloud (Europe).chd","path":null,"sizeBytes":1000000000}}],"lastDisc":0}],""" +
                """"ignored":{"ps2":[{"file":{"name":"bios.bin","uri":"content://p/document/bios.bin","path":null,""" +
                """"sizeBytes":1000000000},"reason":"not_a_game"},{"file":{"name":"a.json","uri":"content://p/document/a.json",""" +
                """"path":null,"sizeBytes":1000000000},"reason":"unsupported"}]}}}"""
        val library =
            Library()
                .withSetup(ps2.id, PlatformSetup(Some(uri("content://p/tree/x"))))
                .withScan(
                    ps2.id,
                    Scan.of(
                        ps2,
                        contents(listOf(listed("Dark Cloud (Europe).chd"), listed("bios.bin"), listed("a.json"))),
                        ps2Titles,
                        DiscGrouping.GROUPED,
                    ),
                )
        LibraryFormat.decode(stored).shouldBeRight() shouldBe StoredLibrary(library.copy(skippedFolders = emptyMap()), version = 1)
    }

    @Test
    fun `a stored last disc past the game's discs reads back as the first disc`() {
        val library =
            Library().withScan(
                ps2.id,
                Scan.of(
                    ps2,
                    contents(listOf(listed("0 Story (Japan) (Disc 1).chd"), listed("0 Story (Japan) (Disc 2).chd"))),
                    ps2Titles,
                    DiscGrouping.GROUPED,
                ),
            )
        val edited = LibraryFormat.encode(library.withLastDisc(library.games.single().id, 1)).replace("\"lastDisc\":1", "\"lastDisc\":9")
        LibraryFormat.decode(edited).shouldBeRight().library.games.single().lastDisc shouldBe 0
    }

    @Test
    fun `INV-E1-05 a stored library reads back identical`() = runBlocking<Unit> {
        checkAll(folderFiles, setups, skippedFolders, Arb.int(0..3)) { files, setup, skipped, disc ->
            val library =
                Library()
                    .withSetup(ps2.id, setup)
                    .withSetup(PlatformId("gba"), setup)
                    .withScan(ps2.id, Scan.of(ps2, FolderContents(files, skipped), ps2Titles, setup.discs))
                    .let { lib -> lib.games.fold(lib) { acc, game -> acc.withLastDisc(game.id, disc) } }
            LibraryFormat.decode(LibraryFormat.encode(library)).shouldBeRight() shouldBe StoredLibrary(library, LibraryFormat.VERSION)
        }
    }
}
