// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.library

import android.net.Uri
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.FakeDocuments
import app.cartouche.android.storage.FileStamp
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.KnownFacts
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.TREE
import app.cartouche.android.storage.cardTree
import app.cartouche.android.storage.discImage
import app.cartouche.android.storage.documentFile
import app.cartouche.android.storage.fileRow
import app.cartouche.android.storage.folderRow
import app.cartouche.android.storage.installDocuments
import app.cartouche.android.storage.rows
import app.cartouche.android.storage.serving
import app.cartouche.android.storage.setAside
import app.cartouche.core.files.FileFacts
import app.cartouche.core.library.ConsoleVariant
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.FolderWalk
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.library.VariantError
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.library.fileNames
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.search.Query
import app.cartouche.core.shelves.Selection
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
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
import java.io.FileNotFoundException

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

    private val factsFolder = File(context.filesDir, "facts")

    private fun service(selection: File = selectionFile) =
        LibraryService(LibraryStore(file), SelectionStore(selection), Folders(context), FactsStore(factsFolder))

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
    fun `INV-15 the form stores its setup and variant together, a refused variant leaving the stored library as it was`() {
        val ps2 = PlatformId("ps2")
        service().setUp(ps2, PlatformSetup(), Some("ps2_fat")).shouldBeRight()
        service().library().variantOf(ps2) shouldBe Some(ConsoleVariant.PS2_FAT)
        val before = file.readText()
        service()
            .setUp(ps2, PlatformSetup(depth = FolderDepth.SUBFOLDERS), Some("unknown"))
            .shouldBeLeft(LibraryFailure.Variant(VariantError.Unknown(ps2, "unknown")))
        file.readText() shouldBe before
    }

    @Test
    fun `INV-13 a removal that cannot be saved leaves the library and the folder access as they were`() {
        val folder = Folders(context).keepAccess(cardTree("ps2")).shouldBeRight().uri
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
        kept() shouldBe listOf(cardTree("ps2"))
    }

    @Test
    fun `INV-15 the selected game is shown again after a restart, and after a rescan that keeps it`() {
        scanned("A", "B", "C").select("B")
        service().shown() shouldBe "B"
        scanned("A", "B", "C", "D").shown() shouldBe "B"
        scanned("A", "C", "D").shown() shouldBe "C"
    }

    @Test
    fun `a selection that could not be saved is saved at the next selection of the same game`() {
        scanned("A", "B")
        val blocked = File(context.filesDir, "blocked").apply { writeText("") }
        val selection = File(blocked, "selection.json")
        val service = service(selection)
        service.select(service.library().games.single { it.title == "B" }.id).shouldBeLeft().shouldBeInstanceOf<LibraryFailure.Storage>()
        blocked.delete()
        service.select("B")
        service(selection).shown() shouldBe "B"
    }

    @Test
    fun `INV-15 an unreadable selection file only means starting from the first game`() {
        scanned("A", "B").select("B")
        selectionFile.writeText("not a selection")
        val service = service()
        service.shown() shouldBe "A"
        service.library().games.size shouldBe 2
        service.select("B")
        service().shown() shouldBe "B"
    }

    @Test
    fun `the games counted before adding a platform are the ones its scan then finds, and counting saves nothing`() = runBlocking<Unit> {
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
    fun `INV-09 a scan whose folder cannot be listed changes nothing, in memory or stored`() {
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
    fun `INV-09 a scan over the limit fails naming the largest folder, and changes nothing`() {
        val service = service()
        val before = service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        installDocuments { rows(*Array(FolderWalk.MAX_ENTRIES + 1) { fileRow("root/$it.dds") }) }
        service.scan().shouldBeLeft() shouldBe
            LibraryFailure.TooManyEntries(WalkFailure.TooManyEntries(FolderWalk.MAX_ENTRIES, None, FolderWalk.MAX_ENTRIES + 1, None))
        service.library() shouldBe before
        service().library() shouldBe before
    }

    @Test
    fun `INV-11 the library service reports an unreadable file and keeps it`() {
        file.writeText("not a library")
        val service = service()
        service.library() shouldBe Library()
        service.loadProblem.shouldBeSome()
        service.setUp(PlatformId("ps2"), PlatformSetup()).shouldBeRight()
        setAside(file).size shouldBe 1
    }

    @Test
    fun `INV-13 a removed platform leaves nothing of it, after a restart too, and gives up its folder unless another uses it`() {
        val other = PlatformId("other")
        val otherTree = cardTree("gba")
        val folders = Folders(context)
        folders.keepAccess(Uri.parse(TREE.value)).shouldBeRight()
        val otherFolder = folders.keepAccess(otherTree).shouldBeRight().uri
        service().setUp(other, PlatformSetup(Some(otherFolder))).shouldBeRight()
        val service = scanned("A", "B")
        service.select("B")
        FactsStore(factsFolder).save(platform.id, mapOf(TREE to KnownFacts(FileStamp(None, None), FileFacts.Silent))).shouldBeRight()
        service.remove(platform.id).shouldBeRight()
        File(factsFolder, "${platform.id.value}.tsv").exists() shouldBe false
        listOf(service, service()).forEach { again ->
            again.library() shouldBe Library(setups = mapOf(other to PlatformSetup(Some(otherFolder))))
            again.selection() shouldBe Selection()
        }
        kept() shouldBe listOf(otherTree)
        service.setUp(platform.id, PlatformSetup(Some(otherFolder))).shouldBeRight()
        service.remove(other).shouldBeRight()
        kept() shouldBe listOf(otherTree)
        service.remove(platform.id).shouldBeRight()
        kept() shouldBe emptyList()
    }

    private fun kept() = context.contentResolver.persistedUriPermissions.map { it.uri }

    @Test
    fun `INV-13 while the library cannot be read, no folder access is given up and no art is known to go`() {
        scanned("A").gamesWithArt().shouldBeSome().size shouldBe 1
        Folders(context).keepAccess(cardTree("gba")).shouldBeRight()
        file.writeText("not a library")
        val service = service()
        service.gamesWithArt().shouldBeNone()
        service.setUp(platform.id, PlatformSetup(Some(TREE))).shouldBeRight()
        kept() shouldBe listOf(cardTree("gba"))
    }

    @Test
    fun `INV-15 a label chosen is there after a restart, and choosing one for a game the library does not have fails`() {
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
    fun `the search follows the library kept, a game renamed found under its new name, in the order of its shelf`() {
        val service = scanned("Okage", "Ico", "The Bouncer")

        fun LibraryService.found(typed: String) =
            finders.of(platform.id).shouldBeSome().search(Query.of(typed).shouldBeSome()).games.map { at ->
                shelves(listOf(platform.id)).shouldBeSome().shelves.single().games[at].shownTitle
            }
        service.found("o") shouldBe listOf("Okage")
        service.rename(service.library().games.single { it.title == "Ico" }.id, DisplayName.of("Ico Odyssey")).shouldBeRight()
        service.found("o") shouldBe listOf("Ico Odyssey", "Okage")
        service.found("bou") shouldBe listOf("The Bouncer")
        service().apply { library() }.found("o") shouldBe listOf("Ico Odyssey", "Okage")
    }

    @Test
    fun `INV-15 a name given is there after a restart, a blank one gives the title back, an unknown game is not renamed`() {
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
    fun `INV-15 the consoles' order is there after a restart, and a console removed leaves it, an unknown one refused`() {
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

    private val ps2 = catalog(definition(playerJson("test.x", pattern = ".*\\\\.(chd|iso)")), minimumGameBytes = 0).platforms.single()

    private val bujingai = TitleIndex.parse("Bujingai - The Forsaken City (Europe)\tSLES-52495")

    /**
     * A service whose PS2 folder holds [files] (by document id), each listed with its size, or the
     * one [size] gives, and as last changed at [modified].
     */
    private fun ps2Folder(
        files: Map<String, ByteArray>,
        size: (String) -> Long = { files.getValue(it).size.toLong() },
        modified: (String) -> Long = { 0L },
    ): Pair<LibraryService, FakeDocuments> {
        val service = service().apply { setUp(ps2.id, PlatformSetup(Some(TREE))).shouldBeRight() }
        val provider =
            installDocuments { rows(*files.keys.map { fileRow(it, size(it), modified(it)) }.toTypedArray()) }
                .serving(files.mapValues { (id, bytes) -> documentFile(id, bytes) })
        return service to provider
    }

    private fun LibraryService.scanPs2() = scan(ps2, bujingai, DataFolders.NONE).shouldBeRight()

    private fun LibraryService.identified(): Int = library().games.count { it.identified }

    @Test
    fun `INV-10 a game whose file is named otherwise is identified by the serial its disc holds`() {
        val (service, _) = ps2Folder(mapOf("root/Mystery Game 1.chd" to discImage("cd-cdlz.chd"), "root/Other.iso" to ByteArray(4096)))
        service.scanPs2()
        val (identified, unknown) = service.library().games.partition { it.identified }
        identified.map { it.serials } shouldBe listOf(listOf("SLES-52495"))
        unknown.map { it.title } shouldBe listOf("Other")
    }

    @Test
    fun `a file unchanged since the last scan is not read again, one whose size or date changed or that could not be opened is`() {
        var date = 0L
        var size = 0L
        val files = mapOf("root/a.chd" to discImage("cd-cdlz.chd"), "root/b.iso" to discImage("disc.iso"))
        val (service, provider) =
            ps2Folder(
                files,
                size = { files.getValue(it).size + if (it == "root/b.iso") size else 0L },
                modified = { if (it == "root/b.iso") date else 0L },
            )
        service.scanPs2()
        provider.opened.size shouldBe 2
        service().scanPs2()
        provider.opened.size shouldBe 2
        date = 1L
        service.scanPs2()
        provider.opened.size shouldBe 3
        size = 1L
        service.scanPs2()
        provider.opened.size shouldBe 4
        val serving = provider.open
        provider.open = { id, _ -> throw FileNotFoundException(id) }
        date = 2L
        service.scanPs2()
        service.identified() shouldBe 1
        provider.open = serving
        service.scanPs2()
        provider.opened.size shouldBe 6
        service.identified() shouldBe 2
        service.scanPs2()
        provider.opened.size shouldBe 6
    }

    @Test
    fun `a count reads no game file and keeps nothing, its files known by what they told at the last scan`() {
        val (service, provider) = ps2Folder(mapOf("root/Mystery Game 1.chd" to discImage("cd-cdlz.chd")))

        fun preview() = service.preview(ps2, PlatformSetup(Some(TREE)), bujingai, DataFolders.NONE).shouldBeRight().identified
        preview() shouldBe 0
        provider.opened shouldBe emptyList()
        FactsStore(factsFolder).load(ps2.id) shouldBe emptyMap()
        service.scanPs2()
        preview() shouldBe 1
        provider.opened.size shouldBe 1
    }

    @Test
    fun `INV-03 a scan opens game files read-only, closes each, and leaves their bytes and date as they were`() {
        val files = mapOf("root/a.chd" to discImage("cd-cdlz.chd"), "root/b.iso" to discImage("disc.iso"), "root/c.iso" to ByteArray(4096))
        val (service, provider) = ps2Folder(files)
        val stored = files.mapValues { (id, _) -> File(context.cacheDir, "documents/$id").apply { setLastModified(1_000_000_000L) } }
        service.scanPs2()
        provider.opened shouldBe listOf("r", "r", "r")
        provider.descriptors.map { it.fileDescriptor.valid() } shouldBe listOf(false, false, false)
        stored.forEach { (id, file) ->
            file.readBytes() shouldBe files.getValue(id)
            file.lastModified() shouldBe 1_000_000_000L
        }
    }
}
