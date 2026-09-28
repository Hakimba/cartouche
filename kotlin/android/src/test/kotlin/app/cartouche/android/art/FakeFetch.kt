// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtUrl
import arrow.core.Either
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.left

/**
 * A server holding [images] by URL, answering [answers] where it has none (not found by default),
 * and a network that is up while [online]. It counts the images it hands out, by URL, and calls
 * [during] as each download starts.
 */
internal class FakeFetch(var images: Map<String, ByteArray>, var answers: Map<String, FetchFailure> = emptyMap()) : Fetch {
    var online = true
    var during: (ArtUrl) -> Unit = {}
    val served = mutableMapOf<String, Int>()
    val asked = mutableListOf<String>()

    override fun get(url: ArtUrl): Either<FetchFailure, ByteArray> {
        asked += url.value
        during(url)
        if (!online) return FetchFailure.Offline("no network").left()
        return images.getOrNone(url.value).map { image -> image.also { served.merge(url.value, 1, Int::plus) } }.toEither {
            answers.getOrElse(url.value) { FetchFailure.NotFound }
        }
    }
}
