// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import arrow.core.None
import arrow.core.Option
import arrow.core.Some

/**
 * The folder pick awaiting its activity result. A pick is answered exactly once: with its result,
 * when the picker cannot open, or when a newer pick replaces it. Not thread-safe: main thread only.
 */
internal class PendingPick<A>(private val answer: (requestId: Int, A) -> Unit) {
    private var current: Option<Int> = None

    /** Answers the pending pick with [replaced], then opens the picker; [open] returns the answer when it could not. */
    fun start(requestId: Int, replaced: A, open: () -> Option<A>) {
        current.onSome { answer(it, replaced) }
        current = Some(requestId)
        open().onSome { failed -> end().onSome { answer(it, failed) } }
    }

    /** Ends the pending pick, to be answered with its result; none when the result belongs to no pick of this process. */
    fun end(): Option<Int> = current.also { current = None }
}
