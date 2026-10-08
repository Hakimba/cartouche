// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.TitleKey
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.getOrElse
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.singleOrNone

/**
 * One platform's extract of the LaunchBox Games Database (`app/data/art`, written by
 * `dev/launchbox_art.py`): each game's disc scans, by region, found by title.
 */
public class ArtIndex private constructor(
    /** None when the file does not name the database's date on its first line. */
    public val version: Option<ArtVersion>,
    private val byName: Map<String, List<List<Image>>>,
    private val byAlternateName: Map<String, List<List<Image>>>,
    /** How many games the extract knows. */
    public val size: Int,
) {
    private class Image(val region: String, file: String) {
        val url: ArtUrl = ArtUrl(IMAGES + file)
    }

    /**
     * The disc scans of the game titled [title], closest to [regions] first (see [Regions]). The title
     * is the game's name, or else one of its alternate names, whatever their case, accents,
     * punctuation and spaces; a title that names several games names none, as it could be any of them.
     */
    public fun scansOf(title: String, regions: List<String>): List<ArtUrl> =
        discsOf(title).sortedBy { Regions.rank(regions, it.region) }.map { it.url }

    /**
     * The disc scan of each region the extract has for the game titled [title] (found as by
     * [scansOf]), closest to [regions] first: one per region, the first the extract lists for it,
     * whichever name a source gives the region (`USA` and `North America` are one).
     */
    public fun variantsOf(title: String, regions: List<String>): List<ArtVariant> = discsOf(title)
        .map { ArtVariant(LabelRegion(Regions.same(it.region)), it.url) }
        .distinctBy { it.region }
        .sortedBy { Regions.rank(regions, it.region.name) }

    /** The scans of the one game titled [title], in the extract's order; none when no game or several are. */
    private fun discsOf(title: String): List<Image> = key(title)
        .let { key -> byName.getOrElse(key) { byAlternateName.getOrElse(key) { emptyList() } } }
        .singleOrNone()
        .getOrElse { emptyList() }

    public companion object {
        public val EMPTY: ArtIndex = ArtIndex(None, emptyMap(), emptyMap(), 0)

        private const val IMAGES = "https://images.launchbox-app.com/"

        /** Reads an extract; lines that are not `name<TAB>alternate names<TAB>discs` are skipped. */
        public fun parse(text: String): ArtIndex {
            val version = versionOf(text)
            val games = text.lines().map(::parseLine).filterOption()
            val byAlternateName = games.flatMap { (_, alternates, entry) -> alternates.map { it to entry } }
            return ArtIndex(
                version,
                games.filter { it.first.isNotEmpty() }.groupBy({ it.first }, { it.third }),
                byAlternateName.groupBy({ it.first }, { it.second }),
                games.size,
            )
        }

        /** The version an extract states on its first line (`# version`), the rest left unread. */
        public fun versionOf(text: String): Option<ArtVersion> =
            Some(text.takeWhile { it != '\n' && it != '\r' }).filter { it.startsWith("#") }.map { ArtVersion(it.removePrefix("#").trim()) }

        private fun parseLine(line: String): Option<Triple<String, Set<String>, List<Image>>> = option {
            val fields = line.split('\t')
            ensure(fields.size == 3 && !line.startsWith("#") && fields[0].isNotBlank())
            // A name of no Latin letter or digit, such as a Japanese one, reduces to nothing: it finds no
            // game, but its romanised alternate names still do.
            val name = key(fields[0])
            val alternates = fields[1].split('|').map(::key).filter(String::isNotEmpty).toSet() - name
            Triple(name, alternates, images(fields[2]))
        }

        private fun images(field: String): List<Image> = field
            .split(';')
            .map { pair ->
                option {
                    val parts = pair.split('=', limit = 2)
                    ensure(parts.size == 2 && parts[1].isNotBlank())
                    Image(parts[0], parts[1])
                }
            }.filterOption()

        /**
         * A title reduced for matching ([TitleKey]) without its spaces, as LaunchBox sometimes joins
         * words (`ChainDive`). Its bracketed tags stay: `Final Fantasy XII [Demo]` is another game.
         */
        private fun key(title: String): String = TitleKey.of(title).value.replace(" ", "")
    }
}
