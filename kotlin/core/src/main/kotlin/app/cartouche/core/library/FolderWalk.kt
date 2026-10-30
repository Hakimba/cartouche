// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.platforms.CatalogError
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** A child of a folder, as its documents provider lists it. */
public sealed interface FolderEntry {
    public data class File(public val file: ListedFile) : FolderEntry

    /** A sub-folder, listed by its [id]. */
    public data class Folder(public val name: FileName, public val id: DocumentId) : FolderEntry
}

/** A sub-folder's path from the scanned folder, made of folder names: `Saves/memcards`. */
@Serializable @JvmInline
public value class FolderPath(public val value: String)

@Serializable
public enum class SkipReason {
    @SerialName("hidden")
    HIDDEN,

    @SerialName("emulator_data")
    EMULATOR_DATA,

    @SerialName("too_deep")
    TOO_DEEP,

    @SerialName("unreadable")
    UNREADABLE,
}

/** A sub-folder a scan did not look into. */
@Serializable
public data class SkippedFolder(public val path: FolderPath, public val reason: SkipReason)

public data class FolderContents(public val files: List<ListedFile>, public val skipped: List<SkippedFolder>)

/**
 * The names emulators give the folders of their own data (`memcards`, `sstates`, `textures`…), matched ignoring case.
 * Emulators often keep them next to the games, and some hold tens of thousands of files; they are read from
 * `app/data/scan/data_folders.json`.
 */
public class DataFolders private constructor(private val names: Set<String>) {
    public operator fun contains(name: FileName): Boolean = name.value.lowercase() in names

    public companion object {
        public val NONE: DataFolders = DataFolders(emptySet())

        /** Reads a JSON array of folder names. */
        public fun parse(source: DefinitionSource): Either<CatalogError, DataFolders> = Either
            .catch { Json.decodeFromString<List<String>>(source.text) }
            .mapLeft { CatalogError.InvalidJson(source.name, it.toString()) }
            .map { names -> DataFolders(names.map(String::lowercase).toSet()) }
    }
}

public sealed interface WalkFailure<out E> {
    /** The scanned folder itself could not be listed. */
    public data class Unlisted<out E>(public val error: E) : WalkFailure<E>

    /**
     * The walk met more than [limit] entries. [largest] is the folder that listed the most of them, [entries] how
     * many, and [stoppedIn] the one being listed when the limit was passed (none for the scanned folder itself):
     * where to look for what is not games.
     */
    public data class TooManyEntries(
        public val limit: Int,
        public val largest: Option<FolderPath>,
        public val entries: Int,
        public val stoppedIn: Option<FolderPath>,
    ) : WalkFailure<Nothing>
}

public object FolderWalk {
    /** Deep enough for any ROM layout, shallow enough to end on a provider listing a folder inside itself. */
    public const val MAX_DEPTH: Int = 8

    /** Far above any game collection; reading this many entries through a documents provider takes seconds. */
    public const val MAX_ENTRIES: Int = 10_000

    /**
     * The files of a folder and, with [FolderDepth.SUBFOLDERS], of its sub-folders, each file once.
     * `children(folder, atMost)` lists the folder itself (none) or one of its sub-folders; it may stop
     * after `atMost + 1` entries, which is enough to know the walk went over [limit]. Hidden
     * sub-folders (`.Trash`), [dataFolders], those [MAX_DEPTH] or more levels down and those
     * [children] cannot list are skipped and reported. The walk fails when the folder itself cannot
     * be listed, or when it meets more than [limit] entries in all: a partial listing would drop games.
     */
    public fun <E> files(
        depth: FolderDepth,
        dataFolders: DataFolders,
        limit: Int = MAX_ENTRIES,
        children: (Option<DocumentId>, Int) -> Either<E, List<FolderEntry>>,
    ): Either<WalkFailure<E>, FolderContents> = either {
        // Local and never shared: what the walk has listed so far, and the folder that listed the most.
        var listed = 0
        var tooMany = WalkFailure.TooManyEntries(limit, None, 0, None)

        fun listing(folder: Option<DocumentId>, at: Option<FolderPath>): Either<E, List<FolderEntry>> =
            children(folder, limit - listed).onRight { entries ->
                listed += entries.size
                if (entries.size > tooMany.entries) tooMany = tooMany.copy(largest = at, entries = entries.size)
                ensure(listed <= limit) { tooMany.copy(stoppedIn = at) }
            }

        fun walk(entries: List<FolderEntry>, prefix: String, level: Int): FolderContents {
            val parts =
                entries.map { entry ->
                    when (entry) {
                        is FolderEntry.File -> FolderContents(listOf(entry.file), emptyList())
                        is FolderEntry.Folder -> {
                            val path = FolderPath(prefix + entry.name.value)

                            fun skip(reason: SkipReason) = FolderContents(emptyList(), listOf(SkippedFolder(path, reason)))
                            when {
                                entry.name.isHidden -> skip(SkipReason.HIDDEN)
                                entry.name in dataFolders -> skip(SkipReason.EMULATOR_DATA)
                                level >= MAX_DEPTH -> skip(SkipReason.TOO_DEEP)
                                else ->
                                    listing(Some(entry.id), Some(path)).fold({ skip(SkipReason.UNREADABLE) }) {
                                        walk(it, "${path.value}/", level + 1)
                                    }
                            }
                        }
                    }
                }
            return FolderContents(parts.flatMap { it.files }, parts.flatMap { it.skipped })
        }

        val entries = listing(None, None).mapLeft(WalkFailure<E>::Unlisted).bind()
        when (depth) {
            FolderDepth.TOP_LEVEL -> FolderContents(entries.filterIsInstance<FolderEntry.File>().map { it.file }, emptyList())
            // A provider that is not a tree (a folder inside itself, one folder in two places) lists files again.
            FolderDepth.SUBFOLDERS -> walk(entries, prefix = "", level = 1).let { it.copy(files = it.files.distinctBy(ListedFile::uri)) }
        }
    }
}
