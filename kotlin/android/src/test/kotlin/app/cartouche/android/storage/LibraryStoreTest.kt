// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.library.Library
import app.cartouche.core.library.LibraryError
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.uri
import arrow.core.Some
import arrow.core.toOption
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
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
    private val library = Library().withSetup(PlatformId("ps2"), PlatformSetup(Some(uri("content://p/tree/ps2"))))

    @Test
    fun `a saved library loads back, and no file means an empty library`() {
        LibraryStore(file).load().shouldBeRight().library shouldBe Library()
        LibraryStore(file).save(library).shouldBeRight()
        LibraryStore(file).load().shouldBeRight().library shouldBe library
    }

    @Test
    fun `INV-E1-08 an unreadable library file is set aside, never overwritten`() {
        file.writeText("not a library")
        LibraryStore(file).load().shouldBeLeft().shouldBeInstanceOf<LibraryError.Unreadable>()
        LibraryStore(file).setAside() shouldBe true
        LibraryStore(file).save(library).shouldBeRight()
        setAside(file).single().readText() shouldBe "not a library"
        LibraryStore(file).load().shouldBeRight().library shouldBe library
    }
}

/** The files [file] was set aside as, being unreadable. */
internal fun setAside(file: File): List<File> = file.parentFile.toOption().toList().flatMap { folder ->
    folder.listFiles { f -> f.name.startsWith("${file.name}.unreadable-") }.orEmpty().toList()
}
