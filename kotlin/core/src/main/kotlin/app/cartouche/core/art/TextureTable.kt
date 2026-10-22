// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.platforms.ScreenScraperSystem
import arrow.core.None
import arrow.core.Option
import arrow.core.filterOption
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.ensure
import arrow.core.raise.ensureNotNull
import arrow.core.raise.option

/**
 * One platform's table of the disc and cartridge textures ScreenScraper has (`app/data/screenscraper`,
 * built by the project from the reference lists' hashes): for each release, its ScreenScraper game
 * and its textures by region and disc. The device only ever downloads what is listed here, never
 * asking ScreenScraper which game a file is.
 */
public class TextureTable private constructor(
    /** None when the file does not name the date of the answers on its first line. */
    public val version: Option<ArtVersion>,
    /** The textures by the release's reference name. */
    private val byRelease: Map<String, List<Candidate.Texture>>,
) {
    /** How many releases the table knows. */
    public val size: Int get() = byRelease.size

    /** The textures of [release] (its reference name), in the table's order; none for a release it lacks, which costs no request. */
    public fun texturesOf(release: String): List<Candidate.Texture> = byRelease.getOrElse(release) { emptyList() }

    public companion object {
        public val EMPTY: TextureTable = TextureTable(None, emptyMap())

        /** `region` or `region[disc]`, as the table writes a texture. */
        private val TEXTURE = Regex("""([a-z]+)(?:\[(\d+)])?""")

        /**
         * ScreenScraper's regions (`regionsListe.php` short names) under the app's names (see
         * `Regions`): the American continent is the zone North America stands for; the codes of
         * [SKIPPED_CODES] are not regions.
         */
        private val REGIONS: Map<String, String> =
            mapOf(
                "wor" to "World",
                "eu" to "Europe",
                "us" to "USA",
                "jp" to "Japan",
                "fr" to "France",
                "de" to "Germany",
                "uk" to "United Kingdom",
                "sp" to "Spain",
                "it" to "Italy",
                "nl" to "Netherlands",
                "au" to "Australia",
                "br" to "Brazil",
                "kr" to "Korea",
                "asi" to "Asia",
                "ame" to "North America",
                "ca" to "Canada",
                "cn" to "China",
                "tw" to "Taiwan",
                "se" to "Sweden",
                "dk" to "Denmark",
                "fi" to "Finland",
                "no" to "Norway",
                "pt" to "Portugal",
                "ru" to "Russia",
                "pl" to "Poland",
                "gr" to "Greece",
                "nz" to "New Zealand",
                "oce" to "Oceania",
                "mex" to "Mexico",
                "cl" to "Chile",
                "pe" to "Peru",
                "za" to "South Africa",
                "hu" to "Hungary",
                "cz" to "Czech Republic",
                "sk" to "Slovakia",
                "bg" to "Bulgaria",
                "il" to "Israel",
                "tr" to "Turkey",
                "sa" to "Saudi Arabia",
                "ae" to "United Arab Emirates",
                "kw" to "Kuwait",
                "mor" to "Middle East",
                "afr" to "Africa",
            )

        /** The regions the table may name, for the tests. */
        internal val regionNames: Collection<String> get() = REGIONS.values

        internal val regionCodes: Set<String> get() = REGIONS.keys

        /** The tables' codes that are not regions, left out on purpose: ScreenScraper's own (`ss`), custom (`cus`), and two of no region (`c`, `cc`). */
        internal val SKIPPED_CODES: Set<String> = setOf("ss", "cus", "c", "cc")

        /**
         * Reads a table for the platform ScreenScraper numbers [system]; lines that are not
         * `release<TAB>game id<TAB>textures` are skipped, as are textures of no region the app knows.
         */
        public fun parse(text: String, system: ScreenScraperSystem): TextureTable =
            TextureTable(ArtIndex.versionOf(text), text.lines().map { parseLine(it, system) }.filterOption().toMap())

        private fun parseLine(line: String, system: ScreenScraperSystem): Option<Pair<String, List<Candidate.Texture>>> = option {
            val fields = line.split('\t')
            ensure(fields.size == 3 && !line.startsWith("#") && fields[0].isNotBlank())
            val game = ScreenScraperGame(ensureNotNull(fields[1].toIntOrNull()))
            fields[0] to fields[2].split(' ').map { texture(it, system, game) }.filterOption()
        }

        private fun texture(field: String, system: ScreenScraperSystem, game: ScreenScraperGame): Option<Candidate.Texture> = option {
            val (code, disc) = ensureNotNull(TEXTURE.matchEntire(field)).destructured
            val media = TextureMedia("support-texture($code)" + if (disc.isEmpty()) "" else "[$disc]")
            Candidate.Texture(system, game, media, REGIONS.getOrNone(code).bind())
        }
    }
}
