// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.Log
import app.cartouche.android.TAG
import app.cartouche.android.trace
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Identity
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.GameId
import app.cartouche.core.serialName
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.time.TimeMark
import kotlin.time.TimeSource

/** What a run learnt of games' labels. */
internal sealed interface LabelNews

/** A game's label image, just stored. */
internal data class FoundArt(val game: GameId, val art: StoredArt) : LabelNews

/**
 * No source has an image of these [games]' labels: remembered so ([ArtStore.markAbsent]), their blanks show their
 * titles.
 */
internal data class AbsentArt(val games: List<GameId>) : LabelNews

/** How the download of a game's label goes, told while the game is on screen ([Scraper.focus]). */
internal sealed interface LabelDownload {
    /** [fraction] of the image being downloaded read, from 0 to 1; none when its size is unknown. */
    data class Running(val fraction: Option<Double>) : LabelDownload

    /** Its look is over, a label found or not; told only after a [Running]. */
    data object Over : LabelDownload
}

/**
 * After [stop] no download starts until [start]; the ones under way end. A stall stops the run until [networkBack] or a delay that grows
 * with each stall in a row. A ScreenScraper texture skipped because it is not open leaves the label found after it provisional (see
 * [ProvisionalArt]); a walk that skipped one and found nothing leaves the label as it was. A label asked again while its look is under way
 * is looked for again once it ends.
 */
