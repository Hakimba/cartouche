// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.read
import app.cartouche.android.storage.write
import app.cartouche.core.art.Absences
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Identity
import app.cartouche.core.art.LookAgain
import app.cartouche.core.art.ProvisionalArt
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.PlatformId
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
 * The label images found for games, one file each in [folder] named after a hash of the game's id, and what is remembered beside them so
 * that it is not asked at every start. Images are written atomically: a file there is always a whole image. Safe to use from several
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
     * The games, by stem, whose label is looked up again ([retry], [lookAgain]), each with the [Ask] that asked it:
     * only a look taken under that ask settles it (see [asked]).
     */
    private val lookedUpAgain =
        Remembered(folder, "again.json", emptyMap<String, Long>(), { Option.catch { Json.decodeFromString<Map<String, Long>>(it) } }) {
            Json.encodeToString(it)
        }

    /** The latest [Ask]'s number; above every remembered one once [asking] ran. */
    private var asks = 0L

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

    // A library answer asks for every game's stem several times; hashing each id once keeps that to a lookup.
    private val stemCache = ConcurrentHashMap<GameId, String>()

    private fun stem(game: GameId): String = stemCache.getOrPut(game) { sha1(game.value) }

    fun stored(game: GameId): Option<StoredArt> = stored.getOrNone(stem(game))

    /**
     * The art stored for [games] and, platform by platform, the ids of those known to have none in the sources of
     * [versionOf] their platform; each game is looked up once.
     */
    fun labelsOf(games: List<Game>, versionOf: (PlatformId) -> Option<ArtVersion>): Pair<List<FoundArt>, List<String>> {
        val found = games.associate { it.id to stored(it.id) }
        val absent =
            games.groupBy { it.platform }.flatMap { (platform, ofPlatform) ->
                val version = versionOf(platform)
                ofPlatform.filter { found.getValue(it.id).isNone() && isAbsent(it.id, version) }.map { it.id.value }
            }
        return games.flatMap { game -> found.getValue(game.id).map { FoundArt(game.id, it) }.toList() } to absent
    }

    /** Stores [image] as [game]'s label, settled: the user chose it, no better one is to come. */
    @Synchronized
    fun save(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> = saving(game, image, None, asked(game))

    /** The mark goes with the image, under the one lock, so that it never lands on a label the user chose. */
    @Synchronized
    fun saveIfAbsent(game: GameId, image: ByteArray, shownFor: Option<Identity>, seen: Option<Ask>): Either<StorageFailure, StoredArt> =
        stored(game).filter { asked(game).isNone() }.fold({ saving(game, image, shownFor, seen) }) { it.right() }

    private fun saving(game: GameId, image: ByteArray, shownFor: Option<Identity>, seen: Option<Ask>): Either<StorageFailure, StoredArt> {
        folder.mkdirs()
        val stem = stem(game)
        val art = StoredArt(File(folder, "$stem.jpg"))
        return AtomicFile(art.file).write(image).flatMap {
            stored[stem] = art
            answered(stem, seen).flatMap { marking(game, shownFor) }.map { art }
        }
    }

    /** The [Ask] [game]'s label is looked up again under, if it is. */
    @Synchronized
    fun asked(game: GameId): Option<Ask> = lookedUpAgain.get().getOrNone(stem(game)).map(::Ask)

    @Synchronized
    fun askedSince(game: GameId, seen: Option<Ask>): Boolean = asked(game).isSome { Some(it) != seen }

    private fun answered(stem: String, seen: Option<Ask>): Either<StorageFailure, Unit> {
        val asked = lookedUpAgain.get()
        return if (asked.getOrNone(stem).map(::Ask) == seen) lookedUpAgain.set(asked - stem) else Unit.right()
    }

    private fun asking(stems: Collection<String>): Either<StorageFailure, Unit> {
        val asked = lookedUpAgain.get()
        asks = maxOf(asks, asked.values.maxOrNull() ?: 0) + 1
        return lookedUpAgain.set(asked + stems.associateWith { asks })
    }

    private fun marking(game: GameId, shownFor: Option<Identity>): Either<StorageFailure, Unit> =
        provisionalLabels.set(shownFor.fold({ provisionalLabels.get().without(game) }) { provisionalLabels.get().with(game, it) })

    /**
     * Looks labels up again ([ArtSources.lookAgain]): no game is known to have none any more, nor any texture, the
     * image stored for each game asked stays until the next one found replaces it (see [saveIfAbsent]), or goes when
     * none is found (see [markAbsent]); those of the games no source can have art for go now. When the absences
     * cannot be forgotten, nothing changes.
     */
    @Synchronized
    fun lookAgain(again: LookAgain): Either<StorageFailure, Unit> = absentGames
        .set(Absences())
        .flatMap { missingTextures.set(Absences()) }
        .flatMap { provisionalLabels.set(ProvisionalArt()) }
        .flatMap { asking(again.asked.map(::stem)) }
        .flatMap { discard(again.unfound.map(::stem)) }

    /** The identity of the image [game]'s label shows for want of a skipped ScreenScraper texture, if so. */
    @Synchronized
    fun provisional(game: GameId): Option<Identity> = provisionalLabels.get().shown(game)

    /** Whether ScreenScraper answered, for sources of [version], that it has no such image as [candidate]. */
    @Synchronized
    fun isMissing(candidate: Candidate, version: Option<ArtVersion>): Boolean = missingTextures.get().covers(candidate.identity, version)

    /**
     * Remembers that [candidate]'s source answered it has no such image, when it is a texture: never asked again in
     * sources of [version]. A scan's absence is only its game's ([markAbsent]).
     */
    @Synchronized
    fun markMissing(candidate: Candidate, version: Option<ArtVersion>): Either<StorageFailure, Unit> = when (candidate) {
        is Candidate.Texture -> missingTextures.set(missingTextures.get().with(candidate.identity, version))
        is Candidate.Web -> Unit.right()
    }

    /** [game]'s label is settled: no better image is to come, unless asked again since [seen] (see [saveIfAbsent]). */
    @Synchronized
    fun settle(game: GameId, seen: Option<Ask>): Either<StorageFailure, Unit> = answered(stem(game), seen).flatMap { marking(game, None) }

    /**
     * [game]'s provisional label stays so, and is not looked up again until ScreenScraper is open at a run, unless
     * asked again since [seen] (see [saveIfAbsent]).
     */
    @Synchronized
    fun keepProvisional(game: GameId, seen: Option<Ask>): Either<StorageFailure, Unit> = answered(stem(game), seen)

    /**
     * Looks [games]' labels up again, under a new [Ask]: each stored image stays until a better one replaces it (see
     * [saveIfAbsent]); remembered across restarts.
     */
    @Synchronized
    fun retry(games: Set<GameId>): Either<StorageFailure, Unit> = if (games.isEmpty()) Unit.right() else asking(games.map(::stem))

    /**
     * Deletes the images of the games of [stems], no longer looked up again; a file that cannot be deleted is listed
     * again at the next start, and goes then.
     */
    private fun discard(stems: Collection<String>): Either<StorageFailure, Unit> {
        stems.forEach { stem -> stored.remove(stem).toOption().onSome { it.file.delete() } }
        return lookedUpAgain.set(lookedUpAgain.get() - stems.toSet())
    }

    /**
     * Stores the image of [candidate] kept by [saveVariant] as [game]'s label; fails when it is gone or cannot be
     * read.
     */
    @Synchronized
    fun adopt(game: GameId, candidate: Candidate): Either<StorageFailure, StoredArt> = Either
        .catch { variantFile(candidate).readBytes() }
        .mapLeft { StorageFailure.Unavailable("the image of ${candidate.identity} cannot be read: $it") }
        .flatMap { save(game, it) }

    /** The image of [candidate] kept by [saveVariant], while it is among the latest ones. */
    fun variant(candidate: Candidate): Option<StoredArt> = Some(variantFile(candidate)).filter(File::isFile).map(::StoredArt)

    /**
     * Keeps [image], the image of [candidate], to be shown and chosen among a game's other images; only the
     * [VARIANTS_KEPT] latest ones are kept, the others deleted.
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

    /** An image stored meanwhile by a download under way goes at the next call. */
    @Synchronized
    fun keepOnly(kept: Set<GameId>): Either<StorageFailure, Int> {
        val stems = kept.mapTo(HashSet(), ::stem)
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
     * Whether [game]'s art is still to be looked for in sources of [version]: none is stored, or it is looked up
     * again, and none is known to be missing there.
     */
    @Synchronized
    fun wants(game: GameId, version: Option<ArtVersion>): Boolean =
        (stored(game).isNone() || asked(game).isSome()) && !isAbsent(game, version)

    /** Answers whether a label is stored then (one the user chose meanwhile), under the one lock. */
    @Synchronized
    fun markAbsent(game: GameId, version: Option<ArtVersion>): Either<StorageFailure, Boolean> = asked(game)
        .fold({ Unit.right() }) { discard(listOf(stem(game))) }
        .flatMap { absentGames.set(absentGames.get().with(game, version)) }
        .flatMap { marking(game, None) }
        .map { stored(game).isSome() }

    companion object {
        private val NAME = Regex("""([0-9a-f]{40})\.jpg""")

        /** Enough for a few screens of a game's images, a few megabytes. */
        const val VARIANTS_KEPT = 48

        /** Without `format`: made for every game at each start. */
        @OptIn(ExperimentalStdlibApi::class)
        internal fun sha1(text: String): String = MessageDigest.getInstance("SHA-1").digest(text.encodeToByteArray()).toHexString()
    }
}

/** An unreadable file is [empty], which only means asking again. */
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
