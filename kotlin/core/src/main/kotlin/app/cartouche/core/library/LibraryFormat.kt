// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import arrow.core.Either
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

public sealed interface LibraryError {
    public data class Unreadable(public val detail: String) : LibraryError

    public data class UnsupportedVersion(public val version: Int) : LibraryError

    /** English description, for logs. */
    public val message: String
        get() =
            when (this) {
                is Unreadable -> "The library file cannot be read: $detail"
                is UnsupportedVersion -> "The library file has format $version, this version of Cartouche reads ${LibraryFormat.VERSION}"
            }
}

/** The library as stored on the device: JSON with a format version, checked like any input when read back. */
public object LibraryFormat {
    public const val VERSION: Int = 1

    @Serializable
    private data class Stored(val version: Int, val library: Library)

    /** Read first, alone, so that a file from another version is reported as such. */
    @Serializable
    private data class Version(val version: Int)

    private val json = Json { encodeDefaults = true }
    private val versionOnly = Json { ignoreUnknownKeys = true }

    public fun encode(library: Library): String = json.encodeToString(Stored.serializer(), Stored(VERSION, library))

    public fun decode(text: String): Either<LibraryError, Library> = either {
        fun <T> read(decode: () -> T): T = Either.catch(decode).mapLeft { LibraryError.Unreadable(it.toString()) }.bind()
        val version = read { versionOnly.decodeFromString(Version.serializer(), text) }.version
        ensure(version == VERSION) { LibraryError.UnsupportedVersion(version) }
        // A hand-edited file may point past a game's discs: launches then start from the first one.
        read { json.decodeFromString(Stored.serializer(), text) }.library.let { library ->
            library.copy(games = library.games.map { if (it.lastDisc in it.discs.indices) it else it.copy(lastDisc = 0) })
        }
    }
}
