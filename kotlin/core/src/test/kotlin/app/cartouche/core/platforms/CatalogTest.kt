// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.Shipped
import app.cartouche.core.art.crop
import app.cartouche.core.art.front
import app.cartouche.core.launch.Component
import app.cartouche.core.launch.Extra
import app.cartouche.core.launch.ExtraValue
import app.cartouche.core.launch.GAME_URI
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.LaunchSpec
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.launch.TemplateError
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldBeUnique
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldContainAll
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
        // The app reads both folders into one map by file name: a repeated name would hide a file.
        shipped.map { it.name }.shouldBeUnique().shouldContainAll("SonyPlayStation2.json", "MicrosoftXbox.json")
        shippedCatalog.rejected.shouldBeEmpty()
        val game = GameFile(FileName("Game.chd"), uri("content://x"), Some(FilePath("/storage/x/Game.chd")))
        shippedCatalog.platforms.flatMap { it.players }.forEach { it.template.resolve(game).shouldBeRight() }
    }

    @Test
    fun `the extensions read from a player's pattern are exactly ones it accepts, and every shipped player has them`() {
        shippedCatalog.platforms.flatMap { it.players }.forEach { player ->
            val extensions = player.accepts.extensions.shouldBeSome()
            extensions.forEach { player.accepts.matches(FileName("Game.$it")) shouldBe true }
            player.accepts.matches(FileName("Game.notadisc")) shouldBe false
        }
        FileNamePattern.of("^(.*)\\.(?:iso|CHD)$").shouldBeSome().extensions shouldBe Some(listOf("iso", "CHD"))
        // Patterns that say other things, or only seem to list extensions.
        listOf("^(?!\\.).*$", "^foo\\.(?:iso)$", "^(.*)\\.(?:iso|)$", "(?:iso|bin)", "^(.*)\\.(?:iso)x$").forEach {
            FileNamePattern.of(it).shouldBeSome().extensions shouldBe None
        }
    }

    @Test
    fun `a player's emulator name leaves out the platform the definitions put first`() {
        val names = shippedCatalog.platform(PlatformId("ps2")).shouldBeSome().players.map { it.emulatorName }
        names shouldContain "ARMSX2 (Refresh/GitHub)"
        names shouldContain "RetroArch 64 - play"
        shippedCatalog.platform(PlatformId("ps2")).shouldBeSome().players.first().copy(name = "Solo").emulatorName shouldBe "Solo"
    }

    @Test
    fun `a PS2 disc image is offered to ARMSX2`() {
        val candidates = shippedCatalog.candidates(FileName("Burnout 3 - Takedown (Europe) (En,Es,Nl,Sv).chd"))
        // A .chd may hold a disc of several platforms: the PS2 is one of them.
        candidates.map { it.platform.id } shouldContain PlatformId("ps2")
        candidates.filter { it.platform.id == PlatformId("ps2") }.map {
            it.player.template.targetPackage.map { p ->
                p.value
            }
        } shouldContain
            Some("com.armsx2")
        shippedCatalog.candidates(FileName("GAME.CHD")).map { it.platform.id } shouldContain PlatformId("ps2")
    }

    @Test
    fun `Xbox and Xbox 360 games are DVDs, offered to their emulators, which are handed the game's URI alone`() {
        fun profile(id: String) = shippedCatalog.platform(PlatformId(id)).shouldBeSome().profile
        profile("xbox") shouldBe
            PlatformProfile(
                MediaType.DVD,
                MediaRule(mediumId("xbox_dvd")),
                16_000_000,
                Some(ArtKind.Disc),
                None,
                Some(ScreenScraperSystem(32)),
            )
        profile("xbox360") shouldBe
            PlatformProfile(
                MediaType.DVD,
                MediaRule(mediumId("xbox360_dvd")),
                1_048_576,
                Some(ArtKind.Disc),
                None,
                Some(ScreenScraperSystem(33)),
            )

        fun extensions(id: String) = shippedCatalog.platform(PlatformId(id)).shouldBeSome().players.map { it.accepts.extensions }.toSet()
        extensions("xbox") shouldBe setOf(Some(listOf("iso", "xiso")))
        extensions("xbox360") shouldBe setOf(Some(listOf("iso", "xex", "zar")))
        val game = GameFile(FileName("Halo 3 (USA).iso"), uri(GAME_URI), None)
        val data = Some(GAME_URI)
        val view = LaunchSpec(None, Some("android.intent.action.VIEW"), data, None, emptyList(), 0, emptySet(), emptyList(), Some(game.uri))
        val extras = listOf(Extra("game_uri", ExtraValue.Text(GAME_URI)))
        val ax360e = view.copy(action = Some("aenu.intent.action.AX360E"), data = None, extras = extras)

        fun LaunchSpec.at(pkg: String, activity: String) = copy(component = PackageName.parse(pkg).map { Component(it, activity) })
        val launches =
            mapOf(
                "xbox.com.rfandango.haku_x" to view.at("com.rfandango.haku_x", "com.rfandango.haku_x.LauncherActivity"),
                "xbox.com.izzy2lost.x1box" to view.at("com.izzy2lost.x1box", "com.izzy2lost.x1box.LauncherActivity"),
                "xbox360.aenu.ax360e" to ax360e.at("aenu.ax360e", "aenu.ax360e.EmulatorActivity"),
                "xbox360.aenu.ax360e.free" to ax360e.at("aenu.ax360e.free", "aenu.ax360e.EmulatorActivity"),
                "xbox360.xendroid.compose" to view.at("xendroid.compose", "xendroid.compose.EmulatorHostActivity"),
            )
        shippedCatalog.platforms.filter { it.id.value.startsWith("xbox") }.flatMap { it.players }.map { it.id.value }.toSet() shouldBe
            launches.keys
        launches.forEach { (id, spec) ->
            shippedCatalog.launch(PlayerId(id), game).shouldBeRight() shouldBe
                Launch(spec, RunningInstance.KEEP)
        }
    }

    @Test
    fun `INV-E10-06 a profile says what its scans show and each cartridge front's shape and label, and refuses a label off it`() {
        fun profiles(art: String) = Catalog.parse(
            listOf(definition(platform = "p")),
            DefinitionSource("profiles.json", """{"p": {"media": "cartridge", "medium": {"default": "c"}, "minimumGameBytes": 1$art}}"""),
        )

        fun artOf(art: String) = profiles(art).platform(PlatformId("p")).shouldBeSome().profile.art

        fun fronts(proportion: String, label: String) =
            """, "art": {"kind": "cartridge_front", "fronts": {"c": {"proportion": 0.9, "label": {"left": 0.1, "top": 0.1, "width": 0.8, "height": 0.5}},
                "d": {"proportion": $proportion, "label": $label}}}"""

        artOf("") shouldBe None
        artOf(""", "art": {"kind": "disc"}""") shouldBe Some(ArtKind.Disc)
        val label = """{"left": 0.15, "top": 0.23, "width": 0.72, "height": 0.62}"""
        val read = artOf(fronts("1.5", label)).shouldBeSome().shouldBeInstanceOf<ArtKind.CartridgeFront>()
        read shouldBe
            ArtKind.CartridgeFront(
                mapOf(
                    mediumId("c") to front(0.9, crop(0.1, 0.1, 0.8, 0.5)),
                    mediumId("d") to front(1.5, crop(0.15, 0.23, 0.72, 0.62)),
                ),
            )
        // In the order the profile gives them, which says which front a scan is read as first.
        read.fronts.keys.map { it.value } shouldBe listOf("c", "d")
        val off = """{"left": 0.5, "top": 0.2, "width": 0.6, "height": 0.6}"""
        listOf(
            fronts("1.5", off),
            fronts("0", label),
            fronts("-1.5", label),
            """, "art": {"kind": "cartridge_front", "label": $label}""",
        ).forEach { art ->
            val refused = profiles(art)
            refused.platforms.shouldBeEmpty()
            refused.rejected.first().shouldBeInstanceOf<CatalogError.InvalidJson>()
        }
        profiles(""", "scansBySerial": {"url": "https://scans.test/{serial}.png", "serial": "[A-Z"}""").platforms.shouldBeEmpty()
    }

    @Test
    fun `a profile names the system ScreenScraper numbers the platform, or none, and refuses anything but a number`() {
        fun profiles(system: String) = Catalog.parse(
            listOf(definition(platform = "p")),
            DefinitionSource("profiles.json", """{"p": {"media": "dvd", "medium": {"default": "d"}, "minimumGameBytes": 1$system}}"""),
        )
        profiles("").platform(PlatformId("p")).shouldBeSome().profile.screenScraperSystem shouldBe None
        profiles(""", "screenScraperSystem": 58""").platform(PlatformId("p")).shouldBeSome().profile.screenScraperSystem shouldBe
            Some(ScreenScraperSystem(58))
        profiles(""", "screenScraperSystem": "ps2"""").platforms.shouldBeEmpty()
    }

    @Test
    fun `INV-E10-06 a shipped cartridge platform has a front for each of its media, a disc platform its face, every extract a kind`() {
        shippedCatalog.platforms.forEach { platform ->
            platform.profile.art.onSome { art ->
                (art is ArtKind.CartridgeFront) shouldBe (platform.profile.media == MediaType.CARTRIDGE)
                // Every medium a game can come in has its front, whose scans are read first for it.
                val media = platform.profile.medium.let { listOf(it.default) + it.ntscU.toList() + it.ntscJ.toList() }
                if (art is ArtKind.CartridgeFront) art.fronts.keys shouldContainAll media
            }
        }
        Shipped.lists("art").keys.forEach { shippedCatalog.platform(it).shouldBeSome().profile.art.shouldBeSome() }
        val nes = shippedCatalog.platform(PlatformId("nes")).shouldBeSome().profile.art
        // The Famicom's front too, whose scans are cut by its own crop.
        nes.shouldBeSome().shouldBeInstanceOf<ArtKind.CartridgeFront>().fronts.keys.map { it.value } shouldBe
            listOf("nes_cart", "famicom_cart")
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
