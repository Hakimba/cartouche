// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.storage.StateUnreadable
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.right
import arrow.core.toOption
import java.io.File

/**
 * A small state in a file of its own in the app's private storage, read on first use and kept: a file that cannot be read is [empty],
 * told to [unreadable]. It is written through [AtomicFile] only when the state changes, and a state that cannot be written changes
 * nothing. Safe to use from several threads.
 */
internal class StateFile<T>(
    file: File,
    private val empty: T,
    private val decode: (String) -> Either<StateUnreadable, T>,
    private val encode: (T) -> String,
    private val unreadable: (StateUnreadable) -> Unit = {},
) {
    private val atomic = AtomicFile(file)

    private var value: Option<T> = None

    @Synchronized
    fun get(): T = value.getOrElse {
        atomic.read(empty, ::StateUnreadable, decode).getOrElse { problem -> empty.also { unreadable(problem) } }.also { value = Some(it) }
    }

    @Synchronized
    fun set(now: T): Either<StorageFailure, Unit> = if (now == get()) {
        Unit.right()
    } else {
        atomic.baseFile.parentFile.toOption().onSome { it.mkdirs() }
        atomic.write(encode(now)).map { value = Some(now) }
    }

    /** Deletes the file: the state is [empty] again. */
    @Synchronized
    fun clear() {
        atomic.delete()
        value = Some(empty)
    }
}

/** For a state whose format tells no reason when it cannot be read. */
internal fun <T> Option<T>.orUnreadable(): Either<StateUnreadable, T> = toEither { StateUnreadable("not in its format") }
