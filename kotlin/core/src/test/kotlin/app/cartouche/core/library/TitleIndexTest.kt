// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import app.cartouche.core.files.FileFacts
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Test

class TitleIndexTest {
    private val ps2Text = Shipped.text("titles/ps2.tsv")
    private val ps2 = Shipped.ps2Titles

    private fun identify(fileName: String) = ps2.identifyByName(fileName)

    private fun titles(platform: String) = TitleIndex.parse(Shipped.text("titles/$platform.tsv"))

    private fun TitleIndex.read(facts: FileFacts, fileName: String) = identifyByContent(facts, GameName.parse(fileName))

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
    fun `every shipped list writes each entry once, so a name written as one finds only it`() {
        Shipped.lists("titles").values.forEach { text ->
            val names = text.lines().filter(String::isNotBlank).map { it.substringBefore('\t') }
            names.distinct().size shouldBe names.size
        }
    }

    @Test
    fun `a name written exactly as an entry is that entry, even among entries its title alone cannot tell apart`() {
        val psx = titles("psx")
        psx.identifyByName("Street Fighter Zero 2' (Japan)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.serials shouldBe
            listOf("SLPS-91105")
        // Read for its title and tags, the name also fits `Street Fighter Zero 2 (Japan)`, without the apostrophe.
        psx.judge(GameName.parse("Street Fighter Zero 2' (Japan)")) shouldBe None
    }

    @Test
    fun `a disc's serial finds its entry whatever the file is named, written with any dashes, dots or underscores`() {
        ps2
            .read(FileFacts.Serial("SLES_524.95"), "Bujingai - Swordmaster (EU)")
            .shouldBeSome()
            .shouldBeInstanceOf<Identification.Disc>()
            .disc.text shouldBe "Bujingai - Swordmaster (Europe) (En,Fr,De,Es,It)"
        // The list writes `SLES---54355`.
        ps2.read(FileFacts.Serial("SLES_543.55"), "ff12").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Final Fantasy XII (France)"
        // The name says another disc: what the file holds wins.
        titles("psx")
            .read(FileFacts.Serial("SLPS_911.05"), "Street Fighter Zero 2 (Japan)")
            .shouldBeSome()
            .shouldBeInstanceOf<Identification.Disc>()
            .disc.text shouldBe "Street Fighter Zero 2' (Japan)"
    }

    @Test
    fun `GameCube and Wii discs are found by the game code of their ID`() {
        titles("gc").read(FileFacts.Serial("GKYP01"), "kirby").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Kirby Air Ride (Europe) (En,Fr,De,Es,It)"
        titles("wii").read(FileFacts.Serial("R4CJ01"), "SimCity Creator").shouldBeSome().title.regions shouldBe listOf("Japan")
    }

    @Test
    fun `versions sharing a serial are told apart by the one written like the name, then by the name's country`() {
        val psx = titles("psx")
        val zero2 = FileFacts.Serial("SLPS_004.15")
        psx.read(zero2, "Street Fighter Zero 2 (Japan) (Rev 1)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Street Fighter Zero 2 (Japan) (Rev 1)"
        // Case, accents and punctuation aside, with the same tags.
        psx.read(zero2, "STREET FIGHTER ZERO-2 (Japan)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "Street Fighter Zero 2 (Japan)"
        val wii = titles("wii")
        val simCity = FileFacts.Serial("R4CP01")
        wii.read(simCity, "SimCity Creator (Europe)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "SimCity Creator (Europe) (En,Fr,De,Es,It,Nl)"
        wii.read(simCity, "SimCity Creator (Australia)").shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe
            "SimCity Creator (Australia) (En,Fr,De,Es,It,Nl) (Rev 1)"
    }

    @Test
    fun `versions of one game still not told apart give its title, with the countries and serials they all have`() {
        ps2.read(FileFacts.Serial("SLES_541.88"), "Nickelodeon Avatar - The Legend of Aang (Europe) (En,Fr,De,Nl)").shouldBeSome() shouldBe
            Identification.Release(
                GameName.parse("Nickelodeon Avatar - The Legend of Aang (Europe) (En,Fr,De,Nl) (v1.00)"),
                listOf("Europe"),
                listOf("SLES-54188"),
            )
        // Europe and Australia: no country nor serial in common.
        titles("wii").read(FileFacts.Serial("R4CP01"), "sim").shouldBeSome().shouldBeInstanceOf<Identification.Release>().let {
            (it.title.displayTitle to it.regions + it.serials) shouldBe ("SimCity Creator" to emptyList<String>())
        }
        titles("psx").read(FileFacts.Serial("SLPS_004.15"), "sf").shouldBeSome() shouldBe
            Identification.Release(GameName.parse("Street Fighter Zero 2 (Japan)"), listOf("Japan"), listOf("SLPS-00415"))
    }

    @Test
    fun `content that names several games, or none of the list, or nothing, identifies nothing`() {
        // Crazy Taxi and an Xploder disc share SLES-50215, both from Europe.
        ps2.read(FileFacts.Serial("SLES_502.15"), "Crazy Taxi (Europe)") shouldBe None
        ps2.read(FileFacts.Serial("SLES_999.99"), "Bujingai - Swordmaster (Europe) (En,Fr,De,Es,It)") shouldBe None
        ps2.read(FileFacts.Print(0x03048DE6u), "Bujingai - Swordmaster (Europe) (En,Fr,De,Es,It)") shouldBe None
        ps2.read(FileFacts.Silent, "Bujingai - Swordmaster (Europe) (En,Fr,De,Es,It)") shouldBe None
    }

    @Test
    fun `every cartridge print shipped finds the entry it was listed for`() {
        Shipped.lists("prints").keys.map { it.value }.toSet() shouldBe setOf("nes", "snes", "n64", "gb", "gbc", "gba")
        Shipped.lists("prints").forEach { (platform, prints) ->
            val index = TitleIndex.parse(Shipped.text("titles/${platform.value}.tsv"), prints)
            prints.lines().filter(String::isNotBlank).forEach { line ->
                val (name, crc) = line.split('\t')
                index
                    .read(FileFacts.Print(crc.toUInt(16)), "some file")
                    .shouldBeSome()
                    .shouldBeInstanceOf<Identification.Disc>()
                    .disc.text shouldBe name
            }
        }
        TitleIndex
            .parse(Shipped.text("titles/n64.tsv"), Shipped.text("prints/n64.tsv"))
            .read(FileFacts.Print(0x03048DE6u), "sm64")
            .shouldBeSome()
            .title.displayTitle shouldBe "Super Mario 64"
    }

    @Test
    fun `a zip's print of a ROM as dumped, with its iNES header or byte-swapped, finds its entry`() {
        TitleIndex
            .parse(Shipped.text("titles/nes.tsv"), Shipped.text("prints/nes.tsv"))
            .read(FileFacts.Print(0x393A432Fu), "smb.zip")
            .shouldBeSome()
            .shouldBeInstanceOf<Identification.Disc>()
            .disc.text shouldBe "Super Mario Bros. (World)"
        TitleIndex
            .parse(Shipped.text("titles/n64.tsv"), Shipped.text("prints/n64.tsv"))
            .read(FileFacts.Print(0x11FB579Bu), "sm64.zip")
            .shouldBeSome()
            .shouldBeInstanceOf<Identification.Disc>()
            .disc.text shouldBe "Super Mario 64 (Europe) (En,Fr,De)"
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
    fun `INV-10 a reference name is identified as itself, and never as another edition, region or disc`() {
        known.forEach { reference ->
            identify(reference.text).shouldBeSome().shouldBeInstanceOf<Identification.Disc>().disc.text shouldBe reference.text
            // Its title in capitals, it is no longer written as the entry: read for its title and tags, it keeps them.
            val title = reference.text.substringBefore(" (")
            val capitals = title.uppercase() + reference.text.removePrefix(title)
            identify(capitals).onSome { found ->
                when (found) {
                    is Identification.Disc ->
                        found.disc.name.let { listOf(it.regions, it.languages, it.versions, it.disc) } shouldBe
                            reference.name.let { listOf(it.regions, it.languages, it.versions, it.disc) }
                    is Identification.Release -> reference.serials.containsAll(found.serials) shouldBe true
                }
            }
            listOf(" (Beta)", " (Taikenban)", " (Korea)", " (Brazil)", " (Disc 3)", " (v9.99)", " (Xx)").forEach { edit ->
                val file = GameName.parse(reference.text + edit)
                identify(reference.text + edit).onSome { found ->
                    // An added version or languages tag is never an exact disc.
                    if (edit == " (v9.99)" || edit == " (Xx)") (found is Identification.Disc) shouldBe false
                    found.title.otherTags.map(String::lowercase).toSet() shouldBe file.otherTags.map(String::lowercase).toSet()
                    if (file.regions.isNotEmpty()) found.title.regions.any(file.regions::contains) shouldBe true
                    file.disc.onSome { found.title.disc shouldBe Some(it) }
                }
            }
        }
    }

    private fun serials(line: String) = line.substringAfter('\t').split(',').filter(String::isNotBlank)
}
