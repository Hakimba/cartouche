// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.toOption
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContainAll
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.text.Normalizer

class ArtIndexTest {
    private val images = "https://images.launchbox-app.com/"

    private fun files(scans: List<ArtUrl>) = scans.map { it.value.removePrefix(images) }

    /** The index of scan `d<i>.png`. */
    private fun number(file: String) = file.removePrefix("d").removeSuffix(".png").toInt()

    private fun scans(games: List<ExtractGame>, title: String, regions: List<String> = emptyList()) =
        files(ArtIndex.parse(extract(games)).scansOf(title, regions))

    @Test
    fun `an extract's version is what its first line states after a hash, read without the rest`() = runBlocking<Unit> {
        val lines = Arb.element("# 2026-09-28", "#2026-10-01 ", "Okage\t\tUSA=o.png", "", "# ", "text")
        checkAll(Arb.list(lines, 0..4), Arb.element("\n", "\r\n", "\r")) { extract, newLine ->
            val text = extract.joinToString(newLine)
            val first = extract.firstOrNone().getOrElse { "" }
            val stated = if (first.startsWith("#")) Some(ArtVersion(first.removePrefix("#").trim())) else None
            ArtIndex.versionOf(text) shouldBe stated
            ArtIndex.parse(text).version shouldBe stated
        }
    }

    @Test
    fun `a game's scans come closest to its region first`() {
        val zone = ExtractGame("Zone of the Enders", emptySet(), listOf("North America=na.png", "Europe=eu.png", "Japan=jp.png"))
        scans(listOf(zone), "Zone of the Enders", listOf("Europe")) shouldContainExactly listOf("eu.png", "na.png", "jp.png")
        scans(listOf(zone), "Zone of the Enders", listOf("Japan")) shouldContainExactly listOf("jp.png", "na.png", "eu.png")
    }

    @Test
    fun `a game of the world shows a zone's own scan before its other countries'`() {
        val mario =
            ExtractGame(
                "Super Mario Bros.",
                setOf("Super Mario", "Super Mário"),
                listOf(
                    "Brazil=br.png",
                    "Canada=ca.png",
                    "Europe=eu.png",
                    "Germany=de.png",
                    "Italy=it.png",
                    "Japan=jp.png",
                    "North America=na.png",
                ),
            )
        scans(listOf(mario), "Super Mario Bros.", listOf("World")) shouldContainExactly
            listOf("na.png", "br.png", "ca.png", "eu.png", "de.png", "it.png", "jp.png")
    }

    @Test
    fun `a title is found by the game's name before its alternate names`() {
        val games =
            listOf(
                ExtractGame("Dark Cloud 2", setOf("Dark Chronicle"), listOf("Europe=g0.png")),
                ExtractGame("Dark Chronicle", emptySet(), listOf("Japan=g1.png")),
                ExtractGame("Okage: Shadow King", setOf("Okage"), listOf("=g2.png")),
            )
        scans(games, "Dark Chronicle", listOf("Europe")) shouldContainExactly listOf("g1.png")
        scans(games, "Okage") shouldContainExactly listOf("g2.png")
    }

    @Test
    fun `a title is found by its words kept apart before they are joined, so that a name of other words is not taken for it`() {
        val castles =
            listOf(
                ExtractGame("Castle Quest", emptySet(), listOf("Japan=cq.png")),
                ExtractGame("Castlequest", emptySet(), listOf("Japan=cql.png")),
            )
        scans(castles, "Castle Quest") shouldContainExactly listOf("cq.png")
        scans(castles, "Castlequest") shouldContainExactly listOf("cql.png")
        val fantasies =
            listOf(
                ExtractGame("Final Fantasy I•II", setOf("Final Fantasy I, II"), listOf("Japan=ff12.png")),
                ExtractGame("Final Fantasy III", emptySet(), listOf("Japan=ff3.png")),
            )
        scans(fantasies, "Final Fantasy I, II") shouldContainExactly listOf("ff12.png")
        scans(fantasies, "Final Fantasy III") shouldContainExactly listOf("ff3.png")
    }

