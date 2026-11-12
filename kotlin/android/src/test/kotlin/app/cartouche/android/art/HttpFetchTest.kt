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
import java.io.File
import java.net.ServerSocket
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
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
    fun `INV-17 only a 404 or a 410 is an image the server will never give, any other answer is tried again later`() = runBlocking<Unit> {
        (300..599).forEach { status ->
            val gone = status == 404 || status == 410
            HttpFetch.failureFor(status) shouldBe (if (gone) FetchFailure.NotFound else FetchFailure.Refused(status))
        }
        fetch.get(serve("/busy", 503), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.Refused(503)
        fetch.get(serve("/missing", 404), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
        fetch.get(serve("/forbidden", 403), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.Refused(403)
    }

    @Test
    fun `an image is downloaded whole up to the largest size, and one byte more is not downloaded`() = runBlocking<Unit> {
        val largest = ByteArray(Http.LARGEST_BYTES) { it.toByte() }
        fetch.get(serve("/largest", body = largest), Progress.NONE).shouldBeRight() shouldBe largest
        fetch.get(serve("/larger", body = largest + 1), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.NotFound
        val file = File.createTempFile("larger", ".part")
        try {
            fetch.get(serve("/larger", body = largest + ByteArray(Http.LARGEST_BYTES)), Progress.NONE, file).shouldBeLeft()
            (file.length() <= Http.LARGEST_BYTES) shouldBe true
        } finally {
            file.delete()
        }
    }

    @Test
    fun `an image that cannot be written on the device is a storage failure, never the network's`() = runBlocking<Unit> {
        val nowhere = File(File.createTempFile("gone", ".d").also(File::delete), "image.part")
        fetch.get(serve("/image", body = ByteArray(1024)), Progress.NONE, nowhere).shouldBeLeft() shouldBe FetchFailure.Unstored
    }

    @Test
    fun `an answer with no error page to read, a redirect not followed, closes its connection`() = runBlocking<Unit> {
        val closed = CompletableFuture<Boolean>()
        thread {
            server.accept().use { client ->
                client.getInputStream().bufferedReader().let { request ->
                    generateSequence { request.readLine() }.takeWhile { it.isNotEmpty() }.count()
                }
                client.getOutputStream().apply {
                    write("HTTP/1.1 301 Moved\r\nLocation: ftp://127.0.0.1/a.png\r\nContent-Length: 5\r\n\r\nmoved".encodeToByteArray())
                    flush()
                }
                client.soTimeout = 3_000
                closed.complete(runCatching { client.getInputStream().read() == -1 }.getOrElse { false })
            }
        }
        fetch.get(ArtUrl("http://127.0.0.1:${server.localPort}/moved"), Progress.NONE).shouldBeLeft() shouldBe FetchFailure.Refused(301)
        closed.get(10, TimeUnit.SECONDS) shouldBe true
    }

    @Test
    fun `INV-19 a server that cannot be reached is offline, for the failure's class alone, never its message`() = runBlocking<Unit> {
        val closed = ServerSocket(0).use { it.localPort }
        fetch.get(ArtUrl("http://127.0.0.1:$closed/a.png?devpassword=DEVSECRET42"), Progress.NONE).shouldBeLeft() shouldBe
            FetchFailure.Offline("ConnectException")
    }
}
