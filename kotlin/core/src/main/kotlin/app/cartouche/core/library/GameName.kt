// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.intOrNone
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.option
import arrow.core.toOption
import java.text.Normalizer

/**
 * A game name read the Redump and No-Intro way, `Title (Region) (Languages) (Version) (Disc 2)`, as ROM sets and
 * Redump lists write them. Tags in parentheses or brackets are classified; the title is what remains.
 */
public data class GameName(
    public val title: String,
    public val regions: List<String>,
    public val languages: List<String>,
    /** Every version tag, in order: a patched dump may name its original version and the patch's. */
    public val versions: List<String>,
    public val disc: Option<Int>,
    /** Tags that are none of the above, such as `Beta` or `Special Edition`. */
    public val otherTags: List<String>,
) {
    /** The version tags as one text, such as `v1.02 Rev 1`; none without any. */
    public val version: Option<String> get() = Some(versions.joinToString(" ")).filter(String::isNotEmpty)

    /** The title as players read it: `The Punisher` rather than Redump's `Punisher, The`. */
    public val displayTitle: String get() = displayed(title)

    /** The title reduced for matching: no articles moved, accents, case or punctuation. */
    public val key: TitleKey get() = TitleKey.of(displayTitle)

    /** The key of the title before its first ` - `, or none when it has no subtitle. */
    public val mainKey: Option<TitleKey> get() = mainKeyOf(displayTitle)

    /** Where a reference list files a name: under its [key], and its [mainKey] or else its key. */
    internal data class Filing(val key: TitleKey, val mainKey: TitleKey)

    public companion object {
        /** Reads a file name without its extension, or a Redump name. Total: any text gives a name. */
        public fun parse(text: String): GameName {
            val tags = TAG.findAll(text).map { it.groupValues[1].trim() }.toList()
            // A second languages tag is not the disc's languages: it stays among the other tags.
            val languageTag = tags.firstOrNone(LANGUAGES::matches)
            return GameName(
                title = titleOf(text),
                regions = tags.flatMap(::regionsOf).distinct(),
                languages = languageTag.fold({ emptyList() }) { it.split(',').map(String::trim) },
                versions = tags.filter(VERSION::matches),
                disc = tags.flatMap { discOf(it).toList() }.firstOrNone(),
                otherTags =
                    tags.filterNot {
                        regionsOf(it).isNotEmpty() ||
                            VERSION.matches(it) ||
                            discOf(it).isSome() ||
                            languageTag == Some(it)
                    },
            )
        }

        /** Where [text], read as a name, is filed: from its title alone, its tags left unclassified. */
        internal fun filing(text: String): Filing {
            val shown = displayed(titleOf(text))
            val key = TitleKey.of(shown)
            return Filing(key, mainKeyOf(shown).getOrElse { key })
        }

        private const val SUBTITLE = " - "

        // One level of nested parentheses, as in `(Multi Tap (SCPH-10090) Doukonban)`.
        private val TAG = Regex("""\s*[(\[]((?:[^()\[\]]|\([^()]*\))*)[)\]]""")
        private val SPACES = Regex("""\s+""")
        private val LANGUAGES = Regex("""[A-Z][a-z](-[A-Z][a-z]+)?(\s?,\s?[A-Z][a-z](-[A-Z][a-z]+)?)*""")
        private val VERSION = Regex("""(?i)v\s?\d[\w.]*|rev\s+[\w.]+""")
        private val DISC = Regex("""(?i)(?:disc|disk|cd)\s*(\d+)(?:\s+of\s+\d+)?""")
        private val ARTICLE = Regex("""^(.*), (The|A|An)$""")

        /**
         * ScreenScraper's regions (`regionsListe.php` short names) under the app's names (see `Regions`): the
         * American continent is the zone North America stands for; the codes of [SKIPPED_CODES] are not regions.
         */
        private val REGIONS: Map<String, String> =
            """Asia, Australia, Austria, Belgium, Brazil, Canada, China, Croatia, Denmark, Europe, Finland, France, Germany, Greece,
            Hong Kong, India, Ireland, Italy, Japan, Korea, Latin America, Mexico, Netherlands, New Zealand, Norway, Poland, Portugal,
            Russia, Scandinavia, South Africa, Spain, Sweden, Switzerland, Taiwan, UK, USA, World""".split(',')
                .map(String::trim)
                .associateBy { it.lowercase() } +
                mapOf("eu" to "Europe", "eur" to "Europe", "us" to "USA", "jp" to "Japan", "jpn" to "Japan")

        private fun regionsOf(tag: String): List<String> =
            option { tag.split(',').map { REGIONS.getOrNone(it.trim().lowercase()).bind() } }.getOrElse { emptyList() }

        private fun titleOf(text: String): String = withoutTags(text).replace(SPACES, " ").trim().ifEmpty { text.trim() }

        private fun displayed(title: String): String = title.split(SUBTITLE).joinToString(SUBTITLE, transform = ::uninvertArticle)

        private fun mainKeyOf(shown: String): Option<TitleKey> =
            Some(shown.split(SUBTITLE)).filter { it.size > 1 }.map { TitleKey.of(it.first()) }

        private tailrec fun withoutTags(text: String): String {
            val stripped = TAG.replace(text, "")
            return if (stripped == text) text else withoutTags(stripped)
        }

        private fun discOf(tag: String): Option<Int> = DISC.matchEntire(tag).toOption().flatMap { it.groupValues[1].intOrNone() }

        private fun uninvertArticle(part: String): String =
            ARTICLE.matchEntire(part).toOption().fold({ part }) { "${it.groupValues[2]} ${it.groupValues[1]}" }
    }
}

/** A title reduced for matching, so that `Dr. Muto`, `Dr Muto` and `DR. MUTO` meet. */
@JvmInline public value class TitleKey private constructor(public val value: String) {
    public companion object {
        private val NON_ALPHANUMERIC = Regex("""[^a-z0-9]+""")
        private val MARKS = Regex("""\p{M}+""")

        public fun of(title: String): TitleKey = TitleKey(unaccented(title).lowercase().replace(NON_ALPHANUMERIC, " ").trim())

        /**
         * [text] without its accents and other marks, its letters decomposed (`é` is `e`, `ﬁ` is `fi`), its case and
         * punctuation kept.
         */
        internal fun unaccented(text: String): String =
            // ASCII has no mark and is its own decomposition: most of a reference list never reaches the normalizer.
            if (text.all { it.code < ASCII }) text else MARKS.replace(Normalizer.normalize(text, Normalizer.Form.NFKD), "")

        private const val ASCII = 0x80
    }
}
