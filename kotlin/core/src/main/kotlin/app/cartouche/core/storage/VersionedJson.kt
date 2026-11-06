// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.storage

import arrow.core.Either
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** Why a stored state was not read; its owner then starts from its default. */
@JvmInline
public value class StateUnreadable(public val detail: String)

/**
 * A small state stored in a file of its own, `{"version": version, field: state}`: its version is checked like any
 * input when read back, and [field] names what the file holds, so it is part of the format.
 */
public open class VersionedJson<T>(private val version: Int, private val field: String, private val state: KSerializer<T>) {
    public fun encode(value: T): String = json.encodeToString(
        JsonObject.serializer(),
        JsonObject(mapOf(VERSION to JsonPrimitive(version), field to json.encodeToJsonElement(state, value))),
    )

    public fun decode(text: String): Either<StateUnreadable, T> = either {
        val stored = read { json.decodeFromString(JsonObject.serializer(), text) }
        ensure(stored.keys == setOf(VERSION, field)) { StateUnreadable("fields ${stored.keys}, Cartouche reads $VERSION and $field") }
        val found = read { json.decodeFromJsonElement(Int.serializer(), stored.getValue(VERSION)) }
        ensure(found == version) { StateUnreadable("format $found, Cartouche reads format $version") }
        read { json.decodeFromJsonElement(state, stored.getValue(field)) }
    }

    private fun <A> Raise<StateUnreadable>.read(decode: () -> A): A = Either.catch(decode).mapLeft { StateUnreadable(it.toString()) }.bind()

    private companion object {
        const val VERSION = "version"

        val json = Json { encodeDefaults = true }
    }
}
