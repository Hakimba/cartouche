// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.util.AtomicFile
import app.cartouche.core.ContentUri
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.Shell
import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.left
import arrow.core.raise.SingletonRaise
import arrow.core.raise.option
import arrow.core.right
import arrow.core.toOption
import java.io.File

/** A file's size and date as its folder listed them: a file read with another stamp may have changed since. */
internal data class FileStamp(val size: Option<Long>, val modified: Option<Long>)

/** What a file told when it was read, and its stamp then. */
internal data class KnownFacts(val stamp: FileStamp, val facts: FileFacts)

/**
 * What the game files of each platform told when they were last read ([Folders.facts]), one file
 * per platform in [folder]: a scan reads only the files new or changed since. Unreadable, or
 * written by another [VERSION] of the readers, it only means reading the files again.
 */
internal class FactsStore(private val folder: File) {
    fun load(platform: PlatformId): Map<ContentUri, KnownFacts> =
        atomic(platform).read(emptyMap(), { it }) { decode(platform, it).right() }.getOrElse { emptyMap() }

    /** Keeps [known] as all that [platform]'s files told: the files of its last scan. */
    fun save(platform: PlatformId, known: Map<ContentUri, KnownFacts>): Either<StorageFailure, Unit> {
        folder.mkdirs()
        return atomic(platform).write(
            known.entries.joinToString("\n", "$HEADER\n") { (uri, it) ->
                listOf(uri.value, it.stamp.size.text, it.stamp.modified.text, it.facts.encoded).joinToString("\t")
            },
        )
    }

    /** Forgets what [platform]'s files told, once it is removed. */
    fun forget(platform: PlatformId) {
        atomic(platform).delete()
    }

    /** Forgets what every file told: each is read again at its platform's next scan. */
    fun forget(): Either<StorageFailure, Unit> =
        if (folder.deleteRecursively()) Unit.right() else StorageFailure.Unavailable("what the game files told cannot be forgotten").left()

    private fun atomic(platform: PlatformId) = AtomicFile(File(folder, "${platform.value}.tsv"))

    private val Option<Long>.text: String get() = fold({ "" }, Long::toString)

    private val FileFacts.encoded: String
        get() =
            when (this) {
                is FileFacts.Serial -> "serial:$code"
                is FileFacts.Print -> "print:$hex:${shell.key}"
                FileFacts.Silent -> "silent"
            }

    private fun decode(platform: PlatformId, text: String): Map<ContentUri, KnownFacts> = text.lines().let { lines ->
        if (lines.firstOrNone() != Some(HEADER)) emptyMap() else lines.drop(1).map { entry(platform, it) }.filterOption().toMap()
    }

    private fun entry(platform: PlatformId, line: String): Option<Pair<ContentUri, KnownFacts>> = option {
        val fields = line.split('\t')
        ensure(fields.size == 4)
        val (uri, size, modified, facts) = fields
        ContentUri.parse(uri).bind() to KnownFacts(FileStamp(number(size), number(modified)), decoded(platform, facts))
    }

    /** None for an empty field. */
    private fun SingletonRaise<None>.number(text: String): Option<Long> =
        if (text.isEmpty()) None else Some(text.toLongOrNull().toOption().bind())

    /** A Game Boy print kept before the shell was told has none: it is read again, the other platforms' prints keep their facts. */
    private fun SingletonRaise<None>.decoded(platform: PlatformId, text: String): FileFacts {
        val value = text.substringAfter(':')
        return when (text.substringBefore(':')) {
            "serial" -> FileFacts.Serial(value)
            "print" ->
                FileFacts.Print(value.substringBefore(':').toUIntOrNull(16).toOption().bind(), shellOf(platform, value).bind())
            else -> FileFacts.Silent.also { ensure(text == "silent") }
        }
    }

    /** The shell a print's text tells: a Game Boy print without one is none, to be read again. */
    private fun shellOf(platform: PlatformId, print: String): Option<Shell> = when {
        ':' in print -> Shell.entries.firstOrNone { it.key == print.substringAfter(':') }
        platform in GAME_BOYS -> None
        else -> Some(Shell.UNKNOWN)
    }

    private companion object {
        /** Raised when the readers come to tell more of some files: those read before are read again. */
        const val VERSION = 1

        val GAME_BOYS = setOf(PlatformId("gb"), PlatformId("gbc"))

        const val HEADER = "cartouche-facts\t$VERSION"
    }
}
