// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.storage.StorageFailure
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.LookAgain
import app.cartouche.core.art.PS2_DISC
import app.cartouche.core.library.GameId
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.security.MessageDigest

@RunWith(RobolectricTestRunner::class)
class ArtStoreTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "art")
    private val game = GameId("ps2/content://p/document/Okage (USA).iso")
    private val image = byteArrayOf(1, 2, 3)
    private val older = Some(ArtVersion("2026-09-28"))
    private val newer = Some(ArtVersion("2026-10-01"))

    private fun request(game: GameId, version: Option<ArtVersion> = older) =
        ArtRequest(game, "A", nonEmptyListOf(ArtUrl("https://a/a.png")), version, PS2_DISC)

    @Test
    fun `INV-E4-06 an image's name is its game id's SHA-1 in lower-case hexadecimal, for any id`() = runBlocking<Unit> {
        checkAll(Arb.string()) { text ->
            val digest = MessageDigest.getInstance("SHA-1").digest(text.encodeToByteArray())
            ArtStore.sha1(text) shouldBe digest.joinToString("") { "%02x".format(it) }
        }
    }

    @Test
    fun `INV-E4-06 images named by earlier versions are found again and kept`() {
        // Named after their game id's SHA-1, of its UTF-8 bytes, as every version has named them.
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
        val store = ArtStore(folder)
        store.markAbsent(request(game)).shouldBeRight()
        store.markAbsent(request(GameId("ps2/b"))).shouldBeRight()
        ArtStore(folder).isAbsent(game, older) shouldBe true
        ArtStore(folder).isAbsent(GameId("ps2/b"), older) shouldBe true
        ArtStore(folder).isAbsent(game, newer) shouldBe false
        ArtStore(folder).isAbsent(GameId("ps2/c"), older) shouldBe false
        store.markAbsent(request(GameId("ps2/c"), None)).shouldBeRight()
        ArtStore(folder).isAbsent(GameId("ps2/c"), None) shouldBe false
        folder.setWritable(false)
        try {
            store.markAbsent(request(GameId("ps2/d"))).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        // Not remembered, so looked for again.
        store.isAbsent(GameId("ps2/d"), older) shouldBe false
        File(folder, "absent.json").writeText("{broken")
        ArtStore(folder).isAbsent(game, older) shouldBe false
    }

    @Test
    fun `a game's art is wanted until it is stored or known to be missing from its sources' version`() {
        val store = ArtStore(folder)
        store.wants(game, older) shouldBe true
        store.markAbsent(request(game)).shouldBeRight()
        store.wants(game, older) shouldBe false
        store.wants(game, newer) shouldBe true
        store.wants(game, None) shouldBe true
        val stored = GameId("ps2/stored")
        store.save(stored, image).shouldBeRight()
        store.wants(stored, older) shouldBe false
        store.wants(stored, None) shouldBe false
    }

    @Test
    fun `INV-E6-03 only the images and absences of the games kept stay, at once and after a restart`() {
        val kept = GameId("ps2/kept")
        val gone = listOf(game, GameId("gba/gone"))
        val store = ArtStore(folder)
        val files = (gone + kept).map { store.save(it, image).shouldBeRight().file }
        (gone + kept).forEach { store.markAbsent(request(it)).shouldBeRight() }
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
        val urls = (0..ArtStore.VARIANTS_KEPT + 4).map { ArtUrl("https://art/$it.png") }
        urls.forEachIndexed { i, url ->
            store.saveVariant(url, byteArrayOf(i.toByte())).shouldBeRight()
            // One second apart, older first, as a person looks at one game after another.
            store.variant(url).shouldBeSome().file.setLastModified(1_000L * (i + 1))
        }
        val (gone, kept) = urls.partition { urls.indexOf(it) < urls.size - ArtStore.VARIANTS_KEPT }
        gone.forEach { store.variant(it).shouldBeNone() }
        kept.forEach { url -> store.variant(url).shouldBeSome().file.readBytes() shouldBe byteArrayOf(urls.indexOf(url).toByte()) }
        ArtStore(folder).variant(kept.last()).shouldBeSome()
        store.stored(game).shouldBeNone()
    }

    @Test
    fun `deleting the images of games gone leaves the images of regions`() {
        val store = ArtStore(folder)
        val url = ArtUrl("https://art/eu.png")
        store.saveVariant(url, image).shouldBeRight()
        store.keepOnly(emptySet()).shouldBeRight(0)
        store.variant(url).shouldBeSome()
    }

    @Test
    fun `an image of a region taken for a game's label is copied whole, and one that is gone fails`() {
        val store = ArtStore(folder)
        val url = ArtUrl("https://art/jp.png")
        store.saveVariant(url, image).shouldBeRight()
        store.adopt(game, url).shouldBeRight().file.readBytes() shouldBe image
        ArtStore(folder).stored(game).shouldBeSome().file.readBytes() shouldBe image
        store.adopt(game, ArtUrl("https://art/gone.png")).shouldBeLeft().shouldBeInstanceOf<StorageFailure.Unavailable>()
        store.stored(game).shouldBeSome().file.readBytes() shouldBe image
    }

    @Test
    fun `a game's image stored meanwhile is kept by a save that only fills a missing one`() {
        val store = ArtStore(folder)
        val chosen = store.save(game, image).shouldBeRight()
        store.saveIfAbsent(game, byteArrayOf(9)).shouldBeRight() shouldBe chosen
        chosen.file.readBytes() shouldBe image
        store.saveIfAbsent(GameId("ps2/other"), byteArrayOf(9)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(9)
    }

    @Test
    fun `looking labels up again forgets the games without art, replaces an image found, and removes one none is found for`() {
        val store = ArtStore(folder)
        val (found, missed, unfound, kept, absent) = listOf("found", "missed", "unfound", "kept", "absent").map { GameId("ps2/$it") }
        listOf(found, missed, unfound, kept).forEach { store.save(it, image).shouldBeRight() }
        store.markAbsent(request(absent)).shouldBeRight()
        store.lookAgain(LookAgain(setOf(found, missed, absent), setOf(unfound))).shouldBeRight()
        // Every game asked, and the one known to have none, want art again; the others do not.
        listOf(found, missed, absent, unfound).forEach { store.wants(it, older) shouldBe true }
        store.wants(kept, older) shouldBe false
        store.stored(unfound).shouldBeNone()
        // Until looked up, the images asked for stay.
        store.stored(missed).shouldBeSome().file.readBytes() shouldBe image
        store.saveIfAbsent(found, byteArrayOf(9)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(9)
        store.markAbsent(request(missed)).shouldBeRight()
        store.stored(missed).shouldBeNone()
        // A game not asked keeps its image, whatever a scan brings.
        store.saveIfAbsent(kept, byteArrayOf(9)).shouldBeRight().file.readBytes() shouldBe image
        listOf(found, missed, kept).forEach { store.wants(it, older) shouldBe false }
        ArtStore(folder).isAbsent(absent, older) shouldBe false
    }

    @Test
    fun `looking labels up again changes nothing when the games without art cannot be forgotten`() {
        val store = ArtStore(folder)
        val (asked, unfound, absent) = listOf("asked", "unfound", "absent").map { GameId("ps2/$it") }
        listOf(asked, unfound).forEach { store.save(it, image).shouldBeRight() }
        store.markAbsent(request(absent)).shouldBeRight()
        folder.setWritable(false)
        try {
            store.lookAgain(LookAgain(setOf(asked, absent), setOf(unfound))).shouldBeLeft()
        } finally {
            folder.setWritable(true)
        }
        store.stored(unfound).shouldBeSome()
        store.wants(asked, older) shouldBe false
        store.isAbsent(absent, older) shouldBe true
        store.saveIfAbsent(asked, byteArrayOf(9)).shouldBeRight().file.readBytes() shouldBe image
    }

    @Test
    fun `a label chosen or of the user's own while it is looked up again is not replaced by a scan`() {
        val store = ArtStore(folder)
        store.save(game, image).shouldBeRight()
        store.lookAgain(LookAgain(setOf(game), emptySet())).shouldBeRight()
        store.save(game, byteArrayOf(7)).shouldBeRight()
        store.saveIfAbsent(game, byteArrayOf(9)).shouldBeRight().file.readBytes() shouldBe byteArrayOf(7)
        store.markAbsent(request(game)).shouldBeRight()
        store.stored(game).shouldBeSome()
    }
}
