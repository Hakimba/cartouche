// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.read
import app.cartouche.android.storage.write
import app.cartouche.core.art.Absences
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Identity
import app.cartouche.core.art.LookAgain
import app.cartouche.core.art.ProvisionalArt
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
import kotlinx.serialization.json.Json
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/** A game's disc scan, as stored. */
@JvmInline
internal value class StoredArt(val file: File)

/** One time labels were asked again ([ArtStore.retry], [ArtStore.lookAgain]), later ones numbered higher. */
@JvmInline
internal value class Ask(val number: Long)

/**
 * The label images found for games, one file each in [folder] (the app's private storage), named
 * after a hash of the game's id, and what is remembered beside them: the games no source has art
 * for and the textures ScreenScraper has none of ([Absences], so that neither is asked at every
 * start), the labels shown for want of a skipped ScreenScraper texture ([ProvisionalArt]), and the
 * labels asked again, so that a look stopped with the app still ends at the next start.
 * Images are written atomically: a file there is always a whole image. Safe to use from several
 * threads.
 */
internal class ArtStore(private val folder: File) {
    private val absentGames =
        Remembered(folder, "absent.json", Absences<GameId>(), { Absences.decode(it, GameId.serializer()) }) {
            Absences.encode(it, GameId.serializer())
        }

    private val missingTextures =
        Remembered(folder, "nomedia.json", Absences<Identity>(), { Absences.decode(it, Identity.serializer()) }) {
            Absences.encode(it, Identity.serializer())
        }

    private val provisionalLabels = Remembered(folder, "provisional.json", ProvisionalArt(), ProvisionalArt::decode, ProvisionalArt::encode)

    private val variants = File(folder, "variants")

    /**
     * The games, by stem, whose label is looked up again ([retry], [lookAgain]), each with the
     * [Ask] that asked it: only a look taken under that ask settles it (see [asked]).
     */
    private val lookedUpAgain =
        Remembered(folder, "again.json", emptyMap<String, Long>(), { Option.catch { Json.decodeFromString<Map<String, Long>>(it) } }) {
            Json.encodeToString(it)
        }

    /** The latest [Ask]'s number; above every remembered one once [asking] ran. */
    private var asks = 0L

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

