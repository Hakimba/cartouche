// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.database.Cursor
import android.database.CursorWrapper
import android.database.sqlite.SQLiteException
import android.net.Uri
import android.os.BadParcelableException
import android.os.OperationCanceledException
import android.provider.DocumentsContract.Document
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.FolderPath
import app.cartouche.core.library.FolderWalk
import app.cartouche.core.library.SkipReason
import app.cartouche.core.library.SkippedFolder
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.library.testDataFolders
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.orNull
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import kotlin.reflect.KClass

@RunWith(RobolectricTestRunner::class)
class FoldersTest {
    private val context = RuntimeEnvironment.getApplication()
    private val tree = TREE

    @Test
    fun `INV-E0-14 access to a picked folder is kept read-only`() {
        val tree = Uri.parse("content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2Fps2")
        Folders(context).keepAccess(tree).shouldBeRight().name shouldBe "ps2"
        context.contentResolver.persistedUriPermissions.map { Triple(it.uri, it.isReadPermission, it.isWritePermission) } shouldBe
            listOf(Triple(tree, true, false))
    }

    @Test
    fun `INV-E0-14 whatever folders are picked, none is kept writable`() = runBlocking<Unit> {
        checkAll(Arb.list(Arb.string(1..12, Codepoint.alphanumeric()), 1..4)) { names ->
            names.forEach {
                Folders(context).keepAccess(Uri.parse("content://com.android.externalstorage.documents/tree/primary%3A$it")).shouldBeRight()
            }
            context.contentResolver.persistedUriPermissions.forEach { it.isWritePermission shouldBe false }
        }
    }

    @Test
    fun `rows become files with their name, or the id's last segment, and their size when known`() {
        installDocuments { folder ->
            when (folder) {
                "root" ->
                    rows(
                        listOf("root/a.iso", "a.iso", "application/x-iso", 7L),
                        listOf("root/sub", "Sub", Document.MIME_TYPE_DIR, null),
                    )
                else -> rows(listOf("root/sub/b.chd", null, null, null))
            }
        }
        val contents = Folders(context).files(tree, FolderDepth.SUBFOLDERS, DataFolders.NONE).shouldBeRight()
        contents.files.map { Triple(it.name.value, it.uri.value, it.sizeBytes) } shouldBe
            listOf(
                Triple("a.iso", "content://$AUTHORITY/tree/root/document/root%2Fa.iso", Some(7L)),
                Triple("b.chd", "content://$AUTHORITY/tree/root/document/root%2Fsub%2Fb.chd", None),
            )
        // Only the external storage provider's documents have a filesystem path.
        contents.files.map { it.path } shouldBe listOf(None, None)
        contents.skipped shouldBe emptyList()
    }

