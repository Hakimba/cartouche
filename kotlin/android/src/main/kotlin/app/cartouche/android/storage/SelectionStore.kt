// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.SelectionFormat
import app.cartouche.core.shelves.SelectionUnreadable
import arrow.core.Either
import java.io.File

/** The selection file in the app's private storage, written through [AtomicFile] like the library. */
internal class SelectionStore(file: File) {
    private val atomic = AtomicFile(file)

    /** The stored selection, or an empty one when none was stored yet. */
    fun load(): Either<SelectionUnreadable, Selection> = atomic.read(Selection(), ::SelectionUnreadable, SelectionFormat::decode)

    fun save(selection: Selection): Either<StorageFailure, Unit> = atomic.write(SelectionFormat.encode(selection))
}
