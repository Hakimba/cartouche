// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import app.cartouche.android.trace
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.ListedFile
import app.cartouche.core.storage.DocumentId
import app.cartouche.core.storage.DocumentPaths
import app.cartouche.core.storage.VolumeId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.getOrElse
import arrow.core.raise.Raise
import arrow.core.raise.catch
import arrow.core.raise.either
import arrow.core.raise.ensureNotNull
import arrow.core.raise.option
import arrow.core.toOption

/** A folder the user granted through the system picker; [path] is none when it has no filesystem path. */
internal data class Folder(val uri: ContentUri, val name: String, val path: Option<FilePath>)

internal data class DocumentEntry(
    val name: FileName,
    val kind: EntryKind,
    val documentId: DocumentId,
    val uri: ContentUri,
    val path: Option<FilePath>,
    /** None when the provider does not report it. */
    val sizeBytes: Option<Long>,
)

internal enum class EntryKind { DIRECTORY, FILE }

internal sealed interface StorageFailure {
    data class Unavailable(val reason: String) : StorageFailure

    data class PermissionDenied(val reason: String) : StorageFailure

    val message: String
        get() =
            when (this) {
                is Unavailable -> "The folder cannot be read: $reason"
                is PermissionDenied -> "Access to the folder was denied or revoked: $reason"
            }
}

/**
 * Folder access through the Storage Access Framework. Cartouche never writes to ROM folders and
 * only keeps read access; the picker's own grant, which may include write, ends with the activity.
 * Every call is IPC with the documents provider and can take seconds on an SD card, so callers run
 * them off the main and render threads.
 */
internal class Folders(private val context: Context) {
    /** Keeps read access to a folder returned by the picker across reboots and app restarts. */
    fun keepAccess(treeUri: Uri): Either<StorageFailure, Folder> = guard {
        context.contentResolver.takePersistableUriPermission(treeUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        describe(treeUri, volumeRoots())
    }

    fun persisted(): Either<StorageFailure, List<Folder>> = guard {
        val roots = volumeRoots()
        context.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission && DocumentsContract.isTreeUri(it.uri) }
            .map { describe(it.uri, roots) }
    }

    /** Lists one level of [tree]: its root, or the sub-folder [documentId]. Nothing is filtered out. */
    fun list(tree: ContentUri, documentId: Option<DocumentId>): Either<StorageFailure, List<DocumentEntry>> = guard {
        entries(tree, documentId, volumeRoots())
    }

    /**
     * Every file of [tree], and with [FolderDepth.SUBFOLDERS] those of its sub-folders, except
     * hidden ones (`.Trash`) and those deeper than [MAX_DEPTH]. A sub-folder that cannot be read is
     * skipped, and traced; folders themselves are not listed.
     */
    fun files(tree: ContentUri, depth: FolderDepth): Either<StorageFailure, List<ListedFile>> = guard {
        val roots = volumeRoots()

        fun walk(entries: List<DocumentEntry>, level: Int): List<ListedFile> = entries.flatMap { entry ->
            when (entry.kind) {
                EntryKind.FILE -> listOf(ListedFile(entry.name, entry.uri, entry.path, entry.sizeBytes))
                EntryKind.DIRECTORY ->
                    if (depth == FolderDepth.TOP_LEVEL || entry.name.isHidden) {
                        emptyList()
                    } else if (level >= MAX_DEPTH) {
                        trace("scan") { "skipped ${entry.name.value}: deeper than $MAX_DEPTH folders" }
                        emptyList()
                    } else {
                        guard { entries(tree, Some(entry.documentId), roots) }.fold({ failure ->
                            trace("scan") { "skipped ${entry.name.value}: ${failure.message}" }
                            emptyList()
                        }) { walk(it, level + 1) }
                    }
            }
        }
        walk(entries(tree, None, roots), level = 1)
    }

