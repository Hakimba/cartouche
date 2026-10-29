// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.art

import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterIsInstance
import arrow.core.getOrElse
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.json.Json

/** A day as ISO `2026-10-19`, which compares as text; the shell reads today's. */
@Serializable @JvmInline
public value class Day(public val iso: String) : Comparable<Day> {
    override fun compareTo(other: Day): Int = iso.compareTo(other.iso)
}

/** The app's developer key as a hash: what an off state kept across restarts is tied to, never the key itself (INV-E11-06). */
@Serializable @JvmInline
public value class KeyHash(public val value: String)

/** A moment on the shell's clock, in milliseconds: when a request was sent, when its answer came. */
@JvmInline
public value class Moment(public val millis: Long) : Comparable<Moment> {
    override fun compareTo(other: Moment): Int = millis.compareTo(other.millis)
}

/**
 * What ScreenScraper allows a member at once and per minute, as `ssuserInfos.php` states them;
 * the app's key alone, with no member, one request at a time.
 */
public data class Limits(public val threads: Int, public val perMinute: Option<Int>) {
    public companion object {
        public val KEY_ALONE: Limits = Limits(1, None)
    }
}

/** What `ssuserInfos.php` says of the member whose account the requests go as. */
public sealed interface Account {
    /** The member's limits. */
    public data class Member(public val limits: Limits) : Account

    /** The member is refused (a 403, the user-login error text, or a level of 0): the key alone from then on. */
    public data object Refused : Account

    public companion object {
        private const val OK = 200
        private const val FORBIDDEN = 403
        private const val USER_REFUSED = "identifiants utilisateurs"

        /** The answers' JSON holds more than the app reads, its numbers written as text. */
        private val answers =
            Json {
                ignoreUnknownKeys = true
                isLenient = true
            }

        /**
         * What an answer of [status] with [body] says of the member; none when it says nothing of
         * them (another status, a text the app cannot read): it is then an answer like any request's.
         */
        public fun of(status: Int, body: Option<String>): Option<Account> = when {
            status == FORBIDDEN -> Some(Refused)
            status != OK -> None
            else ->
                body.flatMap { text ->
                    if (USER_REFUSED in text) {
                        Some(Refused)
                    } else {
                        Option
                            .catch { answers.decodeFromString(UserAnswer.serializer(), text).response.ssuser }
                            .flatMap { user ->
                                if (user.niveau == "0") Some(Refused) else limitsOf(user).map(::Member)
                            }
                    }
                }
        }

        private fun limitsOf(user: User): Option<Limits> =
            Option.fromNullable(user.maxthreads.toIntOrNull()).filter { it > 0 }.flatMap { threads ->
                Option.fromNullable(user.maxrequestspermin.toIntOrNull()).filter { it > 0 }.map { Limits(threads, Some(it)) }
            }
    }
}

/** An `ssuserInfos.php` answer: `response.ssuser.maxthreads`, `maxrequestspermin` and the member's `niveau`, as text. */
@Serializable
private data class UserAnswer(val response: Response) {
    @Serializable
    data class Response(val ssuser: User)
}

@Serializable
private data class User(val maxthreads: String, val maxrequestspermin: String, val niveau: String = "")

/** What ScreenScraper answered a request for an image, as the shell reads it. */
public sealed interface ScreenScraperAnswer {
    /** The image itself: a PNG's or a JPEG's bytes. */
    public data object Image : ScreenScraperAnswer

    /** A 200 whose body is `NOMEDIA`: the game has no such image. */
    public data object NoMedia : ScreenScraperAnswer

    /** A 200 whose body says the developer login is wrong, as a wrong key is answered on an image. */
    public data object LoginRefused : ScreenScraperAnswer

    /** Any other HTTP status than 200. */
    public data class Status(public val code: Int) : ScreenScraperAnswer

    /** No answer in time. */
    public data object TimedOut : ScreenScraperAnswer

    /** The server could not be reached, while the device's network was up. */
    public data object Unreachable : ScreenScraperAnswer

