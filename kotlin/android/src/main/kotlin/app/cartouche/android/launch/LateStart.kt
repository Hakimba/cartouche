// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import app.cartouche.android.trace
import app.cartouche.core.launch.StartDeadline
import arrow.core.Either
import arrow.core.left
import kotlin.time.TimeMark

/** Runs [start] unless the [deadline] of the request made at [asked] has passed: nothing starts, and the caller is told it is too late. */
internal inline fun StartDeadline.startInTime(asked: TimeMark, start: () -> Either<LaunchFailure, Unit>): Either<LaunchFailure, Unit> =
    if (allows(asked.elapsedNow())) {
        start()
    } else {
        trace("launch") { "refused: asked ${asked.elapsedNow()} ago, too late for the screen that waited" }
        LaunchFailure.TooLate.left()
    }
