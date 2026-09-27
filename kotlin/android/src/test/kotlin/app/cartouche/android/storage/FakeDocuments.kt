// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.Manifest
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsProvider
import app.cartouche.core.ContentUri
import app.cartouche.core.uri
import org.robolectric.Robolectric

/**
 * A documents provider whose folders answer with [answer]: rows, no cursor (null) or an exception,
 * as third-party providers may. Installed with [installDocuments]; the Android types it
 * overrides are nullable, as the framework declares them.
 */
internal class FakeDocuments : DocumentsProvider() {
    var answer: (folderId: String) -> Cursor? = { rows() }

    override fun onCreate(): Boolean = true

    override fun queryRoots(projection: Array<out String>?): Cursor = MatrixCursor(emptyArray())

    override fun queryDocument(documentId: String?, projection: Array<out String>?): Cursor = rows()

    override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor? =
        answer(parentDocumentId)

    override fun openDocument(documentId: String?, mode: String?, signal: CancellationSignal?): ParcelFileDescriptor =
        throw UnsupportedOperationException("Folders never opens documents")

    override fun isChildDocument(parentDocumentId: String?, documentId: String?): Boolean = true
}

internal const val AUTHORITY = "app.cartouche.test.documents"

/** The picked folder [FakeDocuments] serves; its own document id is `root`. */
internal val TREE: ContentUri = uri("content://$AUTHORITY/tree/root")

internal val COLUMNS = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE)

/** Replaces the provider serving [AUTHORITY] with one answering [answer]. */
internal fun installDocuments(answer: (folderId: String) -> Cursor?) {
    val info =
        ProviderInfo().apply {
            authority = AUTHORITY
            exported = true
            grantUriPermissions = true
            readPermission = Manifest.permission.MANAGE_DOCUMENTS
            writePermission = Manifest.permission.MANAGE_DOCUMENTS
        }
    Robolectric.buildContentProvider(FakeDocuments::class.java).create(info).get().answer = answer
}

/** One row per `(id, name, mime type, size)`; any of them may be null, as providers send them. */
internal fun rows(vararg rows: List<Any?>, columns: Array<String> = COLUMNS): Cursor =
    MatrixCursor(columns).apply { rows.forEach { addRow(it.take(columns.size)) } }

/** The row of a file of [size] bytes. */
internal fun fileRow(id: String, size: Long = 1L): List<Any?> = listOf(id, id.substringAfterLast('/'), "application/octet-stream", size)

internal fun folderRow(id: String): List<Any?> = listOf(id, id.substringAfterLast('/'), Document.MIME_TYPE_DIR, null)
