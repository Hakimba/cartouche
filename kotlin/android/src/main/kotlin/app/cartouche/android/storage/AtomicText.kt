// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import arrow.core.Either
import arrow.core.flatMap
import arrow.core.raise.catch
import arrow.core.raise.either
import arrow.core.right
import java.io.File
import java.io.IOException

/** Replaces the file with [text] in one step: an interrupted write leaves the previous content intact. */
internal fun AtomicFile.write(text: String): Either<StorageFailure, Unit> = write(text.encodeToByteArray())

/** Replaces the file with [bytes] in one step: an interrupted write leaves the previous content, or no file, never part of [bytes]. */
internal fun AtomicFile.write(bytes: ByteArray): Either<StorageFailure, Unit> = either {
    val out = catch({ startWrite() }) { e: IOException -> raise(StorageFailure.Unavailable(e.toString())) }
    catch({
        out.write(bytes)
        finishWrite(out)
    }) { e: IOException ->
        failWrite(out)
        raise(StorageFailure.Unavailable(e.toString()))
    }
}

/** What the file holds, [decode]d; [empty] when nothing was ever written. */
internal fun <E, T> AtomicFile.read(empty: T, unreadable: (String) -> E, decode: (String) -> Either<E, T>): Either<E, T> =
    if (isWritten) Either.catch { readFully().decodeToString() }.mapLeft { unreadable(it.toString()) }.flatMap(decode) else empty.right()

/** Whether a write ever completed; [AtomicFile.exists] needs Android 12. A backup is left by a write interrupted on Android 11. */
private val AtomicFile.isWritten: Boolean get() = baseFile.exists() || File(baseFile.path + ".bak").exists()
