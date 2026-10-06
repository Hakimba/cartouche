// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

import android.net.Uri
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.TREE
import app.cartouche.android.storage.fileRow
import app.cartouche.android.storage.folderRow
import app.cartouche.android.storage.installDocuments
import app.cartouche.android.storage.rows
import app.cartouche.android.storage.setAside
import app.cartouche.core.library.CountedReason
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.FolderWalk
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryFormat
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.library.fileNames
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.shelves.Selection
import arrow.core.None
import arrow.core.Some
import arrow.core.getOrNone
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Assume.assumeFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
class LibraryServiceTest {
    private val context = RuntimeEnvironment.getApplication()
    private val file = File(context.filesDir, "library.json")
    private val selectionFile = File(context.filesDir, "selection.json")
    private val platform =
        catalog(
            definition(playerJson("test.x", pattern = ".*\\\\.iso"), platform = "test"),
            minimumGameBytes = 0,
        ).platforms.single()

    private fun service(selection: File = selectionFile) = LibraryService(LibraryStore(file), SelectionStore(selection), Folders(context))

    private fun LibraryService.scan() = scan(platform, TitleIndex.EMPTY, DataFolders.NONE)

    /** The title of the game shown first. */
    private fun LibraryService.shown(): String = shelves(listOf(platform.id)).shouldBeSome().let { found ->
        found.shelves[found.selected].let { it.games[it.selected].title }
    }

    /** A service whose platform folder holds the games [titles], scanned. */
    private fun scanned(vararg titles: String): LibraryService = service().also { service ->
        service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        installDocuments { rows(*titles.map { fileRow("root/$it.iso") }.toTypedArray()) }
        service.scan().shouldBeRight()
    }

    private fun LibraryService.select(title: String) = select(library().games.single { it.title == title }.id).shouldBeRight()

    @Test
    fun `INV-E2-05 the selected game is shown again after a restart, and after a rescan that keeps it`() {
        scanned("A", "B", "C").select("B")
        service().shown() shouldBe "B"
        scanned("A", "B", "C", "D").shown() shouldBe "B"
        // Gone: the game that followed it.
        scanned("A", "C", "D").shown() shouldBe "C"
    }

    @Test
    fun `INV-E2-05 a rescan keeps the selected game shown by the same running service`() {
        val service = scanned("A", "B", "C")
        service.select("B")
        installDocuments { rows(fileRow("root/A.iso"), fileRow("root/B.iso"), fileRow("root/D.iso")) }
        service.scan().shouldBeRight()
        service.shown() shouldBe "B"
    }

    @Test
    fun `a selection that could not be saved is saved at the next selection of the same game`() {
        scanned("A", "B")
        // A file where the selection's folder should be: nothing can be written there.
        val blocked = File(context.filesDir, "blocked").apply { writeText("") }
        val selection = File(blocked, "selection.json")
        val service = service(selection)
        service.select(service.library().games.single { it.title == "B" }.id).shouldBeLeft().shouldBeInstanceOf<LibraryFailure.Storage>()
        blocked.delete()
        service.select("B")
        service(selection).shown() shouldBe "B"
    }

    @Test
    fun `INV-E2-05 the last of several selections on a platform is the one shown after a restart`() {
        val service = scanned("A", "B", "C")
        service.select("C")
        service.select("B")
        service().shown() shouldBe "B"
    }

    @Test
    fun `INV-E2-05 an unreadable selection file only means starting from the first game`() {
        scanned("A", "B").select("B")
        selectionFile.writeText("not a selection")
        val service = service()
        service.shown() shouldBe "A"
        service.library().games.size shouldBe 2
        service.select("B")
        service().shown() shouldBe "B"
    }

    @Test
    fun `selecting a game the library does not have fails, and selecting the same game again writes nothing`() {
        val service = scanned("A", "B")
        service.select(GameId("test/none")).shouldBeLeft() shouldBe LibraryFailure.UnknownGame(GameId("test/none"))
        service.select("B")
        selectionFile.delete()
        service.select("B")
        selectionFile.exists() shouldBe false
    }