    @Test
    fun `a title whose words are joined in a game's name finds it before another game's alternate name of those words apart`() {
        val games =
            listOf(
                ExtractGame("Venice Beach Volleyball", setOf("Volley Ball"), listOf("North America=venice.png")),
                ExtractGame("Volleyball", emptySet(), listOf("Japan=volleyball.png")),
            )
        scans(games, "Volley Ball", listOf("USA")) shouldContainExactly listOf("volleyball.png")
    }

    @Test
    fun `an alternate name written as the title and one of the game's countries finds its game first`() {
        val games =
            listOf(
                ExtractGame("Bomber Man GB", setOf("Bomberman GB (Japan)"), listOf("Japan=jp.png")),
                ExtractGame("Bomberman GB", setOf("Bomberman GB 2"), listOf("Japan=gb2.png")),
                ExtractGame("Wario Blast featuring Bomberman!", setOf("Bomberman GB"), listOf("North America=wario.png")),
            )
        scans(games, "Bomberman GB", listOf("Japan")) shouldContainExactly listOf("jp.png")
        scans(games, "Bomberman GB", listOf("USA", "Europe")) shouldContainExactly listOf("gb2.png")
    }

    @Test
    fun `an alternate name written as the title and a country decides for a game of that country only, under any of the country's names`() =
        runBlocking<Unit> {
            val countries =
                Arb.element(
                    "USA" to "United States",
                    "United States" to "North America",
                    "UK" to "United Kingdom",
                    "Japan" to "Japan",
                )
            checkAll(extracts, artTitles, countries) { extract, title, (written, game) ->
                val games = extract.map { it.copy(alternates = it.alternates.filterNot(regionalName::matches).toSet()) }
                val regional = ExtractGame("Regional", setOf("$title ($written)"), listOf("=regional.png"))
                val all = games + regional
                if (TitleKeys.dashed(title).isNotEmpty()) scans(all, title, listOf(game)) shouldContainExactly listOf("regional.png")
                scans(all, title, listOf("Atlantis")) shouldBe scans(games, title, listOf("Atlantis"))
            }
        }

    @Test
    fun `a demo is another game than the one it shows, and games named alike are told apart by their exact text only`() {
        val games =
            listOf(
                ExtractGame("Final Fantasy XII", emptySet(), listOf("Europe=full.png")),
                ExtractGame("Final Fantasy XII [Demo]", emptySet(), listOf("Europe=demo.png")),
                ExtractGame("Ghostbusters", emptySet(), emptyList()),
                ExtractGame("GhostBusters", emptySet(), listOf("Europe=g.png")),
            )
        scans(games, "Final Fantasy XII", listOf("France")) shouldContainExactly listOf("full.png")
        scans(games, "GhostBusters") shouldContainExactly listOf("g.png")
        scans(games, "Ghostbusters").shouldBeEmpty()
        scans(games, "GHOSTBUSTERS").shouldBeEmpty()
    }

    @Test
    fun `Chrono Trigger and Chrono Trigger+ are told apart by their punctuation`() {
        val games =
            listOf(
                ExtractGame("Chrono Trigger", setOf("Chrono Trigger: Kurono Torigaa"), listOf("Japan=jp.png", "North America=na.png")),
                ExtractGame("Chrono Trigger+", setOf("Chrono Trigger Plus"), listOf("World=plus.png")),
            )
        scans(games, "Chrono Trigger", listOf("USA")) shouldContainExactly listOf("na.png", "jp.png")
        scans(games, "CHRONO TRIGGER+") shouldContainExactly listOf("plus.png")
    }

    @Test
    fun `INV-E11-02 games a title names equally by their alternate names give no image, whichever has scans`() {
        val felix =
            listOf(
                ExtractGame("Felix the Cat (Dragon)", setOf("Felix the Cat", "Super Hero"), emptyList()),
                ExtractGame("Felix the Cat (Hudson)", setOf("Felix the Cat"), listOf("North America=hudson.png")),
            )
        scans(felix, "Felix the Cat", listOf("USA")).shouldBeEmpty()
    }

