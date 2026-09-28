// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.Shipped
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.singleOrNone
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.kotest.property.Arb
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

    @Test
    fun `a game's scans come closest to its region first`() {
        val zone = ExtractGame("Zone of the Enders", emptySet(), listOf("North America=na.png", "Europe=eu.png", "Japan=jp.png"))
        val index = ArtIndex.parse(extract(listOf(zone)))
        files(index.scansOf("Zone of the Enders", listOf("Europe"))) shouldContainExactly listOf("eu.png", "na.png", "jp.png")
        files(index.scansOf("Zone of the Enders", listOf("Japan"))) shouldContainExactly listOf("jp.png", "na.png", "eu.png")
    }

    @Test
    fun `a title is found by the game's name before its alternate names`() {
        val index =
            ArtIndex.parse(
                extract(
                    listOf(
                        ExtractGame("Dark Cloud 2", setOf("Dark Chronicle"), listOf("Europe=g0.png")),
                        ExtractGame("Dark Chronicle", emptySet(), listOf("Japan=g1.png")),
                        ExtractGame("Okage: Shadow King", setOf("Okage"), listOf("=g2.png")),
                    ),
                ),
            )
        files(index.scansOf("Dark Chronicle", listOf("Europe"))) shouldContainExactly listOf("g1.png")
        files(index.scansOf("Okage", emptyList())) shouldContainExactly listOf("g2.png")
    }

    @Test
    fun `a demo is another game than the one it shows, and a game without scans still makes its title ambiguous`() {
        val index =
            ArtIndex.parse(
                extract(
                    listOf(
                        ExtractGame("Final Fantasy XII", emptySet(), listOf("Europe=full.png")),
                        ExtractGame("Final Fantasy XII [Demo]", emptySet(), listOf("Europe=demo.png")),
                        ExtractGame("Ghostbusters", emptySet(), listOf("Europe=g.png")),
                        ExtractGame("GhostBusters", emptySet(), emptyList()),
                    ),
                ),
            )
        files(index.scansOf("Final Fantasy XII", listOf("France"))) shouldContainExactly listOf("full.png")
        index.scansOf("Ghostbusters", listOf("Europe")).shouldBeEmpty()
    }

    @Test
    fun `INV-E4-01 a game only ever gets the scans of the one game its title names`() = runBlocking<Unit> {
        var found = 0
        var ambiguous = 0
        checkAll(extracts, artTitles, Arb.list(regionNames, 0..2)) { games, title, regions ->
            val scans = files(ArtIndex.parse(extract(games)).scansOf(title, regions))
            named(games, title).fold({ scans.shouldBeEmpty() }) { game ->
                scans.sorted() shouldBe game.discs.map { it.substringAfter('=') }.sorted()
            }
            if (scans.isNotEmpty()) found++
            if (candidates(games, title).size > 1) ambiguous++
        }
        found shouldBeGreaterThan 100
        ambiguous shouldBeGreaterThan 50
    }

    @Test
    fun `INV-E4-01 a scan of the game's own region never comes after another's, and equally close ones keep the extract's order`() =
        runBlocking<Unit> {
            checkAll(Arb.list(regionNames, 1..6), Arb.list(regionNames, 0..2)) { discs, regions ->
                val lines = discs.mapIndexed { i, region -> "$region=d$i.png" }
                val scans = files(ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), lines)))).scansOf("Okage", regions))
                val own = scans.map { scan -> same(discs[number(scan)]) in regions.map(::same) }
                own shouldBe own.sortedDescending()
                scans.map(::number).zipWithNext().forEach { (first, second) ->
                    if (Regions.rank(regions, discs[first]) == Regions.rank(regions, discs[second])) (first < second) shouldBe true
                }
            }
        }

    @Test
    fun `INV-E4-02 a title changed in case, accents, punctuation and spaces finds the same scans`() = runBlocking<Unit> {
        val index = ArtIndex.parse(extract(listOf(ExtractGame("Dr. Muto: Evil Genius", emptySet(), listOf("Europe=g0.png")))))
        checkAll(Arb.list(Arb.int(0..4), 1..30)) { changes ->
            val title =
                changes.foldIndexed("Dr. Muto: Evil Genius") { at, text, change ->
                    val i = at % (text.length + 1)
                    when (change) {
                        0 -> text.substring(0, i) + " " + text.substring(i)
                        1 -> text.substring(0, i) + "-" + text.substring(i)
                        2 -> text.uppercase()
                        3 -> text.lowercase()
                        else -> text.replace("u", "ú")
                    }
                }
            files(index.scansOf(title, listOf("Europe"))) shouldContainExactly listOf("g0.png")
        }
        listOf("Chain Drive", "Dr Mutant", "").forEach { index.scansOf(it, emptyList()).shouldBeEmpty() }
    }

    @Test
    fun `INV-E4-02 a title that names several games gets none of their scans`() {
        val twice = listOf(ExtractGame("Okage", emptySet(), listOf("Japan=g0.png")), ExtractGame("OKAGE", emptySet(), listOf("USA=g1.png")))
        ArtIndex.parse(extract(twice)).scansOf("Okage", emptyList()).shouldBeEmpty()
        val alternates = listOf(ExtractGame("A", setOf("Okage"), listOf("=g0.png")), ExtractGame("B", setOf("Okage"), listOf("=g1.png")))
        ArtIndex.parse(extract(alternates)).scansOf("Okage", emptyList()).shouldBeEmpty()
    }

    @Test
    fun `reading any text never fails, and keeps only well-formed lines`() = runBlocking<Unit> {
        val nearlyLines = Arb.list(Arb.element("\t", "\n", "=", ";", "|", "#", " ", "a", "é", "x.png"), 0..60).map { it.joinToString("") }
        checkAll(Arb.choice(Arb.string(0..200), nearlyLines), Arb.string(0..40)) { text, title ->
            ArtIndex.parse(text).scansOf(title, emptyList()).forEach { it.value shouldStartWith images }
        }
        val index = ArtIndex.parse("# 2026-09-28\nno tabs here\nA\t\tEurope=a.png\n\t\tEurope=b.png\nB\t\t=;bad-pair\nC\t\t\textra\n")
        index.version shouldBe Some(ArtVersion("2026-09-28"))
        index.size shouldBe 2
        files(index.scansOf("A", emptyList())) shouldContainExactly listOf("a.png")
        index.scansOf("B", emptyList()).shouldBeEmpty()
        ArtIndex.parse("A\t\tEurope=a.png").version shouldBe None
    }

    @Test
    fun `the shipped PS2 extract is dated and reads whole`() {
        val text = Shipped.text("art/ps2.tsv")
        val index = ArtIndex.parse(text)
        index.version shouldBe Some(ArtVersion(text.lines().first().removePrefix("# ")))
        index.size shouldBe text.lines().count { it.isNotBlank() && !it.startsWith("#") }
        index.size shouldBeGreaterThan 4000
    }

    /** A region under the one name Redump and LaunchBox share for it. */
    private fun same(region: String) =
        mapOf("USA" to "North America", "United States" to "North America", "UK" to "United Kingdom").getOrElse(region) { region }

    /** What an extract's reader must find for [title]: the one game named so, else the one whose alternate name it is. */
    private fun named(games: List<ExtractGame>, title: String): Option<ExtractGame> = candidates(games, title).singleOrNone()

    /** A line without a name is no game. */
    private fun candidates(all: List<ExtractGame>, title: String): List<ExtractGame> {
        val key = reduced(title)
        val games = all.filter { it.name.isNotBlank() }
        if (key.isEmpty()) return emptyList()
        return games.filter { reduced(it.name) == key }.ifEmpty { games.filter { game -> game.alternates.any { reduced(it) == key } } }
    }

    /** A title as matching sees it: its Latin letters and digits, without accents or case. */
    private fun reduced(title: String): String = Normalizer
        .normalize(title, Normalizer.Form.NFKD)
        .replace(Regex("""\p{M}+"""), "")
        .lowercase()
        .filter { it in 'a'..'z' || it in '0'..'9' }
}