    @Test
    fun `INV-E6-06 the games counted before adding a platform are the ones its scan then finds, and counting saves nothing`() =
        runBlocking<Unit> {
            var counted = 0
            checkAll(
                40,
                Arb.list(fileNames, 0..12),
                Arb.list(fileNames, 0..6),
                Arb.enum<DiscGrouping>(),
                Arb.enum<FolderDepth>(),
            ) { top, inner, discs, depth ->
                file.delete()
                installDocuments { folder ->
                    when (folder) {
                        "root" -> rows(folderRow("root/sub"), *top.map { fileRow("root/$it") }.toTypedArray())
                        else -> rows(*inner.map { fileRow("root/sub/$it") }.toTypedArray())
                    }
                }
                val setup = PlatformSetup(Some(TREE), discs = discs, depth = depth)
                val service = service()
                val preview = service.preview(platform, setup, TitleIndex.EMPTY, DataFolders.NONE).shouldBeRight()
                service.library() shouldBe Library()
                file.exists() shouldBe false
                service.setUp(platform.id, setup).shouldBeRight()
                service.scan().shouldBeRight().second.games shouldBe preview.games
                if (preview.games > 0) counted++
            }
            counted shouldBeGreaterThan 10
        }

    @Test
    fun `INV-E6-06 counting the games of a folder leaves a stored library as it was, to the byte`() {
        val service = scanned("A", "B")
        val stored = file.readBytes()
        installDocuments { rows(fileRow("root/C.iso"), fileRow("root/D.iso")) }
        service.preview(platform, PlatformSetup(Some(TREE)), TitleIndex.EMPTY, DataFolders.NONE).shouldBeRight().games shouldBe 2
        file.readBytes().toList() shouldBe stored.toList()
        service().library().games.map { it.title } shouldBe listOf("A", "B")
    }

    @Test
    fun `INV-E6-06 the discs of one game count as one game when grouped, as many when not, before and after adding`() {
        installDocuments { rows(fileRow("root/Game (Disc 1).iso"), fileRow("root/Game (Disc 2).iso"), fileRow("root/Other.iso")) }
        listOf(DiscGrouping.GROUPED to 2, DiscGrouping.SEPARATE to 3).forEach { (discs, games) ->
            file.delete()
            val setup = PlatformSetup(Some(TREE), discs = discs)
            val service = service()
            service.preview(platform, setup, TitleIndex.EMPTY, DataFolders.NONE).shouldBeRight().games shouldBe games
            service.setUp(platform.id, setup).shouldBeRight()
            service.scan().shouldBeRight().second.games shouldBe games
        }
    }

    @Test
    fun `INV-E1-10 a scan whose folder cannot be listed changes nothing, in memory or stored`() {
        val service = service()
        service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        installDocuments { rows(fileRow("root/a.iso"), folderRow("root/s")) }
        val (scanned, report) = service.scan().shouldBeRight()
        report.games shouldBe 1
        installDocuments { throw IllegalStateException("storage removed") }
        service.scan().shouldBeLeft() shouldBe
            LibraryFailure.Storage(StorageFailure.Unavailable("java.lang.IllegalStateException: storage removed"))
        service.library() shouldBe scanned
        service().library() shouldBe scanned
    }

    @Test
    fun `INV-E1-14 a scan over the limit fails naming the largest folder, and changes nothing`() {
        val service = service()
        val before = service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        installDocuments { rows(*Array(FolderWalk.MAX_ENTRIES + 1) { fileRow("root/$it.dds") }) }
        service.scan().shouldBeLeft() shouldBe
            LibraryFailure.TooManyEntries(WalkFailure.TooManyEntries(FolderWalk.MAX_ENTRIES, None, FolderWalk.MAX_ENTRIES + 1, None))
        service.library() shouldBe before
        service().library() shouldBe before
    }

