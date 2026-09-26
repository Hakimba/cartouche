// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.library.Disc
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoreReason
import app.cartouche.core.library.IgnoredFile
import app.cartouche.core.library.Library
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.storage.DocumentId
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.godotengine.godot.Dictionary
import org.junit.Test

class WireTest {
    /** The values Godot's JNI bridge converts to Variants; see [toWireArray]. */
    private fun Any.isGodotValue(): Boolean = when (this) {
        is String, is Boolean, is Int, is Long, is Double -> true
        is Dictionary -> values.all { it.isGodotValue() }
        is Array<*> -> this::class.java == Array<Any>::class.java && all { it?.isGodotValue() == true }
        else -> false
    }

    @Test
    fun `INV-E0-16 everything sent to Godot is a value its bridge converts`() {
        val uri = ContentUri.parse("content://p/tree/t").shouldBeSome()
        val folder = Folder(uri, "ps2", Some(FilePath("/storage/x")))
        val entry = DocumentEntry(FileName("g.chd"), EntryKind.FILE, DocumentId("x:g.chd"), uri, None, None)
        val broken = Catalog.parse(listOf(DefinitionSource("broken.json", "{")), DefinitionSource("profiles.json", "{}"))
        val file = ListedFile(FileName("g (Disc 1).chd"), uri, Some(FilePath("/storage/x/g.chd")), Some(1L))
        val game =
            Game(
                GameId("ps2/g"),
                PlatformId("ps2"),
                "G",
                listOf("Japan"),
                listOf("En"),
                Some("v1.1"),
                listOf("SLPM-1"),
                None,
                nonEmptyListOf(Disc(Some(1), file)),
            )
        val library =
            Library()
                .withSetup(PlatformId("ps2"), PlatformSetup(Some(uri), Some(PlayerId("ps2.x"))))
                .withScan(PlatformId("ps2"), Scan(listOf(game), listOf(IgnoredFile(file, IgnoreReason.NOT_A_GAME))))
        listOf(
            library.toWire(),
            ScanReport(1, 1, 0, 1, 12).toWire(),
            success("folders" to listOf(folder).toWireArray { it.toWire() }),
            success("entries" to listOf(entry).toWireArray { it.toWire() }),
            broken.toWire(),
            failure(ErrorCode.CANCELLED, "x"),
        ).forEach { it.isGodotValue() shouldBe true }
        listOf("a").toTypedArray<Any>().isGodotValue() shouldBe true
        arrayOf(dictionary()).isGodotValue() shouldBe false
    }

    @Test
    fun `values from GDScript are read by type, ints arriving as Long`() {
        val request = dictionary("disc" to 2L, "small" to 3, "huge" to Long.MAX_VALUE, "flag" to true, "name" to "x")
        request.integer("disc") shouldBe Some(2)
        request.integer("small") shouldBe Some(3)
        request.integer("huge") shouldBe None
        request.integer("name") shouldBe None
        dictionary("disc" to 1.9).integer("disc") shouldBe None
        request.text("name") shouldBe Some("x")
        request.text("missing") shouldBe None
    }
}
