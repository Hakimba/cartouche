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
import arrow.core.getOrElse
import arrow.core.left
import arrow.core.right
import arrow.core.toOption
import kotlinx.coroutines.delay
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.TimeMark
import kotlin.time.TimeSource

/** Why an image could not be downloaded. */
internal sealed interface FetchFailure {
    /** The server has no such image (a 404 or a 410, or one too large to keep): the next source is tried. */
    data object NotFound : FetchFailure

    /**
     * The server could not be reached: no network, or a network that goes nowhere; [reason] is the failure's class,
     * never its message.
     */
    data class Offline(val reason: String) : FetchFailure

    /** The server answered with [status], busy (a quota), failing or refusing for now: tried again later. */
    data class Refused(val status: Int) : FetchFailure

    /** ScreenScraper is not taking requests, in [state]: the next image is tried at once, and the label found after it is provisional. */
    data class Skipped(val state: ScreenScraperState) : FetchFailure

    /** The image came but could not be written on the device (no room, its folder gone): tried again later. */
    data object Unstored : FetchFailure
}

/** How far an image's download has come, told as each piece of it is read. */
internal fun interface Progress {
    /** [fraction] of the image's bytes read, from 0 to 1; none when the server does not tell its size. */
    fun read(fraction: Option<Double>)

    companion object {
        val NONE = Progress {}
    }
}

/** Downloads one image; the port the scraper and the downloads of a game's images for the chooser go through. */
internal fun interface Fetch {
    /** Returns once [candidate]'s image is downloaded into [image] or fails, telling [progress] how far it has come. */
    suspend fun get(candidate: Candidate, progress: Progress, image: File): Either<FetchFailure, Unit>
}

/** Why a server gave no answer at all. */
internal sealed interface Unanswered {
    /** [reason] is the failure's class only: its message may hold the URL, and so the credentials. */
    data class Offline(val reason: String) : Unanswered

    data object TimedOut : Unanswered
}

/** A server's answer: its [status], and whether its body is [kept] whole by the sink it was given, as it is only when the status is 200. */
internal class Answer(val status: Int, val kept: Boolean)

/** Where a body goes as it is read; closed once it ends. */
internal interface Sink : Closeable {
    /** Takes the next [count] bytes of [bytes]; false, taking nothing, once the body is more than this sink keeps. */
    fun take(bytes: ByteArray, count: Int): Boolean

    override fun close() {}
}

/** A body kept in memory, [limit] bytes at most: an answer that is not an image, which may echo its URL, never reaches the disk. */
internal class MemorySink(private val limit: Int) : Sink {
    private val kept = ByteArrayOutputStream()

    override fun take(bytes: ByteArray, count: Int): Boolean = (kept.size() + count <= limit).also { if (it) kept.write(bytes, 0, count) }

    fun bytes(): ByteArray = kept.toByteArray()
}

/**
 * An image's body written to [file] as it comes, never held whole in memory, [Http.LARGEST_BYTES] at most; [unstored]
 * once the file cannot be written, a failure of the device's and not of the network.
 */
internal class FileSink(private val file: File) : Sink {
    private var written = 0L
    private var out: Option<OutputStream> = None

    var unstored = false
        private set

    override fun take(bytes: ByteArray, count: Int): Boolean = !unstored &&
        written + count <= Http.LARGEST_BYTES &&
        stored {
            out.getOrElse { file.outputStream().also { opened -> out = Some(opened) } }.write(bytes, 0, count)
            written += count
        }

    override fun close() {
        out.onSome { stored(it::close) }
    }

    private fun stored(write: () -> Unit): Boolean = try {
        write()
        true
    } catch (e: IOException) {
        unstored = true
        false
    }
}

/** The HTTP transport every source is reached through; the port the tests replace. */
internal fun interface Http {
    /**
     * Returns once [url] answers, its body given to [body], or the server cannot be reached or does not answer in
     * time, telling [progress] how far its body has come.
     */
    suspend fun get(url: String, progress: Progress, body: Sink): Either<Unanswered, Answer>

    companion object {
        const val LARGEST_BYTES = 16 * 1024 * 1024
    }
}

