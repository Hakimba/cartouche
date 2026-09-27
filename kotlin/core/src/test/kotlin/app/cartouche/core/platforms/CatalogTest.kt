// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.Shipped
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.launch.TemplateError
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class CatalogTest {
    private val shipped = Shipped.definitions
    private val shippedCatalog = Shipped.catalog

    @Test
    fun `INV-E0-07 every shipped definition parses without rejection, and every player can launch`() {
        shipped.map { it.name } shouldContain "SonyPlayStation2.json"
        shippedCatalog.rejected.shouldBeEmpty()
        val game = GameFile(FileName("Game.chd"), uri("content://x"), Some(FilePath("/storage/x/Game.chd")))
        shippedCatalog.platforms.flatMap { it.players }.forEach { it.template.resolve(game).shouldBeRight() }
    }

    @Test
    fun `a PS2 disc image is offered to ARMSX2`() {
        val candidates = shippedCatalog.candidates(FileName("Burnout 3 - Takedown (Europe) (En,Es,Nl,Sv).chd"))
        candidates.map { it.platform.id }.distinct() shouldBe listOf(PlatformId("ps2"))
        candidates.map { it.player.template.targetPackage.map { p -> p.value } } shouldContain Some("com.armsx2")
        shippedCatalog.candidates(FileName("GAME.CHD")).map { it.platform.id }.distinct() shouldBe listOf(PlatformId("ps2"))
    }

    @Test
    fun `players are found by id and launch only files they accept`() {
        shippedCatalog.find(PlayerId("ps2.com.armsx2")).shouldBeSome().player.runningInstance shouldBe RunningInstance.STOP
        val game = GameFile(FileName("Game.chd"), uri("content://x"), None)
        shippedCatalog.launch(PlayerId("ps2.com.armsx2"), game).shouldBeRight().spec.grant shouldBe Some(game.uri)
        shippedCatalog.launch(PlayerId("ps2.com.armsx2"), game.copy(name = FileName("Game.gba"))).shouldBeLeft() shouldBe
            LaunchError.UnsupportedFile(PlayerId("ps2.com.armsx2"), FileName("Game.gba"))
        shippedCatalog.launch(PlayerId("nope"), game).shouldBeLeft() shouldBe LaunchError.UnknownPlayer(PlayerId("nope"))
    }

    @Test
    fun `INV-E0-08 a broken or duplicate player is rejected alone, a duplicate platform whole, and every rejection is reported`() {
        val parsed =
            catalog(
                definition(playerJson("good"), playerJson("bad", template = "-n nopackage"), playerJson("good")),
                definition(playerJson("other"), name = "again.json"),
            )
        parsed.platforms.flatMap { it.players }.map { it.id } shouldBe listOf(PlayerId("good"))
        parsed.rejected shouldBe
            listOf(
                CatalogError.InvalidTemplate("test.json", PlayerId("bad"), TemplateError.InvalidComponent("nopackage")),
                CatalogError.DuplicatePlayer("test.json", PlayerId("good")),
                CatalogError.DuplicatePlatform("again.json", PlatformId("ps2")),
            )
    }

    @Test
    fun `killPackageProcesses is optional`() {
        val player = """{"uniqueId": "p", "name": "p", "acceptedFilenameRegex": ".*", "amStartArguments": "-n a.b/.C"}"""
        catalog(definition(player)).find(PlayerId("p")).shouldBeSome().player.runningInstance shouldBe RunningInstance.KEEP
    }

    @Test
    fun `INV-E0-08 a broken definition file is rejected whole and reported`() {
        catalog(DefinitionSource("broken.json", "{")).rejected.single().shouldBeInstanceOf<CatalogError.InvalidJson>()
        catalog(DefinitionSource("empty.json", "{}")).rejected.single() shouldBe
            CatalogError.MissingField("empty.json", "platform")
        catalog(definition(pattern = "(")).rejected.single() shouldBe CatalogError.InvalidPattern("test.json", "(")
        Catalog.parse(listOf(definition()), DefinitionSource("profiles.json", "{}")).rejected.single() shouldBe
            CatalogError.MissingProfile("test.json", PlatformId("ps2"))
        Catalog.parse(listOf(definition()), DefinitionSource("profiles.json", "[")).rejected.map { it::class } shouldBe
            listOf(CatalogError.InvalidJson::class, CatalogError.MissingProfile::class)
    }

    @Test
    fun `INV-E0-09 hidden files are never offered to a player, whatever the patterns`() = runBlocking<Unit> {
        val permissive = catalog(definition(playerJson("any", pattern = ".*")))
        checkAll(Arb.string()) { name -> permissive.candidates(FileName(".$name")).shouldBeEmpty() }
    }

    @Test
    fun `INV-E0-10 catalog parsing and file matching are total`() = runBlocking<Unit> {
        checkAll(Arb.choice(definitionTexts, Arb.string()), Arb.string()) { text, fileName ->
            catalog(DefinitionSource("fuzz.json", text)).candidates(FileName(fileName))
            shippedCatalog.candidates(FileName(fileName))
        }
    }
}