    /** Stores [image] as [game]'s label, settled: the user chose it, no better one is to come. */
    @Synchronized
    fun save(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> = saving(game, image, None, asked(game))

    /**
     * Stores [image] as [game]'s label unless it has one, chosen by the user meanwhile, or one
     * looked up again, and answers the one it has then. Stored, the label is remembered as
     * provisional when it shows [shownFor] for want of a skipped texture, else settled; the mark
     * goes with the image, under the one lock, so that it never lands on a label the user chose.
     * Asked again since [seen], the ask its look was taken under, it is still looked up again.
     */
    @Synchronized
    fun saveIfAbsent(game: GameId, image: ByteArray, shownFor: Option<Identity>, seen: Option<Ask>): Either<StorageFailure, StoredArt> =
        stored(game).filter { asked(game).isNone() }.fold({ saving(game, image, shownFor, seen) }) { it.right() }

    private fun saving(game: GameId, image: ByteArray, shownFor: Option<Identity>, seen: Option<Ask>): Either<StorageFailure, StoredArt> {
        folder.mkdirs()
        val stem = sha1(game.value)
        val art = StoredArt(File(folder, "$stem.jpg"))
        return AtomicFile(art.file).write(image).flatMap {
            stored[stem] = art
            answered(stem, seen).flatMap { marking(game, shownFor) }.map { art }
        }
    }

    /** The [Ask] [game]'s label is looked up again under, if it is. */
    @Synchronized
    fun asked(game: GameId): Option<Ask> = lookedUpAgain.get().getOrNone(sha1(game.value)).map(::Ask)

    /** Whether [game]'s label was asked again since [seen], the [Ask] its look was taken under. */
    @Synchronized
    fun askedSince(game: GameId, seen: Option<Ask>): Boolean = asked(game).isSome { Some(it) != seen }

    /** The game of [stem] no longer looked up again, unless asked again since [seen]. */
    private fun answered(stem: String, seen: Option<Ask>): Either<StorageFailure, Unit> {
        val asked = lookedUpAgain.get()
        return if (asked.getOrNone(stem).map(::Ask) == seen) lookedUpAgain.set(asked - stem) else Unit.right()
    }

    /** [stems] looked up again under a new [Ask]. */
    private fun asking(stems: Collection<String>): Either<StorageFailure, Unit> {
        val asked = lookedUpAgain.get()
        asks = maxOf(asks, asked.values.maxOrNull() ?: 0) + 1
        return lookedUpAgain.set(asked + stems.associateWith { asks })
    }

    /** [game]'s label remembered as showing [shownFor] for want of a better image, or settled when none. */
    private fun marking(game: GameId, shownFor: Option<Identity>): Either<StorageFailure, Unit> =
        provisionalLabels.set(shownFor.fold({ provisionalLabels.get().without(game) }) { provisionalLabels.get().with(game, it) })

    /**
     * Looks labels up again ([ArtSources.lookAgain]): no game is known to have none any more, nor
     * any texture, the image stored for each game asked stays until the next one found replaces it
     * (see [saveIfAbsent]), or goes when none is found (see [markAbsent]); those of the games no
     * source can have art for go now. When the absences cannot be forgotten, nothing changes.
     */
    @Synchronized
    fun lookAgain(again: LookAgain): Either<StorageFailure, Unit> = absentGames
        .set(Absences())
        .flatMap { missingTextures.set(Absences()) }
        .flatMap { provisionalLabels.set(ProvisionalArt()) }
        .flatMap { asking(again.asked.map { sha1(it.value) }) }
        .flatMap { discard(again.unfound.map { sha1(it.value) }) }

    /** The identity of the image [game]'s label shows for want of a skipped ScreenScraper texture, if so. */
    @Synchronized
    fun provisional(game: GameId): Option<Identity> = provisionalLabels.get().shown(game)

    /** Whether ScreenScraper answered, for sources of [version], that it has no such image as [candidate] (INV-E11-04). */
    @Synchronized
    fun isMissing(candidate: Candidate, version: Option<ArtVersion>): Boolean = missingTextures.get().covers(candidate.identity, version)

    /**
     * Remembers that [candidate]'s source answered it has no such image, when it is a texture: never
     * asked again in sources of [version] (INV-E11-04). A scan's absence is only its game's ([markAbsent]).
     */
    @Synchronized
    fun markMissing(candidate: Candidate, version: Option<ArtVersion>): Either<StorageFailure, Unit> = when (candidate) {
        is Candidate.Texture -> missingTextures.set(missingTextures.get().with(candidate.identity, version))
        is Candidate.Web -> Unit.right()
    }

    /** [game]'s label is settled: no better image is to come, unless asked again since [seen] (see [saveIfAbsent]). */
    @Synchronized
    fun settle(game: GameId, seen: Option<Ask>): Either<StorageFailure, Unit> =
        answered(sha1(game.value), seen).flatMap { marking(game, None) }

    /**
     * [game]'s provisional label stays so, and is not looked up again until ScreenScraper is open
     * at a run, unless asked again since [seen] (see [saveIfAbsent]).
     */
    @Synchronized
    fun keepProvisional(game: GameId, seen: Option<Ask>): Either<StorageFailure, Unit> = answered(sha1(game.value), seen)

    /**
     * Looks [games]' labels up again, under a new [Ask]: each stored image stays until a better one
     * replaces it (see [saveIfAbsent]); remembered across restarts.
     */
    @Synchronized
    fun retry(games: Set<GameId>): Either<StorageFailure, Unit> =
        if (games.isEmpty()) Unit.right() else asking(games.map { sha1(it.value) })

    /**
     * Deletes the images of the games of [stems], no longer looked up again; a file that cannot be
     * deleted is listed again at the next start, and goes then.
     */
    private fun discard(stems: Collection<String>): Either<StorageFailure, Unit> {
        stems.forEach { stem -> stored.remove(stem).toOption().onSome { it.file.delete() } }
        return lookedUpAgain.set(lookedUpAgain.get() - stems.toSet())
    }

    /** Stores the image of [candidate] kept by [saveVariant] as [game]'s label; fails when it is gone or cannot be read. */
    @Synchronized
    fun adopt(game: GameId, candidate: Candidate): Either<StorageFailure, StoredArt> = Either
        .catch { variantFile(candidate).readBytes() }
        .mapLeft { StorageFailure.Unavailable("the image of ${candidate.identity} cannot be read: $it") }
        .flatMap { save(game, it) }

    /** The image of [candidate] kept by [saveVariant], while it is among the latest ones. */
    fun variant(candidate: Candidate): Option<StoredArt> = Some(variantFile(candidate)).filter(File::isFile).map(::StoredArt)

    /**
     * Keeps [image], the image of [candidate], to be shown and chosen among a game's other images;
     * only the [VARIANTS_KEPT] latest ones are kept, the others deleted.
     */
    @Synchronized
    fun saveVariant(candidate: Candidate, image: ByteArray): Either<StorageFailure, StoredArt> {
        variants.mkdirs()
        val art = StoredArt(variantFile(candidate))
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

    private fun variantFile(candidate: Candidate): File = File(variants, "${sha1(candidate.identity.value)}.jpg")

    /**
     * Deletes the images and the absence of the games not in [kept] (a platform removed, games gone
     * from their folder); answers how many images went. An image stored meanwhile by a download
     * under way goes at the next call.
     */
    @Synchronized
    fun keepOnly(kept: Set<GameId>): Either<StorageFailure, Int> {
        val stems = kept.mapTo(HashSet()) { sha1(it.value) }
        val gone = stored.keys.filter { it !in stems }
        return discard(gone)
            .flatMap { lookedUpAgain.set(lookedUpAgain.get().filterKeys { it in stems }) }
            .flatMap { absentGames.set(absentGames.get().keeping(kept)) }
            .flatMap { provisionalLabels.set(provisionalLabels.get().keeping(kept)) }
            .map { gone.size }
    }

    /** Whether [game] is known to have no art in sources of [version]. */
    @Synchronized
    fun isAbsent(game: GameId, version: Option<ArtVersion>): Boolean = absentGames.get().covers(game, version)

    /**
     * Whether [game]'s art is still to be looked for in sources of [version]: none is stored, or it
     * is looked up again, and none is known to be missing there.
     */
    @Synchronized
    fun wants(game: GameId, version: Option<ArtVersion>): Boolean =
        (stored(game).isNone() || asked(game).isSome()) && !isAbsent(game, version)

    /**
     * Remembers that no source of [version] has art for [game]; an image looked up again goes, a
     * provisional label is settled. Answers whether a label is stored then (one the user chose
     * meanwhile), under the one lock: only a game without one shows that none was found.
     */
    @Synchronized
    fun markAbsent(game: GameId, version: Option<ArtVersion>): Either<StorageFailure, Boolean> = asked(game)
        .fold({ Unit.right() }) { discard(listOf(sha1(game.value))) }
        .flatMap { absentGames.set(absentGames.get().with(game, version)) }
        .flatMap { marking(game, None) }
        .map { stored(game).isSome() }

    companion object {
        private val NAME = Regex("""([0-9a-f]{40})\.jpg""")

        /** Enough for a few screens of a game's images, a few megabytes. */
        const val VARIANTS_KEPT = 48

        /** [text]'s SHA-1 in lower-case hexadecimal; made for every game at each start, so without `format`. */
        @OptIn(ExperimentalStdlibApi::class)
        internal fun sha1(text: String): String = MessageDigest.getInstance("SHA-1").digest(text.encodeToByteArray()).toHexString()
    }
}

/**
 * What the store remembers as JSON in the file [name] under [folder], read on first use, then kept
 * in step with the file; an unreadable file is [empty], which only means asking again.
 */
private class Remembered<T>(
    private val folder: File,
    name: String,
    private val empty: T,
    private val decode: (String) -> Option<T>,
    private val encode: (T) -> String,
) {
    private val file = AtomicFile(File(folder, name))

    private var value: Option<T> = None

    fun get(): T = value.getOrElse {
        file.read(None, { it }) { text -> decode(text).right() }.getOrElse { None }.getOrElse { empty }.also { value = Some(it) }
    }

    /** Remembers [now], written only when it differs; when it cannot be written, nothing changes. */
    fun set(now: T): Either<StorageFailure, Unit> = if (now == get()) {
        Unit.right()
    } else {
        folder.mkdirs()
        file.write(encode(now)).map { value = Some(now) }
    }
}