    @Test
    fun `a library file of an earlier format is saved again, upgraded and small, when first read`() {
        val ignored =
            (1..5_000).joinToString(",") {
                """{"file":{"name":"$it.dds","uri":"content://p/document/$it","path":null,"sizeBytes":1},"reason":"unsupported"}"""
            }
        file.writeText("""{"version":1,"library":{"games":[],"ignored":{"test":[$ignored]}}}""")
        service().library().ignoredCounts.getValue(PlatformId("test")).getValue(CountedReason.UNSUPPORTED).count shouldBe 5_000
        file.readText().let {
            it shouldStartWith """{"version":${LibraryFormat.VERSION},"""
            it.length shouldBeLessThan 2_000
        }
    }

    @Test
    fun `INV-E1-08 the library service reports an unreadable file and keeps it`() {
        file.writeText("not a library")
        val service = service()
        service.library() shouldBe Library()
        service.loadProblem.shouldBeSome()
        service.setUp(PlatformId("ps2"), PlatformSetup()).shouldBeRight()
        setAside(file).size shouldBe 1
    }

    @Test
    fun `INV-E1-08 nothing is saved while an unreadable file could not be set aside`() {
        file.writeText("not a library")
        val folder = file.parentFile.shouldNotBeNull()
        folder.setWritable(false)
        try {
            // Running as root, the folder stays writable: the case cannot happen.
            assumeFalse(folder.canWrite())
            val service = service()
            service.library() shouldBe Library()
            service.setUp(PlatformId("ps2"), PlatformSetup()).shouldBeLeft().shouldBeInstanceOf<LibraryFailure.Storage>()
            file.readText() shouldBe "not a library"
        } finally {
            folder.setWritable(true)
        }
    }

    @Test
    fun `INV-E6-03 a removed platform leaves nothing of it, after a restart too, and gives up its folder unless another uses it`() {
        val other = PlatformId("other")
        val otherTree = tree("gba")
        val folders = Folders(context)
        folders.keepAccess(Uri.parse(TREE.value)).shouldBeRight()
        val otherFolder = folders.keepAccess(otherTree).shouldBeRight().uri
        service().setUp(other, PlatformSetup(Some(otherFolder))).shouldBeRight()
        val service = scanned("A", "B")
        service.select("B")
        service.remove(platform.id).shouldBeRight()
        listOf(service, service()).forEach { again ->
            again.library() shouldBe Library(setups = mapOf(other to PlatformSetup(Some(otherFolder))))
            again.selection() shouldBe Selection()
        }
        kept() shouldBe listOf(otherTree)
        // A folder two platforms share stays theirs until the last one goes.
        service.setUp(platform.id, PlatformSetup(Some(otherFolder))).shouldBeRight()
        service.remove(other).shouldBeRight()
        kept() shouldBe listOf(otherTree)
        service.remove(platform.id).shouldBeRight()
        kept() shouldBe emptyList()
    }

    private fun tree(name: String) = Uri.parse("content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2F$name")

    private fun kept() = context.contentResolver.persistedUriPermissions.map { it.uri }

    @Test
    fun `INV-E6-03 moving a platform to another folder gives up the old one and keeps the new`() {
        val folders = Folders(context)
        service().setUp(platform.id, PlatformSetup(Some(folders.keepAccess(tree("old")).shouldBeRight().uri))).shouldBeRight()
        service().setUp(platform.id, PlatformSetup(Some(folders.keepAccess(tree("new")).shouldBeRight().uri))).shouldBeRight()
        kept() shouldBe listOf(tree("new"))
    }

    @Test
    fun `INV-E6-03 a removal that cannot be saved leaves the library and the folder access as they were`() {
        val folder = Folders(context).keepAccess(tree("ps2")).shouldBeRight().uri
        service().setUp(platform.id, PlatformSetup(Some(folder))).shouldBeRight()
        val files = file.parentFile.shouldNotBeNull()
        files.setWritable(false)
        try {
            assumeFalse(files.canWrite())
            service().remove(platform.id).shouldBeLeft()
        } finally {
            files.setWritable(true)
        }
        service().library().setups.keys shouldBe setOf(platform.id)
        kept() shouldBe listOf(tree("ps2"))
    }

    @Test
    fun `INV-E6-03 while the library cannot be read, no folder access is given up and no art is known to go`() {
        scanned("A").gamesWithArt().shouldBeSome().size shouldBe 1
        // The folder of a platform of the library that can no longer be read.
        Folders(context).keepAccess(tree("gba")).shouldBeRight()
        file.writeText("not a library")
        val service = service()
        service.gamesWithArt().shouldBeNone()
        service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        kept() shouldBe listOf(tree("gba"))
    }

