// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import arrow.core.NonEmptyList
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.toNonEmptyListOrNone

/**
 * A disc as a reference list knows it: its exact name ([text], read as [name]) and its serials, such
 * as `SLES-53047`. The list files it by its title alone ([filing]): the whole name is read only once
 * a file could be the disc, a few of the list's thousands.
 */
public data class KnownTitle(public val text: String, public val serials: List<String>) {
    public val name: GameName by lazy { GameName.parse(text) }
    internal val filing: GameName.Filing = GameName.filing(text)
}

/** What a file name tells about the disc a file is. */
public sealed interface Identification {
    /** The reference name of the title, for its display. */
    public val title: GameName
    public val serials: List<String>

    /** The file is exactly [disc] of the reference list. */
    public data class Disc(public val disc: KnownTitle) : Identification {
        override val title: GameName get() = disc.name
        override val serials: List<String> get() = disc.serials
    }

    /** The file is one of several discs of a release (versions, languages) that all have [serials]. */
    public data class Release(override val title: GameName, val shared: NonEmptyList<String>) : Identification {
        override val serials: List<String> get() = shared
    }
}

/**
 * The discs of one platform's reference list (`app/data/redump`, one `name<TAB>serials` line per
 * disc), indexed by title so that a file name finds its disc without reading the file.
 */
public class TitleIndex private constructor(
    private val byTitle: Map<TitleKey, List<KnownTitle>>,
    private val byMainTitle: Map<TitleKey, List<KnownTitle>>,
) {
    public val size: Int get() = byTitle.values.sumOf { it.size }

    /**
     * The disc [file] is, when the reference list leaves no doubt. A disc can be the file when
     * nothing contradicts: same title and other tags (a demo or a beta is not the retail game), a
     * region in common, and no different languages, version or disc where both name them (a fan
     * translation `(Japan) (En) (v1.1)` still is the Japanese disc). The file is that very disc
     * when a single one has exactly its regions, languages and version; otherwise it is one disc of
     * a release, known by the serials all such discs share (two versions of a release often keep
     * one serial). When they share none, it is not identified: a wrong serial is worse than none. A
     * title given without its subtitle (`Dragon Quest V` for `Dragon Quest V - Tenkuu no Hanayome`)
     * still matches when a single title starts that way.
     */
    public fun identify(file: GameName): Option<Identification> {
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
                    it.name.versions == file.versions
            }
        if (exact.size == 1) return Some(Identification.Disc(exact.single()))
        val discs = exact.ifEmpty { possible }
        val common = discs.map { it.serials.toSet() }.fold(discs.flatMap { it.serials }.toSet(), Set<String>::intersect)
        return discs.firstOrNone().flatMap { first ->
            first.serials.filter(common::contains).toNonEmptyListOrNone().map { Identification.Release(first.name, it) }
        }
    }

    public companion object {
        public val EMPTY: TitleIndex = TitleIndex(emptyMap(), emptyMap())

        /** Reads a reference list; lines that are not `name<TAB>serials` are skipped. */
        public fun parse(text: String): TitleIndex {
            val titles = text.lines().map(::parseLine).filterOption()
            return TitleIndex(titles.groupBy { it.filing.key }, titles.groupBy { it.filing.mainKey })
        }

        private fun parseLine(line: String): Option<KnownTitle> = option {
            val fields = line.split('\t')
            ensure(fields.size == 2 && fields[0].isNotBlank())
            KnownTitle(fields[0], fields[1].split(',').filter(String::isNotBlank))
        }

        private fun List<KnownTitle>.preferring(closer: (KnownTitle) -> Boolean): List<KnownTitle> = filter(closer).ifEmpty { this }

        private fun oneTitle(titles: List<KnownTitle>): Boolean = titles.map { it.filing.key }.distinct().size == 1

        /** Whether nothing in [known]'s name contradicts [file]'s. */
        private fun canBe(file: GameName, known: GameName): Boolean =
            file.otherTags.map(String::lowercase).toSet() == known.otherTags.map(String::lowercase).toSet() &&
                (file.regions.isEmpty() || file.regions.any(known.regions::contains)) &&
                (file.languages.isEmpty() || known.languages.isEmpty() || file.languages == known.languages) &&
                (file.versions.containsAll(known.versions) || known.versions.containsAll(file.versions)) &&
                file.disc.fold({ true }) { known.disc == Some(it) }
    }
}
