// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped.ps2
import app.cartouche.core.Shipped.ps2Titles
import app.cartouche.core.files.Shell
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.uri
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.shouldBe
import org.junit.Test

/**
 * Library files as released builds wrote them, kept as files: a renamed field passes every round trip and sets every
 * user's library aside as unreadable, only a file written before the rename notices.
 */
class LibraryGoldenTest {
    private fun golden(name: String): String =
        checkNotNull(LibraryGoldenTest::class.java.getResourceAsStream("/library/$name")) { "No golden $name" }
            .use { it.readBytes().decodeToString().trim() }

    @Test
    fun `INV-11 a library stored in format 1 reads, its ignored files counted`() {
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
        LibraryFormat.decode(golden("library-v1.json")).shouldBeRight() shouldBe
            StoredLibrary(library.copy(skippedFolders = emptyMap()), version = 1)
    }

    @Test
    fun `INV-11 a library stored by 0_4_1 reads back whole and is written again byte for byte`() {
        val stored = golden("library-0.4.1.json")
        LibraryFormat.decode(stored).shouldBeRight() shouldBe StoredLibrary(release041(), LibraryFormat.VERSION)
        LibraryFormat.encode(release041()) shouldBe stored
    }

    /** One of each thing a library holds: two consoles, scanned games, every kind of label, a name, a shell, an order, a variant. */
    private fun release041(): Library {
        val gba = PlatformId("gba")
        val setup =
            PlatformSetup(
                Some(uri("content://p/tree/ROMs%2Fps2")),
                Some(PlayerId("ps2.com.armsx2")),
                DiscGrouping.GROUPED,
                FolderDepth.SUBFOLDERS,
            )
        val files =
            listOf(
                listed("Dark Cloud (Europe).chd"),
                listed("Final Fantasy X (Europe) (Disc 1).chd"),
                listed("Final Fantasy X (Europe) (Disc 2).chd"),
                listed("Okage - Shadow King (USA).chd"),
                listed("bios.bin"),
                listed("a.json"),
                listed("._Dark Cloud (Europe).chd"),
            )
        val scanned =
            Library()
                .withSetup(ps2.id, setup)
                .withSetup(gba, PlatformSetup(Some(uri("content://p/tree/ROMs%2Fgba"))))
                .withScan(
                    ps2.id,
                    Scan.of(
                        ps2,
                        FolderContents(files, listOf(SkippedFolder(FolderPath("Backups"), SkipReason.UNREADABLE))),
                        ps2Titles,
                        setup.discs,
                    ),
                )
        val (darkCloud, finalFantasy, okage) = scanned.games.filter { it.platform == ps2.id }
        val crystal = game("Pokémon Crystal", platform = "gbc").copy(shell = Shell.EXCLUSIVE)
        return scanned
            .copy(games = scanned.games + crystal)
            .withLastDisc(finalFantasy.id, 1)
            .withLabel(darkCloud.id, LabelChoice.Own)
            .withLabel(finalFantasy.id, LabelChoice.Region(LabelRegion("Europe"), ArtSource.SCREENSCRAPER))
            .withLabel(okage.id, LabelChoice.Region(LabelRegion("Japan"), ArtSource.LAUNCHBOX))
            .withDisplayName(okage.id, DisplayName.of("Okage"))
            .withConsoleOrder(listOf(gba, ps2.id))
            .withVariant(ps2.id, "ps2_fat")
            .shouldBeRight()
    }
}
