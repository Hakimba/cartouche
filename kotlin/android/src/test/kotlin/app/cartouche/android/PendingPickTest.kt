// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import arrow.core.None
import arrow.core.Some
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class PendingPickTest {
    private enum class Event { PICK_OPENS, PICK_FAILS_TO_OPEN, RESULT }

    @Test
    fun `INV-E0-15 every folder pick is answered exactly once`() = runBlocking<Unit> {
        checkAll(Arb.list(Arb.element(Event.entries))) { events ->
            val answered = mutableListOf<Pair<Int, String>>()
            val pick = PendingPick<String> { id, answer -> answered += id to answer }
            events.forEachIndexed { id, event ->
                when (event) {
                    Event.PICK_OPENS -> pick.start(id, "replaced") { None }
                    Event.PICK_FAILS_TO_OPEN -> pick.start(id, "replaced") { Some("failed") }
                    Event.RESULT -> pick.end().onSome { answered += it to "result" }
                }
            }
            pick.end().onSome { answered += it to "result" }
            // A pick that opened is ended by whatever comes next: a result, a newer pick, or the final end().
            val expected =
                events.indices.filter { events[it] != Event.RESULT }.associateWith { i ->
                    when {
                        events[i] == Event.PICK_FAILS_TO_OPEN -> "failed"
                        events.getOrElse(i + 1) { Event.RESULT } == Event.RESULT -> "result"
                        else -> "replaced"
                    }
                }
            answered.groupBy({ it.first }, { it.second }) shouldBe expected.mapValues { listOf(it.value) }
        }
    }
}
