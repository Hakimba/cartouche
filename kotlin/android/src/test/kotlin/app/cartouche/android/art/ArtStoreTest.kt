// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Identity
import app.cartouche.core.art.LookAgain
import app.cartouche.core.art.web
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import app.cartouche.core.art.texture as candidateTexture

@Config(sdk = [30, 34])
@RunWith(RobolectricTestRunner::class)
class ArtStoreTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
    private val game = GameId("ps2/content://p/document/Okage (USA).iso")
    private val image = byteArrayOf(1, 2, 3)
    private val older = Some(ArtVersion("2026-09-28"))
    private val newer = Some(ArtVersion("2026-10-01"))

    @Test
    fun `INV-18 images named by earlier versions are found again and kept`() {
        val named =
            mapOf(
                game to "2698dfea0d2e70e3bfe8720d328fa7c9e86ab981",
                GameId("ps2/Pokémon (Europe).iso") to "65b88836cd13fdf68b2e0d28b37312e9312d0094",
            )
        folder.mkdirs()
        named.values.forEach { File(folder, "$it.jpg").writeBytes(image) }
        val store = ArtStore(folder)
        named.forEach { (id, stem) -> store.stored(id).shouldBeSome().file.name shouldBe "$stem.jpg" }
        store.keepOnly(named.keys) shouldBe Either.Right(0)
        named.values.forEach { File(folder, "$it.jpg").exists() shouldBe true }
    }

    @Test
    fun `INV-18 a write that fails leaves the image stored before it, whole`() {
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
    fun `INV-18 only files named as the store names its images are taken for stored ones`() {
        val hash = ArtStore(folder).save(game, image).shouldBeRight().file.name.substringBefore('.')
        File(folder, "$hash.jpg").renameTo(File(folder, "$hash.jpg.new"))
        ArtStore(folder).stored(game).shouldBeNone()
    }

    @Test
    fun `INV-17 games without art are remembered for the sources they were looked for in, and an unreadable memory forgets them`() {
        val store = ArtStore(folder)
        store.markAbsent(game, older).shouldBeRight()
        store.markAbsent(GameId("ps2/b"), older).shouldBeRight()
        ArtStore(folder).isAbsent(game, older) shouldBe true
        ArtStore(folder).isAbsent(GameId("ps2/b"), older) shouldBe true
        ArtStore(folder).isAbsent(game, newer) shouldBe false
        ArtStore(folder).isAbsent(GameId("ps2/c"), older) shouldBe false
        store.markAbsent(GameId("ps2/c"), None).shouldBeRight()
        ArtStore(folder).isAbsent(GameId("ps2/c"), None) shouldBe false
        folder.setWritable(false)
        try {
            store.markAbsent(GameId("ps2/d"), older).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        store.isAbsent(GameId("ps2/d"), older) shouldBe false
        File(folder, "absent.json").writeText("{broken")
        ArtStore(folder).isAbsent(game, older) shouldBe false
    }

    @Test
    fun `INV-13 only the images and absences of the games kept stay, at once and after a restart`() {
        val kept = GameId("ps2/kept")
        val gone = listOf(game, GameId("gba/gone"))
        val store = ArtStore(folder)
        val files = (gone + kept).map { store.save(it, image).shouldBeRight().file }
        (gone + kept).forEach { store.markAbsent(it, older).shouldBeRight() }
        store.keepOnly(setOf(kept, GameId("ps2/no image"))) shouldBe Either.Right(2)
        files.map { it.exists() } shouldBe listOf(false, false, true)
        listOf(store, ArtStore(folder)).forEach { again ->
            again.stored(kept).shouldBeSome()
            gone.forEach { again.stored(it).shouldBeNone() }
            again.isAbsent(kept, older) shouldBe true
            gone.forEach { again.isAbsent(it, older) shouldBe false }
        }
        store.keepOnly(setOf(kept)) shouldBe Either.Right(0)
    }

    @Test
    fun `an image of a region is found again, apart from the games' images, and only the latest ones are kept`() {
        val store = ArtStore(folder)
        val urls = (0..ArtStore.VARIANTS_KEPT + 4).map { web("https://art/$it.png") }
        urls.forEachIndexed { i, url ->
            store.saveVariant(url, byteArrayOf(i.toByte())).shouldBeRight()
            store.variant(url).shouldBeSome().file.setLastModified(1_000L * (i + 1))
        }
        val (gone, kept) = urls.partition { urls.indexOf(it) < urls.size - ArtStore.VARIANTS_KEPT }
        gone.forEach { store.variant(it).shouldBeNone() }
        kept.forEach { url -> store.variant(url).shouldBeSome().file.readBytes() shouldBe byteArrayOf(urls.indexOf(url).toByte()) }
        ArtStore(folder).variant(kept.last()).shouldBeSome()
        store.keepOnly(emptySet()).shouldBeRight()
        urls.last().let { store.variant(it).shouldBeSome() }
        store.stored(game).shouldBeNone()
    }

    @Test
    fun `an image of a region taken for a game's label is copied whole, and one that is gone fails`() {
        val store = ArtStore(folder)
        val url = web("https://art/jp.png")
        store.saveVariant(url, image).shouldBeRight()
        store.adopt(game, url).shouldBeRight().file.readBytes() shouldBe image
        ArtStore(folder).stored(game).shouldBeSome().file.readBytes() shouldBe image
        store.adopt(game, web("https://art/gone.png")).shouldBeLeft().shouldBeInstanceOf<StorageFailure.Unavailable>()
        store.stored(game).shouldBeSome().file.readBytes() shouldBe image
    }

    @Test
    fun `looking labels up again forgets the games without art, replaces an image found, and removes one none is found for`() {
        val store = ArtStore(folder)
        val (found, missed, unfound, kept, absent) = listOf("found", "missed", "unfound", "kept", "absent").map { GameId("ps2/$it") }
        listOf(found, missed, unfound, kept).forEach { store.save(it, image).shouldBeRight() }
        store.markAbsent(absent, older).shouldBeRight()
        store.lookAgain(LookAgain(setOf(found, missed, absent), setOf(unfound))).shouldBeRight()
        listOf(found, missed, absent, unfound).forEach { store.wants(it, older) shouldBe true }
        store.wants(kept, older) shouldBe false
        store.stored(unfound).shouldBeNone()
        store.stored(missed).shouldBeSome().file.readBytes() shouldBe image
        store.saveIfAbsent(found, byteArrayOf(9), None, store.asked(found)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(9)
        store.markAbsent(missed, older).shouldBeRight()
        store.stored(missed).shouldBeNone()
        store.saveIfAbsent(kept, byteArrayOf(9), None, store.asked(kept)).shouldBeRight().file.readBytes() shouldBe image
        listOf(found, missed, kept).forEach { store.wants(it, older) shouldBe false }
        ArtStore(folder).isAbsent(absent, older) shouldBe false
    }

    @Test
    fun `looking labels up again changes nothing when the games without art cannot be forgotten`() {
        val store = ArtStore(folder)
        val (asked, unfound, absent) = listOf("asked", "unfound", "absent").map { GameId("ps2/$it") }
        listOf(asked, unfound).forEach { store.save(it, image).shouldBeRight() }
        store.markAbsent(absent, older).shouldBeRight()
        folder.setWritable(false)
        try {
            store.lookAgain(LookAgain(setOf(asked, absent), setOf(unfound))).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        store.stored(unfound).shouldBeSome()
        store.wants(asked, older) shouldBe false
        store.isAbsent(absent, older) shouldBe true
        store.saveIfAbsent(asked, byteArrayOf(9), None, store.asked(asked)).shouldBeRight().file.readBytes() shouldBe image
    }

    @Test
    fun `INV-16 a label chosen or of the user's own while it is looked up again is not replaced by a scan`() {
        val store = ArtStore(folder)
        store.save(game, image).shouldBeRight()
        store.lookAgain(LookAgain(setOf(game), emptySet())).shouldBeRight()
        store.save(game, byteArrayOf(7)).shouldBeRight()
        store.saveIfAbsent(game, byteArrayOf(9), None, store.asked(game)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(7)
        store.markAbsent(game, older).shouldBeRight()
        store.stored(game).shouldBeSome()
    }

    @Test
    fun `INV-16 a look asks again the labels chosen before it read the library, never one chosen since`() {
        val store = ArtStore(folder)
        val other = GameId("ps2/content://p/document/Other (USA).iso")
        store.save(game, image).shouldBeRight()
        val since = store.choices()
        store.save(other, image).shouldBeRight()
        store.retry(setOf(game, other), since).shouldBeRight()
        store.wants(game, older) shouldBe true
        store.wants(other, older) shouldBe false
    }

    @Test
    fun `a label asked again stays so across a restart until a look settles it, and an unreadable memory asks nothing`() {
        val store = ArtStore(folder)
        store.save(game, image).shouldBeRight()
        store.retry(setOf(game), store.choices()).shouldBeRight()
        val again = ArtStore(folder)
        again.wants(game, older) shouldBe true
        again.saveIfAbsent(game, byteArrayOf(9), None, again.asked(game)).shouldBeRight()
        listOf(again, ArtStore(folder)).forEach { it.wants(game, older) shouldBe false }
        store.retry(setOf(game), store.choices()).shouldBeRight()
        File(folder, "again.json").writeText("{broken")
        ArtStore(folder).wants(game, older) shouldBe false
    }

    @Test
    fun `a label asked again while a look is under way stays asked once that look ends, however it ends`() {
        val store = ArtStore(folder)
        val (found, kept, provisional) = listOf("found", "kept", "provisional").map { GameId("ps2/$it") }
        listOf(found, kept, provisional).forEach { store.save(it, image).shouldBeRight() }
        store.retry(setOf(found), store.choices()).shouldBeRight()
        val seen = listOf(found, kept, provisional).associateWith { store.asked(it) }
        seen.getValue(found).shouldBeSome()
        store.retry(setOf(found, kept, provisional), store.choices()).shouldBeRight()
        store.saveIfAbsent(found, byteArrayOf(9), None, seen.getValue(found)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(9)
        store.settle(kept, seen.getValue(kept)).shouldBeRight()
        store.keepProvisional(provisional, seen.getValue(provisional)).shouldBeRight()
        listOf(found, kept, provisional).forEach { store.wants(it, older) shouldBe true }
        store.saveIfAbsent(found, image, None, store.asked(found)).shouldBeRight()
        store.wants(found, older) shouldBe false
    }

    @Test
    fun `INV-17 a texture ScreenScraper has none of is remembered for the sources' version, until a new table or a look-up anew`() {
        val store = ArtStore(folder)
        val texture = candidateTexture(58, 1, "support-texture(eu)", "Europe")
        store.isMissing(texture, older) shouldBe false
        store.markMissing(texture, older).shouldBeRight()
        ArtStore(folder).isMissing(texture, older) shouldBe true
        store.isMissing(texture, newer) shouldBe false
        store.isMissing(web("https://a/a.png"), older) shouldBe false
        store.markMissing(web("https://a/a.png"), older).shouldBeRight()
        store.isMissing(web("https://a/a.png"), older) shouldBe false
        store.markMissing(texture, None).shouldBeRight()
        store.isMissing(texture, None) shouldBe false
        store.lookAgain(LookAgain(emptySet(), emptySet())).shouldBeRight()
        store.isMissing(texture, older) shouldBe false
        File(folder, "nomedia.json").writeText("{broken")
        ArtStore(folder).isMissing(texture, older) shouldBe false
    }

    @Test
    fun `a provisional label is remembered across a restart, settled by a save or kept, and goes with its game`() {
        val store = ArtStore(folder)
        store.saveIfAbsent(game, image, Some(Identity("https://lb/eu.png")), store.asked(game)).shouldBeRight()
        ArtStore(folder).provisional(game) shouldBe Some(Identity("https://lb/eu.png"))
        store.wants(game, older) shouldBe false
        store.retry(setOf(game), store.choices()).shouldBeRight()
        store.wants(game, older) shouldBe true
        store.keepProvisional(game, store.asked(game)).shouldBeRight()
        store.wants(game, older) shouldBe false
        store.provisional(game) shouldBe Some(Identity("https://lb/eu.png"))
        store.retry(setOf(game), store.choices()).shouldBeRight()
        store.saveIfAbsent(game, byteArrayOf(9), None, store.asked(game)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(9)
        ArtStore(folder).provisional(game).shouldBeNone()
        store.retry(setOf(game), store.choices()).shouldBeRight()
        store.saveIfAbsent(game, image, Some(Identity("ss:58:1:t")), store.asked(game)).shouldBeRight()
        store.provisional(game) shouldBe Some(Identity("ss:58:1:t"))
        store.save(game, byteArrayOf(7)).shouldBeRight()
        store.provisional(game).shouldBeNone()
        store
            .saveIfAbsent(
                game,
                byteArrayOf(9),
                Some(Identity("https://lb/eu.png")),
                store.asked(game),
            ).shouldBeRight()
            .file
            .readBytes() shouldBe
            byteArrayOf(7)
        store.provisional(game).shouldBeNone()
        store.retry(setOf(game), store.choices()).shouldBeRight()
        store.saveIfAbsent(game, image, Some(Identity("https://lb/eu.png")), store.asked(game)).shouldBeRight()
        store.keepOnly(emptySet()).shouldBeRight(1)
        ArtStore(folder).provisional(game).shouldBeNone()
        store.saveIfAbsent(game, image, Some(Identity("https://lb/eu.png")), store.asked(game)).shouldBeRight()
        store.provisional(game) shouldBe Some(Identity("https://lb/eu.png"))
        store.lookAgain(LookAgain(setOf(game), emptySet())).shouldBeRight()
        store.provisional(game).shouldBeNone()
        File(folder, "provisional.json").writeText("{broken")
        ArtStore(folder).provisional(game).shouldBeNone()
    }
}
