// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

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
import app.cartouche.core.library.FolderWalk
import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryFormat
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.kotest.matchers.types.shouldBeInstanceOf
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
}
