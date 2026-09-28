// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.library.GameId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
class ArtStoreTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
    private val game = GameId("ps2/content://p/document/Okage (USA).iso")
    private val image = byteArrayOf(1, 2, 3)

    @Test
    fun `a stored image is found again at the next start, for its game only`() {
        val art = ArtStore(folder).save(game, image).shouldBeRight()
        val again = ArtStore(folder)
        again.stored(game).shouldBeSome() shouldBe art
        art.file.readBytes() shouldBe image
        again.stored(GameId("ps2/other")).shouldBeNone()
    }

    @Test
    fun `INV-E4-04 a write that fails leaves the image stored before it, whole`() {
        val store = ArtStore(folder)
        val art = store.save(game, image).shouldBeRight()
        folder.setWritable(false)
        try {
            store.save(game, byteArrayOf(9, 9, 9, 9)).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        art.file.readBytes() shouldBe image
        ArtStore(folder).stored(game) shouldBe Some(art)
    }

    @Test
    fun `INV-E4-04 only files named as the store names its images are taken for stored ones`() {
        val hash = ArtStore(folder).save(game, image).shouldBeRight().file.name.substringBefore('.')
        File(folder, "$hash.jpg").renameTo(File(folder, "$hash.jpg.new"))
        File(folder, "notes.txt").writeText("not an image")
        ArtStore(folder).stored(game).shouldBeNone()
    }

    @Test
    fun `INV-E4-04 an image that cannot be written is not stored`() {
        folder.writeText("a file where the folder should be")
        ArtStore(folder).run {
            save(game, image).shouldBeLeft()
            stored(game).shouldBeNone()
        }
    }

    @Test
    fun `INV-E4-05 games without art are remembered for the sources they were looked for in, and an unreadable memory forgets them`() {
        fun request(game: GameId, version: Option<String>) = ArtRequest(
            game,
            "A",
            nonEmptyListOf(ArtUrl("https://a/a.png")),
            version.map(::ArtVersion),
        )
        val store = ArtStore(folder)
        store.markAbsent(request(game, Some("2026-09-28"))).shouldBeRight()
        store.markAbsent(request(GameId("ps2/b"), Some("2026-09-28"))).shouldBeRight()
        ArtStore(folder).isAbsent(request(game, Some("2026-09-28"))) shouldBe true
        ArtStore(folder).isAbsent(request(GameId("ps2/b"), Some("2026-09-28"))) shouldBe true
        ArtStore(folder).isAbsent(request(game, Some("2026-10-01"))) shouldBe false
        ArtStore(folder).isAbsent(request(GameId("ps2/c"), Some("2026-09-28"))) shouldBe false
        store.markAbsent(request(GameId("ps2/c"), None)).shouldBeRight()
        ArtStore(folder).isAbsent(request(GameId("ps2/c"), None)) shouldBe false
        folder.setWritable(false)
        try {
            store.markAbsent(request(GameId("ps2/d"), Some("2026-09-28"))).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        // Not remembered, so looked for again.
        store.isAbsent(request(GameId("ps2/d"), Some("2026-09-28"))) shouldBe false
        File(folder, "absent.json").writeText("{broken")
        ArtStore(folder).isAbsent(request(game, Some("2026-09-28"))) shouldBe false
    }
}
