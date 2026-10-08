// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.OwnPicture
import app.cartouche.android.art.StoredArt
import app.cartouche.android.art.VariantFailure
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.library.ScanReport
import app.cartouche.android.storage.DocumentEntry
import app.cartouche.android.storage.EntryKind
import app.cartouche.android.storage.Folder
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.art.ArtRequest
import app.cartouche.core.art.ArtUrl
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.Stall
import app.cartouche.core.library.Disc
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderPath
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoreReason
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.IgnoredFile
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.Scan
import app.cartouche.core.library.SkipReason
import app.cartouche.core.library.SkippedFolder
import app.cartouche.core.library.game
import app.cartouche.core.library.listed
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import app.cartouche.core.storage.DocumentId
import app.cartouche.core.storage.FolderPlace
import app.cartouche.core.storage.Volume
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.godotengine.godot.Dictionary
import org.junit.Test
import java.io.File
import app.cartouche.core.settings.Settings as AppSettings

class WireTest {
    private val found = FoundArt(GameId("ps2/a"), StoredArt(File("/data/art/a.jpg")))

    /** The values Godot's JNI bridge converts to Variants; see [toWireArray]. */
    private fun Any.isGodotValue(): Boolean = when (this) {
        is String, is Boolean, is Int, is Long, is Double -> true
        is Dictionary -> values.all { it.isGodotValue() }
        // A String inside an Object[] reaches GDScript as an opaque JavaObject; a String[] becomes a PackedStringArray.
        is Array<*> ->
            when (this::class.java) {
                Array<Any>::class.java -> all { it is Dictionary && it.isGodotValue() }
                Array<String>::class.java -> true
                else -> false
            }
        else -> false
    }

    /** A library with every field the GDScript adapter reads. */
    private val library =
        Library()
            .withSetup(PlatformId("ps2"), PlatformSetup(Some(uri("content://p/tree/t")), Some(PlayerId("ps2.x"))))
            .withScan(
                PlatformId("ps2"),
                Scan(
                    listOf(game("G", discs = nonEmptyListOf(Disc(Some(1), listed("G (Disc 1).chd"))), version = Some("v1.1"))),
                    listOf(
                        IgnoredFile(listed("bios.bin"), IgnoreReason.NOT_A_GAME),
                        IgnoredFile(listed("a.json"), IgnoreReason.UNSUPPORTED),
                        IgnoredFile(listed("._G.chd"), IgnoreReason.HIDDEN),
                    ),
                    listOf(SkippedFolder(FolderPath(".Trash"), SkipReason.HIDDEN)),
                ),
            ).withConsoleName(PlatformId("ps2"), DisplayName.of("Ma PS2"), "PlayStation 2")

    @Test
    fun `INV-E0-16 everything sent to Godot is a value its bridge converts`() {
        val uri = uri("content://p/tree/t")
        val folder = Folder(uri, "ps2", Some(FilePath("/storage/x")))
        val entry = DocumentEntry(FileName("g.chd"), EntryKind.FILE, DocumentId("x:g.chd"), uri, None, None)
        val broken = Catalog.parse(listOf(DefinitionSource("broken.json", "{")), DefinitionSource("profiles.json", "{}"))
        listOf(
            success("library" to library.toWireJson(None)),
            ScanReport(1, 1, 0, 1, 1, 12).toWire(),
            success("folders" to listOf(folder).toWireArray { it.toWire() }),
            success("entries" to listOf(entry).toWireArray { it.toWire() }),
            broken.toWire(),
            failure(ErrorCode.CANCELLED, "x"),
            Scraping.NONE.toWire().putSome("found", Some(found.toWire())),
            success("library" to library.toWireJson(None), "art" to listOf(found).artWireJson()),
            AppSettings(Some(ButtonStyle.NINTENDO)).toWire(false),
            success("folder" to placed.toWire()),
            BatteryState(Some(57), plugged = true).toWire(),
            BatteryState.NONE.toWire(),
        ).forEach { it.isGodotValue() shouldBe true }
        arrayOf("a").isGodotValue() shouldBe true
        listOf("a").toTypedArray<Any>().isGodotValue() shouldBe false
        arrayOf(dictionary()).isGodotValue() shouldBe false
    }

