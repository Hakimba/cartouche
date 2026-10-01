// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.CursorIndexOutOfBoundsException
import android.database.SQLException
import android.database.StaleDataException
import android.net.Uri
import android.os.BadParcelableException
import android.os.Bundle
import android.os.OperationCanceledException
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import app.cartouche.android.trace
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.FolderContents
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.FolderEntry
import app.cartouche.core.library.FolderWalk
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.WalkFailure
import app.cartouche.core.storage.DocumentId
import app.cartouche.core.storage.DocumentPaths
import app.cartouche.core.storage.FolderPlace
import app.cartouche.core.storage.VolumeId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.raise.Raise
import arrow.core.raise.catch
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.ensureNotNull
import arrow.core.raise.option
import arrow.core.toOption

/**
 * A folder the user granted through the system picker; [path] is none when it has no filesystem path,
 * [place] when its provider is not the device's storage.
 */
internal data class Folder(val uri: ContentUri, val name: String, val path: Option<FilePath>, val place: Option<FolderPlace> = None)

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

private val DocumentEntry.asFolderEntry: FolderEntry
    get() =
        when (kind) {
            EntryKind.DIRECTORY -> FolderEntry.Folder(name, documentId)
            EntryKind.FILE -> FolderEntry.File(ListedFile(name, uri, path, sizeBytes))
        }

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

    /** Gives up the access kept to the folders not in [used] (a platform removed or moved, a pick given up); answers how many. */
    fun keepOnly(used: Set<ContentUri>): Either<StorageFailure, Int> = guard {
        context.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission && DocumentsContract.isTreeUri(it.uri) && contentUri(it.uri) !in used }
            .onEach { context.contentResolver.releasePersistableUriPermission(it.uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            .size
    }

    /** Lists one level of [tree]: its root, or the sub-folder [documentId]. Nothing is filtered out. */
    fun list(tree: ContentUri, documentId: Option<DocumentId>): Either<StorageFailure, List<DocumentEntry>> = guard {
        entries(tree, documentId, volumeRoots())
    }

    /** The files of [tree] and, with [FolderDepth.SUBFOLDERS], of its sub-folders, as [FolderWalk] finds them. */
    fun files(tree: ContentUri, depth: FolderDepth, dataFolders: DataFolders): Either<WalkFailure<StorageFailure>, FolderContents> =
        guard { volumeRoots() }.mapLeft { WalkFailure.Unlisted(it) }.flatMap { roots ->
            FolderWalk.files(depth, dataFolders) { folder, atMost ->
                // The walk reports a sub-folder it cannot list without its reason: the log keeps it.
                guard { entries(tree, folder, roots, atMost).map(DocumentEntry::asFolderEntry) }.onLeft { failure ->
                    folder.onSome { trace("scan") { "cannot list ${it.value}: ${failure.message}" } }
                }
            }
        }

    /** Whether [document] is still there: providers answer a document that is gone, or on removed storage, with no row. */
    fun exists(document: ContentUri): Either<StorageFailure, Boolean> = guard {
        queryAll(Uri.parse(document.value), arrayOf(Document.COLUMN_DOCUMENT_ID)).isSome { cursor -> cursor.use { it.moveToFirst() } }
    }

    private fun Raise<StorageFailure>.entries(
        tree: ContentUri,
        folder: Option<DocumentId>,
        roots: Map<VolumeId, FilePath>,
        /** Rows past one more than this are not read: the caller only needs to know there are more. */
        atMost: Int = Int.MAX_VALUE,
    ): List<DocumentEntry> {
        val treeUri = Uri.parse(tree.value)
        val parent = folder.getOrElse { DocumentId(DocumentsContract.getTreeDocumentId(treeUri)) }
        return queryAll(DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parent.value), CHILD_COLUMNS)
            .getOrElse { raise(StorageFailure.Unavailable("the documents provider returned nothing (storage removed?)")) }
            .use { cursor ->
                val columns = CHILD_COLUMNS.map(cursor::getColumnIndexOrThrow)
                val rows = buildList { while (size <= atMost && cursor.moveToNext()) add(entry(cursor, columns, treeUri, roots)) }
                // Across processes, a window the provider can no longer fill only makes the cursor end early.
                ensure(rows.size > atMost || rows.size == cursor.count) {
                    StorageFailure.Unavailable("the documents provider sent ${rows.size} of ${cursor.count} entries")
                }
                rows
            }
    }

    private fun Raise<StorageFailure>.entry(
        cursor: Cursor,
        columns: List<Int>,
        treeUri: Uri,
        roots: Map<VolumeId, FilePath>,
    ): DocumentEntry {
        val (idColumn, nameColumn, mimeColumn, sizeColumn) = columns
        val id = DocumentId(ensureNotNull(cursor.getString(idColumn)) { StorageFailure.Unavailable("a document has no id") })
        return DocumentEntry(
            name = FileName(cursor.getString(nameColumn).toOption().getOrElse { DocumentPaths.fallbackName(id) }),
            kind = if (cursor.getString(mimeColumn) == Document.MIME_TYPE_DIR) EntryKind.DIRECTORY else EntryKind.FILE,
            documentId = id,
            uri = contentUri(DocumentsContract.buildDocumentUriUsingTree(treeUri, id.value)),
            path = DocumentPaths.pathOf(treeUri.authority.orEmpty(), id, roots),
            sizeBytes = if (cursor.isNull(sizeColumn)) None else Some(cursor.getLong(sizeColumn)),
        )
    }

    private fun Raise<StorageFailure>.describe(treeUri: Uri, roots: Map<VolumeId, FilePath>): Folder {
        val rootId = DocumentId(DocumentsContract.getTreeDocumentId(treeUri))
        val name =
            queryAll(DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId.value), arrayOf(Document.COLUMN_DISPLAY_NAME))
                .flatMap { cursor -> cursor.use { if (it.moveToFirst()) it.getString(0).toOption() else None } }
                .getOrElse { DocumentPaths.fallbackName(rootId) }
        val authority = treeUri.authority.orEmpty()
        return Folder(contentUri(treeUri), name, DocumentPaths.pathOf(authority, rootId, roots), DocumentPaths.placeOf(authority, rootId))
    }

    private fun Raise<StorageFailure>.contentUri(uri: Uri): ContentUri =
        ContentUri.parse(uri.toString()).getOrElse { raise(StorageFailure.Unavailable("$uri is not a content URI")) }

    /**
     * Queries every row of [uri]. On Android the selection form of `query` only wraps this one;
     * Robolectric reaches a `DocumentsProvider` through this one alone, which the tests need. The
     * framework signals "no arguments" with nulls and "provider unavailable" with a null cursor;
     * both stay inside this function.
     */
    private fun queryAll(uri: Uri, projection: Array<String>): Option<Cursor> =
        context.contentResolver.query(uri, projection, null as Bundle?, null).toOption()

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
                    // Malformed or stale URIs and document ids, removed storage, unsupported providers, and
                    // the other exceptions a provider's answer carries across processes (Parcel.writeException).
                    is IllegalArgumentException, is IllegalStateException, is UnsupportedOperationException,
                    is NullPointerException, is BadParcelableException,
                    // Reading a row a provider filled wrongly (a blob), or a listing it cancelled.
                    is SQLException, is OperationCanceledException,
                    is StaleDataException, is CursorIndexOutOfBoundsException,
                    ->
                        StorageFailure.Unavailable(e.toString())
                    else -> throw e
                },
            )
        }
    }

    private companion object {
        val CHILD_COLUMNS =
            arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE)
    }
}