    @Test
    fun `INV-E4-01 a game only ever gets all the scans of one game its title names, and none when no game or several alike are named`() =
        runBlocking<Unit> {
            var found = 0
            var none = 0
            checkAll(extracts, artTitles, Arb.list(regionNames, 0..2)) { games, title, regions ->
                val scans = scans(games, title, regions)
                val regional = regionallyNamed(games, title, regions)
                val named =
                    games.filter { game ->
                        reduced(title).isNotEmpty() &&
                            (game in regional || (listOf(game.name) + game.alternates).any { reduced(it) == reduced(title) })
                    }
                owner(games, scans).onSome { game ->
                    scans.sorted() shouldBe game.discs.map { it.substringAfter('=') }.sorted()
                    (game in named) shouldBe true
                    found++
                }
                // Two games named by the title's very text are told apart by nothing, unless a country's name decides.
                if (named.isEmpty() || (regional.isEmpty() && games.count { it.name.trim() == title.trim() } > 1)) {
                    scans.shouldBeEmpty()
                    none++
                }
            }
            found shouldBeGreaterThan 100
            none shouldBeGreaterThan 100
        }

    @Test
    fun `a title naming one game by its main name, case, accents, punctuation and spaces aside, finds that game's scans`() =
        runBlocking<Unit> {
            var named = 0
            checkAll(extracts, artTitles, Arb.list(regionNames, 0..2)) { games, title, regions ->
                val byName = games.filter { reduced(title).isNotEmpty() && reduced(it.name) == reduced(title) }
                if (byName.size == 1 && regionallyNamed(games, title, regions).isEmpty()) {
                    scans(games, title, regions).sorted() shouldBe byName.single().discs.map { it.substringAfter('=') }.sorted()
                    named++
                }
            }
            named shouldBeGreaterThan 100
        }

    @Test
    fun `INV-E4-01 scans come closest region first, a zone's own name before its countries, then in the extract's order`() =
        runBlocking<Unit> {
            checkAll(Arb.list(regionNames, 1..6), Arb.list(regionNames, 0..2)) { discs, regions ->
                val lines = discs.mapIndexed { i, region -> "$region=d$i.png" }
                val scans = scans(listOf(ExtractGame("Okage", emptySet(), lines)), "Okage", regions)
                val own = scans.map { scan -> sameRegion(discs[number(scan)]) in regions.map(::sameRegion) }
                own shouldBe own.sortedDescending()
                scans.map(::number) shouldBe
                    discs.indices.sortedWith(compareBy({ closeness(regions, discs[it]) }, { sameRegion(discs[it]) !in umbrellas }))
            }
        }

    @Test
    fun `a game's images by region are one per region, its own first, each region under one name`() {
        val zone =
            ExtractGame(
                "Zone of the Enders",
                emptySet(),
                listOf("North America=na.png", "Europe=eu.png", "USA=us.png", "Japan=jp.png", "Europe=eu2.png"),
            )
        val variants = ArtIndex.parse(extract(listOf(zone))).variantsOf("Zone of the Enders", listOf("Europe"))
        variants.map { it.region.name to it.url.value.removePrefix(images) } shouldContainExactly
            listOf("Europe" to "eu.png", "North America" to "na.png", "Japan" to "jp.png")
    }

    @Test
    fun `INV-E7-03 a game's images by region are the first scan of each region of the game its title finds, the closest region's first`() =
        runBlocking<Unit> {
            var several = 0
            checkAll(extracts, artTitles, Arb.list(regionNames, 0..2)) { games, title, regions ->
                val index = ArtIndex.parse(extract(games))
                val variants = index.variantsOf(title, regions)
                val firsts =
                    owner(games, files(index.scansOf(title, regions))).fold({ emptyMap() }) { game ->
                        game.discs.reversed().associate { sameRegion(it.substringBefore('=')) to it.substringAfter('=') }
                    }
                variants.map { it.region }.distinct().size shouldBe variants.size
                variants.associate { it.region.name to files(listOf(it.url)).single() } shouldBe firsts
                variants.map { closeness(regions, it.region.name) }.let { it shouldBe it.sorted() }
                if (variants.size > 1) several++
            }
            several shouldBeGreaterThan 50
        }

