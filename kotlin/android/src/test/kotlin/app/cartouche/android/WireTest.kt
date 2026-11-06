// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.LibraryFailure
import app.cartouche.core.FileName
import app.cartouche.core.PackageName
import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.ConsoleVariant
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.Game
import app.cartouche.core.library.IgnoreReason
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.IgnoredFile
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.library.VariantError
import app.cartouche.core.library.game
import app.cartouche.core.library.listed
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import app.cartouche.core.settings.Setting
import app.cartouche.core.settings.settings
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import app.cartouche.core.uri
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.godotengine.godot.Dictionary
import org.godotengine.godot.plugin.UsedByGodot
import org.junit.Test
import app.cartouche.core.settings.Settings as AppSettings

class WireTest {
    /** The `ps2` platform, whose games are all one medium. */
    private val ps2 = catalog(definition())

    private fun parsed(json: String): JsonObject = Json.parseToJsonElement(json).jsonObject

    private fun Library.sentJson(shelves: Option<Shelves> = None, catalog: Catalog = ps2): JsonObject =
        parsed(jsonOf(sent(0, shelves, catalog)))

    private fun sentGames(vararg games: Game, catalog: Catalog = ps2) =
        Library(games = games.toList()).sentJson(catalog = catalog).getValue("games").jsonArray.map { it.jsonObject }

    private fun JsonObject.text(key: String) = getValue(key).jsonPrimitive.content

    @Test
    fun `INV-23 every getter of the plugin hands Godot JSON text`() {
        CartouchePlugin::class.java.declaredMethods
            .filter { it.isAnnotationPresent(UsedByGodot::class.java) && it.returnType != String::class.java && it.returnType != Void.TYPE }
            .map { it.name }
            .shouldBeEmpty()
    }

    @Test
    fun `an answer carries its payload's fields beside its request id, a library call's revision, and a failure's code`() {
        val renamed = payload(Sent.Renamed("Okage: Shadow King", Some("Okage")))
        parsed(answered(7, Some(3), Either.Right(renamed))) shouldBe
            parsed("""{"request_id": 7, "revision": 3, "ok": true, "title": "Okage: Shadow King", "original_title": "Okage"}""")
        // A value the plugin does not have is an absent key.
        parsed(answered(8, None, Either.Right(payload(Sent.Renamed("Okage"))))) shouldBe
            parsed("""{"request_id": 8, "ok": true, "title": "Okage"}""")
        parsed(answered(9, None, Either.Right(Payload.NONE))) shouldBe parsed("""{"request_id": 9, "ok": true}""")
        parsed(answered(10, None, Either.Left(LaunchFailure.TooLate.failed))).let {
            it.text("code") shouldBe "too_late"
            it.getValue("ok") shouldBe JsonPrimitive(false)
        }
    }

    @Serializable
    class Clash(val revision: Int)

    @Test
    fun `a payload is an object, none of whose keys is the envelope's`() {
        shouldThrow<IllegalArgumentException> { payload(3) }
        shouldThrow<IllegalArgumentException> { payload(listOf("Okage")) }
        shouldThrow<IllegalArgumentException> { payload(Clash(2)) }
    }

    @Test
    fun `INV-23 every setting reaches Godot under its key as its declaration writes it, and is taken back as Godot sends it`() =
        runBlocking<Unit> {
            checkAll(settings) { settings ->
                val wire = parsed(jsonOf(settings.sent(firstLaunch = false)))
                val backdrop = parsed(jsonOf(settings.sentBackdrop()))
                Setting.all.forEach { setting ->
                    val sent = Option.fromNullable(wire[setting.key]).map { it.jsonPrimitive.content }
                    sent shouldBe setting.valueIn(settings).map { it.written }
                    // GDScript sends a value back as `str()` writes it.
                    sent.onSome {
                        Setting.change(AppSettings(), setting.key, it).map(setting::valueIn) shouldBe
                            Either.Right(setting.valueIn(settings))
                    }
                    if (setting.names.isNotEmpty()) {
                        wire.getValue("${setting.key}s").jsonArray.map { it.jsonPrimitive.content } shouldBe setting.names
                    }
                    if (setting.key in backdrop) backdrop[setting.key] shouldBe wire[setting.key]
                }
            }
        }

    @Test
    fun `each launch failure reaches Godot with its own code, which the carousel tells apart`() {
        val file = uri("content://p/tree/t/document/g")
        val codes =
            mapOf(
                LaunchFailure.Rejected(LaunchError.UnknownPlayer(PlayerId("p"))) to "unknown_player",
                LaunchFailure.Rejected(LaunchError.UnsupportedFile(PlayerId("p"), FileName("g.chd"))) to "unsupported_file",
                LaunchFailure.NotInstalled(PackageName.parse("com.armsx2").shouldBeSome()) to "not_installed",
                LaunchFailure.NoPlayer(PlatformId("ps2")) to "no_player",
                LaunchFailure.GameMissing(file) to "game_missing",
                LaunchFailure.TooLate to "too_late",
                LaunchFailure.ActivityNotFound("com.armsx2/.Main") to "activity_not_found",
                LaunchFailure.PermissionDenied("denied") to "permission_denied",
            )
        codes.forEach { (failure, code) -> parsed(jsonOf(failure.failed)).text("code") shouldBe code }
    }

