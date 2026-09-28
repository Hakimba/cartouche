// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.Log
import app.cartouche.android.TAG
import app.cartouche.android.trace
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.GameId
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
import kotlinx.coroutines.sync.withLock
import kotlin.time.TimeSource

/** A game's disc scan, just stored. */
internal data class FoundArt(val game: GameId, val art: StoredArt)

/**
 * Looks for games' art in the background, [WORKERS] downloads at a time, and stores what it finds
 * (see [Scraping] for the rules of a run). A stall (no network, a busy server) stops the run until
 * [networkBack] or a delay that grows with each stall in a row. After [stop] (the app leaves the
 * screen, a game is played), no download starts until [start]: the ones under way end, and their
 * games wait again. [changed] hears every change, in order.
 */
internal class Scraper(
    private val store: ArtStore,
    private val fetch: Fetch,
    private val scope: CoroutineScope,
    private val changed: (Scraping, Option<FoundArt>) -> Unit,
) {
    private sealed interface Outcome {
        data class Found(val art: StoredArt) : Outcome

        data object Absent : Outcome

        data class Stalled(val why: Stall) : Outcome

        /** Stopped before its end: the request waits again. */
        data object SetAside : Outcome
    }

    /** Guards [run], [working], [retrying] and [began]. */
    private val lock = Mutex()

    private var run = Scraping.NONE

    /** The workers running. */
    private var working = 0
    private var retrying: Option<Job> = None

    /** Set at once by [stop] and [start], so that the latest call wins; read before each download. */
    @Volatile private var stopped = false

    private var began = TimeSource.Monotonic.markNow()

    /** Looks for the art of [requests]' games that have none stored, and none known to be absent from their sources. */
    fun lookFor(requests: List<ArtRequest>) {
        scope.launch {
            // Under the lock: a game a worker stores meanwhile is either stored or still under way.
            update(None) {
                if (run.isOver) began = TimeSource.Monotonic.markNow()
                val missing = requests.filter { store.stored(it.game).isNone() && !store.isAbsent(it) }
                trace("art") { "${missing.size} of ${requests.size} games to look for" }
                run.with(missing)
            }
            startWorkers()
        }
    }

    /** Tries again at once if the run stalled for want of a network. */
    fun networkBack() {
        scope.launch {
            if (lock.withLock { run.stall == Some(Stall.OFFLINE) }) resume()
        }
    }

    /** Starts no download until [start]; the ones under way end. */
    fun stop() {
        stopped = true
        scope.launch { lock.withLock { retrying.onSome(Job::cancel) } }
    }

    fun start() {
        stopped = false
        scope.launch { if (lock.withLock { run.stall.isSome() }) scheduleRetry() else startWorkers() }
    }

    private suspend fun resume() {
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
            val request = next().getOrElse { return }
            when (val outcome = lookUp(request, request.candidates)) {
                is Outcome.Found -> update(Some(FoundArt(request.game, outcome.art))) { run.finished(request.game) }
                Outcome.Absent -> {
                    store.markAbsent(request).onLeft { trace("art") { "${request.title}: not remembered as absent: ${it.message}" } }
                    update(None) { run.finished(request.game) }
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

    /** The next request, now under way; none, and one worker fewer, when stopped, stalled or when none waits. */
    private suspend fun next(): Option<ArtRequest> = lock.withLock {
        run.take().filter { !stopped }.map { (request, next) -> request.also { run = next } }.onNone { working-- }
    }

    /** The first of [candidates] that downloads, stored; the next is tried when one is not found or not an image. */
    private fun lookUp(request: ArtRequest, candidates: List<ArtUrl>): Outcome = if (stopped) {
        Outcome.SetAside
    } else {
        candidates.firstOrNone().fold({ Outcome.Absent }) { url -> attempt(request, url).getOrElse { lookUp(request, candidates.drop(1)) } }
    }

    /**
     * The scan at [url] stored, or why the run stalls; none when it is not found or not an image. Anything
     * unexpected (a bug, a broken image) only skips this image: the worker goes on.
     */
    private fun attempt(request: ArtRequest, url: ArtUrl): Option<Outcome> = Either
        .catch {
            val started = TimeSource.Monotonic.markNow()
            fetch.get(url).fold({ failure ->
                trace("art") { "${request.title}: ${url.value}: $failure" }
                when (failure) {
                    FetchFailure.NotFound -> None
                    is FetchFailure.Offline -> Some(Outcome.Stalled(Stall.OFFLINE))
                    is FetchFailure.Refused -> Some(Outcome.Stalled(Stall.REFUSED))
                }
            }) { image ->
                ArtImages.label(image).map { label ->
                    store.save(request.game, label).fold({ Outcome.Stalled(Stall.STORAGE) }) { art ->
                        trace("art") {
                            "${request.title}: scan of ${image.size / 1024} kB, stored in ${label.size / 1024} kB, in ${started.elapsedNow().inWholeMilliseconds} ms"
                        }
                        Outcome.Found(art)
                    }
                }
            }
        }.getOrElse { e ->
            Log.e(TAG, "${request.title}: ${url.value} skipped", e)
            None
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

    /** Applies [change] and tells [changed], in the order changes are made. */
    private suspend fun update(found: Option<FoundArt>, change: () -> Scraping) = lock.withLock {
        run = change()
        changed(run, found)
        if (run.isOver && run.done > 0) trace("art") { "run over: ${run.done} games in ${began.elapsedNow().inWholeSeconds} s" }
    }

    private companion object {
        const val WORKERS = 4
    }
}
