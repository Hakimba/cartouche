// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.storage.DocumentId
import app.cartouche.core.uri
import arrow.core.NonEmptyList
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.nonEmptyListOf

/** The size of a whole game: large enough never to be taken for something else. */
const val GAME_BYTES: Long = 1_000_000_000L

/** A file of a scanned folder; [id] makes its URI, so that files with the same name can be told apart. */
fun listed(name: String, id: String = name, size: Option<Long> = Some(GAME_BYTES)): ListedFile =
    ListedFile(FileName(name), uri("content://p/document/$id"), None, size)

/** What a walk finds in a folder of [files] and no sub-folder. */
fun contents(files: List<ListedFile>): FolderContents = FolderContents(files, emptyList())

fun game(
    title: String,
    platform: String = "ps2",
    discs: NonEmptyList<Disc> = nonEmptyListOf(Disc(None, listed("$title.chd"))),
    version: Option<String> = None,
): Game = Game(GameId("$platform/$title"), PlatformId(platform), title, emptyList(), emptyList(), version, emptyList(), None, discs)

/** A sub-folder entry whose document id is [id], named `f<id>`. */
fun folderEntry(id: Int): FolderEntry = FolderEntry.Folder(FileName("f$id"), DocumentId("$id"))

fun fileEntry(name: String): FolderEntry.File = FolderEntry.File(listed(name))

/** The emulator data folder names the generators never use for other folders. */
val testDataFolders: DataFolders =
    DataFolders.parse(DefinitionSource("test", """["memcards"]""")).getOrElse { error("Test data folders do not parse: $it") }