    @Test
    fun `the library sends effective model choices including the base for old setups`() {
        val ps2Id = PlatformId("ps2")
        val library =
            Library(
                setups = mapOf(ps2Id to PlatformSetup(), PlatformId("gba") to PlatformSetup()),
                consoleVariants = mapOf(ps2Id to ConsoleVariant.PS2_FAT),
            )
        val sent = library.sentJson()
        sent.getValue("console_variants").jsonObject.mapValues { it.value.jsonPrimitive.content } shouldBe
            mapOf("ps2" to "ps2_fat", "gba" to "gba")
        sent.getValue("setups").jsonObject.getValue("ps2").jsonObject.text("variant_id") shouldBe "ps2_fat"
        listOf(
            VariantError.Unknown(ps2Id, "gba_sp") to "unknown_variant",
            VariantError.NotInLibrary(ps2Id) to "not_in_library",
            VariantError.Coming(ps2Id, "ps2_slim") to "coming_console",
        ).forEach { (error, code) -> parsed(jsonOf(LibraryFailure.Variant(error).failed)).text("code") shouldBe code }
    }

    @Test
    fun `each shelf sent to Godot points at its own games in the library, and at the one shown`() {
        val library = Library(games = listOf(game("B", platform = "gba"), game("Z"), game("A"), game("C", platform = "gba")))
        val selection = Selection().with(library.games[3])
        val sent = library.sentJson(Shelves.of(library, listOf(PlatformId("ps2"), PlatformId("gba")), selection))
        val ids = sent.getValue("games").jsonArray.map { it.jsonObject.text("id") }
        val shelves = sent.getValue("shelves").jsonArray.map { it.jsonObject }
        shelves.map { shelf -> shelf.getValue("game_indexes").jsonArray.map { ids[it.jsonPrimitive.content.toInt()] } } shouldBe
            listOf(listOf("ps2/A", "ps2/Z"), listOf("gba/B", "gba/C"))
        sent.text("selected_shelf") shouldBe "1"
        shelves.map { it.text("selected") } shouldBe listOf("0", "1")
    }

    @Test
    fun `the library sent to Godot does not grow with hidden or unsupported files`() {
        fun sent(files: Int): Int {
            val ignored =
                (1..files).flatMap {
                    listOf(
                        IgnoredFile(listed("texture-%05d.dds".format(it)), IgnoreReason.UNSUPPORTED),
                        IgnoredFile(listed("._%05d.chd".format(it)), IgnoreReason.HIDDEN),
                    )
                }
            return jsonOf(Library().withScan(PlatformId("ps2"), Scan(listOf(game("G")), ignored, emptyList())).sent(0, None, ps2)).length
        }
        sent(5_000) shouldBeLessThanOrEqual sent(IgnoredCount.EXAMPLES) + 10
    }

    @Test
    fun `a renamed game reaches Godot under its name, its chosen label under its own keys, an automatic one under none`() {
        val okage = game("Okage")
        val (plain, renamed) = sentGames(okage, okage.copy(displayName = DisplayName.of("Okage: Shadow King")))
        plain.text("title") shouldBe "Okage"
        plain.containsKey("original_title") shouldBe false
        renamed.text("title") shouldBe "Okage: Shadow King"
        renamed.text("original_title") shouldBe "Okage"

        fun label(choice: LabelChoice) = sentGames(okage.copy(label = choice)).single()
        label(LabelChoice.Region(LabelRegion("Japan"))).let {
            it.text("label_region") shouldBe "Japan"
            it.text("label_source") shouldBe "launchbox"
        }
        label(LabelChoice.Region(LabelRegion("Japan"), ArtSource.SCREENSCRAPER)).text("label_source") shouldBe "screenscraper"
        label(LabelChoice.Automatic).keys shouldBe plain.keys
        label(LabelChoice.Own).text("label_own") shouldBe "true"
        label(LabelChoice.Own).containsKey("label_region") shouldBe false
    }

    @Test
    fun `each game reaches Godot with the medium its platform gives its regions, none when the platform is unknown`() {
        val medium = """{"default": "nes_cart", "ntsc_j": "famicom_cart"}"""
        val profiles = """{"nes": {"media": "cartridge", "medium": $medium, "minimumGameBytes": 1}}"""
        val nes = Catalog.parse(listOf(definition(platform = "nes")), DefinitionSource("profiles.json", profiles))
        val sent =
            sentGames(
                game("A", "nes").copy(regions = listOf("Japan")),
                game("B", "nes").copy(regions = listOf("USA")),
                game("C", "gba"),
                catalog = nes,
            )
        sent.take(2).map { it.text("medium") } shouldBe listOf("famicom_cart", "nes_cart")
        sent.last().containsKey("medium") shouldBe false
    }

    @Test
    fun `values from GDScript are read by type, ints arriving as Long`() {
        val request =
            Dictionary().apply {
                put("disc", 2L)
                put("small", 3)
                put("huge", Long.MAX_VALUE)
                put("flag", true)
                put("name", "x")
            }
        request.integer("disc") shouldBe Some(2)
        request.integer("small") shouldBe Some(3)
        request.integer("huge") shouldBe None
        request.integer("name") shouldBe None
        Dictionary().apply { put("disc", 1.9) }.integer("disc") shouldBe None
        request.text("name") shouldBe Some("x")
        request.text("missing") shouldBe None
    }
}
