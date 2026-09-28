// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import arrow.core.Either
import arrow.core.Option
import arrow.core.Some
import arrow.core.left
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/** Why an image could not be downloaded. */
internal sealed interface FetchFailure {
    /** The server has no such image, or will not give it: the next source is tried. */
    data object NotFound : FetchFailure

    /** The server could not be reached: no network, or a network that goes nowhere. */
    data class Offline(val reason: String) : FetchFailure

    /** The server answered with [status], busy (a quota) or failing: tried again later. */
    data class Refused(val status: Int) : FetchFailure
}

/** Downloads one image; the port the scraper downloads through. */
internal fun interface Fetch {
    /** Blocks until the image at [url] is downloaded or fails. */
    fun get(url: ArtUrl): Either<FetchFailure, ByteArray>
}

/**
 * [Fetch] over HTTP, naming Cartouche to the server as [userAgent]. Only a busy or failing server
 * (408, 429, 5xx) is tried again later; any other answer than the image, a redirect it does not
 * follow included, is taken for an image it will never give. An image over [LARGEST_BYTES] is not
 * downloaded.
 */
internal class HttpFetch(private val userAgent: String) : Fetch {
    override fun get(url: ArtUrl): Either<FetchFailure, ByteArray> = try {
        val connection = URL(url.value).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = CONNECT_MS
            connection.readTimeout = READ_MS
            connection.setRequestProperty("User-Agent", userAgent)
            when (val status = connection.responseCode) {
                HttpURLConnection.HTTP_OK -> connection.inputStream.use(::readAtMost).toEither { FetchFailure.NotFound }
                else -> failureFor(status).left()
            }
        } finally {
            connection.disconnect()
        }
    } catch (e: IOException) {
        FetchFailure.Offline(e.toString()).left()
    }

    companion object {
        /** What an answer other than the image means: a server busy or failing, or an image it will never give. */
        fun failureFor(status: Int): FetchFailure =
            if (status == HttpURLConnection.HTTP_CLIENT_TIMEOUT || status == TOO_MANY_REQUESTS || status in SERVER_ERRORS) {
                FetchFailure.Refused(status)
            } else {
                FetchFailure.NotFound
            }

        /** The whole body, when it is no larger than [LARGEST_BYTES]. */
        private fun readAtMost(body: InputStream): Option<ByteArray> {
            val read = ByteArrayOutputStream()
            val buffer = ByteArray(BUFFER_BYTES)
            var count = body.read(buffer)
            while (count >= 0 && read.size() <= LARGEST_BYTES) {
                read.write(buffer, 0, count)
                count = body.read(buffer)
            }
            return Some(read.toByteArray()).filter { it.size <= LARGEST_BYTES }
        }

        const val LARGEST_BYTES = 16 * 1024 * 1024
        private const val CONNECT_MS = 10_000
        private const val READ_MS = 30_000
        private const val BUFFER_BYTES = 64 * 1024
        private const val TOO_MANY_REQUESTS = 429
        private val SERVER_ERRORS = 500..599
    }
}
