// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.library.Arrivals
import app.cartouche.core.library.ArrivalsFormat
import app.cartouche.core.library.ArrivalsUnreadable
import arrow.core.Either
import java.io.File

/** The file of the games not seen yet in the app's private storage, written through [AtomicFile] like the library. */
internal class ArrivalsStore(file: File) {
    private val atomic = AtomicFile(file)

    /** The stored arrivals, or none when none was stored yet. */
    fun load(): Either<ArrivalsUnreadable, Arrivals> = atomic.read(Arrivals(), ::ArrivalsUnreadable, ArrivalsFormat::decode)

    fun save(arrivals: Arrivals): Either<StorageFailure, Unit> = atomic.write(ArrivalsFormat.encode(arrivals))
}