internal class Scraper(
    private val store: ArtStore,
    private val fetch: Fetch,
    private val scope: CoroutineScope,
    private val textures: Textures = Textures.NONE,
    /** Whether the device has a network it validated: a failure without one is the network's, not a server's. */
    private val online: () -> Boolean = { true },
    private val decoding: Semaphore = Semaphore(ArtImages.SCRAPER_DECODES),
    private val downloading: (GameId, LabelDownload) -> Unit,
    private val changed: (Scraping, Option<LabelNews>) -> Unit,
) {
    private sealed interface Outcome {
        /** [art] stored, or the label the user chose meanwhile, kept. */
        data class Found(val art: StoredArt) : Outcome

        /**
         * The label stored stays: the images before it were asked for, with ScreenScraper skipped ([provisional]) or
         * not.
         */
        data class Kept(val provisional: Boolean) : Outcome

        data object Absent : Outcome

        /** Nothing found with a ScreenScraper texture skipped: the label stays as it was, still wanted. */
        data object Skipped : Outcome

        data class Stalled(val why: Stall) : Outcome

        /** Stopped before its end: the request waits again. */
        data object SetAside : Outcome

        /** Its game left the library while it was looked for: nothing stored. */
        data object Gone : Outcome
    }

    private sealed interface Tried {
        /** Not this image: the next, after ScreenScraper was [skipped] or not. */
        data class Next(val skipped: Boolean) : Tried

        data class Found(val art: StoredArt) : Tried

        data class Stalled(val why: Stall) : Tried

        data object Gone : Tried
    }

    /** Guards [run], [working], [retrying] and [began]. */
    private val lock = Mutex()

    private var run = Scraping.NONE

    private var working = 0
    private var retrying: Option<Job> = None

    /** Set at once by [stop] and [start], so that the latest call wins; read before each download. */
    @Volatile private var stopped = false

    private var began = TimeSource.Monotonic.markNow()

    /** The hosts of web images that failed this run with the device online: passed over until the next plan. */
    private val closedHosts: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** The games looked for first, as the carousel last said ([focus]); kept through a new plan, read by the downloads too. */
    @Volatile private var focused: List<GameId> = emptyList()

    /**
     * Calls made in turn, on one thread, change the run in that order (the lock is fair): a later plan always replaces an earlier one.
     * [since] is when the plan read the games' labels.
     */
    suspend fun lookFor(requests: List<ArtRequest>, again: Set<GameId> = emptySet(), since: Choices = store.choices()) {
        textures.newRun()
        closedHosts.clear()
        val provisional = requests.filter { store.provisional(it.game).isSome() && !store.wants(it.game, it.version) }.map { it.game }
        val asked = again + if (textures.open) provisional else emptyList()
        // Under the lock: a game a worker stores meanwhile is either stored or still under way, and
        // one under way that is asked again is looked for again once its look ends.
        update(None) {
            if (run.isOver) began = TimeSource.Monotonic.markNow()
            store.retry(asked, since).onLeft { trace("art") { "${asked.size} labels not asked again: ${it.message}" } }
            val missing = requests.filter { store.wants(it.game, it.version) }
            trace("art") { "${missing.size} of ${requests.size} games to look for, ${asked.size} labels asked again among them" }
            run.with(missing).ahead(focused)
        }
        startWorkers()
    }

    /**
     * Remembers that no source has art for the [unfound] games, of their sources' version, and tells those without a
     * label.
     */
    suspend fun absent(unfound: Map<GameId, Option<ArtVersion>>) {
        val told =
            unfound.filter { (game, version) ->
                val stored =
                    store
                        .markAbsent(game, version, store.asked(game))
                        .onLeft { trace("art") { "${game.value}: not remembered as absent: ${it.message}" } }
                stored.isRight { !it }
            }
        if (told.isNotEmpty()) lock.withLock { changed(run, Some(AbsentArt(told.keys.toList()))) }
    }

    /** Whether nothing is waiting or being looked for. */
    suspend fun isOver(): Boolean = lock.withLock { run.isOver }

    /** Tries again at once if the run stalled for want of a network. */
    fun networkBack() {
        scope.launch {
            if (lock.withLock { run.stall == Some(Stall.OFFLINE) }) resume()
        }
    }

    /**
     * Starts no download until [start]; the ones under way end. A retry due meanwhile starts none either, and is left
     * to run: cancelling it from a coroutine of its own could cancel the one a [start] made since.
     */
    fun stop() {
        stopped = true
    }

    fun start() {
        stopped = false
        scope.launch { if (lock.withLock { run.stall.isSome() }) scheduleRetry() else startWorkers() }
    }

    /**
     * Looks for [games]' art first, now and at each new plan: their requests, when still waiting, go to the front of
     * the run.
     */
    suspend fun focus(games: List<GameId>) = update(None) {
        focused = games
        run.ahead(games)
    }

    private suspend fun resume() {
        // A run that stalled offline lost ScreenScraper with the network, not to the server.
        if (lock.withLock { run.stall == Some(Stall.OFFLINE) }) textures.networkBack()
        update(None) { run.resumed() }
        startWorkers()
    }

    private suspend fun startWorkers() = lock.withLock {
        if (!stopped) {
            repeat(WORKERS - working) { scope.launch { work() } }
            working = WORKERS
        }
    }

    private suspend fun work() {
        while (true) {
            val (request, seen) = next().getOrElse { return }
            var told = false
            val progress =
                Paced(
                    { fraction ->
                        if (request.game in focused) {
                            told = true
                            downloading(request.game, LabelDownload.Running(fraction))
                        }
                    },
                    TimeSource.Monotonic,
                )
            val outcome = lookUp(request, request.candidates, skipped = false, seen, progress)
            if (told) downloading(request.game, LabelDownload.Over)
            // Asked again while under way: looked for again, as the latest plan says.
            val over = { if (store.askedSince(request.game, seen)) run.returned(request.game) else run.finished(request.game) }
            when (outcome) {
                is Outcome.Found -> update(Some(FoundArt(request.game, outcome.art)), over)
                is Outcome.Kept -> {
                    if (outcome.provisional) {
                        store.keepProvisional(request.game, seen)
                    } else {
                        store.settle(request.game, seen)
                    }.onLeft { trace("art") { "${request.title}: label kept but not remembered so: ${it.message}" } }
                    update(None, over)
                }
                Outcome.Skipped, Outcome.Gone -> update(None, over)
                Outcome.Absent -> {
                    // A label the user chose meanwhile stays, and shows.
                    val stored =
                        store
                            .markAbsent(request.game, request.version, seen)
                            .onLeft { trace("art") { "${request.title}: not remembered as absent: ${it.message}" } }
                    update(stored.getOrNone().filter { !it }.map { AbsentArt(listOf(request.game)) }, over)
                }
                Outcome.SetAside -> update(None) { run.returned(request.game) }
                is Outcome.Stalled -> {
                    update(None) { run.stalled(request.game, outcome.why) }
                    lock.withLock { working-- }
                    scheduleRetry()
                    return
                }
            }
        }
    }

    /**
     * The next request, now under way, with the [Ask] its label is looked up again under, if any; none, and one
     * worker fewer, when stopped, stalled or when none waits.
     */
    private suspend fun next(): Option<Pair<ArtRequest, Option<Ask>>> = lock.withLock {
        run
            .take()
            .filter { !stopped }
            .map { (request, next) -> (request to store.asked(request.game)).also { run = next } }
            .onNone { working-- }
    }

    /** A provisional label's own image ends the walk: the images before it were the better ones. */
    private suspend fun lookUp(
        request: ArtRequest,
        candidates: List<Candidate>,
        skipped: Boolean,
        seen: Option<Ask>,
        progress: Progress,
    ): Outcome = if (stopped) {
        Outcome.SetAside
    } else {
        candidates.firstOrNone().fold({ if (skipped) Outcome.Skipped else Outcome.Absent }) { candidate ->
            if (store.provisional(request.game) == Some(candidate.identity)) {
                Outcome.Kept(skipped)
            } else {
                when (val tried = attempt(request, candidate, if (skipped) Some(candidate.identity) else None, seen, progress)) {
                    is Tried.Next -> lookUp(request, candidates.drop(1), skipped || tried.skipped, seen, progress)
                    is Tried.Found -> Outcome.Found(tried.art)
                    is Tried.Stalled -> Outcome.Stalled(tried.why)
                    Tried.Gone -> Outcome.Gone
                }
            }
        }
    }

    /**
     * Anything unexpected only skips this image, the label still wanted. Only the exception's class is logged: its message may hold a
     * URL with the credentials.
     */
    private suspend fun attempt(
        request: ArtRequest,
        candidate: Candidate,
        shownFor: Option<Identity>,
        seen: Option<Ask>,
        progress: Progress,
    ): Tried = if (store.isMissing(candidate, request.version)) {
        Tried.Next(skipped = false)
    } else if (hostOf(candidate).isSome { it in closedHosts }) {
        Tried.Next(skipped = true)
    } else {
        Either
            .catch {
                val started = TimeSource.Monotonic.markNow()
                store
                    .downloading { image -> fetched(request, candidate, shownFor, seen, progress, image, started) }
                    .getOrElse { Tried.Stalled(Stall.STORAGE) }
            }.getOrElse { e ->
                Log.e(TAG, "${request.title}: ${candidate.identity} skipped: ${e.javaClass.name}")
                Tried.Next(skipped = true)
            }
    }

    private suspend fun fetched(
        request: ArtRequest,
        candidate: Candidate,
        shownFor: Option<Identity>,
        seen: Option<Ask>,
        progress: Progress,
        image: File,
        started: TimeMark,
    ): Tried = fetch.get(candidate, progress, image).fold({ failure ->
        trace("art") { "${request.title}: ${candidate.identity}: $failure" }
        when (failure) {
            FetchFailure.NotFound -> {
                store.markMissing(candidate, request.version).onLeft {
                    trace("art") { "${request.title}: ${candidate.identity} not remembered as missing: ${it.message}" }
                }
                Tried.Next(skipped = false)
            }
            is FetchFailure.Skipped -> Tried.Next(skipped = true)
            is FetchFailure.Offline -> unreachable(candidate, Stall.OFFLINE)
            is FetchFailure.Refused -> unreachable(candidate, Stall.REFUSED)
            FetchFailure.Unstored -> Tried.Stalled(Stall.STORAGE)
        }
    }) {
        trace("art") { "front=${request.cut.medium.value} shell=${request.cut.shell.serialName}" }
        // A page in place of the image (a network's sign-in) says nothing of the game: its label stays wanted.
        ArtImages.label(image, candidate, request.cut, decoding).fold({ Tried.Next(skipped = it == Unusable.NOT_AN_IMAGE) }) { label ->
            // An image chosen by the user meanwhile stays.
            store.saveIfAbsent(request.game, label, shownFor, seen).fold({ Tried.Stalled(Stall.STORAGE) }) { kept ->
                kept.fold({ Tried.Gone }) { art ->
                    trace("art") {
                        "${request.title}: ${candidate.identity}: ${image.length() / 1024} kB, stored in ${label.size / 1024} kB, in ${started.elapsedNow().inWholeMilliseconds} ms"
                    }
                    Tried.Found(art)
                }
            }
        }
    }

    /**
     * A server out of reach or failing stalls the run only when the device has no validated network; with one, its host
     * alone is at fault (down, slow, a bad certificate): passed over for the run, the label still wanted.
     */
    private fun unreachable(candidate: Candidate, stall: Stall): Tried = if (online()) {
        hostOf(candidate).onSome { closedHosts += it }
        Tried.Next(skipped = true)
    } else {
        Tried.Stalled(stall)
    }

    private fun hostOf(candidate: Candidate): Option<String> = when (candidate) {
        is Candidate.Web -> Some(candidate.url.value.substringAfter("://").substringBefore('/'))
        is Candidate.Texture -> None
    }

    /** Schedules one retry: the workers that stall together wait for the same one. */
    private suspend fun scheduleRetry() = lock.withLock {
        if (retrying.isSome(Job::isActive)) return@withLock
        val wait = run.retryDelay
        trace("art") { "stalled (${run.stall}), trying again in ${wait.inWholeSeconds} s" }
        retrying =
            Some(
                scope.launch {
                    delay(wait)
                    lock.withLock { retrying = None }
                    resume()
                },
            )
    }

    /**
     * Applies [change] and tells [changed], in the order changes are made; a change that changes nothing is not told.
     */
    private suspend fun update(news: Option<LabelNews>, change: () -> Scraping): Unit = lock.withLock {
        val next = change()
        if (next != run) {
            run = next
            changed(run, news)
            if (run.isOver && run.done > 0) trace("art") { "run over: ${run.done} games in ${began.elapsedNow().inWholeSeconds} s" }
        }
    }

    private companion object {
        const val WORKERS = 4
    }
}
