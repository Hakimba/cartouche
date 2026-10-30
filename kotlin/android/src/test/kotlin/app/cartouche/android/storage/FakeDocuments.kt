// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.Manifest
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.DocumentsProvider
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.library.ListedFile
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.io.FileNotFoundException

/**
 * A documents provider whose folders' children are the rows [answer] gives for a folder's id, and
 * whose documents are the rows [document] gives for a document's id: rows, no cursor (null) or an
 * exception, as third-party providers may; a document that is gone throws
 * [java.io.FileNotFoundException], which `DocumentsProvider` turns into no cursor, as Android's
 * own providers do. A document opens as [open] gives it for its id and the mode asked (by default
 * it is not found); each mode asked is kept in [opened], each descriptor handed out in
 * [descriptors]. Installed with [installDocuments]; the Android types it overrides are nullable,
 * as the framework declares them.
 */
internal class FakeDocuments : DocumentsProvider() {
    var answer: (folderId: String) -> Cursor? = { rows() }
    var document: (documentId: String) -> Cursor? = { rows() }
    var open: (documentId: String, mode: String) -> ParcelFileDescriptor = { id, _ -> throw FileNotFoundException(id) }
    val opened: MutableList<String> = mutableListOf()
    val descriptors: MutableList<ParcelFileDescriptor> = mutableListOf()

    override fun onCreate(): Boolean = true

    override fun queryRoots(projection: Array<out String>?): Cursor = MatrixCursor(emptyArray())

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor? = document(documentId)

    override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor? =
        answer(parentDocumentId)

    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor {
        opened += mode
        return open(documentId, mode).also { descriptors += it }
    }

    override fun isChildDocument(parentDocumentId: String?, documentId: String?): Boolean = true
}

/** A folder [name] of the memory card, as the external storage provider's picker grants it. */
internal fun cardTree(name: String): Uri = Uri.parse("content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2F$name")

internal const val AUTHORITY = "app.cartouche.test.documents"

/** The picked folder [FakeDocuments] serves; its own document id is `root`. */
internal val TREE: ContentUri = uri("content://$AUTHORITY/tree/root")

internal val COLUMNS =
    arrayOf(
        Document.COLUMN_DOCUMENT_ID,
        Document.COLUMN_DISPLAY_NAME,
        Document.COLUMN_MIME_TYPE,
        Document.COLUMN_SIZE,
        Document.COLUMN_LAST_MODIFIED,
    )

/** Replaces the provider serving [AUTHORITY] with one answering [document] and [answer]; answers it. */
internal fun installDocuments(
    document: (documentId: String) -> Cursor? = { rows() },
    answer: (folderId: String) -> Cursor?,
): FakeDocuments {
    val info =
        ProviderInfo().apply {
            authority = AUTHORITY
            exported = true
            grantUriPermissions = true
            readPermission = Manifest.permission.MANAGE_DOCUMENTS
            writePermission = Manifest.permission.MANAGE_DOCUMENTS
        }
    return Robolectric.buildContentProvider(FakeDocuments::class.java).create(info).get().also {
        it.answer = answer
        it.document = document
    }
}

/** One row per `(id, name, mime type, size, last modified)`; any of them may be null or left out, as providers send them. */
internal fun rows(vararg rows: List<Any?>, columns: Array<String> = COLUMNS): Cursor =
    MatrixCursor(columns).apply { rows.forEach { row -> addRow(List(columns.size) { row.getOrNull(it) }) } }

/** The row of a file of [size] bytes, last changed at [modified]. */
internal fun fileRow(id: String, size: Long = 1L, modified: Long = 0L): List<Any?> =
    listOf(id, id.substringAfterLast('/'), "application/octet-stream", size, modified)

internal fun folderRow(id: String): List<Any?> = listOf(id, id.substringAfterLast('/'), Document.MIME_TYPE_DIR, null)

/** Serves [files] by document id, each opened in the mode asked, as a provider of real files does. */
internal fun FakeDocuments.serving(files: Map<String, File>): FakeDocuments = apply {
    open = { id, mode -> ParcelFileDescriptor.open(files.getValue(id), ParcelFileDescriptor.parseMode(mode)) }
}

/** A file holding [bytes], to be served as document [id]. */
internal fun documentFile(id: String, bytes: ByteArray): File = File(RuntimeEnvironment.getApplication().cacheDir, "documents/$id").apply {
    parentFile?.mkdirs()
    writeBytes(bytes)
}

/** Document [id] of [TREE], as a scan lists it, of [size] bytes. */
internal fun listedDocument(id: String, size: Long): ListedFile =
    ListedFile(FileName(id.substringAfterLast('/')), documentUri(id), None, Some(size))

internal fun documentUri(id: String): ContentUri = uri(DocumentsContract.buildDocumentUriUsingTree(Uri.parse(TREE.value), id).toString())

/** Disc image [name] of the core's file readers' tests, made by `scripts/file_fixtures.py`; its SYSTEM.CNF boots [DISC_SERIAL]. */
internal fun discImage(name: String): ByteArray =
    checkNotNull(FakeDocuments::class.java.getResourceAsStream("/files/$name")) { "No disc image $name" }.use { it.readBytes() }

internal const val DISC_SERIAL = "SLES_524.95"

/** A GameCube disc's first bytes: its ID, `GKYP01`, then nothing. */
internal val gameCubeDisc: ByteArray = "GKYP01".toByteArray() + ByteArray(1024)

/** A NES cartridge's iNES header, which No-Intro's prints leave out. */
internal val INES_HEADER: ByteArray = byteArrayOf(0x4E, 0x45, 0x53, 0x1A) + ByteArray(12)