    /** A 200 that is neither an image nor a text the app knows. */
    public data object Unreadable : ScreenScraperAnswer
}

/** Why ScreenScraper is closed for the rest of a run. */
public enum class Closure {
    /** 401: closed to non-members or inactive members while the server is loaded. */
    NOT_FOR_MEMBERS,

    /** 423: the API is closed. */
    API_CLOSED,

    /** 429 again after backing off: the threads or the per-minute allowance are spent. */
    BUSY,

    /** No answer in time. */
    TIMED_OUT,

    /** The server could not be reached: tried again once the device's network is back ([ScreenScraperState.reconnected]). */
    UNREACHABLE,

    /** An answer that is neither an image nor a text the app knows, or a status it does not. */
    UNREADABLE,
}

/** Why ScreenScraper is off for good. */
public enum class Refusal {
    /** 403, or a login error on an image: the app's developer key is refused. */
    WRONG_KEY,

    /** 426: the app is blacklisted. */
    BLACKLISTED,
}

/**
 * Whether ScreenScraper takes requests, as the last answer left it: while not [Open], a texture is
 * skipped at once for the game's next image, and nothing waits on it (INV-E11-05).
 */
public sealed interface ScreenScraperState {
    /**
     * Requests go; after a 429, which came at [slowedAt], the next waits a back-off from then. The
     * requests already under way then say nothing new, whatever they answer; only one sent after
     * the slow-down tells whether the server has room again (see [after]).
     */
    public data class Open(public val slowedAt: Option<Moment> = None) : ScreenScraperState

    /** Closed until the scraper's next run ([reopened]): the server refused or failed. */
    public data class ClosedForRun(public val reason: Closure) : ScreenScraperState

    /** Closed until [day]: the day's quota, or its allowance of unknown games, is spent (430, 431); kept across restarts. */
    public data class ClosedUntil(public val day: Day) : ScreenScraperState

    /** Off for good: the app's key is refused, or the app blacklisted. */
    public data class Off(public val reason: Refusal) : ScreenScraperState

    /**
     * The state after [answer], come at [now] to a request [sent] today, [tomorrow] being the day a
     * spent quota comes back. An answer that comes once ScreenScraper is closed, to a request already
     * under way, never makes the closure lighter: it can only turn it off (a refused key) or close
     * it until tomorrow. A 429 slows an open ScreenScraper from the moment it comes; an image or
     * another 429 to a request sent before then says nothing new; to one sent after, an image
     * reopens it fully, a 429 closes the run.
     */
    public fun after(answer: ScreenScraperAnswer, tomorrow: Day, sent: Moment, now: Moment): ScreenScraperState = when (this) {
        is Off -> this
        is ClosedUntil -> closure(answer, tomorrow).filterIsInstance<Off>().getOrElse { this }
        is ClosedForRun -> closure(answer, tomorrow).getOrElse { this }
        is Open ->
            closure(answer, tomorrow).getOrElse {
                val sinceSlowed = slowedAt.isSome { sent > it }
                when (answer) {
                    ScreenScraperAnswer.Image, ScreenScraperAnswer.NoMedia -> if (sinceSlowed) Open() else this
                    ScreenScraperAnswer.TimedOut -> ClosedForRun(Closure.TIMED_OUT)
                    ScreenScraperAnswer.Unreachable -> ClosedForRun(Closure.UNREACHABLE)
                    ScreenScraperAnswer.Unreadable -> ClosedForRun(Closure.UNREADABLE)
                    ScreenScraperAnswer.LoginRefused -> Off(Refusal.WRONG_KEY)
                    is ScreenScraperAnswer.Status ->
                        when (answer.code) {
                            TOO_MANY -> if (sinceSlowed) ClosedForRun(Closure.BUSY) else Open(Some(slowedAt.getOrElse { now }))
                            NOT_FOR_MEMBERS -> ClosedForRun(Closure.NOT_FOR_MEMBERS)
                            API_CLOSED -> ClosedForRun(Closure.API_CLOSED)
                            else -> ClosedForRun(Closure.UNREADABLE)
                        }
                }
            }
    }

