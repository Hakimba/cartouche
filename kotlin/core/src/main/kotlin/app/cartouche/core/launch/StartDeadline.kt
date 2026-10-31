// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import arrow.core.Option
import arrow.core.Some
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

/**
 * How long after a start was asked it may still begin. The one who asked gives up waiting then and shows its screen again:
 * an emulator started later would open over a screen that is no longer waiting for it.
 */
@JvmInline
public value class StartDeadline private constructor(private val within: Duration) {
    /** Whether a start [elapsed] after it was asked is still wanted; one exactly at the deadline is not. */
    public fun allows(elapsed: Duration): Boolean = elapsed < within

    public companion object {
        public fun ofMillis(milliseconds: Int): Option<StartDeadline> =
            Some(milliseconds).filter { it >= 0 }.map { StartDeadline(it.milliseconds) }
    }
}
