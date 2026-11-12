// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import android.util.AtomicFile
import app.cartouche.android.storage.StateFile
import app.cartouche.android.storage.StorageFailure
import app.cartouche.android.storage.orUnreadable
import app.cartouche.android.storage.write
import app.cartouche.core.art.Absences
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Identity
import app.cartouche.core.art.ProvisionalArt
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.flatMap
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

/** One time labels were asked again ([ArtStore.retry]), later ones numbered higher. */
@JvmInline
internal value class Ask(val number: Long)

/** How many labels the user had chosen at one moment ([ArtStore.choices]): a plan made from the library read then asks none chosen since. */
@JvmInline
internal value class Choices(val made: Long)

/**
 * The label images found for games, one file each in [folder] named after a hash of the game's id, and what is remembered beside them so
 * that it is not asked at every start. Images are written atomically: a file there is always a whole image. Safe to use from several
 * threads.
 */
internal class ArtStore(private val folder: File) {
    private val absentGames =
        StateFile(
            File(folder, "absent.json"),
            Absences<GameId>(),
            { Absences.decode(it, GameId.serializer()).orUnreadable() },
            { Absences.encode(it, GameId.serializer()) },
        )

    /** The images, by identity (ScreenScraper textures and web images alike), their source answered it has none of. */
    private val missingImages =
        StateFile(
            File(folder, "nomedia.json"),
            Absences<Identity>(),
            { Absences.decode(it, Identity.serializer()).orUnreadable() },
            { Absences.encode(it, Identity.serializer()) },
        )

    private val provisionalLabels =
        StateFile(File(folder, "provisional.json"), ProvisionalArt(), { ProvisionalArt.decode(it).orUnreadable() }, ProvisionalArt::encode)

    private val variants = File(folder, "variants")

    /** The bodies being downloaded; those a stopped process left go as the store is made. */
    private val downloads = File(folder, "downloads").apply { deleteRecursively() }

    /**
     * The games, by stem, whose label is looked up again ([retry]), each with the [Ask] that asked it:
     * only a look taken under that ask settles it (see [asked]).
     */
    private val lookedUpAgain =
        StateFile(
            File(folder, "again.json"),
            emptyMap<String, Long>(),
            { Option.catch { Json.decodeFromString<Map<String, Long>>(it) }.orUnreadable() },
            { Json.encodeToString(it) },
        )

    /** The latest [Ask]'s number; above every remembered one once [asking] ran. */
    private var asks = 0L

    /**
     * The labels chosen in this run ([save]), and the count each game's (by stem) was last chosen at: a plan reads the library's
     * labels before it asks, and a choice made in between must win ([retry]).
     */
    private var chosen = 0L
    private val chosenAt = HashMap<String, Long>()

    /** The games, by stem, [keepOnly] last kept: no other is stored or looked for after it; every game before its first call. */
    private var kept: Option<Set<String>> = None

    private fun inLibrary(game: GameId): Boolean = kept.fold({ true }) { stem(game) in it }

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
    fun save(game: GameId, image: ByteArray): Either<StorageFailure, StoredArt> =
        saving(game, image, None, asked(game)).onRight { chosenAt[stem(game)] = ++chosen }

    @Synchronized
    fun choices(): Choices = Choices(chosen)

    /**
     * The mark goes with the image, under the one lock, so that it never lands on a label the user chose; none for a game [keepOnly] no
     * longer kept.
     */
    @Synchronized
    fun saveIfAbsent(
        game: GameId,
        image: ByteArray,
        shownFor: Option<Identity>,
        seen: Option<Ask>,
    ): Either<StorageFailure, Option<StoredArt>> = if (!inLibrary(game)) {
        None.right()
    } else {
        stored(game).filter { asked(game).isNone() }.fold({ saving(game, image, shownFor, seen) }) { it.right() }.map(::Some)
    }

    private fun saving(game: GameId, image: ByteArray, shownFor: Option<Identity>, seen: Option<Ask>): Either<StorageFailure, StoredArt> {
        folder.mkdirs()
        val stem = stem(game)
        val art = StoredArt(File(folder, "$stem.jpg"))
        return AtomicFile(art.file).write(image).flatMap {
            stored[stem] = art
            answered(stem, seen).flatMap { marking(game, shownFor) }.map { art }
        }
    }