    @Test
    fun `INV-E4-02 a title changed in case, accents, punctuation and spaces finds the same scans`() = runBlocking<Unit> {
        val games = listOf(ExtractGame("Dr. Muto: Evil Genius", emptySet(), listOf("Europe=g0.png")))
        checkAll(Arb.list(Arb.int(0..4), 1..30)) { changes ->
            val title =
                changes.foldIndexed("Dr. Muto: Evil Genius") { at, text, change ->
                    val i = at % (text.length + 1)
                    when (change) {
                        0 -> text.substring(0, i) + " " + text.substring(i)
                        1 -> text.substring(0, i) + "-" + text.substring(i)
                        2 -> text.uppercase()
                        3 -> text.lowercase()
                        else -> text.replace("u", "ú")
                    }
                }
            scans(games, title, listOf("Europe")) shouldContainExactly listOf("g0.png")
        }
        listOf("Chain Drive", "Dr Mutant", "").forEach { scans(games, it).shouldBeEmpty() }
    }

    @Test
    fun `INV-E11-02 several games a title names are told apart by the ladder, and none is taken when it does not leave one`() =
        runBlocking<Unit> {
            val spellings: List<(String) -> String> =
                listOf(
                    { it },
                    String::uppercase,
                    String::lowercase,
                    { it.replace(": ", " - ") },
                    { it.replace("é", "e") },
                    { "$it+" },
                    { "$it " },
                    { it.replace(" ", "") },
                )
            val spelled = Arb.element(spellings)
            // The games named so by their main names, or by an alternate name only, their main names naming another game.
            val samples =
                Arb.bind(
                    Arb.element("Dr. Muto: Evil Genius", "Pokémon Snap: Gold", "Chrono Trigger"),
                    spelled,
                    Arb.list(spelled, 2..4),
                    Arb.boolean(),
                ) { title, spelling, names, byAlternate ->
                    spelling(title) to
                        names.mapIndexed { i, name ->
                            val scans = listOf("=g$i-disc-0.png")
                            if (byAlternate) ExtractGame("Ys $i", setOf(name(title)), scans) else ExtractGame(name(title), setOf(), scans)
                        }
                }
            val told = mutableMapOf<Int, Int>()
            var none = 0
            var alternates = 0
            checkAll(samples) { (title, games) ->
                val named = { game: ExtractGame -> game.alternates.firstOrNone().getOrElse { game.name } }
                if (games.first().alternates.isNotEmpty()) alternates++
                // Each rung keeps the games still equal to the title at it and at every rung before it.
                val kept =
                    TitleKeys.ladder.indices.map { rung ->
                        games.filter { game -> TitleKeys.ladder.take(rung + 1).all { it(named(game)) == it(title) } }
                    }
                val alone = (listOf(games) + kept).firstOrNone { it.size <= 1 }.flatMap { it.firstOrNone() }
                owner(games, scans(games, title)) shouldBe alone
                alone.fold({ none++ }) { told.merge(kept.indexOfFirst { it.size <= 1 }, 1, Int::plus) }
            }
            told.keys shouldContainAll TitleKeys.ladder.indices.toList()
            told.values.forEach { it shouldBeGreaterThan 10 }
            none shouldBeGreaterThan 100
            alternates shouldBeGreaterThan 300
        }

    @Test
    fun `reading any text never fails, and keeps only well-formed lines`() = runBlocking<Unit> {
        val nearlyLines =
            Arb
                .list(
                    Arb.element("\t", "\n", "=", ";", "|", "#", " ", "a", "é", "x.png", "(", ")"),
                    0..60,
                ).map { it.joinToString("") }
        checkAll(Arb.choice(Arb.string(0..200), nearlyLines), Arb.string(0..40), Arb.list(regionNames, 0..2)) { text, title, regions ->
            ArtIndex.parse(text).scansOf(title, regions).forEach { it.value shouldStartWith images }
        }
        val index = ArtIndex.parse("# 2026-09-28\nno tabs here\nA\t\tEurope=a.png\n\t\tEurope=b.png\nB\t\t=;bad-pair\nC\t\t\textra\n")
        index.version shouldBe Some(ArtVersion("2026-09-28"))
        index.size shouldBe 2
        files(index.scansOf("A", emptyList())) shouldContainExactly listOf("a.png")
        index.scansOf("B", emptyList()).shouldBeEmpty()
        ArtIndex.parse("A\t\tEurope=a.png").version shouldBe None
    }

