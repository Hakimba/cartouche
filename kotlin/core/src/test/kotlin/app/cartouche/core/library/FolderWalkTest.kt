// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.storage.DocumentId
import arrow.core.None
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.left
import arrow.core.right
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.filter
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class FolderWalkTest {
    private enum class Change { HIDDEN, EMULATOR_DATA, UNREADABLE }

    private fun walk(tree: InMemoryFolders, depth: FolderDepth = FolderDepth.SUBFOLDERS, limit: Int = FolderWalk.MAX_ENTRIES) =
        FolderWalk.files(depth, testDataFolders, limit, tree.children)

    @Test
    fun `INV-08 every file of readable, visible folders is listed once, and nothing is skipped`() = runBlocking<Unit> {
        checkAll(trees) { root ->
            val tree = InMemoryFolders(root)
            walk(tree).shouldBeRight().let { contents ->
                contents.files shouldContainExactlyInAnyOrder tree.files
                contents.skipped shouldBe emptyList()
            }
        }
    }

    @Test
    fun `INV-08 a hidden, emulator data or unreadable sub-folder is skipped and reported, and everything else is listed`() =
        runBlocking<Unit> {
            checkAll(trees.filter { InMemoryFolders(it).folders.isNotEmpty() }, Arb.int(), Arb.enum<Change>()) { root, pick, change ->
                val original = InMemoryFolders(root)
                val position = original.folders.let { it[Math.floorMod(pick, it.size)] }.second
                val tree =
                    original.changing(position) {
                        when (change) {
                            Change.HIDDEN -> it.copy(name = ".${it.name}")
                            Change.EMULATOR_DATA -> it.copy(name = "MemCards")
                            Change.UNREADABLE -> it.copy(readable = false)
                        }
                    }
                val contents = walk(tree).shouldBeRight()
                contents.files shouldContainExactlyInAnyOrder original.changing(position) { it.copy(children = emptyList()) }.files
                val path = tree.folders.single { it.second == position }.first
                contents.skipped shouldBe listOf(SkippedFolder(path, SkipReason.valueOf(change.name)))
                // Only a folder that cannot be listed was asked for.
                (Some(DocumentId(position.joinToString("/"))) in tree.listed) shouldBe (change == Change.UNREADABLE)
            }
        }

    @Test
    fun `INV-08 a file is listed only when fewer than MAX_DEPTH folders hold it, else the folder too deep is reported`() {
        (0..FolderWalk.MAX_DEPTH + 3).forEach { levels ->
            val root = (levels downTo 1).fold(listOf<Node>(Node.File("game.iso"))) { inner, level -> listOf(Node.Folder("f$level", inner)) }
            val contents = walk(InMemoryFolders(root)).shouldBeRight()
            if (levels < FolderWalk.MAX_DEPTH) {
                contents.files.map { it.name.value } shouldBe listOf("game.iso")
                contents.skipped shouldBe emptyList()
            } else {
                contents.files shouldBe emptyList()
                val tooDeep = FolderPath((1..FolderWalk.MAX_DEPTH).joinToString("/") { "f$it" })
                contents.skipped shouldBe listOf(SkippedFolder(tooDeep, SkipReason.TOO_DEEP))
            }
        }
    }

    @Test
    fun `without sub-folders, only the folder itself is listed`() = runBlocking<Unit> {
        checkAll(trees) { root ->
            val tree = InMemoryFolders(root)
            val contents = walk(tree, FolderDepth.TOP_LEVEL).shouldBeRight()
            tree.listed shouldBe listOf(None)
            contents.files shouldBe tree.answers.getValue(None).shouldBeRight().filterIsInstance<FolderEntry.File>().map { it.file }
            contents.skipped shouldBe emptyList()
        }
    }

    @Test
    fun `INV-09 failing to list the folder itself fails the walk`() = runBlocking<Unit> {
        checkAll(trees, Arb.enum<FolderDepth>()) { root, depth ->
            walk(InMemoryFolders(root, readable = false), depth).shouldBeLeft() shouldBe WalkFailure.Unlisted(Unit)
        }
    }

    @Test
    fun `INV-09 a walk meeting more entries than its limit fails, even when the provider stops one past it`() = runBlocking<Unit> {
        checkAll(trees, Arb.int(0..30)) { root, limit ->
            val tree = InMemoryFolders(root)
            val outcomes =
                listOf(walk(tree, limit = limit), FolderWalk.files(FolderDepth.SUBFOLDERS, testDataFolders, limit, tree.stoppingChildren))
            if (tree.entries.size <= limit) {
                outcomes.map { it.shouldBeRight() }.distinct().size shouldBe 1
            } else {
                outcomes.forEach { it.shouldBeLeft().shouldBeInstanceOf<WalkFailure.TooManyEntries>().limit shouldBe limit }
                // With every entry listed, the folder named is the one that listed the most.
                val largest = tree.listed.maxOf { tree.answers.getValue(it).getOrElse { emptyList() }.size }
                outcomes.first().shouldBeLeft().shouldBeInstanceOf<WalkFailure.TooManyEntries>().entries shouldBe largest
            }
        }
    }

    @Test
    fun `a walk over its limit names the folder that listed the most entries`() {
        val many = Node.Folder("a", List(9) { Node.File("$it.dds") })
        val tree = InMemoryFolders(listOf(many, Node.Folder("zeta", List(3) { Node.File("$it.iso") })))
        // The limit is passed while listing zeta, after a: a is the folder to look at.
        walk(tree, limit = 12).shouldBeLeft() shouldBe WalkFailure.TooManyEntries(12, Some(FolderPath("a")), 9, Some(FolderPath("zeta")))
    }

    @Test
    fun `INV-08 INV-09 the walk ends whatever the provider answers, even folders inside themselves`() = runBlocking<Unit> {
        // Four folders, each failing or listing up to three entries: files, or any of the four folders.
        val entry = Arb.choice(Arb.int(0..3).map(::folderEntry), Arb.string(1..6, Codepoint.alphanumeric()).map(::fileEntry))
        val answer = Arb.choice(Arb.list(entry, 0..3).map { it.right() }, Arb.constant(Unit.left()))
        checkAll(Arb.list(answer, 4..4)) { answers ->
            var calls = 0
            val contents =
                FolderWalk
                    .files(FolderDepth.SUBFOLDERS, testDataFolders) { id, _ ->
                        calls++
                        id.fold({ listOf(folderEntry(0)).right() }) { answers[it.value.toInt()] }
                    }.shouldBeRight()
            // The folder itself, then at most 3^(level - 1) folders at each level below MAX_DEPTH.
            calls shouldBeLessThanOrEqual 1 + generateSequence(1) { it * 3 }.take(FolderWalk.MAX_DEPTH - 1).sum()
            contents.skipped.forEach { it.path.value.split('/').size shouldBeLessThanOrEqual FolderWalk.MAX_DEPTH }
            // A file found twice is listed once.
            contents.files.map { it.uri }.distinct().size shouldBe contents.files.size
        }
    }
}
