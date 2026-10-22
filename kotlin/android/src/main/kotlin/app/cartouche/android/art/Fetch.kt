// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.ScreenScraperState
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.flatMap
import arrow.core.left
import arrow.core.right
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

/** Why an image could not be downloaded. */
internal sealed interface FetchFailure {
    /** The server has no such image, or will not give it: the next source is tried. */
    data object NotFound : FetchFailure

    /** The server could not be reached: no network, or a network that goes nowhere; [reason] is the failure's class, never its message. */
    data class Offline(val reason: String) : FetchFailure

    /** The server answered with [status], busy (a quota) or failing: tried again later. */
    data class Refused(val status: Int) : FetchFailure

    /** ScreenScraper is not taking requests, in [state]: the next image is tried at once, and the label found after it is provisional. */
    data class Skipped(val state: ScreenScraperState) : FetchFailure
}

/** Downloads one image; the port the scraper and the downloads of a game's images for the chooser go through. */
internal fun interface Fetch {
    /** Returns once [candidate]'s image is downloaded or fails. */
    suspend fun get(candidate: Candidate): Either<FetchFailure, ByteArray>
}

/** Why a server gave no answer at all. */
internal sealed interface Unanswered {
    /** [reason] names the failure's class only: its message may hold the URL, and so the credentials (INV-E11-06). */
    data class Offline(val reason: String) : Unanswered

    data object TimedOut : Unanswered
}

/** A server's answer: its [status], and its [body] when the status is 200 and it is no larger than [Http.LARGEST_BYTES]. */
internal class Answer(val status: Int, val body: Option<ByteArray>)

/** The HTTP transport every source is reached through; the port the tests replace. */
internal fun interface Http {
    /** Returns once [url] answers, or the server cannot be reached or does not answer in time. */
    suspend fun get(url: String): Either<Unanswered, Answer>

    companion object {
        const val LARGEST_BYTES = 16 * 1024 * 1024
    }
}

/** [Http] over the platform's connections, naming Cartouche to the server as [userAgent]; a redirect to another protocol is not followed. */
internal class JavaHttp(private val userAgent: String) : Http {
    override suspend fun get(url: String): Either<Unanswered, Answer> = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = CONNECT_MS
            connection.readTimeout = READ_MS
            connection.setRequestProperty("User-Agent", userAgent)
            val status = connection.responseCode
            Answer(status, if (status == HttpURLConnection.HTTP_OK) connection.inputStream.use(::readAtMost) else None).right()
        } finally {
            connection.disconnect()
        }
    } catch (e: SocketTimeoutException) {
        Unanswered.TimedOut.left()
    } catch (e: IOException) {
        Unanswered.Offline(e.javaClass.simpleName).left()
    }

    private companion object {
        const val CONNECT_MS = 10_000
        const val READ_MS = 30_000
        const val BUFFER_BYTES = 64 * 1024

        /** The whole body, when it is no larger than [Http.LARGEST_BYTES]. */
        fun readAtMost(body: InputStream): Option<ByteArray> {
            val read = ByteArrayOutputStream()
            val buffer = ByteArray(BUFFER_BYTES)
            var count = body.read(buffer)
            while (count >= 0 && read.size() <= Http.LARGEST_BYTES) {
                read.write(buffer, 0, count)
                count = body.read(buffer)
            }
            return Some(read.toByteArray()).filter { it.size <= Http.LARGEST_BYTES }
        }
    }
}

/**
 * Scans over [http]. Only a busy or failing server (408, 429, 5xx) is tried again later; any other
 * answer than the image, a redirect it does not follow included, is taken for an image it will
 * never give; a server not answering in time is as one out of reach.
 */
internal class HttpFetch(private val http: Http) {
    suspend fun get(url: ArtUrl): Either<FetchFailure, ByteArray> = http
        .get(url.value)
        .mapLeft { unanswered ->
            when (unanswered) {
                is Unanswered.Offline -> FetchFailure.Offline(unanswered.reason)
                Unanswered.TimedOut -> FetchFailure.Offline("no answer in time")
            }
        }.flatMap { answer ->
            if (answer.status ==
                HttpURLConnection.HTTP_OK
            ) {
                answer.body.toEither { FetchFailure.NotFound }
            } else {
                failureFor(answer.status).left()
            }
        }

    companion object {
        /** What an answer other than the image means: a server busy or failing, or an image it will never give. */
        fun failureFor(status: Int): FetchFailure =
            if (status == HttpURLConnection.HTTP_CLIENT_TIMEOUT || status == TOO_MANY_REQUESTS || status in SERVER_ERRORS) {
                FetchFailure.Refused(status)
            } else {
                FetchFailure.NotFound
            }

        private const val TOO_MANY_REQUESTS = 429
        private val SERVER_ERRORS = 500..599
    }
}
