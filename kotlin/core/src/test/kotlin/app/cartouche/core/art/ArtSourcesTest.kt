// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.game
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.MediaRule
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.SerialScans
import app.cartouche.core.platforms.mediumId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.pair
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ArtSourcesTest {
    private val index = ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png")))))

    private val bySerial = SerialScans.of("https://scans.test/{serial}.jpg", PLAYSTATION_SERIAL)

    @Test
    fun `a game is looked for as the extract's scans, then those of its serials, in the sources' version`() {
        val okage = game("Okage").copy(serials = listOf("SCUS-97129"))
        val request = ArtSources(ArtKind.Disc, PS2_MEDIA, index, bySerial).requestFor(okage).shouldBeSome()
        request.title shouldBe "Okage"
        request.version shouldBe Some(ArtVersion("2026-09-28"))
        request.candidates.map { it.value.substringAfterLast('/') } shouldBe listOf("na.png", "jp.png", "SCUS-97129.jpg")
    }

    @Test
    fun `INV-E4-05 only the games still wanting art in their sources' version are planned, and only their platforms' extracts read`() =
        runBlocking<Unit> {
            val newer = Some(ArtVersion("2026-10-01"))
            val okage = ExtractGame("Okage", emptySet(), listOf("USA=o.png"))
            val extracts =
                mapOf(
                    PlatformId("ps2") to extract(listOf(okage, ExtractGame("Ico", emptySet(), listOf("Japan=i.png"))), "2026-10-01"),
                    PlatformId("gc") to extract(listOf(ExtractGame("Ikaruga", emptySet(), listOf("Japan=k.png")))),
                )

            fun versionOf(platform: PlatformId) = extracts.getOrNone(platform).flatMap(ArtIndex::versionOf)

            fun sources(platform: PlatformId) =
                ArtSources(ArtKind.Disc, PS2_MEDIA, extracts.getOrNone(platform).fold({ ArtIndex.EMPTY }, ArtIndex::parse), None)
            val library = listOf(game("Okage"), game("Ico"), game("Unknown"), game("Ikaruga", "gc"), game("Okage", "gba"))
            val versions = Arb.element(Some(ArtVersion("2026-09-28")), newer, None)
            checkAll(Arb.list(Arb.element(library), 0..5), Arb.list(Arb.pair(Arb.element(library), versions), 0..6)) { games, done ->
                // Stored, or known to be missing from that version of its sources.
                val wants = { id: GameId, version: Option<ArtVersion> -> done.none { (game, v) -> game.id == id && v == version } }
                val read = mutableSetOf<PlatformId>()
                val planned = ArtSources.requests(games, wants, ::versionOf) { platform -> sources(platform).also { read += platform } }
                // Every game's plan, as the scraper keeps it.
                planned shouldBe games.flatMap { sources(it.platform).requestFor(it).toList() }.filter { wants(it.game, it.version) }
                read shouldBe games.filter { wants(it.id, versionOf(it.platform)) }.map { it.platform }.toSet()
            }
            // Missing from the extract's previous version: looked for again in its new one.
            val missing = { id: GameId, version: Option<ArtVersion> ->
                !(id == game("Okage").id && version == Some(ArtVersion("2026-09-28")))
            }
            ArtSources.requests(listOf(game("Okage")), missing, ::versionOf, ::sources).map { it.version } shouldBe listOf(newer)
        }

    @Test
    fun `a game's label is cut for the medium its regions give it, in each of its requests`() {
        val kind = cartridge("snes_pal_cart", 1.41, crop(0.09, 0.06, 0.82, 0.4))
        val sources = ArtSources(kind, MediaRule(mediumId("snes_pal_cart"), Some(mediumId("snes_us_cart"))), index, None)
        val american = game("Okage").copy(regions = listOf("USA"))
        sources.cutOf(american) shouldBe LabelCut(kind, mediumId("snes_us_cart"))
        sources.requestFor(american).shouldBeSome().cut shouldBe sources.cutOf(american)
        sources.cutOf(game("Okage").copy(regions = listOf("Japan", "Europe"))) shouldBe LabelCut(kind, mediumId("snes_pal_cart"))
    }

    @Test
    fun `INV-E10-06 a game is looked for in its own platform's scans only, each of its platform's kind`() = runBlocking<Unit> {
        val kinds = mapOf("ps2" to ArtKind.Disc, "gba" to cartridge("gba_cart", 1.74, crop(0.147, 0.218, 0.706, 0.628)))
        val media = mapOf("ps2" to "ps2_dvd", "gba" to "gba_cart").mapValues { mediumId(it.value) }
        var both = 0
        checkAll(extracts, extracts, artTitles, Arb.list(regionNames, 0..2)) { ps2, gba, title, regions ->
            // Every scan's file names its platform too: `gba-g3-disc-1.png`.
            val texts =
                mapOf("ps2" to ps2, "gba" to gba)
                    .map { (platform, games) ->
                        PlatformId(platform) to
                            extract(games.map { game -> game.copy(discs = game.discs.map { it.replace("=", "=$platform-") }) })
                    }.toMap()
            val asked =
                kinds.keys.map { platform ->
                    val sources = ArtSources.of(Shipped.catalog, texts, PlatformId(platform))
                    val game = game(title, platform).copy(regions = regions)
                    val request = sources.requestFor(game)
                    request.onSome {
                        it.cut shouldBe LabelCut(kinds.getValue(platform), media.getValue(platform))
                        it.candidates.all { url -> url.value.substringAfterLast('/').startsWith("$platform-") } shouldBe true
                    }
                    sources.variantsOf(game).all { it.url.value.substringAfterLast('/').startsWith("$platform-") } shouldBe true
                    request
                }
            if (asked.all { it.isSome() }) both++
        }
        // A title often names a game with scans on both platforms, which never mix.
        both shouldBeGreaterThan 50
    }

    @Test
    fun `a game the extract does not know is looked for by its serials, and a game no source can have is not`() {
        val unknown = game("Unknown").copy(serials = listOf("SLPS-25358"))
        ArtSources(ArtKind.Disc, PS2_MEDIA, index, bySerial).requestFor(unknown).shouldBeSome().candidates.size shouldBe 1
        ArtSources(ArtKind.Disc, PS2_MEDIA, index, bySerial).requestFor(game("Unknown")).shouldBeNone()
        ArtSources(ArtKind.Disc, PS2_MEDIA, index, None).requestFor(unknown).shouldBeNone()
        ArtSources(ArtKind.Disc, PS2_MEDIA, ArtIndex.EMPTY, None).requestFor(game("Okage")).shouldBeNone()
    }

    @Test
    fun `INV-E7-03 a game whose label shows a chosen region is looked for in that region's scan first, among the same scans`() =
        runBlocking<Unit> {
            var moved = 0
            // Mostly a region of the game's scans, sometimes one it has no scan for; another game
            // beside it, whose scans must never come.
            checkAll(Arb.list(regionNames, 1..5), Arb.list(regionNames, 0..2), regionNames, Arb.int(0..6)) { discs, regions, other, pick ->
                val chosen = sameRegion(discs.getOrElse(pick) { other })
                val lines = discs.mapIndexed { i, region -> "$region=d$i.png" }
                val extract =
                    extract(listOf(ExtractGame("Okage", emptySet(), lines), ExtractGame("Okage 2", emptySet(), listOf("$chosen=o.png"))))
                val sources = ArtSources(ArtKind.Disc, PS2_MEDIA, ArtIndex.parse(extract), bySerial)
                val okage = game("Okage").copy(regions = regions, serials = listOf("SCUS-97129"))
                val automatic = sources.requestFor(okage).shouldBeSome().candidates
                val picked = sources.requestFor(okage.copy(label = LabelChoice.Region(LabelRegion(chosen)))).shouldBeSome().candidates
                // The first scan the extract lists for the chosen region, under any of its names.
                val first = discs.indexOfFirst { sameRegion(it) == chosen }
                val expected =
                    if (first < 0) {
                        automatic
                    } else {
                        automatic.first { it.value.endsWith("/d$first.png") }.let { listOf(it) + (automatic - it) }
                    }
                picked shouldBe expected
                if (picked != automatic) moved++
            }
            moved shouldBeGreaterThan 200
        }

    @Test
    fun `INV-E7-04 a game whose label is a picture of the user's own is never looked for, whatever its sources have`() = runBlocking<Unit> {
        var withScans = 0
        val serialLists = Arb.list(Arb.element("SCUS-97129", "SLPS-25358"), 0..2)
        checkAll(Arb.list(regionNames, 0..5), Arb.list(regionNames, 0..2), serialLists) { discs, regions, serials ->
            val extract = extract(listOf(ExtractGame("Okage", emptySet(), discs.mapIndexed { i, region -> "$region=d$i.png" })))
            val okage = game("Okage").copy(regions = regions, serials = serials)
            val sources = ArtSources(ArtKind.Disc, PS2_MEDIA, ArtIndex.parse(extract), bySerial)
            if (sources.requestFor(okage).isSome()) withScans++
            sources.requestFor(okage.copy(label = LabelChoice.Own)).shouldBeNone()
        }
        // Mostly games the sources do have scans for, which an automatic label would get.
        withScans shouldBeGreaterThan 500
    }

    @Test
    fun `INV-E7-04 looking labels up again asks for each game a source may have art for, and never touches a label the user chose`() =
        runBlocking<Unit> {
            val sources = ArtSources(ArtKind.Disc, PS2_MEDIA, index, None)
            val labels = Arb.element(LabelChoice.Automatic, LabelChoice.Own, LabelChoice.Region(LabelRegion("Japan")))
            var own = 0
            var region = 0
            checkAll(Arb.list(Arb.pair(Arb.element("Okage", "Ico", "Unknown"), labels), 0..6)) { picked ->
                val games = picked.mapIndexed { i, (title, label) -> game(title).copy(id = GameId("$i"), label = label) }
                val again = ArtSources.lookAgain(games) { sources }
                games.forEach { game ->
                    val expected =
                        when {
                            game.label == LabelChoice.Own -> (false to false).also { own++ }
                            game.label is LabelChoice.Region -> (false to false).also { region++ }
                            game.title == "Okage" -> true to false
                            else -> false to true
                        }
                    ((game.id in again.asked) to (game.id in again.unfound)) shouldBe expected
                }
            }
            own shouldBeGreaterThan 100
            region shouldBeGreaterThan 100
        }
}
