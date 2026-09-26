// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.Shipped
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.launch.TemplateError
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
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class CatalogTest {
    private val shipped = Shipped.definitions
    private val catalog = Shipped.catalog

    private fun parse(definitions: List<DefinitionSource>) =
        Catalog.parse(definitions, DefinitionSource("profiles.json", """{"ps2": {"media": "dvd", "minimumGameBytes": 1000000}}"""))

    private fun player(id: String, template: String = "-n com.armsx2/.Main -d {file.uri}", pattern: String = "^.*\\\\.chd$") =
        """{"uniqueId": "$id", "name": "$id", "acceptedFilenameRegex": "$pattern",
            "amStartArguments": "$template", "killPackageProcesses": true}"""

    private fun definition(vararg players: String, pattern: String = "^.*$", name: String = "test.json") = DefinitionSource(
        name,
        """{"platform": {"uniqueId": "ps2", "name": "PS2", "acceptedFilenameRegex": "$pattern"},
            "playerList": [${players.joinToString()}]}""",
    )

    @Test
    fun `INV-E0-07 every shipped definition parses without rejection, and every player can launch`() {
        shipped.map { it.name } shouldContain "SonyPlayStation2.json"
        catalog.rejected.shouldBeEmpty()
        val game = GameFile(FileName("Game.chd"), ContentUri.parse("content://x").shouldBeSome(), Some(FilePath("/storage/x/Game.chd")))
        catalog.platforms.flatMap { it.players }.forEach { it.template.resolve(game).shouldBeRight() }
    }

    @Test
    fun `a PS2 disc image is offered to ARMSX2`() {
        val candidates = catalog.candidates(FileName("Burnout 3 - Takedown (Europe) (En,Es,Nl,Sv).chd"))
        candidates.map { it.platform.id }.distinct() shouldBe listOf(PlatformId("ps2"))
        candidates.map { it.player.template.targetPackage.map { p -> p.value } } shouldContain Some("com.armsx2")
        catalog.candidates(FileName("GAME.CHD")).map { it.platform.id }.distinct() shouldBe listOf(PlatformId("ps2"))
    }

    @Test
    fun `players are found by id and launch only files they accept`() {
        catalog.find(PlayerId("ps2.com.armsx2")).shouldBeSome().player.runningInstance shouldBe RunningInstance.STOP
        val game = GameFile(FileName("Game.chd"), ContentUri.parse("content://x").shouldBeSome(), None)
        catalog.launch(PlayerId("ps2.com.armsx2"), game).shouldBeRight().spec.grant shouldBe Some(game.uri)
        catalog.launch(PlayerId("ps2.com.armsx2"), game.copy(name = FileName("Game.gba"))).shouldBeLeft() shouldBe
            LaunchError.UnsupportedFile(PlayerId("ps2.com.armsx2"), FileName("Game.gba"))
        catalog.launch(PlayerId("nope"), game).shouldBeLeft() shouldBe LaunchError.UnknownPlayer(PlayerId("nope"))
    }

    @Test
    fun `INV-E0-08 a broken or duplicate player is rejected alone, a duplicate platform whole, and every rejection is reported`() {
        val parsed =
            parse(
                listOf(
                    definition(player("good"), player("bad", template = "-n nopackage"), player("good")),
                    definition(player("other"), name = "again.json"),
                ),
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
        parse(listOf(definition(player))).find(PlayerId("p")).shouldBeSome().player.runningInstance shouldBe RunningInstance.KEEP
    }

    @Test
    fun `INV-E0-08 a broken definition file is rejected whole and reported`() {
        parse(listOf(DefinitionSource("broken.json", "{"))).rejected.single().shouldBeInstanceOf<CatalogError.InvalidJson>()
        parse(listOf(DefinitionSource("empty.json", "{}"))).rejected.single() shouldBe
            CatalogError.MissingField("empty.json", "platform")
        parse(listOf(definition(pattern = "("))).rejected.single() shouldBe CatalogError.InvalidPattern("test.json", "(")
        Catalog.parse(listOf(definition()), DefinitionSource("profiles.json", "{}")).rejected.single() shouldBe
            CatalogError.MissingProfile("test.json", PlatformId("ps2"))
        Catalog.parse(listOf(definition()), DefinitionSource("profiles.json", "[")).rejected.map { it::class } shouldBe
            listOf(CatalogError.InvalidJson::class, CatalogError.MissingProfile::class)
    }

    @Test
    fun `INV-E0-09 hidden files are never offered to a player, whatever the patterns`() = runBlocking<Unit> {
        val permissive = parse(listOf(definition(player("any", pattern = ".*"))))
        checkAll(Arb.string()) { name -> permissive.candidates(FileName(".$name")).shouldBeEmpty() }
    }

    @Test
    fun `INV-E0-10 catalog parsing and file matching are total`() = runBlocking<Unit> {
        checkAll(Arb.choice(definitions, Arb.string()), Arb.string()) { text, fileName ->
            parse(listOf(DefinitionSource("fuzz.json", text))).candidates(FileName(fileName))
            catalog.candidates(FileName(fileName))
        }
    }

    private companion object {
        val jsonValue: Arb<String> = Arb.element("\"x\"", "\"^.*$\"", "\"(\"", "1", "true", "null", "[]", "{}", "\"-n a.b/.C\"")

        val playerJson: Arb<String> =
            Arb.bind(
                Arb.list(Arb.element("uniqueId", "name", "acceptedFilenameRegex", "amStartArguments", "killPackageProcesses")),
                jsonValue,
                Arb.boolean(),
            ) { keys, value, flag ->
                keys.joinToString(prefix = "{", postfix = "}") { key -> "\"$key\": ${if (key == "killPackageProcesses") flag else value}" }
            }

        /** Definition files built from the Daijishō structure, with fields missing, mistyped or invalid. */
        val definitions: Arb<String> =
            Arb.bind(jsonValue, Arb.list(playerJson, 0..4)) { value, players ->
                """{"platform": {"uniqueId": $value, "name": "P", "acceptedFilenameRegex": $value},
                    "playerList": [${players.joinToString()}]}"""
            }
    }
}
