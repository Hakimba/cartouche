// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.Log
import app.cartouche.android.TAG
import app.cartouche.android.Threads
import app.cartouche.android.trace
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.LabelCut
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.Option
import arrow.core.flatMap
import arrow.core.flatten
import arrow.core.right
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** Why an image of a game's label could not be had. */
@Serializable
internal enum class VariantFailure {
    @SerialName("offline")
    OFFLINE,

    @SerialName("refused")
    REFUSED,

    @SerialName("not_found")
    NOT_FOUND,

    /** Downloaded, but not an image Android can read, or a scan of no shape its label can be cut from. */
    @SerialName("unreadable")
    UNREADABLE,

    @SerialName("storage")
    STORAGE,
}

/**
 * Downloads the images of games' labels by region (see `ArtSources.variantsOf`) on [downloads], a few at a time
 * beside the scraper, and keeps them in [store]; [done] hears how each went. An image already under way or kept is not
 * asked for again.
 */
internal class VariantDownloads(
    private val store: ArtStore,
    private val fetch: Fetch,
    private val scope: CoroutineScope,
    private val downloads: CoroutineDispatcher,
    private val decoding: Semaphore = Semaphore(Threads.VARIANT_DOWNLOADS),
    private val done: (GameId, ArtVariant, Either<VariantFailure, StoredArt>) -> Unit,
) {
    private val underWay = ConcurrentHashMap.newKeySet<ArtVariant>()

    /** Off from [stop] to [start]: a game is played meanwhile, no download starts; those under way end. */
    private val running = MutableStateFlow(true)

    fun stop() {
        running.value = false
    }

    fun start() {
        running.value = true
    }

    /** Downloads [game]'s [variants], of sources of [version], whose labels [cut] gives, that are not under way. */
    fun download(game: GameId, variants: List<ArtVariant>, cut: LabelCut, version: Option<ArtVersion>) {
        variants.filter(underWay::add).forEach { variant ->
            scope.launch(downloads) {
                try {
                    running.first { it }
                    // Read again once under way: one kept since the caller's read is not downloaded twice. Anything
                    // unexpected is told too, or the card would wait for ever; its class alone is logged, as its
                    // message may hold a URL with the credentials.
                    val kept =
                        Either
                            .catch { store.variant(variant.candidate).fold({ kept(variant, cut, version) }) { it.right() } }
                            .mapLeft { e ->
                                Log.e(TAG, "${variant.candidate.identity} not downloaded: ${e.javaClass.name}")
                                VariantFailure.UNREADABLE
                            }.flatten()
                    done(game, variant, kept)
                } finally {
                    underWay.remove(variant)
                }
            }
        }
    }

    /** The image, cut and kept; a texture ScreenScraper has none of is remembered so. */
    private suspend fun kept(variant: ArtVariant, cut: LabelCut, version: Option<ArtVersion>): Either<VariantFailure, StoredArt> =
        store.downloading { image -> kept(variant, cut, version, image) }.mapLeft { VariantFailure.STORAGE }.flatten()

    private suspend fun kept(
        variant: ArtVariant,
        cut: LabelCut,
        version: Option<ArtVersion>,
        image: File,
    ): Either<VariantFailure, StoredArt> = fetch
        .get(variant.candidate, Progress.NONE, image)
        .mapLeft { failure ->
            when (failure) {
                FetchFailure.NotFound -> {
                    store.markMissing(variant.candidate, version).onLeft {
                        trace("art") { "${variant.candidate.identity} not remembered as missing: ${it.message}" }
                    }
                    VariantFailure.NOT_FOUND
                }
                is FetchFailure.Offline -> VariantFailure.OFFLINE
                is FetchFailure.Refused, is FetchFailure.Skipped -> VariantFailure.REFUSED
                FetchFailure.Unstored -> VariantFailure.STORAGE
            }
        }.flatMap { ArtImages.label(image, variant.candidate, cut, decoding).mapLeft { VariantFailure.UNREADABLE } }
        .flatMap { label -> store.saveVariant(variant.candidate, label).mapLeft { VariantFailure.STORAGE } }
}
