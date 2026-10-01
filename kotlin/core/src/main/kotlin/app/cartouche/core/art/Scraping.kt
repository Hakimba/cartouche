// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.GameId
import arrow.core.NonEmptyList
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import kotlin.time.Duration
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds

/**
 * A game whose art is looked for, and where to look, best first, in the sources of [version]; its
 * [title] names it in the traces.
 */
public data class ArtRequest(
    public val game: GameId,
    public val title: String,
    public val candidates: NonEmptyList<ArtUrl>,
    public val version: Option<ArtVersion>,
)

/** Why a scraping run waits: no network, a server refusing (a quota) or failing, or no room to store images. */
public enum class Stall {
    OFFLINE,
    REFUSED,
    STORAGE,
}

/**
 * A scraping run: the games waiting to be looked for, those under way, and how many are done. Each
 * waiting request is handed out once by [take]; it only waits again when it stalls, behind the
 * others, so that a game whose image a server keeps refusing never holds the others back, unless the
 * run no longer asks for it (its platform removed meanwhile). A stall hands nothing out until [resumed].
 */
@ConsistentCopyVisibility
public data class Scraping private constructor(
    public val waiting: List<ArtRequest>,
    public val underWay: List<ArtRequest>,
    public val done: Int,
    public val stall: Option<Stall>,
    /** Stalls since the last request that finished, for [retryDelay]. */
    private val stalls: Int,
    /** The games under way that the last [with] no longer asks for: they do not wait again. */
    private val leaving: Set<GameId>,
) {
    public val total: Int get() = done + waiting.size + underWay.size

    public val isOver: Boolean get() = waiting.isEmpty() && underWay.isEmpty()

    /** How long to wait before trying again after a stall: 30 s, doubling with each stall in a row, up to 15 min. */
    public val retryDelay: Duration get() = (FIRST_RETRY * (1 shl (stalls - 1).coerceIn(0, 5))).coerceAtMost(LONGEST_RETRY)

    /** The next request to look for, and the run with it under way; none while stalled or when none waits. */
    public fun take(): Option<Pair<ArtRequest, Scraping>> = waiting
        .firstOrNone()
        .filter { stall.isNone() }
        .map { it to copy(waiting = waiting.drop(1), underWay = underWay + it) }

    /** [game]'s request is over: its art found, or none in any source. */
    public fun finished(game: GameId): Scraping =
        ifUnderWay(game) { _, others -> copy(underWay = others, done = done + 1, stalls = 0, leaving = leaving - game) }

    /** [game]'s request stalled for [why]: it waits again, last. */
    public fun stalled(game: GameId, why: Stall): Scraping = ifUnderWay(game) { request, others ->
        copy(
            waiting = waiting + again(game, request),
            underWay = others,
            stall = Some(why),
            stalls = if (stall.isNone()) stalls + 1 else stalls,
            leaving = leaving - game,
        )
    }

    /** [game]'s request was set aside before its end, as when the app stops: it waits again, first. */
    public fun returned(game: GameId): Scraping =
        ifUnderWay(game) { request, others -> copy(waiting = again(game, request) + waiting, underWay = others, leaving = leaving - game) }

    public fun resumed(): Scraping = copy(stall = None)

    /**
     * The run for [requests], the games that have no art now: those under way stay so, the others
     * wait in the given order. A run that was over starts again from nothing done.
     */
    public fun with(requests: List<ArtRequest>): Scraping {
        val run = if (isOver) copy(done = 0, stall = None, stalls = 0) else this
        val asked = requests.mapTo(HashSet()) { it.game }
        return run.copy(
            waiting = requests.distinctBy { it.game }.filter { request -> underWay.none { it.game == request.game } },
            leaving = underWay.map { it.game }.filterTo(HashSet()) { it !in asked },
        )
    }

    /** [request] of [game], to wait again: none when the run no longer asks for it. */
    private fun again(game: GameId, request: List<ArtRequest>): List<ArtRequest> = if (game in leaving) emptyList() else request

    /** [change] of [game]'s request under way and the others; unchanged when it is not under way. */
    private fun ifUnderWay(game: GameId, change: (List<ArtRequest>, List<ArtRequest>) -> Scraping): Scraping =
        underWay.partition { it.game == game }.let { (request, others) -> if (request.isEmpty()) this else change(request, others) }

    public companion object {
        public val NONE: Scraping = Scraping(emptyList(), emptyList(), 0, None, 0, emptySet())

        private val FIRST_RETRY = 30.seconds
        private val LONGEST_RETRY = 15.minutes
    }
}
