// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Test
import java.net.ServerSocket
import kotlin.concurrent.thread

class HttpFetchTest {
    private val fetch = HttpFetch("Cartouche test")
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

    @After
    fun stopped() = server.close()

    @Test
    fun `INV-E4-05 only a busy or failing server is tried again later, any other answer is an image it will never give`() =
        runBlocking<Unit> {
            checkAll(Arb.int(300..599)) { status ->
                val busy = status == 408 || status == 429 || status >= 500
                HttpFetch.failureFor(status) shouldBe (if (busy) FetchFailure.Refused(status) else FetchFailure.NotFound)
            }
            fetch.get(serve("/busy", 503)).shouldBeLeft() shouldBe FetchFailure.Refused(503)
            fetch.get(serve("/missing", 404)).shouldBeLeft() shouldBe FetchFailure.NotFound
            fetch.get(serve("/forbidden", 403)).shouldBeLeft() shouldBe FetchFailure.NotFound
        }

    @Test
    fun `an image is downloaded whole up to the largest size, and one byte more is not downloaded`() {
        val largest = ByteArray(HttpFetch.LARGEST_BYTES) { it.toByte() }
        fetch.get(serve("/largest", 200, largest)).shouldBeRight() shouldBe largest
        fetch.get(serve("/larger", 200, largest + 1)).shouldBeLeft() shouldBe FetchFailure.NotFound
    }

    @Test
    fun `a redirect to another protocol is an image it will never give`() {
        fetch.get(serve("/moved", 301, headers = mapOf("Location" to "ftp://127.0.0.1/a.png"))).shouldBeLeft() shouldBe
            FetchFailure.NotFound
    }

    @Test
    fun `a server that cannot be reached is offline`() {
        val closed = ServerSocket(0).use { it.localPort }
        fetch.get(ArtUrl("http://127.0.0.1:$closed/a.png")).shouldBeLeft().shouldBeInstanceOf<FetchFailure.Offline>()
    }
}