    /** The closures that hold whatever the state: the key refused or the app blacklisted (off), the day's quota spent (until [tomorrow]). */
    private fun closure(answer: ScreenScraperAnswer, tomorrow: Day): Option<ScreenScraperState> = when (answer) {
        ScreenScraperAnswer.LoginRefused -> Some(Off(Refusal.WRONG_KEY))
        is ScreenScraperAnswer.Status ->
            when (answer.code) {
                FORBIDDEN -> Some(Off(Refusal.WRONG_KEY))
                BLACKLISTED -> Some(Off(Refusal.BLACKLISTED))
                QUOTA_SPENT, UNKNOWN_GAMES_SPENT -> Some(ClosedUntil(tomorrow))
                else -> None
            }
        ScreenScraperAnswer.Image,
        ScreenScraperAnswer.NoMedia,
        ScreenScraperAnswer.TimedOut,
        ScreenScraperAnswer.Unreachable,
        ScreenScraperAnswer.Unreadable,
        -> None
    }

    /** The state as a new run starts: a closure for the run is over, a day's or a key's is not. */
    public fun reopened(): ScreenScraperState = if (this is ClosedForRun) Open() else this

    /**
     * The state once the device's network is back: a run closed only because the server was out of reach is
     * open again, a network lost on the way looking like a server gone; any other closure holds.
     */
    public fun reconnected(): ScreenScraperState = if (this == ClosedForRun(Closure.UNREACHABLE)) Open() else this

    /** The state on [today]: a closure until a day that has come is over. */
    public fun on(today: Day): ScreenScraperState = if (this is ClosedUntil && day <= today) Open() else this

    public companion object {
        private const val NOT_FOR_MEMBERS = 401
        private const val FORBIDDEN = 403
        private const val API_CLOSED = 423
        private const val BLACKLISTED = 426
        private const val TOO_MANY = 429
        private const val UNKNOWN_GAMES_SPENT = 431

        /** ScreenScraper's status for the day's quota spent. */
        public const val QUOTA_SPENT: Int = 430
    }
}

/**
 * What of ScreenScraper's state outlives a run and a restart: the closure until a day (the quota
 * spent) and, beside it, the key it is off for (refused, or the app blacklisted), so that a key
 * found wrong does not forget the day's quota. An off state for another key is over: a new build
 * may carry a new key.
 */
@Serializable
public data class KeptClosures(public val closedUntil: Option<Day> = None, public val off: Option<KeptRefusal> = None) {
    /** These closures once [next] is the state, the app's key hashing to [key]. */
    public fun after(next: ScreenScraperState, key: KeyHash): KeptClosures = when (next) {
        is ScreenScraperState.Open -> NONE
        is ScreenScraperState.ClosedForRun -> this
        is ScreenScraperState.ClosedUntil -> copy(closedUntil = Some(next.day))
        is ScreenScraperState.Off -> copy(off = Some(KeptRefusal(next.reason, key)))
    }

    /** The state these closures leave ScreenScraper in on [today], for the app whose key hashes to [key]. */
    public fun state(key: KeyHash, today: Day): ScreenScraperState = off
        .filter { it.key == key }
        .map<ScreenScraperState> { ScreenScraperState.Off(it.reason) }
        .getOrElse { closedUntil.fold({ ScreenScraperState.Open() }) { ScreenScraperState.ClosedUntil(it) } }
        .on(today)

    public companion object {
        public val NONE: KeptClosures = KeptClosures()

        /** Stored as JSON; an unreadable text is none, which only means ScreenScraper is asked again. */
        public fun decode(text: String): Option<KeptClosures> = Option.catch { Json.decodeFromString(serializer(), text) }

        public fun encode(kept: KeptClosures): String = Json.encodeToString(serializer(), kept)
    }
}

/** ScreenScraper off for [reason], for the app whose key hashes to [key]. */
@Serializable
public data class KeptRefusal(public val reason: Refusal, public val key: KeyHash)
