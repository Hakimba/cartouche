// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.art.ScreenScraperState.ClosedForRun
import app.cartouche.core.art.ScreenScraperState.ClosedUntil
import app.cartouche.core.art.ScreenScraperState.Off
import app.cartouche.core.art.ScreenScraperState.Open
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.time.LocalDate

class ScreenScraperTest {
    private val today = Day("2026-10-18")
    private val tomorrow = Day("2026-10-19")
    private val key = KeyHash("1a2b")

    /** [answer] to a request sent and answered as the clock starts. */
    private fun ScreenScraperState.answered(answer: ScreenScraperAnswer) = after(answer, tomorrow, Moment(0), Moment(0))

    /** Every answer the server may give, the statuses the API documents most often. */
    private val answers: Arb<ScreenScraperAnswer> =
        Arb.choice(
            Arb.constant(ScreenScraperAnswer.Image),
            Arb.constant(ScreenScraperAnswer.NoMedia),
            Arb.constant(ScreenScraperAnswer.LoginRefused),
            Arb.constant(ScreenScraperAnswer.TimedOut),
            Arb.constant(ScreenScraperAnswer.Unreachable),
            Arb.constant(ScreenScraperAnswer.Unreadable),
            Arb.element(200, 400, 401, 403, 404, 423, 426, 429, 430, 431, 500, 503).map(ScreenScraperAnswer::Status),
            Arb.element(430, 431).map(ScreenScraperAnswer::Status),
            Arb.int(100..599).map(ScreenScraperAnswer::Status),
        )

    private sealed interface Step {
        data class Answered(val answer: ScreenScraperAnswer) : Step

        data object NewRun : Step

        data class DayCame(val day: Day) : Step
    }

    private val steps: Arb<Step> =
        Arb.choice(
            answers.map(Step::Answered),
            Arb.constant(Step.NewRun),
            Arb.element(Day("2026-10-18"), Day("2026-10-19"), Day("2026-10-20")).map(Step::DayCame),
        )

    @Test
    fun `INV-E11-05 a spent quota closes ScreenScraper until the next day, an off state for good, both kept across a restart`() =
        runBlocking<Unit> {
            var closed = 0
            checkAll(Arb.list(steps, 1..30)) { script ->
                var state: ScreenScraperState = Open()
                var kept = KeptClosures.NONE
                var day = today
                script.forEachIndexed { i, step ->
                    val before = state
                    state =
                        when (step) {
                            // Only an open ScreenScraper is asked, so only it is answered.
                            is Step.Answered ->
                                if (before is Open) {
                                    before.after(
                                        step.answer,
                                        dayAfter(day),
                                        Moment(i.toLong()),
                                        Moment(
                                            i + 1L,
                                        ),
                                    )
                                } else {
                                    before
                                }
                            Step.NewRun -> before.reopened()
                            is Step.DayCame -> before.on(step.day).also { day = step.day }
                        }
                    kept = kept.after(state, key)
                    if (step is Step.Answered && before is Open && step.answer in QUOTA_SPENT) {
                        state shouldBe ClosedUntil(dayAfter(day))
                        closed++
                    }
                    // A new run leaves a closure until a day, only the day lifts it; nothing lifts an off state.
                    if (before is ClosedUntil) state shouldBe (if (step is Step.DayCame && step.day >= before.day) Open() else before)
                    if (before is Off) state shouldBe before
                    // Stored and read back on the same day, a restart finds the closures that outlive a run, and only them.
                    val restarted = KeptClosures.decode(KeptClosures.encode(kept)).shouldBeSome().state(key, day)
                    restarted shouldBe
                        when (state) {
                            is Open, is ClosedForRun -> Open()
                            is ClosedUntil, is Off -> state
                        }
                }
            }
            closed shouldBeGreaterThan 100
            KeptClosures.NONE.after(Open(), key) shouldBe KeptClosures.NONE
            KeptClosures.NONE.after(ClosedForRun(Closure.BUSY), key) shouldBe KeptClosures.NONE
            KeptClosures.decode("{broken").shouldBeNone()
        }

