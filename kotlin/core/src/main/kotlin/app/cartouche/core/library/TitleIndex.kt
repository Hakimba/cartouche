// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.files.FileFacts
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.toOption

/**
 * A disc as a reference list knows it: its exact name ([text], read as [name]) and its serials, such as `SLES-53047`.
 * The list files it by its title alone ([filing]): the whole name is read only once a file could be the disc, a few
 * of the list's thousands.
 */
public data class KnownTitle(public val text: String, public val serials: List<String>) {
    public val name: GameName by lazy { GameName.parse(text) }
    internal val filing: GameName.Filing = GameName.filing(text)
}

/** What a file's name or content tells about the disc it is. */
public sealed interface Identification {
    /** The reference name of the title, for its display. */
    public val title: GameName

    public val regions: List<String>
    public val serials: List<String>

    /** The file is exactly [disc] of the reference list. */
    public data class Disc(public val disc: KnownTitle) : Identification {
        override val title: GameName get() = disc.name
        override val regions: List<String> get() = disc.name.regions
        override val serials: List<String> get() = disc.serials
    }

    /**
     * The file is one of several discs of one game (versions, languages) that the list cannot tell apart: [serials]
     * are those they all have, [regions] the file name's when found by its name, or those they all have when found by
     * its content. Found by its name, it always has [serials].
     */
    public data class Release(override val title: GameName, override val regions: List<String>, override val serials: List<String>) :
        Identification
}

/**
 * The discs of one platform's reference list (`app/data/titles`, one `name<TAB>serials` line per
 * disc), indexed by title so that a file name finds its disc without reading the file, and by
 * serial and cartridge print (`app/data/prints`, one `name<TAB>CRC32` line per ROM) so that what a
 * file holds finds it whatever its name.
 */