    private val placed = Folder(uri("content://p/tree/t"), "ps2", None, Some(FolderPlace(Volume.CARD, listOf("ROMs", "ps2"))))

    @Test
    fun `the settings and a folder's place reach Godot with the keys the GDScript adapter reads`() {
        AppSettings().toWire(true) shouldBe dictionary("first_launch" to true, "edge_smoothing" to "4x")
        AppSettings(Some(ButtonStyle.PLAYSTATION), EdgeSmoothing.TWICE).toWire(false) shouldBe
            dictionary("first_launch" to false, "button_style" to "playstation", "edge_smoothing" to "2x")
        AppSettings(edgeSmoothing = EdgeSmoothing.OFF).toWire(false)["edge_smoothing"] shouldBe "off"
        val place = placed.toWire()["place"] as Dictionary
        place["volume"] shouldBe "card"
        (place["folders"] as Array<*>).toList() shouldBe listOf("ROMs", "ps2")
    }

    @Test
    fun `a run's progress and the art found reach Godot with the keys and codes the GDScript adapter reads`() {
        val request = ArtRequest(GameId("ps2/a"), "A", nonEmptyListOf(ArtUrl("https://a/a.png")), None)
        val (_, underWay) = Scraping.NONE.with(listOf(request)).take().shouldBeSome()
        underWay.toWire() shouldBe dictionary("done" to 0, "total" to 1)
        Stall.entries.map { underWay.stalled(request.game, it).toWire()["stall"] } shouldBe listOf("offline", "refused", "storage")
        found.toWire() shouldBe dictionary("game_id" to "ps2/a", "path" to "/data/art/a.jpg")
        Json.parseToJsonElement(listOf(found).artWireJson()) shouldBe
            Json.parseToJsonElement("""[{"game_id": "ps2/a", "path": "/data/art/a.jpg"}]""")
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
                LaunchFailure.ActivityNotFound("com.armsx2/.Main") to "activity_not_found",
                LaunchFailure.PermissionDenied("denied") to "permission_denied",
            )
        codes.forEach { (failure, code) -> failure.toWire()["code"] shouldBe code }
    }

    @Test
    fun `the library and its shelves reach Godot as JSON of this shape, which the GDScript adapter reads`() {
        val shelves = Shelves.of(library, listOf(PlatformId("ps2")), Selection())
        Json.parseToJsonElement(library.toWireJson(shelves)) shouldBe Json.parseToJsonElement(GOLDEN)
    }

    @Test
    fun `each shelf sent to Godot points at its own games in the library, and at the one shown`() {
        val library = Library(games = listOf(game("B", platform = "gba"), game("Z"), game("A"), game("C", platform = "gba")))
        val selection = Selection().with(library.games[3])
        val shelves = Shelves.of(library, listOf(PlatformId("ps2"), PlatformId("gba")), selection)
        val sent = Json.parseToJsonElement(library.toWireJson(shelves)).jsonObject
        val ids = sent.getValue("games").jsonArray.map { it.jsonObject.getValue("id").jsonPrimitive.content }
        val shelved =
            sent.getValue("shelves").jsonObject.getValue("shelves").jsonArray.map { shelf ->
                shelf.jsonObject.getValue("games").jsonArray.map { ids[it.jsonPrimitive.int] }
            }
        shelved shouldBe listOf(listOf("ps2/A", "ps2/Z"), listOf("gba/B", "gba/C"))
        val found = sent.getValue("shelves").jsonObject
        found.getValue("selected").jsonPrimitive.int shouldBe 1
        found.getValue("shelves").jsonArray.map { it.jsonObject.getValue("selected").jsonPrimitive.int } shouldBe listOf(0, 1)
    }

    @Test
    fun `INV-E1-13 the library sent to Godot does not grow with hidden or unsupported files`() {
        fun sent(files: Int): Int {
            val ignored =
                (1..files).flatMap {
                    listOf(
                        IgnoredFile(listed("texture-%05d.dds".format(it)), IgnoreReason.UNSUPPORTED),
                        IgnoredFile(listed("._%05d.chd".format(it)), IgnoreReason.HIDDEN),
                    )
                }
            return Library().withScan(PlatformId("ps2"), Scan(listOf(game("G")), ignored, emptyList())).toWireJson(None).length
        }
        sent(5_000) shouldBeLessThanOrEqual sent(IgnoredCount.EXAMPLES) + 10
    }

    @Test
    fun `values from GDScript are read by type, ints arriving as Long`() {
        val request = dictionary("disc" to 2L, "small" to 3, "huge" to Long.MAX_VALUE, "flag" to true, "name" to "x")
        request.integer("disc") shouldBe Some(2)
        request.integer("small") shouldBe Some(3)
        request.integer("huge") shouldBe None
        request.integer("name") shouldBe None
        dictionary("disc" to 1.9).integer("disc") shouldBe None
        request.text("name") shouldBe Some("x")
        request.text("missing") shouldBe None
    }

    private companion object {
        // Absent keys are values the library does not have (here, a Redump name).
        const val GOLDEN = """{
            "setups": {
                "ps2": {"disc_grouping": "grouped", "folder_depth": "top_level", "folder_uri": "content://p/tree/t", "player_id": "ps2.x"}
            },
            "games": [{
                "id": "ps2/G", "platform_id": "ps2", "title": "G", "regions": [], "languages": [], "serials": [],
                "discs": [{"name": "G (Disc 1).chd", "number": 1}], "last_disc": 0, "identified": false, "version": "v1.1"
            }],
            "not_games": {"ps2": ["bios.bin"]},
            "ignored_counts": {
                "ps2": {"unsupported": {"count": 1, "examples": ["a.json"]}, "hidden": {"count": 1, "examples": ["._G.chd"]}}
            },
            "skipped_folders": {"ps2": [{"path": ".Trash", "reason": "hidden"}]},
            "console_names": {"ps2": "Ma PS2"},
            "shelves": {"shelves": [{"platform": "ps2", "games": [0], "selected": 0}], "selected": 0}
        }"""
    }

    @Test
    fun `a renamed game reaches Godot under its name, with its title beside it`() {
        fun sent(game: Game) = Json
            .parseToJsonElement(Library(games = listOf(game)).toWireJson(None))
            .jsonObject
            .getValue("games")
            .jsonArray
            .single()
            .jsonObject
        val okage = game("Okage")
        sent(okage).getValue("title").jsonPrimitive.content shouldBe "Okage"
        sent(okage).containsKey("original_title") shouldBe false
        val renamed = sent(okage.copy(displayName = DisplayName.of("Okage: Shadow King")))
        renamed.getValue("title").jsonPrimitive.content shouldBe "Okage: Shadow King"
        renamed.getValue("original_title").jsonPrimitive.content shouldBe "Okage"
    }

    @Test
    fun `a game's chosen region reaches Godot under its own key, and an automatic label sends none`() {
        fun sent(label: LabelChoice) = Json
            .parseToJsonElement(Library(games = listOf(game("Okage").copy(label = label))).toWireJson(None))
            .jsonObject
            .getValue("games")
            .jsonArray
            .single()
            .jsonObject
        sent(LabelChoice.Region(LabelRegion("Japan"))).getValue("label_region").jsonPrimitive.content shouldBe "Japan"
        sent(LabelChoice.Region(LabelRegion(""))).getValue("label_region").jsonPrimitive.content shouldBe ""
        sent(LabelChoice.Automatic).containsKey("label_region") shouldBe false
        sent(LabelChoice.Own).getValue("label_own").jsonPrimitive.content shouldBe "true"
        sent(LabelChoice.Own).containsKey("label_region") shouldBe false
        VariantFailure.entries.map { it.wire }.distinct().size shouldBe VariantFailure.entries.size
    }

    @Test
    fun `a picture being framed is sent with its path and size`() {
        OwnPicture(File("/own/picked.jpg"), 640, 480).toWire() shouldBe
            dictionary("path" to "/own/picked.jpg", "width" to 640, "height" to 480)
    }
}
