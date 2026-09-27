// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Test

class TitleIndexTest {
    private val ps2Text = Shipped.text("redump/ps2.tsv")
    private val ps2 = Shipped.ps2Titles

    private fun identify(fileName: String) = ps2.identify(GameName.parse(fileName))

    @Test
    fun `the shipped PS2 list parses whole`() {
        ps2.size shouldBe ps2Text.lines().count { it.isNotBlank() }
        ps2.size shouldBeGreaterThan 10_000
    }

    @Test
    fun `file names find their disc, preferring the same region and version`() {
        identify("Punisher, The (Europe) (En,Fr)").shouldBeSome().serials shouldBe listOf("SLES-53047")
        identify("The Punisher (Europe) (En,Fr)").shouldBeSome().serials shouldBe listOf("SLES-53047")
        identify("The Punisher (USA)").shouldBeSome().serials shouldBe listOf("SLUS-20864")
        identify("Bleach - Blade Battlers (Japan)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Bleach - Blade Battlers (Japan)"
        identify("Urban Reign (EU)").shouldBeSome().title.regions shouldBe listOf("Europe")
        identify("0 Story (Japan) (Disc 2)").shouldBeSome().serials shouldBe listOf("SLPM-65003")
    }

    @Test
    fun `a title without its subtitle matches only when a single title starts that way`() {
        identify("Dragon Quest V (Japan) (En) (v1.2)").shouldBeSome().title.title shouldBe "Dragon Quest V - Tenkuu no Hanayome"
        identify("Bleach (Japan)") shouldBe None
    }

    @Test
    fun `demos, betas and other regions only match their own discs, ambiguous names none`() {
        identify("Katamari Damacy (Japan) (v2.00)").shouldBeSome().serials shouldBe listOf("SLPS-25360", "SLPS-73210", "SLPS-73240")
        identify("Ico (Japan) (Taikenban)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Ico (Japan) (Taikenban)"
        identify("We Love Katamari (Europe)").shouldBeSome().title.otherTags shouldBe emptyList()
        // No Europe release, no region at all.
        identify("Katamari Damacy (Europe)") shouldBe None
        identify("Grand Theft Auto - Vice City") shouldBe None
        // Several discs fit and share no serial (other languages): the file does not say which it is.
        identify("Burnout 3 - Takedown (Europe)") shouldBe None
        identify("Call of Duty - Finest Hour (Europe)") shouldBe None
    }

    @Test
    fun `versions of one release are identified by the serial they share`() {
        identify("Katamari Damacy (Japan)").shouldBeSome().serials shouldBe listOf("SLPS-25360")
        identify("Gran Turismo 4 (USA)").shouldBeSome().serials shouldBe listOf("SCUS-97328")
        identify("Nickelodeon Avatar - The Legend of Aang (Europe) (En,Fr,De,Nl)").shouldBeSome().serials shouldBe listOf("SLES-54188")
    }

    @Test
    fun `a patched dump naming its original version keeps that version's serial`() {
        identify("Real World Golf (Europe) (v1.01) (v1.1)").shouldBeSome().shouldBeInstanceOf<Identification.Release>().serials shouldBe
            listOf("SLES-53371")
        // The only disc with two version tags is `(USA) (v3.00) (Rev 1)`: naming one of them is enough.
        listOf("(USA) (v3.00)", "(Rev 1)", "(USA) (Rev 1)").forEach { tags ->
            identify("Grand Theft Auto - San Andreas $tags").shouldBeSome().serials shouldBe listOf("SLUS-20946P3")
        }
    }

    @Test
    fun `discs naming the file's languages win over discs naming none`() {
        identify("007 - Quantum of Solace (En,Fr)").shouldBeSome().serials shouldBe listOf("SLUS-21813")
        identify("007 - Quantum of Solace (Europe) (En,Fr)") shouldBe None
    }

    @Test
    fun `fan translations are the original disc`() {
        identify("Berserk - Millennium Falcon-hen - Seima Senki no Shou (Japan) (En) (v1.1)").shouldBeSome().serials shouldBe
            listOf("SLPM-65688")
    }

    // These properties go through every reference name: the rare cases (two version tags) are the ones that matter.
    private val known = ps2Text.lines().filter { it.isNotBlank() }.map { KnownTitle(it.substringBefore('\t'), serials(it)) }

    @Test
    fun `INV-E1-04 a reference name is identified as itself, and never as another edition, region or disc`() {
        known.forEach { reference ->
            ps2.identify(reference.name).shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe reference.text
            listOf(" (Beta)", " (Taikenban)", " (Korea)", " (Brazil)", " (Disc 3)", " (v9.99)", " (Xx)").forEach { edit ->
                val file = GameName.parse(reference.text + edit)
                ps2.identify(file).onSome { found ->
                    // An added version or languages tag is never an exact disc.
                    if (edit == " (v9.99)" || edit == " (Xx)") (found is Identification.Disc) shouldBe false
                    found.title.otherTags.map(String::lowercase).toSet() shouldBe file.otherTags.map(String::lowercase).toSet()
                    if (file.regions.isNotEmpty()) found.title.regions.any(file.regions::contains) shouldBe true
                    file.disc.onSome { found.title.disc shouldBe Some(it) }
                }
            }
        }
    }

    @Test
    fun `INV-E1-04 a name that leaves out a tag never gets a serial the full name's disc lacks`() {
        known.forEach { reference ->
            // Only tags whose absence makes the name less precise; without `(Beta)`, it names another disc.
            val precision =
                Regex("""\s*\([^()]*\)""").findAll(reference.text).map { it.value }.filter { tag ->
                    tag.trim().removeSurrounding("(", ")").let { it !in reference.name.otherTags && !it.startsWith("Disc") }
                }
            precision.forEach { tag ->
                val file = GameName.parse(reference.text.replace(tag, ""))
                ps2.identify(file).onSome { found ->
                    when (found) {
                        // The file could be the reference disc: another disc only when it matches the name exactly.
                        is Identification.Disc ->
                            listOf(found.disc.name.regions, found.disc.name.languages, found.disc.name.versions) shouldBe
                                listOf(file.regions, file.languages, file.versions)
                        is Identification.Release -> reference.serials.containsAll(found.serials) shouldBe true
                    }
                }
            }
        }
    }

    @Test
    fun `INV-E1-04 a name stating another disc's languages or version never gets a disc contradicting it`() {
        known.groupBy { it.name.key }.values.forEach { discs ->
            discs.forEach { reference ->
                discs.filter { it != reference }.forEach { other ->
                    // The reference's name with the other disc's languages, then with its versions.
                    val renamed =
                        listOf(
                            reference.name.copy(languages = other.name.languages),
                            reference.name.copy(versions = other.name.versions),
                        )
                    renamed.forEach { file ->
                        ps2.identify(file).onSome { found ->
                            val title = found.title
                            (file.languages.isEmpty() || title.languages.isEmpty() || title.languages == file.languages) shouldBe true
                            (file.versions.containsAll(title.versions) || title.versions.containsAll(file.versions)) shouldBe true
                        }
                    }
                }
            }
        }
    }

    private fun serials(line: String) = line.substringAfter('\t').split(',').filter(String::isNotBlank)
}