public class TitleIndex private constructor(
    private val titles: List<KnownTitle>,
    private val byText: Map<String, KnownTitle>,
    private val byPrint: Map<UInt, List<KnownTitle>>,
) {
    private val byTitle = titles.groupBy { it.filing.key }
    private val byMainTitle = titles.groupBy { it.filing.mainKey }
    private val bySerial = indexed { known -> known.serials.map(::serialKey) }
    private val byDiscId = indexed { known -> known.serials.map { discIdOf(it) }.filterOption() }

    public val size: Int get() = titles.size

    /**
     * The disc a file named [text] (without its extension) is: the entry written exactly so, else the one its name
     * designates ([judge]).
     */
    public fun identifyByName(text: String): Option<Identification> =
        byText.getOrNone(text).fold({ judge(GameName.parse(text)) }) { Some(Identification.Disc(it)) }

    /**
     * The disc or cartridge that [facts] name, whatever [file]'s name says. Versions sharing them are
     * told apart by the one written like the name (same reduced title, same tags), then by the name's
     * countries; several versions of one game left are a release, with the countries and serials they
     * all have. Nothing when the list knows no version with them, or when several games do.
     */
    public fun identifyByContent(facts: FileFacts, file: GameName): Option<Identification> {
        val kept =
            versionsOf(facts)
                .preferring { it.name.written == file.written }
                .preferring { it.name.regions.any(file.regions::contains) }
        if (kept.size == 1) return Some(Identification.Disc(kept.single()))
        return kept.firstOrNone().filter { first -> kept.all { it.name.displayTitle == first.name.displayTitle } }.map { first ->
            Identification.Release(first.name, first.name.regions.filter { region -> kept.all { region in it.name.regions } }, shared(kept))
        }
    }

    /**
     * The disc [file] is, when the reference list leaves no doubt. A disc can be the file when
     * nothing contradicts: same title and other tags (a demo or a beta is not the retail game), a
     * region in common, and no different languages, version or disc where both name them (a fan
     * translation `(Japan) (En) (v1.1)` still is the Japanese disc). The file is that very disc
     * when a single one has exactly its regions, languages, version and disc; otherwise it is one
     * disc of a release, known by the serials all such discs share (two versions of a release often
     * keep one serial). When they share none, it is not identified: a wrong serial is worse than
     * none. A title given without its subtitle (`Dragon Quest V` for `Dragon Quest V - Tenkuu no
     * Hanayome`) still matches when a single title starts that way.
     */
    internal fun judge(file: GameName): Option<Identification> {
        val sameTitle = byTitle.getOrElse(file.key) { byMainTitle.getOrNone(file.key).filter(::oneTitle).getOrElse { emptyList() } }
        // Discs that name the file's version or languages are closer than discs that name none.
        val possible =
            sameTitle
                .filter { canBe(file, it.name) }
                .preferring { file.versions.isNotEmpty() && it.name.versions.isNotEmpty() }
                .preferring { file.languages.isNotEmpty() && it.name.languages.isNotEmpty() }
        val exact =
            possible.filter {
                it.name.regions == file.regions &&
                    it.name.languages == file.languages &&
                    it.name.versions == file.versions &&
                    it.name.disc == file.disc
            }
        if (exact.size == 1) return Some(Identification.Disc(exact.single()))
        val discs = exact.ifEmpty { possible }
        return discs.firstOrNone().flatMap { first ->
            Some(shared(discs)).filter(List<String>::isNotEmpty).map { Identification.Release(first.name, file.regions, it) }
        }
    }

    private fun versionsOf(facts: FileFacts): List<KnownTitle> = when (facts) {
        is FileFacts.Serial -> bySerial.getOrElse(facts.key) { byDiscId.getOrElse(facts.key.take(GAME_CODE)) { emptyList() } }
        is FileFacts.Print -> byPrint.getOrElse(facts.crc32) { emptyList() }
        FileFacts.Silent -> emptyList()
    }

    private fun indexed(keys: (KnownTitle) -> List<String>): Map<String, List<KnownTitle>> =
        titles.flatMap { known -> keys(known).distinct().map { it to known } }.groupBy({ it.first }, { it.second })

    public companion object {
        public val EMPTY: TitleIndex = parse("")

        // A GameCube or Wii disc holds its game ID (`GKYP01`); the lists write its game code in their serials.
        private const val GAME_CODE = 4
        private val DISC_ID = Regex("""^(?:DL-DOL|RVL)-([^-]+)""")

        /**
         * Reads a reference list and its cartridges' prints; lines that are not `name<TAB>serials`, or
         * `name<TAB>CRC32` of a listed name, are skipped.
         */
        public fun parse(titles: String, prints: String = ""): TitleIndex {
            val known = titles.lines().map(::parseLine).filterOption()
            val byText = known.associateBy(KnownTitle::text)
            val byPrint = prints.lines().map { parsePrint(it, byText) }.filterOption().groupBy({ it.first }, { it.second })
            return TitleIndex(known, byText, byPrint)
        }

        private fun parseLine(line: String): Option<KnownTitle> = option {
            val fields = line.split('\t')
            ensure(fields.size == 2 && fields[0].isNotBlank())
            KnownTitle(fields[0], fields[1].split(',').filter(String::isNotBlank))
        }

        private fun parsePrint(line: String, byText: Map<String, KnownTitle>): Option<Pair<UInt, KnownTitle>> = option {
            val fields = line.split('\t')
            ensure(fields.size == 2)
            fields[1].toUIntOrNull(16).toOption().bind() to byText.getOrNone(fields[0]).bind()
        }

        /** How serials compare: `SLES-52495`, `SLES---52495` and the disc's `SLES_524.95` are one. */
        private fun serialKey(serial: String): String = FileFacts.Serial(serial).key

        private fun discIdOf(serial: String): Option<String> = DISC_ID.find(serial).toOption().map { serialKey(it.groupValues[1]) }

        private fun shared(discs: List<KnownTitle>): List<String> {
            val common = discs.map { it.serials.toSet() }.fold(discs.flatMap { it.serials }.toSet(), Set<String>::intersect)
            return discs.firstOrNone().fold({ emptyList() }) { first -> first.serials.filter(common::contains) }
        }

        /** What tells a name's version apart: its reduced title and every tag, other tags in any case. */
        private val GameName.written: GameName
            get() = copy(title = key.value, otherTags = otherTags.map(String::lowercase).distinct().sorted())

        private fun List<KnownTitle>.preferring(closer: (KnownTitle) -> Boolean): List<KnownTitle> = filter(closer).ifEmpty { this }

        private fun oneTitle(titles: List<KnownTitle>): Boolean = titles.map { it.filing.key }.distinct().size == 1

        private fun canBe(file: GameName, known: GameName): Boolean =
            file.otherTags.map(String::lowercase).toSet() == known.otherTags.map(String::lowercase).toSet() &&
                (file.regions.isEmpty() || file.regions.any(known.regions::contains)) &&
                (file.languages.isEmpty() || known.languages.isEmpty() || file.languages == known.languages) &&
                (file.versions.containsAll(known.versions) || known.versions.containsAll(file.versions)) &&
                file.disc.fold({ true }) { known.disc == Some(it) }
    }
}
