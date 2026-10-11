// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.LabelCut
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.flatMap
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

/** Why an image of a game's label could not be had. */
internal enum class VariantFailure {
    OFFLINE,
    REFUSED,
    NOT_FOUND,

    /** Downloaded, but not an image Android can read, or a scan of no shape its label can be cut from. */
    UNREADABLE,
    STORAGE,
}

/**
 * Downloads the images of games' labels by region (see `ArtSources.variantsOf`) on [downloads], a
 * few at a time beside the scraper, and keeps them in [store]; [done] hears how each went. An image
 * already under way is not asked for again.
 */
internal class VariantDownloads(
    private val store: ArtStore,
    private val fetch: Fetch,
    private val scope: CoroutineScope,
    private val downloads: CoroutineDispatcher,
    private val done: (GameId, ArtVariant, Either<VariantFailure, StoredArt>) -> Unit,
) {
    private val underWay = ConcurrentHashMap.newKeySet<ArtVariant>()

    /** Downloads [game]'s [variants], whose labels [cut] gives, that are not under way. */
    fun download(game: GameId, variants: List<ArtVariant>, cut: LabelCut) {
        variants.filter(underWay::add).forEach { variant ->
            scope.launch(downloads) {
                try {
                    done(game, variant, kept(variant, cut))
                } finally {
                    underWay.remove(variant)
                }
            }
        }
    }

    private fun kept(variant: ArtVariant, cut: LabelCut): Either<VariantFailure, StoredArt> = fetch
        .get(variant.url)
        .mapLeft { failure ->
            when (failure) {
                FetchFailure.NotFound -> VariantFailure.NOT_FOUND
                is FetchFailure.Offline -> VariantFailure.OFFLINE
                is FetchFailure.Refused -> VariantFailure.REFUSED
            }
        }.flatMap { image -> ArtImages.label(image, cut).toEither { VariantFailure.UNREADABLE } }
        .flatMap { label -> store.saveVariant(variant.url, label).mapLeft { VariantFailure.STORAGE } }
}
