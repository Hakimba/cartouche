// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import app.cartouche.core.launch.StartDeadline
import arrow.core.Either
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.TestTimeSource

@RunWith(RobolectricTestRunner::class)
class LateStartTest {
    private val deadline = StartDeadline.ofMillis(4_500).shouldBeSome()
    private var starts = 0

    /** Asks a start, then lets [wait] milliseconds pass before it gets to run. */
    private fun startedAfter(wait: Long): Either<LaunchFailure, Unit> {
        val clock = TestTimeSource()
        val asked = clock.markNow()
        clock += wait.milliseconds
        return deadline.startInTime(asked) { Unit.right().also { starts++ } }
    }

    @Test
    fun `INV-21 a start whose deadline has passed starts nothing and is told it is too late`() {
        startedAfter(4_500).shouldBeLeft() shouldBe LaunchFailure.TooLate
        starts shouldBe 0
    }

    @Test
    fun `a start in time begins`() {
        startedAfter(4_499).shouldBeRight()
        starts shouldBe 1
    }
}
