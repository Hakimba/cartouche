// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import arrow.core.None
import arrow.core.Option
import arrow.core.Some

/**
 * A system pick awaiting its activity result, answered exactly once: with its result, when the picker cannot open,
 * or when a newer pick replaces it. Main thread only.
 */
internal class PendingPick<A>(private val answer: (requestId: Int, A) -> Unit) {
    private var current: Option<Int> = None

    /** Answers the pending pick with [replaced], then opens the picker; [open] returns the answer when it could not. */
    fun start(requestId: Int, replaced: A, open: () -> Option<A>) {
        current.onSome { answer(it, replaced) }
        current = Some(requestId)
        open().onSome { failed -> end().onSome { answer(it, failed) } }
    }

    /** None when the result belongs to no pick of this process. */
    fun end(): Option<Int> = current.also { current = None }
}