    @Test
    fun `an app off for its key is open again under another key, a closure until a day holding still`() {
        val kept = KeptClosures.NONE.after(ClosedUntil(tomorrow), key).after(Off(Refusal.WRONG_KEY), key)
        kept.state(key, today) shouldBe Off(Refusal.WRONG_KEY)
        kept.state(key, Day("2099-01-01")) shouldBe Off(Refusal.WRONG_KEY)
        kept.state(KeyHash("other"), today) shouldBe ClosedUntil(tomorrow)
        kept.state(KeyHash("other"), tomorrow) shouldBe Open()
        KeptClosures.NONE.after(Off(Refusal.BLACKLISTED), key).state(KeyHash("other"), today) shouldBe Open()
        KeptClosures.decode(KeptClosures.encode(kept)).shouldBeSome() shouldBe kept
    }

    @Test
    fun `INV-E11-05 an answer that comes once ScreenScraper is closed never makes the closure lighter`() = runBlocking<Unit> {
        val closed =
            Arb.element(
                ClosedForRun(Closure.BUSY),
                ClosedForRun(Closure.TIMED_OUT),
                ClosedUntil(tomorrow),
                Off(Refusal.WRONG_KEY),
            )
        checkAll(closed, answers) { before, answer ->
            val after = before.answered(answer)
            when (before) {
                is Off -> after shouldBe before
                is ClosedUntil -> (after == before || after is Off) shouldBe true
                is ClosedForRun -> (after == before || after is Off || after == ClosedUntil(tomorrow)) shouldBe true
                is Open -> Unit
            }
        }
        ClosedUntil(tomorrow).answered(ScreenScraperAnswer.Status(429)) shouldBe ClosedUntil(tomorrow)
        ClosedUntil(tomorrow).answered(ScreenScraperAnswer.Image) shouldBe ClosedUntil(tomorrow)
        ClosedForRun(Closure.BUSY).answered(ScreenScraperAnswer.Status(430)) shouldBe ClosedUntil(tomorrow)
        ClosedForRun(Closure.BUSY).answered(ScreenScraperAnswer.Image) shouldBe ClosedForRun(Closure.BUSY)
    }

    @Test
    fun `a wrong developer key or a blacklisted app turns ScreenScraper off, and nothing turns it on again`() = runBlocking<Unit> {
        listOf(ScreenScraperAnswer.LoginRefused, ScreenScraperAnswer.Status(403), ScreenScraperAnswer.Status(426)).forEach { refusal ->
            val off = Open().answered(refusal).shouldBeInstanceOf<Off>()
            off.reason shouldBe (if (refusal == ScreenScraperAnswer.Status(426)) Refusal.BLACKLISTED else Refusal.WRONG_KEY)
            checkAll(answers) { answer -> off.answered(answer) shouldBe off }
            off.reopened() shouldBe off
            off.on(Day("2099-01-01")) shouldBe off
        }
    }

    @Test
    fun `a busy server slows ScreenScraper from the 429's arrival, and only a request sent after that reopens it or closes the run`() {
        val busy = ScreenScraperAnswer.Status(429)
        val slowed = Open().after(busy, tomorrow, sent = Moment(0), now = Moment(1_000))
        slowed shouldBe Open(Some(Moment(1_000)))
        // The requests under way when it came say nothing new, whatever they answer.
        slowed.after(busy, tomorrow, Moment(0), Moment(1_001)) shouldBe slowed
        slowed.after(ScreenScraperAnswer.Image, tomorrow, Moment(1_000), Moment(2_000)) shouldBe slowed
        // One sent after the slow-down tells.
        slowed.after(ScreenScraperAnswer.Image, tomorrow, Moment(11_000), Moment(12_000)) shouldBe Open()
        slowed.after(ScreenScraperAnswer.NoMedia, tomorrow, Moment(11_000), Moment(12_000)) shouldBe Open()
        slowed.after(busy, tomorrow, Moment(11_000), Moment(12_000)) shouldBe ClosedForRun(Closure.BUSY)
        ClosedForRun(Closure.BUSY).reopened() shouldBe Open()
    }

    @Test
    fun `the network back reopens a run closed for an unreachable server only, and leaves every other state as it is`() {
        ClosedForRun(Closure.UNREACHABLE).reconnected() shouldBe Open()
        val others =
            Closure.entries.filter { it != Closure.UNREACHABLE }.map(::ClosedForRun) +
                listOf(Open(), Open(Some(Moment(5))), ScreenScraperState.ClosedUntil(tomorrow), ScreenScraperState.Off(Refusal.WRONG_KEY))
        others.forEach { it.reconnected() shouldBe it }
    }

