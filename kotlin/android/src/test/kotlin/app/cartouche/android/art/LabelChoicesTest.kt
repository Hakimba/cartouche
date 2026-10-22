// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.web
import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Assume.assumeFalse
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import app.cartouche.core.art.texture as candidateTexture

@RunWith(RobolectricTestRunner::class)
class LabelChoicesTest {
    private val context = RuntimeEnvironment.getApplication()
    private val okage = game("Okage")
    private val japan = ArtVariant(LabelRegion("Japan"), web("https://art/jp.png", "Japan"))
    private val folder = File(context.filesDir, "art")
    private val libraryFile = File(context.filesDir, "library.json")
    private val own = byteArrayOf(1, 1)
    private val japanese = byteArrayOf(2, 2, 2)

    private fun library() = LibraryService(
        LibraryStore(libraryFile),
        SelectionStore(File(context.filesDir, "selection.json")),
        Folders(context),
        FactsStore(File(context.filesDir, "facts")),
    )

    private fun label() = library().library().game(okage.id).shouldBeSome().label

    @Before
    fun stored() {
        LibraryStore(libraryFile).save(Library(games = listOf(okage))).shouldBeRight()
        ArtStore(folder).save(okage.id, own).shouldBeRight()
    }

    @Test
    fun `an image chosen shows on the label and its region is remembered`() {
        val store = ArtStore(folder)
        store.saveVariant(japan.candidate, japanese).shouldBeRight()
        LabelChoices(library(), store).choose(okage, japan).shouldBeRight().file.readBytes() shouldBe japanese
        label() shouldBe LabelChoice.Region(japan.region)
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe japanese
    }

    @Test
    fun `a texture chosen is remembered with its source, so that it is the image looked for first`() {
        val store = ArtStore(folder)
        val texture =
            ArtVariant(
                LabelRegion("Japan"),
                candidateTexture(58, 1, "support-texture(jp)", "Japan"),
            )
        store.saveVariant(texture.candidate, japanese).shouldBeRight()
        LabelChoices(library(), store).choose(okage, texture).shouldBeRight()
        label() shouldBe LabelChoice.Region(LabelRegion("Japan"), ArtSource.SCREENSCRAPER)
    }

    @Test
    fun `an image not downloaded is not chosen, and nothing changes`() {
        LabelChoices(library(), ArtStore(folder)).choose(okage, japan).shouldBeLeft(LabelFailure.NotDownloaded)
        label() shouldBe LabelChoice.Automatic
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe own
    }

    @Test
    fun `an image that cannot be stored gives the choice up, the label as it was`() {
        val store = ArtStore(folder)
        store.saveVariant(japan.candidate, japanese).shouldBeRight()
        folder.setWritable(false)
        try {
            assumeFalse(folder.canWrite())
            LabelChoices(library(), store).choose(okage, japan).shouldBeLeft().shouldBeInstanceOf<LabelFailure.Storage>()
        } finally {
            folder.setWritable(true)
        }
        label() shouldBe LabelChoice.Automatic
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe own
    }

    @Test
    fun `a picture of one's own shows on the label and is remembered as one's own`() {
        val framed = byteArrayOf(3, 3, 3, 3)
        LabelChoices(library(), ArtStore(folder)).keepOwn(okage, framed).shouldBeRight().file.readBytes() shouldBe framed
        label() shouldBe LabelChoice.Own
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe framed
    }

    @Test
    fun `a region chosen after a picture of one's own replaces it, image and choice`() {
        val store = ArtStore(folder)
        LabelChoices(library(), store).keepOwn(okage, byteArrayOf(3, 3)).shouldBeRight()
        store.saveVariant(japan.candidate, japanese).shouldBeRight()
        LabelChoices(library(), store).choose(okage.copy(label = LabelChoice.Own), japan).shouldBeRight()
        label() shouldBe LabelChoice.Region(japan.region)
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe japanese
    }

    @Test
    fun `a picture of one's own that cannot be stored gives the choice up, the label as it was`() {
        folder.setWritable(false)
        try {
            assumeFalse(folder.canWrite())
            LabelChoices(
                library(),
                ArtStore(folder),
            ).keepOwn(okage, byteArrayOf(3)).shouldBeLeft().shouldBeInstanceOf<LabelFailure.Storage>()
        } finally {
            folder.setWritable(true)
        }
        label() shouldBe LabelChoice.Automatic
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe own
    }

    @Test
    fun `a choice the library cannot save leaves the label and its image as they were`() {
        val store = ArtStore(folder)
        store.saveVariant(japan.candidate, japanese).shouldBeRight()
        val files = libraryFile.parentFile.shouldNotBeNull()
        files.setWritable(false)
        try {
            assumeFalse(files.canWrite())
            LabelChoices(library(), store).choose(okage, japan).shouldBeLeft().shouldBeInstanceOf<LabelFailure.Library>()
        } finally {
            files.setWritable(true)
        }
        label() shouldBe LabelChoice.Automatic
        ArtStore(folder).stored(okage.id).shouldBeSome().file.readBytes() shouldBe own
    }
}
