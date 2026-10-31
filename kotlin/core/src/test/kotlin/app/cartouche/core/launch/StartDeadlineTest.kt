// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import arrow.core.None
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.negativeInt
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.time.Duration.Companion.milliseconds

class StartDeadlineTest {
    private val within100 = StartDeadline.ofMillis(100).shouldBeSome()

    @Test
    fun `INV-21 a start just before its deadline is allowed, at it or after it refused`() {
        within100.allows(99.milliseconds) shouldBe true
        within100.allows(100.milliseconds) shouldBe false
        within100.allows(101.milliseconds) shouldBe false
    }

    @Test
    fun `INV-21 a start is allowed exactly while it is less than the deadline after it was asked`() = runBlocking<Unit> {
        checkAll(Arb.int(0..Int.MAX_VALUE), Arb.int(0..Int.MAX_VALUE)) { within, elapsed ->
            StartDeadline.ofMillis(within).shouldBeSome().allows(elapsed.milliseconds) shouldBe (elapsed < within)
        }
    }

    @Test
    fun `a negative deadline is no deadline`() = runBlocking<Unit> {
        checkAll(Arb.negativeInt()) { StartDeadline.ofMillis(it) shouldBe None }
    }
}
