// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import arrow.core.Option
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Test
import java.net.ServerSocket
import kotlin.concurrent.thread

class HttpFetchTest {
    private val fetch = HttpFetch(JavaHttp("Cartouche test"))
    private val server = ServerSocket(0)

    /** Answers the next request with [status], [headers] and [body], whose length is told unless [sized] is false. */
    private fun serve(
        path: String,
        status: Int = 200,
        body: ByteArray = ByteArray(0),
        headers: Map<String, String> = emptyMap(),
        sized: Boolean = true,
    ): ArtUrl {
        thread {
            server.accept().use { client ->
                client.getInputStream().bufferedReader().let { request ->
                    generateSequence { request.readLine() }.takeWhile { it.isNotEmpty() }.count()
                }
                val head = headers.entries.joinToString("") { "${it.key}: ${it.value}\r\n" }
                val length = if (sized) "Content-Length: ${body.size}\r\n" else ""
                client.getOutputStream().apply {
                    write("HTTP/1.1 $status Status\r\n$head${length}Connection: close\r\n\r\n".encodeToByteArray())
                    write(body)
                    flush()
                }
            }
        }
        return ArtUrl("http://127.0.0.1:${server.localPort}$path")
    }

    @After
    fun stopped() = server.close()

    @Test
    fun `a download tells how far it has come, never back, up to its whole size, and an unknown size as such`() = runBlocking<Unit> {
        val body = ByteArray(256 * 1024) { it.toByte() }
        val sized = mutableListOf<Option<Double>>()
        fetch.get(serve("/sized", body = body)) { sized += it }.shouldBeRight() shouldBe body
        val fractions = sized.map { it.shouldBeSome() }
        fractions.size shouldBeGreaterThan 2
        fractions shouldBe fractions.sorted()
        fractions.all { it in 0.0..1.0 } shouldBe true
        fractions.last() shouldBe 1.0
        val unsized = mutableListOf<Option<Double>>()
        fetch.get(serve("/unsized", body = body, sized = false)) { unsized += it }.shouldBeRight() shouldBe body
        unsized.shouldNotBeEmpty()
        unsized.all { it.isNone() } shouldBe true
    }

    @Test
    fun `INV-17 only a busy or failing server is tried again later, any other answer is an image it will never give`() = runBlocking<Unit> {
        (300..599).forEach { status ->
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
        fetch.get(serve("/largest", body = largest), Progress.NONE).shouldBeRight() shouldBe largest
        fetch.get(serve("/larger", body = largest + 1), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
    }

    @Test
    fun `INV-19 a server that cannot be reached is offline, for the failure's class alone, never its message`() = runBlocking<Unit> {
        val closed = ServerSocket(0).use { it.localPort }
        fetch.get(ArtUrl("http://127.0.0.1:$closed/a.png?devpassword=DEVSECRET42"), Progress.NONE).shouldBeLeft() shouldBe
            FetchFailure.Offline("ConnectException")
    }
}
