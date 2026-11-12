// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.Candidate
import arrow.core.Either
import arrow.core.Option
import kotlinx.coroutines.delay
import java.io.File

/** What a staged server answers: its [status] and its [body], if any. */
internal class Served(val status: Int, val body: Option<ByteArray>)

/**
 * Servers as a test stages them: [answer] by URL, each request taking [latency] of the test clock,
 * so that requests overlap in virtual time. It keeps every URL asked, when each request started
 * (by [now]) and how many were under way at most at once.
 */
internal class FakeHttp(private val latency: Long = 1_000, var answer: (String) -> Either<Unanswered, Served>) : Http {
    var now: () -> Long = { 0 }
    val asked = mutableListOf<String>()
    val startedAt = mutableListOf<Long>()
    var underWay = 0
    var mostAtOnce = 0

    /** Called once a body is given, before the request ends. */
    var during: () -> Unit = {}

    override suspend fun get(url: String, progress: Progress, body: Sink): Either<Unanswered, Answer> {
        asked += url
        startedAt += now()
        underWay++
        mostAtOnce = maxOf(mostAtOnce, underWay)
        try {
            delay(latency)
            return answer(url).map { served ->
                val kept = body.use { sink -> served.body.isSome { sink.take(it, it.size) } }
                during()
                Answer(served.status, kept)
            }
        } finally {
            underWay--
        }
    }
}

/** The bytes downloaded, read from the file they were downloaded into. */
internal suspend fun downloaded(get: suspend (File) -> Either<FetchFailure, Unit>): Either<FetchFailure, ByteArray> {
    val image = File.createTempFile("image", ".part")
    try {
        return get(image).map { image.readBytes() }
    } finally {
        image.delete()
    }
}

internal suspend fun ScreenScraperFetch.get(texture: Candidate.Texture, progress: Progress): Either<FetchFailure, ByteArray> =
    downloaded { get(texture, progress, it) }

internal suspend fun HttpFetch.get(url: ArtUrl, progress: Progress): Either<FetchFailure, ByteArray> = downloaded { get(url, progress, it) }
