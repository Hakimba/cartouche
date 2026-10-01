// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Why stored settings were not read; the app then starts with none, as on a first launch. */
@JvmInline
public value class SettingsUnreadable(public val detail: String)

/** The settings as stored on the device: JSON with a format version, checked like any input when read back. */
public object SettingsFormat {
    private const val VERSION: Int = 2

    @Serializable
    private data class Stored(val version: Int, val settings: Settings)

    private val json = Json { encodeDefaults = true }

    public fun encode(settings: Settings): String = json.encodeToString(Stored.serializer(), Stored(VERSION, settings))

    public fun decode(text: String): Either<SettingsUnreadable, Settings> = either {
        val stored = Either.catch { json.decodeFromString(Stored.serializer(), text) }.mapLeft { SettingsUnreadable(it.toString()) }.bind()
        ensure(stored.version == VERSION) { SettingsUnreadable("format ${stored.version}, Cartouche reads format $VERSION") }
        stored.settings
    }
}
