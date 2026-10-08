// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.read
import app.cartouche.android.storage.write
import app.cartouche.core.art.AbsentArt
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.right
import arrow.core.toOption
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/** A game's disc scan, as stored. */
@JvmInline
internal value class StoredArt(val file: File)

/**
 * The label images found for games, one file each in [folder] (the app's private storage), named
 * after a hash of the game's id, and the games no source has art for ([AbsentArt]), so that they
 * are not looked for at every start. Images are written atomically: a file there is always a whole
 * image. Safe to use from several threads.
 */
internal class ArtStore(private val folder: File) {
    private val absentFile = AtomicFile(File(folder, "absent.json"))

    /** The games no source has art for, read on first use, then kept in step with their file. */
    private var absent: Option<AbsentArt> = None

    private val variants = File(folder, "variants")

    /** The stored images by file name stem (the hash), read from [folder] on first use. */
    private val stored: ConcurrentHashMap<String, StoredArt> by lazy {
        ConcurrentHashMap(
            folder
                .listFiles()
                .orEmpty()
                .flatMap { file ->
                    NAME.matchEntire(file.name).toOption().map { it.groupValues[1] to StoredArt(file) }.toList()
                }.toMap(),
        )
    }

    fun stored(game: GameId): Option<StoredArt> = stored.getOrNone(sha1(game.value))

    /** Stores [image] as [game]'s disc scan. */
    @Synchronized
    fun save(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> {
        folder.mkdirs()
        val stem = sha1(game.value)
        val art = StoredArt(File(folder, "$stem.jpg"))
        return AtomicFile(art.file).write(image).map { art.also { stored[stem] = it } }
    }

    /** Stores [image] as [game]'s disc scan unless it has one, chosen by the user meanwhile; answers the one it has then. */
    @Synchronized
    fun saveIfAbsent(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> =
        stored(game).fold({ save(game, image) }) { it.right() }

    /** Stores the scan of [url] kept by [saveVariant] as [game]'s disc scan; fails when it is gone or cannot be read. */
    @Synchronized
    fun adopt(game: GameId, url: ArtUrl): Either<StorageFailure, StoredArt> = Either
        .catch { variantFile(url).readBytes() }
        .mapLeft { StorageFailure.Unavailable("the image of ${url.value} cannot be read: $it") }
        .flatMap { save(game, it) }

    /** The scan of [url] kept by [saveVariant], while it is among the latest ones. */
    fun variant(url: ArtUrl): Option<StoredArt> = Some(variantFile(url)).filter(File::isFile).map(::StoredArt)

    /**
     * Keeps [image], the scan at [url], to be shown and chosen among a game's other images; only
     * the [VARIANTS_KEPT] latest ones are kept, the others deleted.
     */
    @Synchronized
    fun saveVariant(url: ArtUrl, image: ByteArray): Either<StorageFailure, StoredArt> {
        variants.mkdirs()
        val art = StoredArt(variantFile(url))
        return AtomicFile(art.file).write(image).map {
            // The newest kept, this one first; a file that cannot be deleted only stays until the next save.
            variants
                .listFiles()
                .orEmpty()
                .filter { NAME.matches(it.name) && it != art.file }
                .sortedByDescending(File::lastModified)
                .drop(VARIANTS_KEPT - 1)
                .forEach(File::delete)
            art
        }
    }

    private fun variantFile(url: ArtUrl): File = File(variants, "${sha1(url.value)}.jpg")

    /**
     * Deletes the images and the absence of the games not in [kept] (a platform removed, games gone
     * from their folder); answers how many images went. An image stored meanwhile by a download
     * under way goes at the next call.
     */
    @Synchronized
    fun keepOnly(kept: Set<GameId>): Either<StorageFailure, Int> {
        val stems = kept.mapTo(HashSet()) { sha1(it.value) }
        val gone = stored.keys.filter { it !in stems }
        // A file that cannot be deleted is listed again at the next start, and goes then.
        gone.forEach { stem -> stored.remove(stem).toOption().onSome { it.file.delete() } }
        val absentKept = absent().keeping(kept)
        return (if (absentKept == absent()) Unit.right() else writeAbsent(absentKept)).map { gone.size }
    }

    /** Whether [game] is known to have no art in sources of [version]. */
    @Synchronized
    fun isAbsent(game: GameId, version: Option<ArtVersion>): Boolean = absent().covers(game, version)

    /** Whether [game]'s art is still to be looked for in sources of [version]: none is stored, nor known to be missing there. */
    fun wants(game: GameId, version: Option<ArtVersion>): Boolean = stored(game).isNone() && !isAbsent(game, version)

    /** Remembers that no source of [request] has art for its game. */
    @Synchronized
    fun markAbsent(request: ArtRequest): Either<StorageFailure, Unit> {
        folder.mkdirs()
        return writeAbsent(absent().with(request))
    }

    private fun writeAbsent(now: AbsentArt): Either<StorageFailure, Unit> =
        absentFile.write(AbsentArt.encode(now)).map { absent = Some(now) }

    /** An unreadable file only means looking for those games again. */
    private fun absent(): AbsentArt = absent.getOrElse {
        absentFile
            .read(None, { it }) { text -> AbsentArt.decode(text).right() }
            .getOrElse { None }
            .getOrElse { AbsentArt() }
            .also { absent = Some(it) }
    }

    companion object {
        private val NAME = Regex("""([0-9a-f]{40})\.jpg""")

        /** Enough for a few screens of a game's images, a few megabytes. */
        const val VARIANTS_KEPT = 48

        /** [text]'s SHA-1 in lower-case hexadecimal; made for every game at each start, so without `format`. */
        @OptIn(ExperimentalStdlibApi::class)
        internal fun sha1(text: String): String = MessageDigest.getInstance("SHA-1").digest(text.encodeToByteArray()).toHexString()
    }
}
