// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import arrow.core.Option
import arrow.core.getOrNone
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * What no source of a given version has: the games none has art for (by their id), or the
 * textures ScreenScraper answered it has none of (`NOMEDIA`, by their identity), each with the
 * version of the sources it was asked in, so that it is asked again once the extract or the
 * texture table changes. Sources of no version are never remembered.
 */
@Serializable
public data class Absences<K>(private val known: Map<K, ArtVersion> = emptyMap()) {
    /** Whether [key] is known to be missing from sources of [version]; never from sources of no version. */
    public fun covers(key: K, version: Option<ArtVersion>): Boolean = version.isSome { known.getOrNone(key) == Option(it) }

    /** Remembers that sources of [version] lack [key]. */
    public fun with(key: K, version: Option<ArtVersion>): Absences<K> = version.fold({ this }) { copy(known = known + (key to it)) }

    /** Only what is remembered of [kept]. */
    public fun keeping(kept: Set<K>): Absences<K> = copy(known = known.filterKeys { it in kept })

    public companion object {
        /** Stored as JSON, the keys written by [key]; an unreadable text is none, which only means asking again. */
        public fun <K> decode(text: String, key: KSerializer<K>): Option<Absences<K>> =
            Option.catch { Json.decodeFromString(serializer(key), text) }

        public fun <K> encode(absences: Absences<K>, key: KSerializer<K>): String = Json.encodeToString(serializer(key), absences)
    }
}
