// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.storage

import app.cartouche.core.FilePath
import arrow.core.None
import arrow.core.Some
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
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
