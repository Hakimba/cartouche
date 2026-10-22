// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.BuildConfig
import app.cartouche.android.storage.read
import app.cartouche.android.storage.write
import app.cartouche.android.trace
import app.cartouche.core.art.Account
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.KeptClosures
import app.cartouche.core.art.KeyHash
import app.cartouche.core.art.Limits
import app.cartouche.core.art.Moment
import app.cartouche.core.art.ScreenScraperAnswer
import app.cartouche.core.art.ScreenScraperState
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.left
import arrow.core.right
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.time.LocalDate

/** A ScreenScraper member, whose quota and threads the requests count on. */
internal data class Member(val id: String, val password: String) {
    /** Never the password: a member may be traced (INV-E11-06). */
    override fun toString(): String = "Member($id)"
}

/** The app's developer key and, if any, the member its requests go as: built into the app, never stored or traced. */
internal data class Credentials(val devId: String, val devPassword: String, val softName: String, val member: Option<Member>) {
    override fun toString(): String = "Credentials($devId, $softName, $member)"

    companion object {
        /** The credentials built into the app (`local.properties` or the environment at build time); none without a key: the app then has no ScreenScraper. */
        fun fromBuild(): Option<Credentials> = Some(BuildConfig.SCREENSCRAPER_DEVID).filter(String::isNotEmpty).map { devId ->
            val ssid = Some(BuildConfig.SCREENSCRAPER_SSID).filter(String::isNotEmpty)
            val member = ssid.map { Member(it, BuildConfig.SCREENSCRAPER_SSPASSWORD) }
            Credentials(devId, BuildConfig.SCREENSCRAPER_DEVPASSWORD, BuildConfig.SCREENSCRAPER_SOFTNAME, member)
        }
    }
}

/** What the scraper knows of ScreenScraper: whether it takes requests, and that a run starts. */
internal interface Textures {
    val open: Boolean

    suspend fun newRun()

    companion object {
        /** No ScreenScraper: never open. */
        val NONE: Textures =
            object : Textures {
                override val open: Boolean get() = false

                override suspend fun newRun() = Unit
            }
    }
}

/**
 * Downloads ScreenScraper's textures with the app's key and, if any, the member's account, at the
 * pace they allow (INV-E11-05): one request at a time with the key alone, the member's threads and
 * per-minute allowance otherwise, read by `ssuserInfos.php` at the first request of each day (a
 * refused member leaves the key alone); after a 429 the next request waits [BACK_OFF]. Every
 * request goes through this one gate, and asks only for images (`mediaJeu.php`), never which game
 * a file is (INV-E11-04). The credentials go into a URL at request time only: nothing stored or
 * traced holds them (INV-E11-06). The state follows the answers ([ScreenScraperState]), a server
 * out of reach closing it for the run like any failure (a device really offline stalls on its next
 * scan); what outlives a restart (a closure until a day, an off state for this key) is kept in
 * [stateFile] ([KeptClosures]). [changed] hears each new state.
 */
