// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.left
import arrow.core.right

/** A node of a folder tree held in memory. */
sealed interface Node {
    data class File(val name: String) : Node

    data class Folder(val name: String, val children: List<Node>, val readable: Boolean = true) : Node
}

/**
 * A folder tree held in memory, standing for a documents provider in [FolderWalk.files]. Each
 * node's document id is its position (`0/2/1`), so that changing one folder keeps every other id.
 * [listed] records the folders asked for, in order.
 */
class InMemoryFolders(val root: List<Node>, readable: Boolean = true) {
    val listed: MutableList<Option<DocumentId>> = mutableListOf()

    /** What listing each folder answers: its entries, or a failure when it is not readable. */
    val answers: Map<Option<DocumentId>, Either<Unit, List<FolderEntry>>> = answers(Node.Folder("", root, readable), None, "")

    /** Every entry the readable folders list. */
    val entries: List<FolderEntry> get() = answers.values.flatMap { it.getOrElse { emptyList() } }

    /** Every file of the readable folders, wherever they are. */
    val files: List<ListedFile> get() = entries.filterIsInstance<FolderEntry.File>().map { it.file }

    /** Every folder of the tree: its path of names, and its position. */
    val folders: List<Pair<FolderPath, List<Int>>> get() = folders(root, "", emptyList())

    /** The walk's listing function, answering every entry whatever `atMost` says. */
    val children: (Option<DocumentId>, Int) -> Either<Unit, List<FolderEntry>> = { folder, _ ->
        answers.getValue(folder).also {
            listed +=
                folder
        }
    }

    /** The walk's listing function, stopping one entry past `atMost` as a documents provider may. */
    val stoppingChildren: (Option<DocumentId>, Int) -> Either<Unit, List<FolderEntry>> = { folder, atMost ->
        children(folder, atMost).map { it.take(atMost + 1) }
    }

    /** The same tree with the folder at [position] changed. */
    fun changing(position: List<Int>, change: (Node.Folder) -> Node.Folder): InMemoryFolders =
        InMemoryFolders(root.changing(position, change))

    private companion object {
        fun answers(
            folder: Node.Folder,
            self: Option<DocumentId>,
            prefix: String,
        ): Map<Option<DocumentId>, Either<Unit, List<FolderEntry>>> {
            val ids = folder.children.indices.map { DocumentId("$prefix$it") }
            val entries =
                folder.children.zip(ids) { node, id ->
                    when (node) {
                        is Node.File -> FolderEntry.File(listed(node.name, id.value, None))
                        is Node.Folder -> FolderEntry.Folder(FileName(node.name), id)
                    }
                }
            val own = mapOf(self to if (folder.readable) entries.right() else Unit.left())
            return folder.children.zip(ids).fold(own) { all, (node, id) ->
                if (node is Node.Folder) all + answers(node, Some(id), "${id.value}/") else all
            }
        }

        fun folders(nodes: List<Node>, prefix: String, at: List<Int>): List<Pair<FolderPath, List<Int>>> =
            nodes.withIndex().flatMap { (i, node) ->
                if (node is Node.Folder) {
                    val path = prefix + node.name
                    listOf(FolderPath(path) to at + i) + folders(node.children, "$path/", at + i)
                } else {
                    emptyList()
                }
            }

        fun List<Node>.changing(at: List<Int>, change: (Node.Folder) -> Node.Folder): List<Node> = mapIndexed { i, node ->
            when {
                i != at.first() || node !is Node.Folder -> node
                at.size == 1 -> change(node)
                else -> node.copy(children = node.children.changing(at.drop(1), change))
            }
        }
    }
}
