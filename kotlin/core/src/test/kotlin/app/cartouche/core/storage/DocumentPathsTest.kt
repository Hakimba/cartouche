// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.storage

import app.cartouche.core.FilePath
import arrow.core.None
import arrow.core.Some
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.filter
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class DocumentPathsTest {
    private val volumes =
        mapOf(VolumeId.PRIMARY to FilePath("/storage/emulated/0"), VolumeId("1A2B-3C4D") to FilePath("/storage/1A2B-3C4D"))

    private fun pathOf(documentId: String, authority: String = DocumentPaths.EXTERNAL_STORAGE_AUTHORITY) =
        DocumentPaths.pathOf(authority, DocumentId(documentId), volumes).map { it.value }

    @Test
    fun `external storage documents map to their volume's mount point`() {
        pathOf("primary:ROMs/ps2") shouldBe Some("/storage/emulated/0/ROMs/ps2")
        pathOf("1A2B-3C4D:ROMs/ps2/Game (Europe).chd") shouldBe Some("/storage/1A2B-3C4D/ROMs/ps2/Game (Europe).chd")
        pathOf("1A2B-3C4D:") shouldBe Some("/storage/1A2B-3C4D")
        pathOf("home:ROMs") shouldBe Some("/storage/emulated/0/Documents/ROMs")
    }

    @Test
    fun `a picked folder reads as its volume and the folders down to it`() {
        fun placeOf(id: String, authority: String = DocumentPaths.EXTERNAL_STORAGE_AUTHORITY) =
            DocumentPaths.placeOf(authority, DocumentId(id))
        placeOf("1A2B-3C4D:ROMs/ps2") shouldBe Some(FolderPlace(Volume.CARD, listOf("ROMs", "ps2")))
        placeOf("primary:ROMs/ps2/") shouldBe Some(FolderPlace(Volume.INTERNAL, listOf("ROMs", "ps2")))
        placeOf("primary:") shouldBe Some(FolderPlace(Volume.INTERNAL, emptyList()))
        placeOf("home:ROMs") shouldBe Some(FolderPlace(Volume.INTERNAL, listOf("Documents", "ROMs")))
        placeOf("no-separator") shouldBe None
        placeOf("primary:ROMs", authority = "com.android.providers.downloads.documents") shouldBe None
    }

    @Test
    fun `reading where a folder is never fails, gives a place only on the device's storage, and no empty folder name`() =
        runBlocking<Unit> {
            val authorities = Arb.element(DocumentPaths.EXTERNAL_STORAGE_AUTHORITY, "com.android.providers.downloads.documents")
            val ids = Arb.choice(Arb.string(0..30), Arb.element("primary:ROMs//ps2", ":ROMs", "primary", "home:", "1A2B-3C4D:/"))
            checkAll(authorities, ids) { authority, id ->
                val place = DocumentPaths.placeOf(authority, DocumentId(id))
                place.isSome() shouldBe (authority == DocumentPaths.EXTERNAL_STORAGE_AUTHORITY && id.substringBefore(':', "").isNotEmpty())
                place.onSome { found -> found.folders.forEach { it.isNotEmpty() shouldBe true } }
            }
        }

    @Test
    fun `fallback names use the last segment`() {
        DocumentPaths.fallbackName(DocumentId("1A2B-3C4D:ROMs/ps2")) shouldBe "ps2"
        DocumentPaths.fallbackName(DocumentId("1A2B-3C4D:")) shouldBe "1A2B-3C4D:"
    }

    @Test
    fun `INV-E0-11 unmounted volumes and malformed ids have no path`() {
        pathOf("ABCD-1234:ROMs") shouldBe None
        pathOf("no-separator") shouldBe None
        pathOf(":ROMs") shouldBe None
    }

    @Test
    fun `INV-E0-11 documents of any other provider never get a path`() = runBlocking<Unit> {
        checkAll(Arb.string().filter { it != DocumentPaths.EXTERNAL_STORAGE_AUTHORITY }, Arb.string()) { authority, id ->
            pathOf(id, authority) shouldBe None
        }
    }

    @Test
    fun `INV-E0-11 the mapping is total`() = runBlocking<Unit> {
        checkAll(Arb.string()) { id -> pathOf(id) }
    }
}
