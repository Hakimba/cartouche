// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import arrow.core.Option
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Test
import java.net.ServerSocket
import kotlin.concurrent.thread
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.TestTimeSource

class HttpFetchTest {
    private val fetch = HttpFetch(JavaHttp("Cartouche test"))
    private val server = ServerSocket(0)

    /** Answers the next request with [status], [headers] and [body]. */
    private fun serve(path: String, status: Int, body: ByteArray = ByteArray(0), headers: Map<String, String> = emptyMap()): ArtUrl {
        thread {
            server.accept().use { client ->
                client.getInputStream().bufferedReader().let { request ->
                    generateSequence { request.readLine() }.takeWhile { it.isNotEmpty() }.count()
                }
                val head = headers.entries.joinToString("") { "${it.key}: ${it.value}\r\n" }
                client.getOutputStream().apply {
                    write("HTTP/1.1 $status Status\r\n${head}Content-Length: ${body.size}\r\nConnection: close\r\n\r\n".encodeToByteArray())
                    write(body)
                    flush()
                }
            }
        }
        return ArtUrl("http://127.0.0.1:${server.localPort}$path")
    }

    /** Answers the next request with [body] in [chunks] pieces, flushed apart, with its length when [sized]. */
    private fun serveInChunks(body: ByteArray, chunks: Int, sized: Boolean): ArtUrl {
        thread {
            server.accept().use { client ->
                client.getInputStream().bufferedReader().let { request ->
                    generateSequence { request.readLine() }.takeWhile { it.isNotEmpty() }.count()
                }
                val length = if (sized) "Content-Length: ${body.size}\r\n" else ""
                client.getOutputStream().apply {
                    write("HTTP/1.1 200 OK\r\n${length}Connection: close\r\n\r\n".encodeToByteArray())
                    body.asList().chunked(body.size / chunks).forEach {
                        write(it.toByteArray())
                        flush()
                        Thread.sleep(5)
                    }
                }
            }
        }
        return ArtUrl("http://127.0.0.1:${server.localPort}/chunked")
    }

    @After
    fun stopped() = server.close()

    @Test
    fun `INV-E11-09 a download tells how far it has come, never back, up to its whole size, and an unknown size as such`() =
        runBlocking<Unit> {
            val body = ByteArray(256 * 1024) { it.toByte() }
            val sized = mutableListOf<Option<Double>>()
            fetch.get(serveInChunks(body, 16, sized = true)) { sized += it }.shouldBeRight() shouldBe body
            val fractions = sized.map { it.shouldBeSome() }
            fractions.size shouldBeGreaterThan 2
            fractions shouldBe fractions.sorted()
            fractions.all { it in 0.0..1.0 } shouldBe true
            fractions.last() shouldBe 1.0
            val unsized = mutableListOf<Option<Double>>()
            fetch.get(serveInChunks(body, 16, sized = false)) { unsized += it }.shouldBeRight() shouldBe body
            unsized.shouldNotBeEmpty()
            unsized.all { it.isNone() } shouldBe true
        }

    @Test
    fun `INV-E11-09 progress is told at most every 100 ms, the first at once`() = runBlocking<Unit> {
        checkAll(Arb.list(Arb.long(0L..250L), 0..40)) { gaps ->
            val times = gaps.runningFold(0L, Long::plus)
            val clock = TestTimeSource()
            val told = mutableListOf<Option<Double>>()
            val paced = Paced({ told += it }, clock)
            times.forEachIndexed { i, time ->
                if (i > 0) clock += (time - times[i - 1]).milliseconds
                paced.read(Some(i.toDouble()))
            }
            // The model: told when none was, or when the last one told is 100 ms old or more.
            val expected =
                times.indices.fold(emptyList<Int>()) { kept, i ->
                    if (kept.isEmpty() ||
                        times[i] - times[kept.last()] >= 100
                    ) {
                        kept + i
                    } else {
                        kept
                    }
                }
            told shouldBe expected.map { Some(it.toDouble()) }
        }
    }

    @Test
    fun `INV-E4-05 only a busy or failing server is tried again later, any other answer is an image it will never give`() =
        runBlocking<Unit> {
            checkAll(Arb.int(300..599)) { status ->
                val busy = status == 408 || status == 429 || status >= 500
                HttpFetch.failureFor(status) shouldBe (if (busy) FetchFailure.Refused(status) else FetchFailure.NotFound)
            }
            fetch.get(serve("/busy", 503), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.Refused(503)
            fetch.get(serve("/missing", 404), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
            fetch.get(serve("/forbidden", 403), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
        }

    @Test
    fun `an image is downloaded whole up to the largest size, and one byte more is not downloaded`() = runBlocking<Unit> {
        val largest = ByteArray(Http.LARGEST_BYTES) { it.toByte() }
        fetch.get(serve("/largest", 200, largest), Progress.NONE).shouldBeRight() shouldBe largest
        fetch.get(serve("/larger", 200, largest + 1), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
    }

    @Test
    fun `a redirect to another protocol is an image it will never give`() = runBlocking<Unit> {
        fetch.get(serve("/moved", 301, headers = mapOf("Location" to "ftp://127.0.0.1/a.png")), Progress.NONE).shouldBeLeft() shouldBe
            FetchFailure.NotFound
    }

    @Test
    fun `INV-E11-06 a server that cannot be reached is offline, for the failure's class alone, never its message`() = runBlocking<Unit> {
        val closed = ServerSocket(0).use { it.localPort }
        fetch.get(ArtUrl("http://127.0.0.1:$closed/a.png?devpassword=DEVSECRET42"), Progress.NONE).shouldBeLeft() shouldBe
            FetchFailure.Offline("ConnectException")
    }
}
