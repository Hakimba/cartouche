// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import app.cartouche.android.ART_PROGRESS_SIGNAL
import app.cartouche.android.ART_SIGNAL
import app.cartouche.android.Code
import app.cartouche.android.Failed
import app.cartouche.android.Reference
import app.cartouche.android.Sent
import app.cartouche.android.Threads
import app.cartouche.android.VARIANT_SIGNAL
import app.cartouche.android.failed
import app.cartouche.android.jsonOf
import app.cartouche.android.library.Shown
import app.cartouche.android.sent
import app.cartouche.android.trace
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Scraping
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.serialName
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.raise.either
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.withContext
import kotlin.time.TimeSource

/** Its pieces share [fetch], so every download counts on the same ScreenScraper quota and limits. */
internal class ArtService(
    private val threads: Threads,
    val store: ArtStore,
    private val shown: () -> Shown,
    private val reference: () -> Reference,
    private val preferredRegion: () -> Option<PreferredRegion>,
    fetch: Fetch,
    private val textures: Textures,
    private val connectivity: () -> ConnectivityManager,
    scraperDecoding: Semaphore = Semaphore(ArtImages.SCRAPER_DECODES),
    private val emit: (String, String) -> Unit,
) {
    // Two gates, so a variant card opened during a scrape does not wait behind the scraper's queued decodes.
    private val scraper = Scraper(store, fetch, threads.scope, textures, ::online, scraperDecoding, ::downloading, ::changed)
    private val variantDownloads =
        VariantDownloads(store, fetch, threads.scope, threads.variants, Semaphore(Threads.VARIANT_DOWNLOADS), ::variantDownloaded)

    private val network =
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = scraper.networkBack()
        }

    /**
     * The platform of the label chooser opened last, until the app leaves the screen: its art table outlives the run. Nothing tells
     * the plugin a chooser closed, so it is held until the next pause or the next chooser.
     */
    @Volatile private var chooser: Option<PlatformId> = None

    /** Watches the network from the first art looked for on, to resume as soon as it comes back. */
    private val watchingNetwork = lazy { Either.catch { connectivity().registerDefaultNetworkCallback(network) }.isRight() }

    /** Whether the device's network reaches the internet, as Android validated it; not when it cannot tell. */
    private fun online(): Boolean = Either
        .catch {
            val manager = connectivity()
            Option.fromNullable(manager.getNetworkCapabilities(manager.activeNetwork)).isSome {
                it.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            }
        }.getOrElse { false }

    fun start() {
        scraper.start()
        variantDownloads.start()
    }

    fun stop() {
        scraper.stop()
        variantDownloads.stop()
        chooser = None
        threads.scope.launch(threads.planning) { forgetSources() }
    }

    fun close() {
        if (watchingNetwork.isInitialized() && watchingNetwork.value) Either.catch { connectivity().unregisterNetworkCallback(network) }
    }

    fun focus(games: List<GameId>) {
        threads.scope.launch(threads.planning) { scraper.focus(games) }
    }

    suspend fun forgetLooks() = withContext(threads.planning) { scraper.lookFor(emptyList()) }

    /**
     * Done once the scraper has the games to look for. [again] picks, among the games, the labels asked again; it is planned on the
     * planning thread so that an answer never waits for it and its failure fails no answer.
     */
    fun lookForArt(again: (List<Game>) -> Set<GameId> = { emptySet() }): Job = threads.scope.launch(threads.library) {
        val library = shown()
        if (library is Shown.Demo) return@launch
        library.service.gamesWithArt().onSome { kept ->
            store
                .keepOnly(kept)
                .onRight { deleted -> if (deleted > 0) trace("art") { "$deleted images of games no longer in the library deleted" } }
                .onLeft { trace("art") { "images of games no longer in the library not deleted: ${it.message}" } }
        }
        // Read with the games, on this thread like the user's choices: one made after is never asked again.
        val since = store.choices()
        val games = library.service.library().games
        val preferred = preferredRegion()
        val reference = reference()
        // A child: the look is over once the scraper has its requests, but this thread is free at once.
        launch(threads.planning) {
            val asked = again(games)
            val wants = { game: GameId, version: Option<ArtVersion> -> game in asked || store.wants(game, version) }
            val plan =
                ArtSources.requests(games, wants, { store.provisional(it).isSome() }, reference::artVersion) {
                    reference.sources(it, preferred)
                }
            scraper.absent(plan.unfound)
            scraper.lookFor(plan.requests, asked, since)
            // A plan that started no download tells no change of the run.
            forgetSources()
        }
        if (!watchingNetwork.value) trace("art") { "the network is not watched: retries only follow their delay" }
    }

    fun preferredRegionChanged(before: Option<PreferredRegion>, chosen: Option<PreferredRegion>) {
        if (chosen == before) return
        lookForArt { games ->
            ArtSources
                .reordered(games, { sources(it, before) }, { sources(it, chosen) }) { candidate, version ->
                    !store.isMissing(candidate, version)
                }.also { trace("art") { "${it.size} labels to look up again in the preferred region's order" } }
        }
    }

    /** A file's header may now tell a shell that moves its label's cut: those labels are cut anew. */
    fun recutAfterScan(before: List<Game>) {
        val catalog = reference().catalog
        lookForArt { games -> ArtSources.recut(before, games, catalog) }
    }

    /**
     * Downloads the images not downloaded yet, each told through [VARIANT_SIGNAL]. Its trace tells whether the platform's art table
     * had to be indexed again first, the wait a chooser opened after a run has.
     */
    fun labelVariants(game: Game): Sent.LabelVariants {
        val asked = TimeSource.Monotonic.markNow()
        chooser = Some(game.platform)
        val held = if (reference().holdsSources(game.platform)) "held" else "indexed"
        val sources = sources(game.platform, preferredRegion())
        val stored = sources.variantsOf(game, offered(sources.version)).map { it to store.variant(it.candidate) }
        // The newest kept: the downloads that follow never push out the images of the chooser now open.
        val now = System.currentTimeMillis()
        stored.forEach { (_, art) -> art.onSome { it.file.setLastModified(now) } }
        val missing = stored.filter { it.second.isNone() }.map { it.first }
        val took = asked.elapsedNow().inWholeMilliseconds
        trace("art") { "${game.title}: ${stored.size} images, ${missing.size} to download, answered in $took ms, art table $held" }
        variantDownloads.download(game.id, missing, sources.cutOf(game), sources.version)
        return Sent.LabelVariants(stored.map { (variant, art) -> variant.sent(None, art.map { it.file.path }, None) })
    }

    fun chooseLabel(game: Game, region: String, source: String): Either<Failed, Sent.ArtAnswer> = either {
        val sources = sources(game.platform, preferredRegion())
        val offered = offered(sources.version)
        // An image already downloaded stays choosable once its source closes (ScreenScraper after the chooser opened).
        val variant =
            sources
                .variantsOf(game) { store.variant(it).isSome() || offered(it) }
                .firstOrNone { it.region.name == region && it.candidate.source.serialName == source }
                .getOrElse { raise(Failed(Code.NO_IMAGE, "No image of ${game.title} for region '$region' at '$source'")) }
        val art = LabelChoices(shown().service, store).choose(game, variant).mapLeft { it.failed }.bind()
        trace("art") { "${game.title}: label of region '$region' at '$source' chosen" }
        Sent.ArtAnswer(FoundArt(game.id, art).sent())
    }

    /** No texture while ScreenScraper is not open or the app has no key: the region's scan alone then. */
    fun offered(version: Option<ArtVersion>): (Candidate) -> Boolean = { candidate ->
        !store.isMissing(candidate, version) &&
            when (candidate) {
                is Candidate.Web -> true
                is Candidate.Texture -> textures.open
            }
    }

    private fun sources(platform: PlatformId, preferred: Option<PreferredRegion>): ArtSources = reference().sources(platform, preferred)

    /**
     * The art tables serve only a look's plan and a chooser: once the run is over, all but the last chooser's are forgotten.
     * Run on the planning thread, so that no plan loses them halfway (it asks them game by game).
     */
    private suspend fun forgetSources() {
        if (scraper.isOver()) reference().forgetSources(keeping = chooser)
    }

    private fun variantDownloaded(game: GameId, variant: ArtVariant, kept: Either<VariantFailure, StoredArt>) {
        trace("art") {
            "${variant.region.name} image of ${game.value} at ${variant.candidate.source.serialName}: ${kept.fold(
                { it.serialName },
            ) { "downloaded" }}"
        }
        emit(VARIANT_SIGNAL, jsonOf(variant.sent(Some(game), kept.getOrNone().map { it.file.path }, kept.swap().getOrNone())))
    }

    private fun changed(run: Scraping, news: Option<LabelNews>) {
        emit(ART_SIGNAL, jsonOf(run.sent(news)))
        if (run.isOver) threads.scope.launch(threads.planning) { forgetSources() }
    }

    private fun downloading(game: GameId, download: LabelDownload) = emit(ART_PROGRESS_SIGNAL, jsonOf(download.sent(game)))
}
