// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import arrow.core.Either
import kotlinx.coroutines.delay

/**
 * Servers as a test stages them: [answer] by URL, each request taking [latency] of the test clock,
 * so that requests overlap in virtual time. It keeps every URL asked, when each request started
 * (by [now]) and how many were under way at most at once.
 */
internal class FakeHttp(private val latency: Long = 1_000, var answer: (String) -> Either<Unanswered, Answer>) : Http {
    var now: () -> Long = { 0 }
    val asked = mutableListOf<String>()
    val startedAt = mutableListOf<Long>()
    var underWay = 0
    var mostAtOnce = 0

    override suspend fun get(url: String, progress: Progress): Either<Unanswered, Answer> {
        asked += url
        startedAt += now()
        underWay++
        mostAtOnce = maxOf(mostAtOnce, underWay)
        try {
            delay(latency)
            return answer(url)
        } finally {
            underWay--
        }
    }
}