    @Test
    fun `an image, no image or a 429 to a request sent before a slow-down never changes it`() = runBlocking<Unit> {
        val answers = Arb.element(ScreenScraperAnswer.Image, ScreenScraperAnswer.NoMedia, ScreenScraperAnswer.Status(429))
        checkAll(Arb.long(0L..100_000L), Arb.long(0L..100_000L), answers) { at, before, answer ->
            val slowed = Open(Some(Moment(at)))
            slowed.after(answer, tomorrow, Moment(minOf(at, before)), Moment(at + before)) shouldBe slowed
        }
    }

    @Test
    fun `a closed API, a server closed to members, out of reach, a timeout or an answer the app cannot read close the run only`() =
        runBlocking<Unit> {
            val forTheRun =
                mapOf(
                    ScreenScraperAnswer.Status(401) to Closure.NOT_FOR_MEMBERS,
                    ScreenScraperAnswer.Status(423) to Closure.API_CLOSED,
                    ScreenScraperAnswer.TimedOut to Closure.TIMED_OUT,
                    ScreenScraperAnswer.Unreachable to Closure.UNREACHABLE,
                    ScreenScraperAnswer.Unreadable to Closure.UNREADABLE,
                    ScreenScraperAnswer.Status(500) to Closure.UNREADABLE,
                )
            forTheRun.forEach { (answer, reason) ->
                val closed = Open().answered(answer)
                closed shouldBe ClosedForRun(reason)
                closed.reopened() shouldBe Open()
                closed.on(tomorrow) shouldBe closed
            }
            // Whatever the status, the state is never open after one that is not 200's answer.
            checkAll(Arb.int(100..599)) { code ->
                (Open().answered(ScreenScraperAnswer.Status(code)) is Open) shouldBe (code == 429)
            }
        }

    @Test
    fun `the account's limits are read from its answer, a refused member told apart, and any other answer says nothing of them`() =
        runBlocking<Unit> {
            val member = Some(Account.Member(Limits(6, Some(7168))))
            val answer = """{"header":{"APIversion":"2"},"response":{"ssuser":{"id":"cartouche","maxthreads":"6","maxrequestspermin":"7168",
            "maxrequestsperday":"100000","requeststoday":"9","niveau":"4"}}}"""
            Account.of(200, Some(answer)) shouldBe member
            Account.of(200, Some("""{"response":{"ssuser":{"maxthreads":6,"maxrequestspermin":7168}}}""")) shouldBe member
            Account.of(200, Some("""{"response":{"ssuser":{"maxthreads":"6","maxrequestspermin":"7168","niveau":"0"}}}""")) shouldBe
                Some(Account.Refused)
            Account.of(403, Some("Erreur de login : Vérifier les identifiants utilisateurs !")) shouldBe Some(Account.Refused)
            Account.of(403, None) shouldBe Some(Account.Refused)
            Account.of(200, Some("Erreur de login : Vérifier les identifiants utilisateurs !")) shouldBe Some(Account.Refused)
            // The developer's login text, a failing server or an answer of no limits say nothing of the member.
            Account.of(200, Some("Erreur de login : Vérifier vos identifiants développeur !")).shouldBeNone()
            Account.of(500, Some(answer)).shouldBeNone()
            Account.of(200, None).shouldBeNone()
            Account.of(200, Some("""{"response":{"ssuser":{"maxthreads":"0","maxrequestspermin":"7168"}}}""")).shouldBeNone()
            Account.of(200, Some("""{"response":{"ssuser":{"maxthreads":"6"}}}""")).shouldBeNone()
            checkAll(Arb.string()) { text ->
                Account.of(200, Some(text)).onSome { if (it is Account.Member) it.limits.threads shouldBeGreaterThan 0 }
            }
        }

    private companion object {
        val QUOTA_SPENT = setOf(ScreenScraperAnswer.Status(430), ScreenScraperAnswer.Status(431))

        fun dayAfter(day: Day): Day = Day(LocalDate.parse(day.iso).plusDays(1).toString())
    }
}
