// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.shelves

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Why a stored selection was not read; the user then starts from the first game. */
@JvmInline
public value class SelectionUnreadable(public val detail: String)

/**
 * The selection as stored on the device, in its own small file: saving it costs the same whatever the size of the
 * library. JSON with a format version, checked like any input when read back.
 */
public object SelectionFormat {
    private const val VERSION: Int = 1

    @Serializable
    private data class Stored(val version: Int, val selection: Selection)

    private val json = Json { encodeDefaults = true }

    public fun encode(selection: Selection): String = json.encodeToString(Stored.serializer(), Stored(VERSION, selection))

    public fun decode(text: String): Either<SelectionUnreadable, Selection> = either {
        val stored = Either.catch { json.decodeFromString(Stored.serializer(), text) }.mapLeft { SelectionUnreadable(it.toString()) }.bind()
        ensure(stored.version == VERSION) { SelectionUnreadable("format ${stored.version}, Cartouche reads format $VERSION") }
        stored.selection
    }
}
