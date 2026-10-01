// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.read
import app.cartouche.android.storage.write
import app.cartouche.core.art.AbsentArt
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
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
 * are not looked for at every start. Images are written atomically: a file there is always a whole image. Safe to use from
 * several threads.
 */
internal class ArtStore(private val folder: File) {
    private val absentFile = AtomicFile(File(folder, "absent.json"))

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

    fun stored(game: GameId): Option<StoredArt> = stored.getOrNone(hash(game))

    /** Stores [image] as [game]'s disc scan. */
    fun save(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> {
        folder.mkdirs()
        val stem = hash(game)
        val art = StoredArt(File(folder, "$stem.jpg"))
        return AtomicFile(art.file).write(image).map { art.also { stored[stem] = it } }
    }

    /**
     * Deletes the images and the absence of the games not in [kept] (a platform removed, games gone
     * from their folder); answers how many images went. An image stored meanwhile by a download
     * under way goes at the next call.
     */
    @Synchronized
    fun keepOnly(kept: Set<GameId>): Either<StorageFailure, Int> {
        val stems = kept.mapTo(HashSet(), ::hash)
        val gone = stored.keys.filter { it !in stems }
        // A file that cannot be deleted is listed again at the next start, and goes then.
        gone.forEach { stem -> stored.remove(stem).toOption().onSome { it.file.delete() } }
        val absentKept = absent().keeping(kept)
        return (if (absentKept == absent()) Unit.right() else writeAbsent(absentKept)).map { gone.size }
    }

    /** The games no source has art for, read on first use, then kept in step with their file. */
    private var absent: Option<AbsentArt> = None

    /** Whether [request]'s game is known to have no art in its sources. */
    @Synchronized
    fun isAbsent(request: ArtRequest): Boolean = absent().covers(request)

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

    private companion object {
        val NAME = Regex("""([0-9a-f]{40})\.jpg""")

        fun hash(game: GameId): String =
            MessageDigest.getInstance("SHA-1").digest(game.value.encodeToByteArray()).joinToString("") { "%02x".format(it) }
    }
}
