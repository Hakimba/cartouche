// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.android.library.LibraryService
import app.cartouche.core.ContentUri
import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryError
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.platforms.PlatformId
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
class LibraryStoreTest {
    private val file = File(RuntimeEnvironment.getApplication().filesDir, "library.json")
    private val library = Library().withSetup(PlatformId("ps2"), PlatformSetup(ContentUri.parse("content://p/tree/ps2")))

    @Test
    fun `a saved library loads back, and no file means an empty library`() {
        LibraryStore(file).load().shouldBeRight() shouldBe Library()
        LibraryStore(file).save(library).shouldBeRight()
        LibraryStore(file).load().shouldBeRight() shouldBe library
    }

    @Test
    fun `INV-E1-08 an unreadable library file is set aside, never overwritten`() {
        file.writeText("not a library")
        LibraryStore(file).load().shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
        LibraryStore(file).setAside() shouldBe true
        LibraryStore(file).save(library).shouldBeRight()
        file.parentFile
            .shouldNotBeNull()
            .listFiles { f ->
                f.name.startsWith("library.json.unreadable-")
            }.shouldNotBeNull()
            .single()
            .readText() shouldBe
            "not a library"
        LibraryStore(file).load().shouldBeRight() shouldBe library
    }

    @Test
    fun `INV-E1-08 the library service reports an unreadable file and keeps it`() {
        file.writeText("not a library")
        val service = LibraryService(LibraryStore(file), Folders(RuntimeEnvironment.getApplication()))
        service.library() shouldBe Library()
        service.loadProblem.shouldBeSome()
        service.setUp(PlatformId("ps2"), PlatformSetup()).shouldBeRight()
        file.parentFile.shouldNotBeNull().listFiles { f -> f.name.startsWith("library.json.unreadable-") }.shouldNotBeNull().size shouldBe 1
    }

    @Test
    fun `INV-E1-08 nothing is saved while an unreadable file could not be set aside`() {
        file.writeText("not a library")
        val folder = file.parentFile.shouldNotBeNull()
        folder.setWritable(false)
        try {
            val service = LibraryService(LibraryStore(file), Folders(RuntimeEnvironment.getApplication()))
            service.library() shouldBe Library()
            service.setUp(PlatformId("ps2"), PlatformSetup()).shouldBeLeft()
            file.readText() shouldBe "not a library"
        } finally {
            folder.setWritable(true)
        }
    }
}