    @Test
    fun `INV-E7-01 a label chosen is there after a restart, and choosing one for a game the library does not have fails`() {
        val service = scanned("Okage", "Ico")
        val okage = service.library().games.single { it.title == "Okage" }.id
        val japan = LabelChoice.Region(LabelRegion("Japan"))
        service.chooseLabel(okage, japan).shouldBeRight()
        service().library().game(okage).shouldBeSome().label shouldBe japan
        service().library().games.single { it.title == "Ico" }.label shouldBe LabelChoice.Automatic
        val missing = GameId("test/none")
        service.chooseLabel(missing, japan).shouldBeLeft(LibraryFailure.UnknownGame(missing))
    }

    @Test
    fun `INV-E7-06 a name given is there after a restart, a blank one gives the title back, an unknown game is not renamed`() {
        val service = scanned("Okage", "Ico")
        val okage = service.library().games.single { it.title == "Okage" }.id
        service.rename(okage, DisplayName.of("Okage: Shadow King")).shouldBeRight().shownTitle shouldBe "Okage: Shadow King"
        service().library().game(okage).shouldBeSome().shownTitle shouldBe "Okage: Shadow King"
        service().library().game(okage).shouldBeSome().title shouldBe "Okage"
        service.rename(okage, DisplayName.of("  ")).shouldBeRight()
        service().library().game(okage).shouldBeSome().shownTitle shouldBe "Okage"
        service.rename(okage, DisplayName.of("Okage")).shouldBeRight().displayName shouldBe None
        val missing = GameId("test/none")
        service.rename(missing, DisplayName.of("X")).shouldBeLeft(LibraryFailure.UnknownGame(missing))
    }

    @Test
    fun `INV-E7-07 a console's name is there after a restart, a blank one or its own gives its own back, an unknown one is refused`() {
        val service = scanned("Okage")
        service.renameConsole(platform.id, DisplayName.of("Ma PS2"), "PlayStation 2").shouldBeRight() shouldBe DisplayName.of("Ma PS2")
        service().library().consoleNames.getOrNone(platform.id) shouldBe DisplayName.of("Ma PS2")
        service.renameConsole(platform.id, DisplayName.of(" "), "PlayStation 2").shouldBeRight()
        service().library().consoleNames.containsKey(platform.id) shouldBe false
        service.renameConsole(platform.id, DisplayName.of("Ma PS2"), "PlayStation 2").shouldBeRight()
        service.renameConsole(platform.id, DisplayName.of("PlayStation 2"), "PlayStation 2").shouldBeRight()
        service().library().consoleNames.containsKey(platform.id) shouldBe false
        // Removing the console forgets its name, after a restart too.
        service.renameConsole(platform.id, DisplayName.of("Ma PS2"), "PlayStation 2").shouldBeRight()
        service.remove(platform.id).shouldBeRight()
        service().library().consoleNames.isEmpty() shouldBe true
        val unknown = PlatformId("nes")
        service.renameConsole(unknown, DisplayName.of("Mine"), "NES").shouldBeLeft(LibraryFailure.UnknownPlatform(unknown))
    }

    @Test
    fun `INV-E7-08 the consoles' order is there after a restart, and a console removed leaves it, an unknown one refused`() {
        val service = scanned("Okage")
        val other = PlatformId("gba")
        service.setUp(other, PlatformSetup(Some(TREE))).shouldBeRight()
        service.orderConsoles(listOf(other, platform.id)).shouldBeRight()
        service().library().consoleOrder shouldBe listOf(other, platform.id)
        val unknown = PlatformId("nes")
        service.orderConsoles(listOf(platform.id, unknown)).shouldBeLeft(LibraryFailure.UnknownPlatform(unknown))
        service().library().consoleOrder shouldBe listOf(other, platform.id)
        service.remove(other).shouldBeRight()
        service().library().consoleOrder shouldBe listOf(platform.id)
    }
}
