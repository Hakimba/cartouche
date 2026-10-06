// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.trace
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.library.Game
import app.cartouche.core.library.LabelChoice
import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure

/** Why an image could not be kept as a game's label. */
internal sealed interface LabelFailure {
    /** The image is not downloaded. */
    data object NotDownloaded : LabelFailure

    /** No picture of the user's own is being framed. */
    data object NotPicked : LabelFailure

    /** The picture picked cannot be read as an image. */
    data class Unreadable(val reason: String) : LabelFailure

    data class Library(val failure: LibraryFailure) : LabelFailure

    data class Storage(val failure: StorageFailure) : LabelFailure
}

/** Keeps an image as a game's label: the choice recorded in [library], the image stored in [store]. */
internal class LabelChoices(private val library: LibraryService, private val store: ArtStore) {
    /**
     * Shows [variant] (downloaded) on [game]'s label from now on. The choice is recorded first;
     * when its image cannot be stored then, the choice is given up and the label stays as it was.
     */
    fun choose(game: Game, variant: ArtVariant): Either<LabelFailure, StoredArt> = either {
        ensure(store.variant(variant.url).isSome()) { LabelFailure.NotDownloaded }
        keeping(game, LabelChoice.Region(variant.region)) { store.adopt(game.id, variant.url) }.bind()
    }

    /** Shows [image], a picture of the user's own framed by them, on [game]'s label from now on, as [choose] does. */
    fun keepOwn(game: Game, image: ByteArray): Either<LabelFailure, StoredArt> =
        keeping(game, LabelChoice.Own) { store.save(game.id, image) }

    /** Records [choice], then stores its image with [storing]; gives the choice up when the image cannot be stored. */
    private fun keeping(
        game: Game,
        choice: LabelChoice,
        storing: () -> Either<StorageFailure, StoredArt>,
    ): Either<LabelFailure, StoredArt> = either {
        library.chooseLabel(game.id, choice).mapLeft(LabelFailure::Library).bind()
        storing()
            .mapLeft { failure ->
                library.chooseLabel(game.id, game.label).onLeft { trace("art") { "${game.title}: choice not given up: ${it.message}" } }
                LabelFailure.Storage(failure)
            }.bind()
    }
}