    private fun Raise<StorageFailure>.entries(
        tree: ContentUri,
        folder: Option<DocumentId>,
        roots: Map<VolumeId, FilePath>,
    ): List<DocumentEntry> {
        val treeUri = Uri.parse(tree.value)
        val parent = folder.getOrElse { DocumentId(DocumentsContract.getTreeDocumentId(treeUri)) }
        return queryAll(DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parent.value), CHILD_COLUMNS)
            .getOrElse { raise(StorageFailure.Unavailable("the documents provider returned nothing (storage removed?)")) }
            .use { cursor ->
                val (idColumn, nameColumn, mimeColumn, sizeColumn) = CHILD_COLUMNS.map(cursor::getColumnIndexOrThrow)
                buildList {
                    while (cursor.moveToNext()) {
                        val id =
                            DocumentId(ensureNotNull(cursor.getString(idColumn)) { StorageFailure.Unavailable("a document has no id") })
                        add(
                            DocumentEntry(
                                name = FileName(cursor.getString(nameColumn).toOption().getOrElse { DocumentPaths.fallbackName(id) }),
                                kind = if (cursor.getString(mimeColumn) == Document.MIME_TYPE_DIR) EntryKind.DIRECTORY else EntryKind.FILE,
                                documentId = id,
                                uri = contentUri(DocumentsContract.buildDocumentUriUsingTree(treeUri, id.value)),
                                path = DocumentPaths.pathOf(treeUri.authority.orEmpty(), id, roots),
                                sizeBytes = if (cursor.isNull(sizeColumn)) None else Some(cursor.getLong(sizeColumn)),
                            ),
                        )
                    }
                }
            }
    }

    private fun Raise<StorageFailure>.describe(treeUri: Uri, roots: Map<VolumeId, FilePath>): Folder {
        val rootId = DocumentId(DocumentsContract.getTreeDocumentId(treeUri))
        val name =
            queryAll(DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId.value), arrayOf(Document.COLUMN_DISPLAY_NAME))
                .flatMap { cursor -> cursor.use { if (it.moveToFirst()) it.getString(0).toOption() else None } }
                .getOrElse { DocumentPaths.fallbackName(rootId) }
        return Folder(contentUri(treeUri), name, DocumentPaths.pathOf(treeUri.authority.orEmpty(), rootId, roots))
    }

    private fun Raise<StorageFailure>.contentUri(uri: Uri): ContentUri =
        ContentUri.parse(uri.toString()).getOrElse { raise(StorageFailure.Unavailable("$uri is not a content URI")) }

    /**
     * Queries every row of [uri]. The framework signals "no selection, default order" with nulls and
     * "provider unavailable" with a null cursor; both stay inside this function.
     */
    private fun queryAll(uri: Uri, projection: Array<String>): Option<Cursor> =
        context.contentResolver.query(uri, projection, null, null, null).toOption()

    private fun volumeRoots(): Map<VolumeId, FilePath> =
        context.getSystemService(StorageManager::class.java).toOption().fold({ emptyMap() }) { manager ->
            manager.storageVolumes
                .map { volume ->
                    option {
                        val id = if (volume.isPrimary) VolumeId.PRIMARY else VolumeId(ensureNotNull(volume.uuid))
                        id to FilePath(ensureNotNull(volume.directory).path)
                    }
                }.filterOption()
                .toMap()
        }

    /** Runs [block], mapping the documents provider's failures to typed ones; anything else is a bug and propagates. */
    private fun <T> guard(block: Raise<StorageFailure>.() -> T): Either<StorageFailure, T> = either {
        catch({ block() }) { e: RuntimeException ->
            raise(
                when (e) {
                    is SecurityException -> StorageFailure.PermissionDenied(e.toString())
                    // Malformed or stale URIs and document ids, removed storage, unsupported providers.
                    is IllegalArgumentException, is IllegalStateException, is UnsupportedOperationException ->
                        StorageFailure.Unavailable(e.toString())
                    else -> throw e
                },
            )
        }
    }

    private companion object {
        /** Deep enough for any ROM layout, shallow enough never to exhaust the stack. */
        const val MAX_DEPTH = 8

        val CHILD_COLUMNS =
            arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE)
    }
}
