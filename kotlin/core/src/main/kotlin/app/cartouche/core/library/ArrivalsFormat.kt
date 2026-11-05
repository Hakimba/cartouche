// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Why stored arrivals were not read; the app then marks no game. */
@JvmInline
public value class ArrivalsUnreadable(public val detail: String)

/**
 * The arrivals as stored on the device, in their own small file: leaving a game rewrites a few ids, not the library.
 * JSON with a format version, checked like any input when read back.
 */
public object ArrivalsFormat {
    private const val VERSION: Int = 1

    @Serializable
    private data class Stored(val version: Int, val arrivals: Arrivals)

    private val json = Json { encodeDefaults = true }

    public fun encode(arrivals: Arrivals): String = json.encodeToString(Stored.serializer(), Stored(VERSION, arrivals))

    public fun decode(text: String): Either<ArrivalsUnreadable, Arrivals> = either {
        val stored = Either.catch { json.decodeFromString(Stored.serializer(), text) }.mapLeft { ArrivalsUnreadable(it.toString()) }.bind()
        ensure(stored.version == VERSION) { ArrivalsUnreadable("format ${stored.version}, Cartouche reads format $VERSION") }
        stored.arrivals
    }
}
