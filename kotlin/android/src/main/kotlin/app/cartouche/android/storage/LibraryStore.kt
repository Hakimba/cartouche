// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryError
import app.cartouche.core.library.LibraryFormat
import arrow.core.Either
import arrow.core.flatMap
import arrow.core.raise.catch
import arrow.core.raise.either
import java.io.File
import java.io.IOException

/**
 * The library file in the app's private storage. Writes go through [AtomicFile], so an interrupted
 * write leaves the previous library intact.
 */
internal class LibraryStore(private val file: File) {
    private val atomic = AtomicFile(file)

    /** The stored library, or an empty one when none was stored yet. */
    fun load(): Either<LibraryError, Library> = if (!file.exists() && !File(file.path + ".bak").exists()) {
        Either.Right(Library())
    } else {
        Either
            .catch { atomic.readFully().decodeToString() }
            .mapLeft {
                LibraryError.Unreadable(
                    it.toString(),
                )
            }.flatMap(LibraryFormat::decode)
    }

    /** Moves an unreadable library file aside (next to it, named after the time), so that saving a new library does not destroy it. */
    fun setAside(): Boolean = file.renameTo(File("${file.path}.unreadable-${System.currentTimeMillis()}"))

    fun save(library: Library): Either<StorageFailure, Unit> = either {
        val out = catch({ atomic.startWrite() }) { e: IOException -> raise(StorageFailure.Unavailable(e.toString())) }
        catch({
            out.write(LibraryFormat.encode(library).encodeToByteArray())
            atomic.finishWrite(out)
        }) { e: IOException ->
            atomic.failWrite(out)
            raise(StorageFailure.Unavailable(e.toString()))
        }
    }
}
