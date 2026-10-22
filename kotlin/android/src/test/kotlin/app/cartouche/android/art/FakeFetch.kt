// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.Candidate
import arrow.core.Either
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.left

/**
 * Servers holding [images] by candidate identity (a scan's URL), answering [answers] where they
 * have none (not found by default), and a network that is up while [online]. It counts the images
 * it hands out, by identity, and calls [during] as each download starts; an image handed out is told
 * whole to its progress.
 */
internal class FakeFetch(var images: Map<String, ByteArray>, var answers: Map<String, FetchFailure> = emptyMap()) : Fetch {
    var online = true
    var during: (Candidate) -> Unit = {}
    val served = mutableMapOf<String, Int>()
    val asked = mutableListOf<String>()

    override suspend fun get(candidate: Candidate, progress: Progress): Either<FetchFailure, ByteArray> {
        val identity = candidate.identity.value
        asked += identity
        during(candidate)
        if (!online) return FetchFailure.Offline("no network").left()
        return images
            .getOrNone(identity)
            .map { image -> image.also { served.merge(identity, 1, Int::plus) }.also { progress.read(Some(1.0)) } }
            .toEither { answers.getOrElse(identity) { FetchFailure.NotFound } }
    }
}
