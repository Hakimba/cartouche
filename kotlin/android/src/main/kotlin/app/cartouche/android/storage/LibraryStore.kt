// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryError
import app.cartouche.core.library.LibraryFormat
import app.cartouche.core.library.StoredLibrary
import arrow.core.Either
import java.io.File

/**
 * The library file in the app's private storage. Writes go through [AtomicFile], so an interrupted write leaves the
 * previous library intact.
 */
internal class LibraryStore(private val file: File) {
    private val atomic = AtomicFile(file)

    /** The stored library, or an empty one when none was stored yet. */
    fun load(): Either<LibraryError, StoredLibrary> =
        atomic.read(StoredLibrary(Library(), LibraryFormat.VERSION), LibraryError::Unreadable, LibraryFormat::decode)

    /** Moves an unreadable library file aside (next to it, named after the time), so that saving a new library does not destroy it. */
    fun setAside(): Boolean = file.renameTo(File("${file.path}.unreadable-${System.currentTimeMillis()}"))

    fun save(library: Library): Either<StorageFailure, Unit> = atomic.write(LibraryFormat.encode(library))
}