    @Test
    fun `INV-E1-12 a folder the provider cannot list is a typed failure, a sub-folder a skipped one`() {
        val failures: List<Pair<() -> Cursor?, KClass<out StorageFailure>>> =
            listOf(
                { throw SecurityException("revoked") } to StorageFailure.PermissionDenied::class,
                { throw IllegalStateException("storage removed") } to StorageFailure.Unavailable::class,
                { throw NullPointerException("provider bug") } to StorageFailure.Unavailable::class,
                { throw IllegalArgumentException("stale document id") } to StorageFailure.Unavailable::class,
                { throw UnsupportedOperationException("not a folder") } to StorageFailure.Unavailable::class,
                { throw BadParcelableException("bad answer") } to StorageFailure.Unavailable::class,
                // Thrown on a device when a row holds a blob, or when the provider cancels the listing.
                { throw SQLiteException("blob") } to StorageFailure.Unavailable::class,
                { throw OperationCanceledException() } to StorageFailure.Unavailable::class,
                { null } to StorageFailure.Unavailable::class,
                { rows(listOf(null, "x", null, null)) } to StorageFailure.Unavailable::class,
                { rows(listOf("x", "x"), columns = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME)) } to
                    StorageFailure.Unavailable::class,
            )
        failures.forEach { (fail, expected) ->
            installDocuments { fail() }
            Folders(context).files(tree, FolderDepth.SUBFOLDERS, DataFolders.NONE).shouldBeLeft().unlisted()::class shouldBe expected
            installDocuments { folder ->
                if (folder ==
                    "root"
                ) {
                    rows(listOf("root/s", "s", Document.MIME_TYPE_DIR, null))
                } else {
                    fail()
                }
            }
            Folders(context).files(tree, FolderDepth.SUBFOLDERS, DataFolders.NONE).shouldBeRight().skipped shouldBe
                listOf(SkippedFolder(FolderPath("s"), SkipReason.UNREADABLE))
        }
    }

    @Test
    fun `INV-E1-12 whatever rows a provider returns, listing is a result, never a crash`() = runBlocking<Unit> {
        val folders = listOf("root", "root/0", "root/1", "root/2")
        val mime = Arb.element(Document.MIME_TYPE_DIR, "application/octet-stream", "").orNull(0.2)
        val id = Arb.element(folders).orNull(0.1)
        val name = Arb.string(0..6).orNull(0.2)
        // Sizes the column type does not allow, too: MatrixCursor fails to read them, as providers may.
        val size = Arb.choice(Arb.long(-1L..10L), Arb.string(0..2), Arb.constant(byteArrayOf(1))).orNull(0.3)
        val row = Arb.bind(id, name, mime, size) { i, n, m, s -> listOf(i, n, m, s) }
        var listed = 0
        checkAll(Arb.list(Arb.list(row, 0..4), folders.size..folders.size)) { answers ->
            installDocuments { folder -> rows(*answers[folders.indexOf(folder)].toTypedArray()) }
            Folders(context)
                .files(tree, FolderDepth.SUBFOLDERS, DataFolders.NONE)
                .onRight { listed++ }
                .onLeft { it.unlisted().shouldBeInstanceOf<StorageFailure.Unavailable>() }
        }
        // About half the cases list something: the property is not only about failures.
        listed shouldBeGreaterThan 300
    }

    @Test
    fun `INV-E1-14 a folder holding more entries than a scan reads fails it, and rows past the limit are not read`() {
        var read = 0
        installDocuments {
            val files = Array(FolderWalk.MAX_ENTRIES + 50) { fileRow("root/$it.dds") }
            object : CursorWrapper(rows(*files)) {
                override fun moveToNext(): Boolean = super.moveToNext().also { if (it) read++ }
            }
        }
        Folders(context).files(tree, FolderDepth.TOP_LEVEL, DataFolders.NONE).shouldBeLeft() shouldBe
            WalkFailure.TooManyEntries(FolderWalk.MAX_ENTRIES, None, FolderWalk.MAX_ENTRIES + 1, None)
        read shouldBe FolderWalk.MAX_ENTRIES + 1
    }

    @Test
    fun `INV-E1-15 an emulator data folder is reported, never listed`() {
        val listed = mutableListOf<String>()
        installDocuments { folder -> rows(folderRow("root/MemCards"), fileRow("root/g.iso")).also { listed += folder } }
        val contents = Folders(context).files(tree, FolderDepth.SUBFOLDERS, testDataFolders).shouldBeRight()
        contents.skipped shouldBe listOf(SkippedFolder(FolderPath("MemCards"), SkipReason.EMULATOR_DATA))
        listed shouldBe listOf("root")
    }

    @Test
    fun `INV-E1-14 a scan reads at most one entry past the limit, over its sub-folders too`() {
        var read = 0
        installDocuments { folder ->
            val entries =
                if (folder ==
                    "root"
                ) {
                    Array(5_999) { fileRow("root/$it.dds") } + arrayOf(folderRow("root/s"))
                } else {
                    Array(6_000) { fileRow("root/s/$it") }
                }
            object : CursorWrapper(rows(*entries)) {
                override fun moveToNext(): Boolean = super.moveToNext().also { if (it) read++ }
            }
        }
        Folders(context).files(tree, FolderDepth.SUBFOLDERS, DataFolders.NONE).shouldBeLeft() shouldBe
            WalkFailure.TooManyEntries(FolderWalk.MAX_ENTRIES, None, 6_000, Some(FolderPath("s")))
        read shouldBe FolderWalk.MAX_ENTRIES + 1
    }

    @Test
    fun `INV-E1-12 a listing that ends before the provider's own count fails, as when the provider dies meanwhile`() {
        installDocuments {
            object : CursorWrapper(rows(fileRow("root/a.iso"), fileRow("root/b.iso"))) {
                override fun moveToNext(): Boolean = position < 0 && super.moveToNext()
            }
        }
        Folders(
            context,
        ).files(tree, FolderDepth.TOP_LEVEL, DataFolders.NONE).shouldBeLeft().unlisted().shouldBeInstanceOf<StorageFailure.Unavailable>()
    }

    private companion object {
        fun WalkFailure<StorageFailure>.unlisted(): StorageFailure = shouldBeInstanceOf<WalkFailure.Unlisted<StorageFailure>>().error
    }

    @Test
    fun `INV-E6-03 the access to the folders no platform uses is given up, the others kept`() {
        fun tree(name: String) = Uri.parse("content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2F$name")
        val trees = listOf("ps2", "gba", "gc").map(::tree)
        val folders = Folders(context)
        val kept = trees.map { folders.keepAccess(it).shouldBeRight().uri }
        folders.keepOnly(setOf(kept[1])).shouldBeRight() shouldBe 2
        context.contentResolver.persistedUriPermissions.map { it.uri } shouldBe listOf(trees[1])
        folders.keepOnly(setOf(kept[1])).shouldBeRight() shouldBe 0
    }
}
