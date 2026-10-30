// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.game
import app.cartouche.core.platforms.ArtKind
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.MediaRule
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.ScreenScraperSystem
import app.cartouche.core.platforms.SerialScans
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.mediumId
import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrNone
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.flatMap
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.pair
import io.kotest.property.arbitrary.set
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class ArtSourcesTest {
    private val index = ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png")))))

    private val bySerial = SerialScans.of("https://scans.test/{serial}.jpg", PLAYSTATION_SERIAL)

    private val ps2 = ScreenScraperSystem(58)

    private val table = TextureTable.parse("# 2026-10-18\nOkage (USA)\t1234\tus jp\n", ps2)

    private val gba = cartridge("gba_cart", 1.74, crop(0.147, 0.218, 0.706, 0.628))

    /** Okage as an American release the table knows, with a serial. */
    private val okage = game("Okage").copy(regions = listOf("USA"), serials = listOf("SCUS-97129"), redumpName = Some("Okage (USA)"))

    private fun sources(
        kind: ArtKind = ArtKind.Disc,
        index: ArtIndex = this.index,
        bySerial: Option<SerialScans> = None,
        textures: TextureTable = TextureTable.EMPTY,
    ) = ArtSources(kind, PS2_MEDIA, index, bySerial, textures)

    /** A candidate as the tests name it: a scan's file, a texture's identity. */
    private fun names(candidates: List<Candidate>) = candidates.map { it.identity.value.substringAfterLast('/') }

    private fun texture(region: String, media: String = "t-$region") =
        Candidate.Texture(ps2, ScreenScraperGame(1), TextureMedia(media), region)

    private fun texture(number: Int, region: String) = texture(region, "t$number")

    @Test
    fun `a disc is looked for as its region's scans, its region's textures, its serials' scans, then the rest, in the sources' version`() {
        val request = sources(bySerial = bySerial, textures = table).requestFor(okage).shouldBeSome()
        request.title shouldBe "Okage"
        request.version shouldBe Some(ArtVersion("2026-09-28 2026-10-18"))
        names(request.candidates) shouldBe
            listOf("na.png", "ss:58:1234:support-texture(us)", "SCUS-97129.jpg", "jp.png", "ss:58:1234:support-texture(jp)")
    }

    @Test
    fun `a cartridge is looked for as its region's textures, then its region's scans, then the rest, a texture first when as close`() {
        val request = sources(kind = gba, textures = table).requestFor(okage).shouldBeSome()
        names(request.candidates) shouldBe listOf("ss:58:1234:support-texture(us)", "na.png", "ss:58:1234:support-texture(jp)", "jp.png")
    }

    @Test
    fun `only a game identified as a release the table lists gets textures, and only on a platform whose profile names its system`() {
        names(sources(textures = table).requestFor(okage.copy(redumpName = None)).shouldBeSome().candidates) shouldBe
            listOf("na.png", "jp.png")
        names(sources(textures = table).requestFor(okage.copy(redumpName = Some("Okage (Europe)"))).shouldBeSome().candidates) shouldBe
            listOf("na.png", "jp.png")
        val extracts = mapOf(PlatformId("p") to extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png")))))
        val tables = mapOf(PlatformId("p") to "# 2026-10-18\nOkage (USA)\t1234\tus\n")
        names(
            ArtSources.of(catalog(system = false), extracts, tables, PlatformId("p")).requestFor(okage).shouldBeSome().candidates,
        ) shouldBe
            listOf("na.png")
        names(ArtSources.of(catalog(system = true), extracts, tables, PlatformId("p")).requestFor(okage).shouldBeSome().candidates) shouldBe
            listOf("na.png", "ss:58:1234:support-texture(us)")
    }

    /** A disc platform `p` whose profile names the PS2's ScreenScraper system when [system]. */
    private fun catalog(system: Boolean): Catalog {
        val named = if (system) """, "screenScraperSystem": 58""" else ""
        val profile = """{"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1, "art": {"kind": "disc"}$named}"""
        return Catalog.parse(listOf(definition(platform = "p")), DefinitionSource("profiles.json", """{"p": $profile}"""))
    }

    @Test
    fun `INV-17 the sources' version is their dated files', the same read from their first lines alone, and none without any`() =
        runBlocking<Unit> {
            val p = PlatformId("p")
            checkAll(Arb.boolean(), Arb.boolean(), Arb.boolean()) { withExtract, withTable, withSystem ->
                val extracts = if (withExtract) mapOf(p to extract(emptyList(), "2026-09-28")) else emptyMap()
                val tables = if (withTable) mapOf(p to "# 2026-10-18\n") else emptyMap()
                val catalog = catalog(withSystem)
                val dates = listOfNotNull("2026-09-28".takeIf { withExtract }, "2026-10-18".takeIf { withTable && withSystem })
                val expected = if (dates.isEmpty()) None else Some(ArtVersion(dates.joinToString(" ")))
                ArtSources.of(catalog, extracts, tables, p).version shouldBe expected
                ArtSources.versionOf(catalog, extracts, tables, p) shouldBe expected
            }
            ArtSources.versionOf(catalog(true), emptyMap(), emptyMap(), PlatformId("other")).shouldBeNone()
        }

    @Test
    fun `INV-17 only the games still wanting art in their sources' version are planned, and only their platforms' extracts read`() =
        runBlocking<Unit> {
            val newer = Some(ArtVersion("2026-10-01"))
            val okage = ExtractGame("Okage", emptySet(), listOf("USA=o.png"))
            val extracts =
                mapOf(
                    PlatformId("ps2") to extract(listOf(okage, ExtractGame("Ico", emptySet(), listOf("Japan=i.png"))), "2026-10-01"),
                    PlatformId("gc") to extract(listOf(ExtractGame("Ikaruga", emptySet(), listOf("Japan=k.png")))),
                )

            fun versionOf(platform: PlatformId) = extracts.getOrNone(platform).flatMap(ArtIndex::versionOf)

            fun sources(platform: PlatformId) = sources(index = extracts.getOrNone(platform).fold({ ArtIndex.EMPTY }, ArtIndex::parse))
            val library = listOf(game("Okage"), game("Ico"), game("Unknown"), game("Ikaruga", "gc"), game("Okage", "gba"))
            val versions = Arb.element(Some(ArtVersion("2026-09-28")), newer, None)
            checkAll(Arb.list(Arb.element(library), 0..5), Arb.list(Arb.pair(Arb.element(library), versions), 0..6)) { games, done ->
                // Stored, or known to be missing from that version of its sources.
                val wants = { id: GameId, version: Option<ArtVersion> -> done.none { (game, v) -> game.id == id && v == version } }
                val read = mutableSetOf<PlatformId>()
                val planned =
                    ArtSources
                        .requests(games, wants, { false }, ::versionOf) { platform ->
                            sources(platform).also {
                                read +=
                                    platform
                            }
                        }.requests
                // Every game's plan, as the scraper keeps it.
                planned shouldBe games.flatMap { sources(it.platform).requestFor(it).toList() }.filter { wants(it.game, it.version) }
                read shouldBe games.filter { wants(it.id, versionOf(it.platform)) }.map { it.platform }.toSet()
            }
            // Missing from the extract's previous version: looked for again in its new one.
            val missing = { id: GameId, version: Option<ArtVersion> ->
                !(id == game("Okage").id && version == Some(ArtVersion("2026-09-28")))
            }
            ArtSources.requests(listOf(game("Okage")), missing, { false }, ::versionOf, ::sources).requests.map { it.version } shouldBe
                listOf(newer)
        }

    @Test
    fun `a game whose label is provisional is planned again only while its label is automatic`() {
        val sources = sources(textures = table)
        val labels = listOf(LabelChoice.Automatic, LabelChoice.Region(LabelRegion("Japan")), LabelChoice.Own)
        val games = labels.mapIndexed { i, label -> okage.copy(id = GameId("$i"), label = label) }
        val stored = { _: GameId, _: Option<ArtVersion> -> false }
        ArtSources.requests(games, stored, { true }, { sources.version }) { sources }.requests.map { it.game } shouldBe listOf(GameId("0"))
        ArtSources.requests(games, stored, { false }, { sources.version }) { sources }.requests.shouldBeEmpty()
    }

    @Test
    fun `the automatic labels wanting art that no source can have are planned unfound, with their sources' version`() {
        val sources = sources(textures = table)
        val unknown = game("Unknown")
        val games =
            listOf(
                okage,
                unknown,
                unknown.copy(id = GameId("chosen"), label = LabelChoice.Region(LabelRegion("Japan"))),
                unknown.copy(id = GameId("own"), label = LabelChoice.Own),
                unknown.copy(id = GameId("stored")),
            )
        val wants = { id: GameId, _: Option<ArtVersion> -> id != GameId("stored") }
        val plan = ArtSources.requests(games, wants, { false }, { sources.version }) { sources }
        plan.requests.map { it.game } shouldBe listOf(okage.id)
        plan.unfound shouldBe mapOf(unknown.id to sources.version)
    }

    @Test
    fun `a game's label is cut for the medium its regions give it, in each of its requests`() {
        val kind = cartridge("snes_pal_cart", 1.41, crop(0.09, 0.06, 0.82, 0.4))
        val sources =
            ArtSources(kind, MediaRule(mediumId("snes_pal_cart"), Some(mediumId("snes_us_cart"))), index, None, TextureTable.EMPTY)
        val american = game("Okage").copy(regions = listOf("USA"))
        sources.cutOf(american) shouldBe LabelCut(kind, mediumId("snes_us_cart"))
        sources.requestFor(american).shouldBeSome().cut shouldBe sources.cutOf(american)
        sources.cutOf(game("Okage").copy(regions = listOf("Japan", "Europe"))) shouldBe LabelCut(kind, mediumId("snes_pal_cart"))
    }

    @Test
    fun `INV-16 a game is looked for in its own platform's scans only, each of its platform's kind`() = runBlocking<Unit> {
        val kinds = mapOf("ps2" to ArtKind.Disc, "gba" to gba)
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
                    val sources = ArtSources.of(Shipped.catalog, texts, emptyMap(), PlatformId(platform))
                    val game = game(title, platform).copy(regions = regions)
                    val request = sources.requestFor(game)
                    request.onSome {
                        it.cut shouldBe LabelCut(kinds.getValue(platform), media.getValue(platform))
                        it.candidates.all { candidate ->
                            candidate.identity.value.substringAfterLast('/').startsWith("$platform-")
                        } shouldBe
                            true
                    }
                    sources
                        .variantsOf(
                            game,
                        ) { true }
                        .all { it.candidate.identity.value.substringAfterLast('/').startsWith("$platform-") } shouldBe
                        true
                    request
                }
            if (asked.all { it.isSome() }) both++
        }
        // A title often names a game with scans on both platforms, which never mix.
        both shouldBeGreaterThan 5
    }

    @Test
    fun `a game the extract does not know is looked for by its serials, and a game no source can have is not`() {
        val unknown = game("Unknown").copy(serials = listOf("SLPS-25358"))
        sources(bySerial = bySerial).requestFor(unknown).shouldBeSome().candidates.size shouldBe 1
        sources(bySerial = bySerial).requestFor(game("Unknown")).shouldBeNone()
        sources().requestFor(unknown).shouldBeNone()
        sources(index = ArtIndex.EMPTY).requestFor(game("Okage")).shouldBeNone()
    }

    /**
     * Which images are of a game's region, written by hand: its own regions and the zone each lies
     * in; the world only a world release's. The oracle of the order's stages, apart from the code's.
     */
    private val ownImages =
        mapOf(
            "France" to setOf("France", "Europe"),
            "Germany" to setOf("Germany", "Europe"),
            "Europe" to setOf("Europe"),
            "USA" to setOf("USA", "North America"),
            "North America" to setOf("North America", "USA"),
            "Japan" to setOf("Japan", "Asia"),
            "Korea" to setOf("Korea", "Asia"),
            "Asia" to setOf("Asia"),
            "Australia" to setOf("Australia", "Oceania"),
            "Oceania" to setOf("Oceania"),
            "Brazil" to setOf("Brazil", "South America"),
            "South America" to setOf("South America"),
            "World" to setOf("World"),
        )

    @Test
    fun `a cartridge's own-region texture comes before any scan, a disc's own-region scan before any texture, then the rest`() =
        runBlocking<Unit> {
            val kinds = Arb.element(ArtKind.Disc, gba)
            val gameRegions = Arb.element(ownImages.keys.toList())
            val imageRegions = Arb.element(ownImages.keys.toList() + "")
            // The images' regions lean on the game's own and their zones, so that images of its region are common.
            val images =
                Arb.list(gameRegions, 0..2).flatMap { regions ->
                    val own = regions.flatMap { ownImages.getValue(it) }
                    val near = if (own.isEmpty()) imageRegions else Arb.choice(imageRegions, Arb.element(own))
                    Arb.bind(Arb.list(near, 0..5), Arb.list(near, 0..5)) { scans, textures ->
                        Triple(regions, scans.mapIndexed { i, region -> web("https://lb/$i.png", region) }, textures.mapIndexed(::texture))
                    }
                }
            val serials = Arb.set(Arb.element("SCUS-97129", "SLPS-25358"), 0..2).map { it.map { s -> web("https://serial/$s.jpg") } }
            var staged = 0
            checkAll(kinds, images, serials) { kind, (regions, lb, ss), serial ->
                val ordered = ArtSources.order(kind, regions, lb, ss, serial)
                ordered shouldContainExactlyInAnyOrder lb + ss + serial
                val textureFirst = kind != ArtKind.Disc

                // The invariant's stages: the kind's first source of the game's region, its second, the serial scans, the rest.
                fun stage(candidate: Candidate): Int = when {
                    candidate in serial -> 2
                    regions.none { candidate.region in ownImages.getValue(it) } -> 3
                    (candidate is Candidate.Texture) == textureFirst -> 0
                    else -> 1
                }
                ordered.zipWithNext().forEach { (before, after) -> stage(before) shouldBeLessThanOrEqual stage(after) }
                if (ordered.map(::stage).distinct().size == 4) staged++
            }
            staged shouldBeGreaterThan 12
        }

    @Test
    fun `a game's images are every image of both sources among those offered, once per region and source, as tried`() {
        fun shown(variants: List<ArtVariant>) = variants.map { "${it.region.name} · ${it.candidate.source.label}" }
        val cartridge = sources(kind = gba, textures = table)
        shown(cartridge.variantsOf(okage) { true }) shouldBe
            listOf("North America · ScreenScraper", "North America · LaunchBox", "Japan · ScreenScraper", "Japan · LaunchBox")
        // Textures left out, as while ScreenScraper is not open: the scans alone, the serial source never.
        shown(cartridge.variantsOf(okage) { it is Candidate.Web }) shouldBe listOf("North America · LaunchBox", "Japan · LaunchBox")
        val disc = sources(bySerial = bySerial, textures = table)
        shown(disc.variantsOf(okage) { true }) shouldBe
            listOf("North America · LaunchBox", "North America · ScreenScraper", "Japan · LaunchBox", "Japan · ScreenScraper")
        // Two scans of one region at one source: the first alone.
        val twice = ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "USA=na2.png")))))
        names(sources(index = twice).variantsOf(okage) { true }.map { it.candidate }) shouldBe listOf("na.png")
        // A chosen label is looked for as its region's image at its source first.
        val texture = okage.copy(label = LabelChoice.Region(LabelRegion("Japan"), ArtSource.SCREENSCRAPER))
        names(disc.requestFor(texture).shouldBeSome().candidates) shouldBe
            listOf("ss:58:1234:support-texture(jp)", "na.png", "ss:58:1234:support-texture(us)", "SCUS-97129.jpg", "jp.png")
        names(disc.requestFor(okage.copy(label = LabelChoice.Region(LabelRegion("Japan")))).shouldBeSome().candidates).take(1) shouldBe
            listOf("jp.png")
    }

    @Test
    fun `INV-16 looking labels up again asks for each game a source may have art for, and never touches a label the user chose`() =
        runBlocking<Unit> {
            val sources = sources()
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
            own shouldBeGreaterThan 60
            region shouldBeGreaterThan 60
        }

    @Test
    fun `either chosen source moves only its image and an unavailable choice keeps every fallback`() = runBlocking<Unit> {
        val sources = sources(bySerial = bySerial, textures = table)
        val automatic = listOf("na.png", "ss:58:1234:support-texture(us)", "SCUS-97129.jpg", "jp.png", "ss:58:1234:support-texture(jp)")
        val cases =
            listOf(
                Triple(ArtSource.LAUNCHBOX, "North America", automatic),
                Triple(
                    ArtSource.SCREENSCRAPER,
                    "North America",
                    listOf("ss:58:1234:support-texture(us)", "na.png", "SCUS-97129.jpg", "jp.png", "ss:58:1234:support-texture(jp)"),
                ),
                Triple(
                    ArtSource.LAUNCHBOX,
                    "Japan",
                    listOf("jp.png", "na.png", "ss:58:1234:support-texture(us)", "SCUS-97129.jpg", "ss:58:1234:support-texture(jp)"),
                ),
                Triple(
                    ArtSource.SCREENSCRAPER,
                    "Japan",
                    listOf("ss:58:1234:support-texture(jp)", "na.png", "ss:58:1234:support-texture(us)", "SCUS-97129.jpg", "jp.png"),
                ),
                Triple(ArtSource.LAUNCHBOX, "Atlantis", automatic),
                Triple(ArtSource.SCREENSCRAPER, "Atlantis", automatic),
            )
        cases.forEach { (source, region, expected) ->
            names(
                sources.requestFor(okage.copy(label = LabelChoice.Region(LabelRegion(region), source))).shouldBeSome().candidates,
            ) shouldBe
                expected
        }
    }

    @Test
    fun `a preferred region orders the rest only when no single region is surely the game's, case by case`() {
        val na = web("https://lb/na.png", "North America")
        val us = web("https://lb/us.png", "USA")
        val eu = web("https://lb/eu.png", "Europe")
        val jp = web("https://lb/jp.png", "Japan")
        val br = web("https://lb/br.png", "Brazil")
        val fr = web("https://lb/fr.png", "France")
        val de = web("https://lb/de.png", "Germany")
        val disc = ArtKind.Disc

        fun order(regions: List<String>, scans: List<Candidate.Web>, preferred: PreferredRegion) =
            ArtSources.order(disc, regions, scans, emptyList(), emptyList(), Some(preferred))
        // No region of its own: France's zone first, then the others ranked.
        order(emptyList(), listOf(na, eu, jp), PreferredRegion.FRANCE) shouldBe listOf(eu, na, jp)
        ArtSources.order(disc, emptyList(), listOf(na, eu, jp), emptyList(), emptyList()) shouldBe listOf(na, eu, jp)
        // Two regions surely its own: its own images first, then the preferred one before a closer one.
        order(listOf("USA", "Europe"), listOf(us, eu), PreferredRegion.JAPAN) shouldBe listOf(us, eu)
        order(listOf("USA", "Europe"), listOf(us, eu, jp, br), PreferredRegion.JAPAN) shouldBe listOf(us, eu, jp, br)
        ArtSources.order(disc, listOf("USA", "Europe"), listOf(us, eu, jp, br), emptyList(), emptyList()) shouldBe listOf(us, eu, br, jp)
        // One region surely its own: the preference changes nothing.
        order(listOf("France"), listOf(fr, de, us, jp), PreferredRegion.JAPAN) shouldBe listOf(fr, de, us, jp)
        // The world or no region before any other region, after the preferred one and its zone.
        order(emptyList(), listOf(jp, web("https://lb/any.png"), eu, fr), PreferredRegion.FRANCE) shouldBe
            listOf(fr, eu, web("https://lb/any.png"), jp)
    }

    @Test
    fun `INV-16 a chosen region stays first and an own picture is never asked, whatever the preferred region`() {
        val japan = sources(textures = table).preferring(Some(PreferredRegion.JAPAN))
        val anywhere = okage.copy(regions = emptyList())
        names(japan.requestFor(anywhere).shouldBeSome().candidates) shouldBe
            listOf("jp.png", "ss:58:1234:support-texture(jp)", "na.png", "ss:58:1234:support-texture(us)")
        names(sources(textures = table).requestFor(anywhere).shouldBeSome().candidates) shouldBe
            listOf("na.png", "ss:58:1234:support-texture(us)", "jp.png", "ss:58:1234:support-texture(jp)")
        val chosen = anywhere.copy(label = LabelChoice.Region(LabelRegion("North America"), ArtSource.LAUNCHBOX))
        names(japan.requestFor(chosen).shouldBeSome().candidates).first() shouldBe "na.png"
        japan.requestFor(anywhere.copy(label = LabelChoice.Own)).shouldBeNone()
    }

    @Test
    fun `a change of the preferred region looks up again only the automatic labels whose first image changes`() {
        val plain = sources(textures = table)
        val japan = plain.preferring(Some(PreferredRegion.JAPAN))
        val anywhere = okage.copy(id = GameId("anywhere"), regions = emptyList())
        val games =
            listOf(
                anywhere,
                okage,
                anywhere.copy(id = GameId("chosen"), label = LabelChoice.Region(LabelRegion("North America"), ArtSource.LAUNCHBOX)),
                anywhere.copy(id = GameId("own"), label = LabelChoice.Own),
            )
        val any = { _: Candidate, _: Option<ArtVersion> -> true }
        ArtSources.reordered(games, { plain }, { japan }, any) shouldBe setOf(GameId("anywhere"))
        ArtSources.reordered(games, { japan }, { japan }, any).shouldBeEmpty()
        // Japan's images first change nothing when neither is ever tried (a texture remembered missing, the scan too here).
        val notJapan = { candidate: Candidate, _: Option<ArtVersion> -> candidate.region != "Japan" }
        ArtSources.reordered(games, { plain }, { japan }, notJapan).shouldBeEmpty()
    }
}