    /**
     * Runs [use] with a new file to download an image into, deleted once it returns: a body is never held whole in
     * memory, only its decoded image. Fails when no file can be made.
     */
    suspend fun <T> downloading(use: suspend (File) -> T): Either<StorageFailure, T> = Either
        .catch { File.createTempFile("image", ".part", downloads.apply { mkdirs() }) }
        .mapLeft { StorageFailure.Unavailable("no file to download into: ${it.javaClass.simpleName}") }
        .map { image ->
            try {
                use(image)
            } finally {
                image.delete()
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

    /** The identity of the image [game]'s label shows for want of a skipped ScreenScraper texture, if so. */
    @Synchronized
    fun provisional(game: GameId): Option<Identity> = provisionalLabels.get().shown(game)

    /** Whether [candidate]'s source answered, for sources of [version], that it has no such image. */
    @Synchronized
    fun isMissing(candidate: Candidate, version: Option<ArtVersion>): Boolean = missingImages.get().covers(candidate.identity, version)

    /**
     * Remembers that [candidate]'s source answered it has no such image: never asked again in sources of [version], even when
     * its game is not given up (a ScreenScraper texture skipped before it).
     */
    @Synchronized
    fun markMissing(candidate: Candidate, version: Option<ArtVersion>): Either<StorageFailure, Unit> =
        missingImages.set(missingImages.get().with(candidate.identity, version))

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
     * Looks [games]' labels up again, under a new [Ask], but those the user chose after [since], when their labels were read: each
     * stored image stays until a better one replaces it (see [saveIfAbsent]); remembered across restarts.
     */
    @Synchronized
    fun retry(games: Set<GameId>, since: Choices): Either<StorageFailure, Unit> =
        games.map(::stem).filter { chosenAt.getOrDefault(it, 0) <= since.made }.let { if (it.isEmpty()) Unit.right() else asking(it) }

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

    /** Only [kept]'s images stay, and only theirs are stored or looked for from now on (see [saveIfAbsent], [wants]). */
    @Synchronized
    fun keepOnly(kept: Set<GameId>): Either<StorageFailure, Int> {
        val stems = kept.mapTo(HashSet(), ::stem)
        this.kept = Some(stems)
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
     * Whether [game]'s art is still to be looked for in sources of [version]: the game was kept ([keepOnly]), none is
     * stored or it is looked up again, and none is known to be missing there.
     */
    @Synchronized
    fun wants(game: GameId, version: Option<ArtVersion>): Boolean =
        inLibrary(game) && (stored(game).isNone() || asked(game).isSome()) && !isAbsent(game, version)

    /**
     * Remembers that [game] has no art in sources of [version], found by a look under [seen]: its stored image goes when
     * that ask was to replace it. Asked again since, nothing is remembered: the look comes again under the new ask.
     * Answers, under the one lock, whether there is nothing to tell: a label stored then (one the user chose meanwhile),
     * or a look to come.
     */
    @Synchronized
    fun markAbsent(game: GameId, version: Option<ArtVersion>, seen: Option<Ask>): Either<StorageFailure, Boolean> =
        if (askedSince(game, seen)) {
            true.right()
        } else {
            asked(game)
                .fold({ Unit.right() }) { discard(listOf(stem(game))) }
                .flatMap { absentGames.set(absentGames.get().with(game, version)) }
                .flatMap { marking(game, None) }
                .map { stored(game).isSome() }
        }

    companion object {
        private val NAME = Regex("""([0-9a-f]{40})\.jpg""")

        /** Enough for a few screens of a game's images, a few megabytes. */
        const val VARIANTS_KEPT = 48

        /** Without `format`: made for every game at each start. */
        @OptIn(ExperimentalStdlibApi::class)
        internal fun sha1(text: String): String = MessageDigest.getInstance("SHA-1").digest(text.encodeToByteArray()).toHexString()
    }
}
