// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.raise.either
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
                is UnsupportedVersion -> "The library file has format $version, Cartouche reads formats 1 to ${LibraryFormat.VERSION}"
            }
}

/** A library read back, with the format it was stored in. */
public data class StoredLibrary(public val library: Library, public val version: Int) {
    /** Whether it was stored by an earlier format: saving it again upgrades the file. */
    public val isOutdated: Boolean get() = version < LibraryFormat.VERSION
}

/**
 * The library as stored on the device: JSON with a format version, checked like any input when read back. Format 1
 * kept every ignored file; format 2 counts hidden and unsupported ones.
 */
public object LibraryFormat {
    public const val VERSION: Int = 2

    @Serializable
    private data class Stored(val version: Int, val library: Library)

    @Serializable
    private data class StoredV1(val library: LibraryV1)

    @Serializable
    private data class LibraryV1(
        val setups: Map<PlatformId, PlatformSetup> = emptyMap(),
        val games: List<Game> = emptyList(),
        val ignored: Map<PlatformId, List<IgnoredFile>> = emptyMap(),
    ) {
        fun upgraded(): Library =
            ignored.entries.fold(Library(setups, games)) { library, (platform, files) -> library.withIgnored(platform, files) }
    }

    /** Read alone when a file is not of this version, so that one from another version is reported as such. */
    @Serializable
    private data class Version(val version: Int)

    private val json = Json { encodeDefaults = true }

    // The version is read alone, and format 1 may hold fields a later build of it added: both
    // ignore what they do not know.
    private val lenient = Json { ignoreUnknownKeys = true }

    public fun encode(library: Library): String = json.encodeToString(Stored.serializer(), Stored(VERSION, library))

    public fun decode(text: String): Either<LibraryError, StoredLibrary> = either {
        fun <T> read(decode: () -> T): T = Either.catch(decode).mapLeft { LibraryError.Unreadable(it.toString()) }.bind()
        // A file of this version, the usual case, is read in one pass; any other goes through its version first.
        val current = Either.catch { json.decodeFromString(Stored.serializer(), text) }.getOrNone().filter { it.version == VERSION }
        val version = current.fold({ read { lenient.decodeFromString(Version.serializer(), text) }.version }) { VERSION }
        val library =
            when (version) {
                1 -> read { lenient.decodeFromString(StoredV1.serializer(), text) }.library.upgraded()
                VERSION -> current.fold({ read { json.decodeFromString(Stored.serializer(), text) } }) { it }.library
                else -> raise(LibraryError.UnsupportedVersion(version))
            }
        // A hand-edited file may point past a game's discs: launches then start from the first one.
        val games = library.games.map { if (it.lastDisc in it.discs.indices) it else it.copy(lastDisc = 0) }
        StoredLibrary(library.copy(games = games), version)
    }
}