    @Test
    fun `every shipped extract is dated and reads whole`() {
        val extracts = Shipped.lists("art")
        extracts.keys shouldContainAll listOf(PlatformId("ps2"), PlatformId("gba"))
        extracts.values.forEach { text ->
            val index = ArtIndex.parse(text)
            index.version shouldBe Some(ArtVersion(text.lines().first().removePrefix("# ")))
            index.size shouldBe text.lines().count { it.isNotBlank() && !it.startsWith("#") }
            // The smallest complete extract, the GameCube's, has about 800 games: the floor only catches a truncated file.
            index.size shouldBeGreaterThan 500
        }
    }

    private val umbrellas = listOf("North America", "Europe", "Japan")

    /** The generators' regions by their group, in INV-E4-01's order: NTSC-U, PAL, NTSC-J. */
    private val groups: Map<String, Int> =
        listOf(
            listOf("North America", "Canada", "Brazil"),
            listOf("Europe", "France", "Germany", "United Kingdom", "Australia", "Oceania", "Netherlands"),
            listOf("Japan", "Korea", "Asia", "China"),
        ).flatMapIndexed { group, names -> names.map { it to group } }.toMap()

    /**
     * How close [image]'s region is to a game of [game]'s, written from INV-E4-01: its own region, its group's umbrella,
     * the rest of its group, the world, then NTSC-U, PAL, NTSC-J, then a region of no group.
     */
    private fun closeness(game: List<String>, image: String): Int {
        val region = sameRegion(image)
        val own = game.map(::sameRegion)
        val gameGroups = own.filter(groups::containsKey).map(groups::getValue)
        return when {
            region in own -> 0
            gameGroups.any { umbrellas[it] == region } -> 1
            region in groups && groups.getValue(region) in gameGroups -> 2
            region in setOf("World", "") -> 3
            region in groups -> 4 + groups.getValue(region)
            else -> 7
        }
    }

    private val regionalName = Regex("""(.*) \(([^()]+)\)""")

    /** The games an alternate name written `<title> (<one of [regions]>)` names. */
    private fun regionallyNamed(games: List<ExtractGame>, title: String, regions: List<String>): List<ExtractGame> = games.filter { game ->
        game.alternates.any { alternate ->
            regionalName.matchEntire(alternate).toOption().isSome { written ->
                val (named, country) = written.destructured
                TitleKeys.dashed(title).isNotEmpty() &&
                    TitleKeys.dashed(named) == TitleKeys.dashed(title) &&
                    sameRegion(country) in regions.map(::sameRegion)
            }
        }
    }

    /** The game whose scans [scans] are: each scan's file names its game (`g3-disc-1.png` is the fourth game's). */
    private fun owner(games: List<ExtractGame>, scans: List<String>): Option<ExtractGame> =
        scans.firstOrNone().map { games[it.removePrefix("g").substringBefore('-').toInt()] }

    /** A title as matching sees it at last: its Latin letters and digits, without accents or case. */
    private fun reduced(title: String): String = TitleKeys.dashed(title).replace(" ", "")

    /** The reductions the ladder puts back one at a time, written from their definition. */
    private object TitleKeys {
        private fun folded(title: String) = Normalizer.normalize(title, Normalizer.Form.NFKD).replace(Regex("""\p{M}+"""), "")

        private fun accented(title: String) = title.lowercase().replace(": ", " - ").replace(Regex("""\s+"""), " ").trim()

        fun dashed(title: String): String = folded(title)
            .lowercase()
            .map { if (it in 'a'..'z' || it in '0'..'9') it else ' ' }
            .joinToString("")
            .split(' ')
            .filter(String::isNotEmpty)
            .joinToString(" ")

        val ladder: List<(String) -> String> = listOf(::dashed, { accented(folded(it)) }, ::accented, String::trim)
    }
}