/**
 * A redirect to another protocol is not followed. A body goes to its sink as it is read; an error's is read to its
 * end, up to [DRAINED_BYTES], so that its connection is reused. Each chunk of a body waits [chunkDelay] more (debug
 * builds' `--art-slow`, to see a download's progress).
 */
internal class JavaHttp(private val userAgent: String, private val chunkDelay: Duration = Duration.ZERO) : Http {
    override suspend fun get(url: String, progress: Progress, body: Sink): Either<Unanswered, Answer> = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = CONNECT_MS
        connection.readTimeout = READ_MS
        connection.setRequestProperty("User-Agent", userAgent)
        val status = connection.responseCode
        if (status == HttpURLConnection.HTTP_OK) {
            val size = Some(connection.contentLengthLong).filter { it > 0 }
            Answer(status, body.use { sink -> connection.inputStream.use { taken(it, size, progress, sink) } }).right()
        } else {
            // Without a page to read (a redirect not followed), nothing would ever close the connection.
            connection.errorStream.toOption().fold(connection::disconnect) { it.use(::drained) }
            Answer(status, kept = false).right()
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

        /** An error's body is a page at most: one longer is not worth reading for its connection. */
        const val DRAINED_BYTES = 64 * 1024
    }

    /** Whether [sink] took the whole body, of [size] bytes when the server tells it; [progress] told as it is read. */
    private suspend fun taken(body: InputStream, size: Option<Long>, progress: Progress, sink: Sink): Boolean {
        val buffer = ByteArray(BUFFER_BYTES)
        var read = 0L
        var count = body.read(buffer)
        while (count >= 0) {
            if (!sink.take(buffer, count)) return false
            read += count
            progress.read(size.map { minOf(1.0, read.toDouble() / it) })
            delay(chunkDelay)
            count = body.read(buffer)
        }
        return true
    }

    private fun drained(body: InputStream) {
        val buffer = ByteArray(BUFFER_BYTES)
        var read = 0
        var count = body.read(buffer)
        while (count >= 0 && read < DRAINED_BYTES) {
            read += count
            count = body.read(buffer)
        }
    }
}

/** Tells [progress] what it is told at most once every [EVERY] of [clock]: one per look at a game's label, whatever it downloads. */
internal class Paced(private val progress: Progress, private val clock: TimeSource) : Progress {
    private var told: Option<TimeMark> = None

    override fun read(fraction: Option<Double>) {
        if (!told.isSome { it.elapsedNow() < EVERY }) {
            told = Some(clock.markNow())
            progress.read(fraction)
        }
    }

    companion object {
        /** Ten times a second at most: enough for a ring to fill smoothly, nothing per byte. */
        val EVERY = 100.milliseconds
    }
}

/**
 * Scans over [http]. Only a 404 or a 410 is taken for an image the server will never give; any other
 * answer than the image (busy, failing, refusing, a redirect it does not follow, a network's sign-in
 * page) is tried again later; a server not answering in time is as one out of reach.
 */
internal class HttpFetch(private val http: Http) {
    suspend fun get(url: ArtUrl, progress: Progress, image: File): Either<FetchFailure, Unit> {
        val body = FileSink(image)
        return http
            .get(url.value, progress, body)
            .mapLeft { unanswered ->
                when (unanswered) {
                    is Unanswered.Offline -> FetchFailure.Offline(unanswered.reason)
                    Unanswered.TimedOut -> FetchFailure.Offline("no answer in time")
                }
            }.flatMap { answer ->
                when {
                    answer.status != HttpURLConnection.HTTP_OK -> failureFor(answer.status).left()
                    body.unstored -> FetchFailure.Unstored.left()
                    answer.kept -> Unit.right()
                    else -> FetchFailure.NotFound.left()
                }
            }
    }

    companion object {
        /** What an answer other than the image means: an image the server will never give, or one it does not give now. */
        fun failureFor(status: Int): FetchFailure = if (status in NOT_THERE) FetchFailure.NotFound else FetchFailure.Refused(status)

        private val NOT_THERE = setOf(HttpURLConnection.HTTP_NOT_FOUND, HttpURLConnection.HTTP_GONE)
    }
}