internal class ScreenScraperFetch(
    private val http: Http,
    private val credentials: Credentials,
    stateFile: File,
    private val now: () -> Long,
    private val today: () -> Day,
    private val changed: (ScreenScraperState) -> Unit,
) : Textures {
    /** The gate: guards [state], [limits], [member], [checkedOn], [sent] and [underWay]. */
    private val lock = Mutex()

    private val stateFile = AtomicFile(stateFile)

    private val key = KeyHash(ArtStore.sha1("${credentials.devId}:${credentials.devPassword}"))

    private var kept: KeptClosures =
        this.stateFile
            .read(None, { it }) { text -> KeptClosures.decode(text).right() }
            .getOrElse { None }
            .getOrElse { KeptClosures.NONE }

    @Volatile private var state: ScreenScraperState = kept.state(key, today())

    @Volatile private var limits = Limits.KEY_ALONE

    @Volatile private var member = credentials.member

    private var checkedOn: Option<Day> = None

    /** When the requests of the last minute started. */
    private val sent = ArrayDeque<Long>()

    /** The requests sent since the run began, traced as the next begins. */
    private var requested = 0

    private var underWay = 0

    /**
     * Counts the threads freed and the limits read: a request waiting for a thread waits for this to
     * change, which a thread freed and taken back at once still does (a value would be conflated).
     */
    private val freed = MutableStateFlow(0)

    /** One account check at a time: requests arriving together on a new day wait for the one that checks. */
    private val checking = Mutex()

    override val open: Boolean get() = state.on(today()) is ScreenScraperState.Open

    override suspend fun newRun() {
        lock.withLock {
            if (requested > 0) trace("art") { "ScreenScraper: $requested requests in the last run" }
            requested = 0
            change(state.reopened())
        }
    }

    /**
     * [texture]'s image, [progress] told as it downloads; skipped at once while ScreenScraper is not
     * open, not found when the game has no such image.
     */
    suspend fun get(texture: Candidate.Texture, progress: Progress): Either<FetchFailure, ByteArray> {
        checkAccount()
        val sent = admitted().getOrElse { return it.left() }
        val url =
            url(
                IMAGE,
                "systemeid" to "${texture.system.id}",
                "jeuid" to "${texture.game.id}",
                "media" to texture.media.name,
                "maxwidth" to "$SIZE",
                "maxheight" to "$SIZE",
            )
        return try {
            val result = http.get(url, progress)
            answered(answerOf(result), result.getOrNone().flatMap { it.body }, sent)
        } finally {
            release()
        }
    }

    /** Frees the request's thread, even once the request is cancelled. */
    private suspend fun release() {
        withContext(NonCancellable) {
            lock.withLock {
                underWay--
                freed.value++
            }
        }
    }

    /** The answer to the request [sent], taken into the state, and what it means for the image. */
    private suspend fun answered(answer: ScreenScraperAnswer, body: Option<ByteArray>, sent: Moment): Either<FetchFailure, ByteArray> {
        val next = lock.withLock { change(state.after(answer, tomorrow(), sent, Moment(now()))) }
        return when (answer) {
            ScreenScraperAnswer.Image -> body.toEither { FetchFailure.NotFound }
            ScreenScraperAnswer.NoMedia -> FetchFailure.NotFound.left()
            ScreenScraperAnswer.LoginRefused,
            ScreenScraperAnswer.TimedOut,
            ScreenScraperAnswer.Unreachable,
            ScreenScraperAnswer.Unreadable,
            is ScreenScraperAnswer.Status,
            -> FetchFailure.Skipped(next).left()
        }
    }

    /**
     * Waits for a request's turn: ScreenScraper open, a thread free, the minute's allowance and the
     * back-off over; answers the moment it is sent, or skipped when not open.
     */
    private suspend fun admitted(): Either<FetchFailure.Skipped, Moment> {
        while (true) {
            val admission =
                lock.withLock {
                    val open =
                        when (val current = change(state.on(today()))) {
                            is ScreenScraperState.Open -> current
                            is ScreenScraperState.ClosedForRun, is ScreenScraperState.ClosedUntil, is ScreenScraperState.Off ->
                                return FetchFailure.Skipped(current).left()
                        }
                    val time = now()
                    while (sent.isNotEmpty() && sent.first() <= time - MINUTE) sent.removeFirst()
                    val backOff = open.slowedAt.map { it.millis + BACK_OFF - time }.filter { it > 0 }
                    val window = limits.perMinute.filter { sent.size >= it }.map { sent.first() + MINUTE - time }
                    when {
                        underWay >= limits.threads -> Admission.Full(freed.value)
                        backOff.isSome() || window.isSome() -> Admission.Later(maxOf(backOff.getOrElse { 0 }, window.getOrElse { 0 }))
                        else -> {
                            underWay++
                            requested++
                            sent.addLast(time)
                            return Moment(time).right()
                        }
                    }
                }
            when (admission) {
                is Admission.Full -> freed.first { it != admission.seen }
                is Admission.Later -> delay(admission.millis)
            }
        }
    }

    private sealed interface Admission {
        /** Every thread is taken: wait for one freed after the [seen] so far. */
        data class Full(val seen: Int) : Admission

        /** Wait [millis] for the minute's allowance or the back-off. */
        data class Later(val millis: Long) : Admission
    }

    /**
     * Reads the member's limits once a day, a request like the others. The member is left out from
     * then on only when refused ([Account.Refused]); an answer that says nothing of them counts for
     * the state as any request's, and the day stays unchecked.
     */
    private suspend fun checkAccount() = checking.withLock {
        if (!due()) return@withLock
        val sent = admitted().getOrElse { return@withLock }
        val result =
            try {
                http.get(url(USER, "output" to "json"), Progress.NONE)
            } finally {
                release()
            }
        lock.withLock {
            val account = result.getOrNone().flatMap { Account.of(it.status, it.body.map(ByteArray::decodeToString)) }
            account.fold({ change(state.after(answerOf(result), tomorrow(), sent, Moment(now()))) }) { found ->
                checkedOn = Some(today())
                limits =
                    when (found) {
                        is Account.Member -> found.limits
                        Account.Refused -> Limits.KEY_ALONE.also { member = None }
                    }
                freed.value++
                trace(
                    "art",
                ) { "ScreenScraper account: ${if (found is Account.Member) "${found.limits}" else "refused, the key alone from now on"}" }
            }
        }
    }

    /** What the server answered, for the state: no answer in time or no server reached count as answers of their own. */
    private fun answerOf(result: Either<Unanswered, Answer>): ScreenScraperAnswer = result.fold({ unanswered ->
        when (unanswered) {
            is Unanswered.Offline -> ScreenScraperAnswer.Unreachable
            Unanswered.TimedOut -> ScreenScraperAnswer.TimedOut
        }
    }, ::read)

    private suspend fun due(): Boolean = lock.withLock { member.isSome() && checkedOn != Some(today()) }

    private fun change(next: ScreenScraperState): ScreenScraperState {
        if (next != state) {
            state = next
            changed(next)
            val before = kept
            kept = kept.after(next, key)
            if (kept != before) {
                if (kept == KeptClosures.NONE) {
                    stateFile.delete()
                } else {
                    stateFile.write(KeptClosures.encode(kept)).onLeft { trace("art") { "ScreenScraper closure not kept: ${it.message}" } }
                }
            }
        }
        return next
    }

    private fun tomorrow(): Day = Day(LocalDate.parse(today().iso).plusDays(1).toString())

    /** The URL of [script] with the key, the member if any, and [params], each encoded. */
    private fun url(script: String, vararg params: Pair<String, String>): String {
        val key = listOf("devid" to credentials.devId, "devpassword" to credentials.devPassword, "softname" to credentials.softName)
        val account = member.fold({ emptyList() }) { listOf("ssid" to it.id, "sspassword" to it.password) }
        return "$API$script?" + (key + account + params).joinToString("&") { (name, value) -> "$name=${URLEncoder.encode(value, "UTF-8")}" }
    }

    companion object {
        private const val API = "https://api.screenscraper.fr/api2/"
        private const val IMAGE = "mediaJeu.php"
        private const val USER = "ssuserInfos.php"
        private const val SIZE = 1024
        private const val MINUTE = 60_000L

        /** How long the next request waits after a 429, from its arrival. */
        const val BACK_OFF = 10_000L

        private val PNG = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47)
        private val JPEG = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte())
        private const val NO_MEDIA = "NOMEDIA"

        /** The text a wrong key is answered with on an image, as a 200; a refused member's text starts alike, so [DEVELOPER_REFUSED] tells. */
        const val LOGIN_REFUSED = "Erreur de login : Vérifier vos identifiants développeur !"

        private const val DEVELOPER_REFUSED = "identifiants développeur"

        /** What [answer] says: an image only when its bytes are one. */
        fun read(answer: Answer): ScreenScraperAnswer = when {
            answer.status != HttpURLConnection.HTTP_OK -> ScreenScraperAnswer.Status(answer.status)
            else ->
                answer.body.fold({ ScreenScraperAnswer.Unreadable }) { body ->
                    when {
                        body.startsWith(PNG) || body.startsWith(JPEG) -> ScreenScraperAnswer.Image
                        body.size > LONGEST_TEXT -> ScreenScraperAnswer.Unreadable
                        body.decodeToString() == NO_MEDIA -> ScreenScraperAnswer.NoMedia
                        DEVELOPER_REFUSED in body.decodeToString() -> ScreenScraperAnswer.LoginRefused
                        else -> ScreenScraperAnswer.Unreadable
                    }
                }
        }

        private const val LONGEST_TEXT = 1024

        private fun ByteArray.startsWith(prefix: ByteArray): Boolean = size >= prefix.size && prefix.indices.all { this[it] == prefix[it] }
    }
}
