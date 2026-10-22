// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.BuildConfig
import app.cartouche.core.art.Closure
import app.cartouche.core.art.Day
import app.cartouche.core.art.Moment
import app.cartouche.core.art.Refusal
import app.cartouche.core.art.ScreenScraperAnswer
import app.cartouche.core.art.ScreenScraperState
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.lastOrNone
import arrow.core.left
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import io.kotest.matchers.string.shouldStartWith
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.shadows.ShadowLog
import java.io.File
import java.net.HttpURLConnection
import java.net.URLDecoder
import app.cartouche.core.art.texture as candidateTexture

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ScreenScraperFetchTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
    private val stateFile = File(folder, "screenscraper.json")
    private val key = Credentials("cartouche-dev", "DEVSECRET42", "Cartouche", None)
    private val member = Member("someone", "MEMBERSECRET42")
    private val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3)
    private val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 9)

    private fun texture(game: Int, media: String = "support-texture(eu)") = candidateTexture(58, game, media, "Europe")

    private fun ok(body: ByteArray) = Answer(HttpURLConnection.HTTP_OK, Some(body)).right()

    private fun status(code: Int) = Answer(code, None).right()

    private fun limits(threads: Int, perMinute: Int) =
        ok("""{"response":{"ssuser":{"maxthreads":"$threads","maxrequestspermin":"$perMinute"}}}""".encodeToByteArray())

    /** A fetch on [scope]'s clock, whose day changes every [DAY] of it, told the states it goes through. */
    private class Harness(folder: File, credentials: Credentials, http: FakeHttp, val scope: TestScope) {
        /** Each state ScreenScraper went into, with the clock's time then. */
        val states = mutableListOf<Pair<Long, ScreenScraperState>>()
        val now = { scope.testScheduler.currentTime }
        val fetch = ScreenScraperFetch(http, credentials, File(folder, "screenscraper.json"), now, { day(now()) }) { states += now() to it }

        init {
            http.now = now
        }
    }

    private val answers: Arb<(String) -> Either<Unanswered, Answer>> =
        Arb.choice(
            Arb.constant { _ -> ok(png) },
            Arb.constant { _ -> ok(jpeg) },
            Arb.constant { _ -> ok("NOMEDIA".encodeToByteArray()) },
            Arb.constant { _ -> ok(ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray()) },
            Arb.element(401, 423, 429, 430, 431, 500).map { code -> { _: String -> status(code) } },
            Arb.element(430, 431).map { code -> { _: String -> status(code) } },
            Arb.constant { _ -> Unanswered.TimedOut.left() },
            Arb.constant { _ -> Unanswered.Offline("no network").left() },
        )

    /** A member's threads, or no member. */
    private val members: Arb<Option<Int>> = Arb.choice(Arb.constant(None), Arb.int(1..4).map { Some(it) })

    @Test
    fun `INV-E11-05 no more requests than allowed at once or per minute, none after a spent quota until the next day, restarts included`() =
        runBlocking<Unit> {
            var closed = 0
            var paced = 0
            checkAll(60, Arb.list(answers, 1..12), members, Arb.int(1..6), Arb.int(1..6)) { script, threads, perMinute, requests ->
                folder.deleteRecursively()
                ShadowLog.clear()
                val scope = TestScope(StandardTestDispatcher())
                var served = 0
                val http =
                    FakeHttp { url ->
                        if ("ssuserInfos" in url) {
                            threads.fold({ status(HttpURLConnection.HTTP_FORBIDDEN) }) { limits(it, perMinute) }
                        } else {
                            script[served++ % script.size](url)
                        }
                    }
                val credentials = key.copy(member = if (threads.isSome()) Some(member) else None)
                val harness = Harness(folder, credentials, http, scope)
                var restartFrom = 0
                var restartTo = 0
                // Several games' textures asked for together, a run a day for three days, the answers consumed in the script's order.
                repeat(3) { day ->
                    scope.launch { harness.fetch.newRun() }
                    repeat(requests) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
                    scope.advanceUntilIdle()
                    if (day == 0) {
                        // Restarted the same day: a closure until a day and an off state are remembered, and still answer
                        // nothing; open again, the member's account is checked anew, then the image asked for.
                        val again = Harness(folder, credentials, http, scope)
                        val closed =
                            harness.states.lastOrNone().isSome { (_, state) ->
                                state is ScreenScraperState.ClosedUntil || state is ScreenScraperState.Off
                            }
                        again.fetch.open shouldBe !closed
                        restartFrom = http.asked.size
                        scope.launch { again.fetch.get(texture(9), Progress.NONE) }
                        scope.advanceUntilIdle()
                        restartTo = http.asked.size
                        (restartTo - restartFrom) shouldBe (
                            if (closed) {
                                0
                            } else if (threads.isSome()) {
                                2
                            } else {
                                1
                            }
                        )
                    }
                    scope.advanceTimeBy(DAY - scope.testScheduler.currentTime % DAY)
                    scope.runCurrent()
                }
                val allowed = threads.getOrElse { 1 }
                http.mostAtOnce shouldBeLessThanOrEqual allowed
                if (http.mostAtOnce == allowed && allowed > 1) paced++
                val images = http.asked.indices.filter { "mediaJeu" in http.asked[it] }
                http.asked.forEach { url ->
                    url shouldStartWith "https://api.screenscraper.fr/api2/"
                    (url.contains("mediaJeu.php?") || url.contains("ssuserInfos.php?")) shouldBe true
                }
                // Each instance spends the member's minute allowance on its account check and its images;
                // the window lives in memory, so a restart starts it anew.
                if (threads.isSome()) {
                    fun withinMinute(times: List<Long>) {
                        times.forEach { from ->
                            times.count { it in from..(from + 59_999) } shouldBeLessThanOrEqual perMinute
                        }
                    }
                    listOf(
                        http.startedAt.take(restartFrom) + http.startedAt.drop(restartTo),
                        http.startedAt.subList(restartFrom, restartTo),
                    ).forEach(::withinMinute)
                }
                // Nothing sent after a spent quota until the next day.
                harness.states.forEach { (at, state) ->
                    if (state is ScreenScraperState.ClosedUntil) {
                        images.filter { http.startedAt[it] > at }.forEach { (day(http.startedAt[it]) >= state.day) shouldBe true }
                        closed++
                    }
                }
                // INV-E11-06: no file written, no line traced holds a password.
                folder.walk().filter(File::isFile).forEach { file ->
                    val text = file.readText()
                    text shouldNotContain "DEVSECRET42"
                    text shouldNotContain "MEMBERSECRET42"
                    text shouldNotContain "devpassword"
                }
                ShadowLog.getLogs().map { it.msg }.forEach { line ->
                    line shouldNotContain "DEVSECRET42"
                    line shouldNotContain "MEMBERSECRET42"
                    line shouldNotContain "sspassword"
                }
            }
            closed shouldBeGreaterThan 10
            paced shouldBeGreaterThan 5
        }

    @Test
    fun `INV-E11-04 an image is asked for as the table names it, with the key and the member, and never which game a file is`() {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { url -> if ("ssuserInfos" in url) limits(6, 7168) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        val got = scope.async { harness.fetch.get(texture(195388, "support-texture(jp)[2]"), Progress.NONE) }
        scope.advanceUntilIdle()
        got.getCompleted().shouldBeRight() shouldBe png
        val (account, image) = http.asked
        account shouldStartWith "https://api.screenscraper.fr/api2/ssuserInfos.php?"
        image shouldStartWith "https://api.screenscraper.fr/api2/mediaJeu.php?"
        val query =
            image.substringAfter('?').split('&').associate {
                it.substringBefore('=') to
                    URLDecoder.decode(it.substringAfter('='), "UTF-8")
            }
        query shouldBe
            mapOf(
                "devid" to "cartouche-dev",
                "devpassword" to "DEVSECRET42",
                "softname" to "Cartouche",
                "ssid" to "someone",
                "sspassword" to "MEMBERSECRET42",
                "systemeid" to "58",
                "jeuid" to "195388",
                "media" to "support-texture(jp)[2]",
                "maxwidth" to "1024",
                "maxheight" to "1024",
            )
        http.asked.none { "jeuInfos" in it || "jeuRecherche" in it } shouldBe true
        // The requests of a run are counted as the next begins; the credentials print without their passwords.
        scope.launch { harness.fetch.newRun() }
        scope.runCurrent()
        if (BuildConfig.DEBUG) ShadowLog.getLogs().map { it.msg }.filter { "2 requests in the last run" in it }.shouldNotBeEmpty()
        "${key.copy(member = Some(member))}" shouldBe "Credentials(cartouche-dev, Cartouche, Option.Some(Member(someone)))"
    }

    @Test
    fun `a refused member leaves the key alone, one request at a time, and is not sent again`() {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { url -> if ("ssuserInfos" in url) status(HttpURLConnection.HTTP_FORBIDDEN) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 1
        http.asked.filter { "mediaJeu" in it }.forEach { it shouldNotContain "ssid=" }
        http.mostAtOnce shouldBe 1
        // Traces are debug builds' alone.
        if (BuildConfig.DEBUG) ShadowLog.getLogs().map { it.msg }.filter { "account" in it }.shouldNotBeEmpty()
    }

    @Test
    fun `an account answer saying nothing of the member keeps them, counts for the state, and is asked again at the next request`() {
        val scope = TestScope(StandardTestDispatcher())
        var checks = 0
        val http = FakeHttp { url -> if ("ssuserInfos" in url) (if (checks++ == 0) status(500) else limits(3, 100)) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        scope.launch { harness.fetch.get(texture(1), Progress.NONE) }
        scope.advanceUntilIdle()
        // The failing server closes the run as any request's would: the texture is skipped without a request.
        harness.states.map { it.second } shouldBe listOf(ScreenScraperState.ClosedForRun(Closure.UNREADABLE))
        http.asked.count { "mediaJeu" in it } shouldBe 0
        scope.launch { harness.fetch.newRun() }
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 2
        http.asked.filter { "mediaJeu" in it }.forEach { it shouldContain "ssid=someone" }
        http.mostAtOnce shouldBe 3
    }

    @Test
    fun `the developer's login text on the account check turns ScreenScraper off, and a member of level 0 is refused`() {
        val scope = TestScope(StandardTestDispatcher())
        val wrongKey = FakeHttp { url -> if ("ssuserInfos" in url) ok(ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray()) else ok(png) }
        val off = Harness(folder, key.copy(member = Some(member)), wrongKey, scope)
        val got = scope.async { off.fetch.get(texture(1), Progress.NONE) }
        scope.advanceUntilIdle()
        got.getCompleted().shouldBeLeft(FetchFailure.Skipped(ScreenScraperState.Off(Refusal.WRONG_KEY)))
        wrongKey.asked.size shouldBe 1
        folder.deleteRecursively()
        val level0 = """{"response":{"ssuser":{"maxthreads":"6","maxrequestspermin":"7168","niveau":"0"}}}"""
        val refused = FakeHttp { url -> if ("ssuserInfos" in url) ok(level0.encodeToByteArray()) else ok(png) }
        val keyAlone = Harness(folder, key.copy(member = Some(member)), refused, scope)
        repeat(3) { i -> scope.launch { keyAlone.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        refused.asked.count { "ssuserInfos" in it } shouldBe 1
        refused.asked.filter { "mediaJeu" in it }.forEach { it shouldNotContain "ssid=" }
        refused.mostAtOnce shouldBe 1
    }

    @Test
    fun `an answer is an image only when its bytes are one, no image means not found, and anything else skips the texture`() {
        val scope = TestScope(StandardTestDispatcher())
        var body: Either<Unanswered, Answer> = ok(png)
        val http = FakeHttp { body }
        val harness = Harness(folder, key, http, scope)

        fun got(answer: Either<Unanswered, Answer>): Either<FetchFailure, ByteArray> {
            body = answer
            val got = scope.async { harness.fetch.get(texture(1), Progress.NONE) }
            scope.advanceUntilIdle()
            return got.getCompleted()
        }
        got(ok(png)).shouldBeRight() shouldBe png
        got(ok(jpeg)).shouldBeRight() shouldBe jpeg
        got(ok("NOMEDIA".encodeToByteArray())).shouldBeLeft(FetchFailure.NotFound)
        val unreadable = FetchFailure.Skipped(ScreenScraperState.ClosedForRun(Closure.UNREADABLE))
        got(ok("<html>not an image</html>".encodeToByteArray())).shouldBeLeft(unreadable)
        // Closed for the run: the next texture is skipped without a request, until a new run.
        got(ok(png)).shouldBeLeft(unreadable)
        val before = http.asked.size
        scope.launch { harness.fetch.newRun() }
        scope.runCurrent()
        got(ok(png)).shouldBeRight()
        http.asked.size shouldBe before + 1
        got(status(430)).shouldBeLeft(FetchFailure.Skipped(ScreenScraperState.ClosedUntil(day(DAY))))
        stateFile.readText() shouldContain "2026-10-19"
        got(
            ok(ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray()),
        ).shouldBeLeft(FetchFailure.Skipped(ScreenScraperState.ClosedUntil(day(DAY))))
        ScreenScraperFetch.read(Answer(200, None)) shouldBe ScreenScraperAnswer.Unreadable
        ScreenScraperFetch.read(Answer(404, None)) shouldBe ScreenScraperAnswer.Status(404)
    }

    @Test
    fun `a wrong key turns ScreenScraper off, every texture skipped without a request, across restarts until the key changes`() {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { ok(ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray()) }
        val harness = Harness(folder, key, http, scope)
        val got = mutableListOf<Either<FetchFailure, ByteArray>>()
        repeat(3) { i -> scope.launch { got += harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        got.forEach { it.shouldBeLeft(FetchFailure.Skipped(ScreenScraperState.Off(Refusal.WRONG_KEY))) }
        http.asked.size shouldBe 1
        harness.fetch.open shouldBe false
        // INV-E11-06: the off state is kept for the key as a hash, never the key.
        stateFile.readText() shouldNotContain "DEVSECRET42"
        stateFile.readText() shouldNotContain "cartouche-dev"
        val again = Harness(folder, key, http, scope)
        again.fetch.open shouldBe false
        scope.launch { again.fetch.get(texture(9), Progress.NONE) }
        scope.advanceUntilIdle()
        http.asked.size shouldBe 1
        Harness(folder, key.copy(devPassword = "NEWSECRET"), http, scope).fetch.open shouldBe true
    }

    @Test
    fun `a busy server makes the next request wait the back-off, and a server out of reach closes the run, never stalling it`() {
        val scope = TestScope(StandardTestDispatcher())
        var body: Either<Unanswered, Answer> = status(429)
        val http = FakeHttp { body }
        val harness = Harness(folder, key, http, scope)
        scope.launch { harness.fetch.get(texture(1), Progress.NONE) }
        scope.advanceUntilIdle()
        body = ok(png)
        scope.launch { harness.fetch.get(texture(2), Progress.NONE) }
        // The back-off runs from the 429's arrival, a second after the request was sent.
        scope.advanceTimeBy(9_999)
        scope.runCurrent()
        http.asked.size shouldBe 1
        scope.advanceTimeBy(2)
        scope.runCurrent()
        http.asked.size shouldBe 2
        body = Unanswered.Offline("UnknownHostException").left()
        val got = mutableListOf<Either<FetchFailure, ByteArray>>()
        scope.launch { got += harness.fetch.get(texture(3), Progress.NONE) }
        scope.advanceUntilIdle()
        got shouldBe listOf(FetchFailure.Skipped(ScreenScraperState.ClosedForRun(Closure.UNREACHABLE)).left())
        harness.fetch.open shouldBe false
        scope.launch { harness.fetch.newRun() }
        scope.runCurrent()
        harness.fetch.open shouldBe true
    }

    @Test
    fun `the 429s of requests under way slow ScreenScraper once, from the first's arrival, and a 429 after the back-off closes the run`() {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { url -> if ("ssuserInfos" in url) limits(3, 100) else status(429) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        // The account read first, then the three textures sent together and answered together.
        http.startedAt shouldBe listOf(0L, 1_000L, 1_000L, 1_000L)
        harness.states.map { it.second } shouldBe listOf(ScreenScraperState.Open(Some(Moment(2_000))))
        harness.fetch.open shouldBe true
        scope.launch { harness.fetch.get(texture(3), Progress.NONE) }
        scope.advanceUntilIdle()
        http.startedAt.last() shouldBe 12_000L
        harness.states.last().second shouldBe ScreenScraperState.ClosedForRun(Closure.BUSY)
    }

    @Test
    fun `an image to a request sent before a 429 does not end the slow-down, one sent after it does`() {
        val scope = TestScope(StandardTestDispatcher())
        var images = 0
        val http =
            FakeHttp { url ->
                if ("ssuserInfos" in url) {
                    limits(2, 100)
                } else if (images++ == 0) {
                    status(429)
                } else {
                    ok(png)
                }
            }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        repeat(2) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        harness.states.map { it.second } shouldBe listOf(ScreenScraperState.Open(Some(Moment(2_000))))
        scope.launch { harness.fetch.get(texture(2), Progress.NONE) }
        scope.advanceUntilIdle()
        http.startedAt.last() shouldBe 12_000L
        harness.states.last().second shouldBe ScreenScraperState.Open()
    }

    @Test
    fun `INV-E11-05 the account request spends the only allowance of its minute`() {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { url -> if ("ssuserInfos" in url) limits(1, 1) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        val got = scope.async { harness.fetch.get(texture(1), Progress.NONE) }
        scope.advanceTimeBy(59_999)
        scope.runCurrent()
        http.startedAt shouldBe listOf(0L)
        scope.advanceTimeBy(1)
        scope.runCurrent()
        http.startedAt shouldBe listOf(0L, 60_000L)
        scope.advanceUntilIdle()
        got.getCompleted().shouldBeRight() shouldBe png
    }

    @Test
    fun `INV-E11-05 the first image each day refreshes changed account limits without a new run`() {
        val scope = TestScope(StandardTestDispatcher())
        var nextDay = false
        val http = FakeHttp { url -> if ("ssuserInfos" in url) limits(if (nextDay) 1 else 3, 100) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i), Progress.NONE) } }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 1
        http.mostAtOnce shouldBe 3
        scope.advanceTimeBy(86_400_000 - scope.testScheduler.currentTime)
        nextDay = true
        val before = http.asked.size
        http.mostAtOnce = 0
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i + 3), Progress.NONE) } }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 2
        http.asked.drop(before).first() shouldContain "ssuserInfos.php"
        http.asked.drop(before).count { "mediaJeu" in it } shouldBe 3
        http.mostAtOnce shouldBe 1
        scope.launch { harness.fetch.get(texture(9), Progress.NONE) }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 2
    }

    @Test
    fun `INV-E11-05 a member refused at the next day's check is omitted from every following image`() {
        val scope = TestScope(StandardTestDispatcher())
        var nextDay = false
        val http =
            FakeHttp { url ->
                if ("ssuserInfos" !in url) {
                    ok(png)
                } else if (nextDay) {
                    status(403)
                } else {
                    limits(3, 100)
                }
            }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        scope.launch { harness.fetch.get(texture(1), Progress.NONE) }
        scope.advanceUntilIdle()
        scope.advanceTimeBy(86_400_000 - scope.testScheduler.currentTime)
        nextDay = true
        val before = http.asked.size
        repeat(3) { i -> scope.launch { harness.fetch.get(texture(i + 2), Progress.NONE) } }
        scope.advanceUntilIdle()
        http.asked.count { "ssuserInfos" in it } shouldBe 2
        val following = http.asked.drop(before)
        following.first() shouldContain "ssuserInfos.php"
        following.filter { "mediaJeu" in it }.size shouldBe 3
        following.filter { "mediaJeu" in it }.forEach {
            it shouldNotContain "ssid="
            it shouldNotContain "sspassword="
        }
    }

    @Test
    fun `a cancelled image frees its thread for a later request on the same gate`() = runBlocking<Unit> {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { ok(png) }
        val harness = Harness(folder, key, http, scope)
        val cancelled = scope.launch { harness.fetch.get(texture(1), Progress.NONE) }
        scope.runCurrent()
        http.asked.size shouldBe 1
        val stopped = scope.launch { cancelled.cancelAndJoin() }
        scope.runCurrent()
        stopped.isCompleted shouldBe true
        http.underWay shouldBe 0
        val later = scope.async { harness.fetch.get(texture(2), Progress.NONE) }
        scope.advanceTimeBy(2_000)
        scope.runCurrent()
        later.isCompleted shouldBe true
        later.getCompleted().shouldBeRight() shouldBe png
        http.asked.size shouldBe 2
        http.underWay shouldBe 0
    }

    @Test
    fun `a cancelled account check frees its thread and the next request checks again`() = runBlocking<Unit> {
        val scope = TestScope(StandardTestDispatcher())
        val http = FakeHttp { url -> if ("ssuserInfos" in url) limits(1, 100) else ok(png) }
        val harness = Harness(folder, key.copy(member = Some(member)), http, scope)
        val cancelled = scope.launch { harness.fetch.get(texture(1), Progress.NONE) }
        scope.runCurrent()
        http.asked.size shouldBe 1
        val stopped = scope.launch { cancelled.cancelAndJoin() }
        scope.runCurrent()
        stopped.isCompleted shouldBe true
        http.underWay shouldBe 0
        val later = scope.async { harness.fetch.get(texture(2), Progress.NONE) }
        scope.advanceTimeBy(3_000)
        scope.runCurrent()
        later.isCompleted shouldBe true
        later.getCompleted().shouldBeRight() shouldBe png
        http.asked.count { "ssuserInfos" in it } shouldBe 2
        http.asked.count { "mediaJeu" in it } shouldBe 1
        http.underWay shouldBe 0
    }

    private companion object {
        const val MINUTE = 60_000L
        const val DAY = 24 * 60 * MINUTE

        /** The day of the test clock's [millis]: the 18th of October 2026 and the days after. */
        fun day(millis: Long): Day = Day("2026-10-%02d".format(18 + millis / DAY))
    }
}
