// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.TitleKey
import app.cartouche.core.regions.Regions
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.filterOption
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.singleOrNone
import arrow.core.toOption

/**
 * One platform's extract of the LaunchBox Games Database (`app/data/art`, written by `dev/launchbox_art.py`): each
 * game's names and scans, by region, all of the type of image its platform's profile names (`ArtKind`: a disc's face,
 * a cartridge's front).
 */
public class ArtIndex private constructor(
    /** None when the file does not name the database's date on its first line. */
    public val version: Option<ArtVersion>,
    private val byName: Map<String, List<Match>>,
    private val byAlternateName: Map<String, List<Match>>,
    /** The games an alternate name written `<title> (<Country>)` names, by the title's [dashed] key and the country. */
    private val regional: Map<Pair<String, String>, List<Match>>,
    /** How many games the extract knows. */
    public val size: Int,
) {
    private class Image(val region: String, file: String) {
        val url: ArtUrl = ArtUrl(IMAGES + file)
    }

    /** Compared by identity: two lines of the extract are two games, whatever they hold. */
    private class Game(val name: String, val alternates: List<String>, val images: List<Image>)

    private class Match(val game: Game, val name: String)

    /**
     * The scans of the game titled [title], closest to [regions] first (see [Regions.closestTo]),
     * equally close ones in the extract's order. The game is the one an alternate name written
     * `<title> (<one of regions>)` names; else those whose name is the title, else those of whom an
     * alternate name is, whatever their case, accents, punctuation and spaces (LaunchBox sometimes
     * joins words, `ChainDive`). Several games found are told apart by putting back what reducing
     * took away, one step at a time (the spaces between words, punctuation with `: ` and ` - ` alike,
     * accents, then the exact text), keeping those still named as the title; none or several left
     * name none, as the title could be any of them.
     */
    public fun scansOf(title: String, regions: List<String>): List<Candidate.Web> =
        imagesOf(title, regions).sortedWith(compareBy(Regions.closestTo(regions), Image::region)).map {
            Candidate.Web(it.url, it.region, ArtSource.LAUNCHBOX)
        }

    private fun imagesOf(title: String, regions: List<String>): List<Image> {
        val found =
            regions
                .flatMap { regional.getOrElse(dashed(title) to Regions.same(it)) { emptyList() } }
                .ifEmpty { byName.getOrElse(joined(title)) { emptyList() } }
                .ifEmpty { byAlternateName.getOrElse(joined(title)) { emptyList() } }
        return LADDER
            .runningFold(found) { kept, reduce -> kept.filter { reduce(it.name) == reduce(title) } }
            .map { kept -> kept.map(Match::game).distinct() }
            .firstOrNone { it.size <= 1 }
            .flatMap { it.singleOrNone() }
            .fold({ emptyList() }, Game::images)
    }

    public companion object {
        public val EMPTY: ArtIndex = ArtIndex(None, emptyMap(), emptyMap(), emptyMap(), 0)

        private const val IMAGES = "https://images.launchbox-app.com/"

        private val REGIONAL_NAME = Regex("""(.*) \(([^()]+)\)""")
        private val SPACES = Regex("""\s+""")

        /**
         * The title reduced for matching ([TitleKey]), its words kept apart; its bracketed tags stay (`Final Fantasy
         * XII [Demo]` is another game).
         */
        private fun dashed(title: String): String = TitleKey.of(title).value

        private fun joined(title: String): String = dashed(title).replace(" ", "")

        private fun accented(title: String): String = title.lowercase().replace(": ", " - ").replace(SPACES, " ").trim()

        private fun punctuated(title: String): String = accented(TitleKey.unaccented(title))

        private val LADDER: List<(String) -> String> = listOf(::dashed, ::punctuated, ::accented, String::trim)

        /** Reads an extract; lines that are not `name<TAB>alternate names<TAB>scans` are skipped. */
        public fun parse(text: String): ArtIndex {
            val games = text.lines().map(::parseLine).filterOption()

            // A name of no Latin letter or digit, such as a Japanese one, reduces to nothing: it finds no
            // game, but its romanised alternate names still do.
            fun byKey(names: (Game) -> List<String>) =
                games.flatMap { game -> names(game).map { Match(game, it) } }.groupBy { joined(it.name) } - ""
            val regional =
                games.flatMap { game ->
                    game.alternates.map { REGIONAL_NAME.matchEntire(it).toOption() }.filterOption().map { written ->
                        val (title, country) = written.destructured
                        (dashed(title) to Regions.same(country)) to Match(game, title)
                    }
                }
            return ArtIndex(
                versionOf(text),
                byKey { listOf(it.name) },
                byKey(Game::alternates),
                regional.filter { it.first.first.isNotEmpty() }.groupBy({ it.first }, { it.second }),
                games.size,
            )
        }

        /** The version an extract states on its first line (`# version`), the rest left unread. */
        public fun versionOf(text: String): Option<ArtVersion> =
            Some(text.takeWhile { it != '\n' && it != '\r' }).filter { it.startsWith("#") }.map { ArtVersion(it.removePrefix("#").trim()) }

        private fun parseLine(line: String): Option<Game> = option {
            val fields = line.split('\t')
            ensure(fields.size == 3 && !line.startsWith("#") && fields[0].isNotBlank())
            Game(fields[0], fields[1].split('|').filter(String::isNotEmpty), images(fields[2]))
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
    }
}
