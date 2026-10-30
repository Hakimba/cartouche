// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.regions

import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone

/**
 * How close an image's region is to a game's, for picking the image that looks most like the
 * user's copy. Regions are grouped the way consoles sell them: NTSC-U (the Americas), PAL (Europe,
 * Oceania), NTSC-J (East Asia). Closest first: one of the game's own regions, the umbrella region
 * of its group (North America, Europe, Japan), another region of its group, the world or no region
 * named, then the other groups in that order, then regions this table does not know. Redump's and
 * LaunchBox's names are both understood (`USA`, `United States`, `North America`).
 */
internal object Regions {
    enum class Group(val umbrella: String) {
        NTSC_U("North America"),
        PAL("Europe"),
        NTSC_J("Japan"),
    }

    private val SAME: Map<String, String> =
        mapOf("USA" to "North America", "United States" to "North America", "UK" to "United Kingdom", "The Netherlands" to "Netherlands")

    private val GROUPS: Map<String, Group> =
        listOf(
            Group.NTSC_U to "North America, Canada, Brazil, Mexico, Chile, Peru, Latin America, South America",
            Group.PAL to
                """Europe, Australia, New Zealand, Oceania, South Africa, Africa, Middle East, India, Austria, Belgium, Bulgaria, Croatia,
                Czech Republic, Denmark, Finland, France, Germany, Greece, Hungary, Ireland, Israel, Italy, Kuwait, Netherlands, Norway,
                Poland, Portugal, Russia, Saudi Arabia, Scandinavia, Slovakia, Spain, Sweden, Switzerland, Turkey, United Arab Emirates,
                United Kingdom""",
            Group.NTSC_J to "Japan, Asia, China, Hong Kong, Korea, Taiwan",
        ).flatMap { (group, names) -> names.split(',').map { it.trim() to group } }.toMap()

    private val WORLD = setOf("World", "")

    /** The zone each country's releases belong to, as a release names its region: a French game's is Europe. */
    private val ZONES: Map<String, String> =
        listOf(
            "Europe" to
                """Austria, Belgium, Croatia, Denmark, Finland, France, Germany, Greece, Ireland, Italy, Netherlands, Norway, Poland,
                Portugal, Russia, Scandinavia, Spain, Sweden, Switzerland, United Kingdom""",
            "Oceania" to "Australia, New Zealand",
            "North America" to "Canada, Mexico",
            "South America" to "Brazil",
            "Asia" to "China, Hong Kong, Japan, Korea, Taiwan",
        ).flatMap { (zone, countries) -> countries.split(',').map { it.trim() to zone } }.toMap()

    private const val OTHER_GROUPS = 4

    /** The rank of [image]'s region for a game of [game]'s regions: the lower, the closer. */
    fun rank(game: List<String>, image: String): Int {
        val region = same(image)
        val own = game.map(::same)
        val groups = groupsOf(game)
        val group = GROUPS.getOrNone(region)
        return when {
            region in own -> 0
            groups.any { it.umbrella == region } -> 1
            group.isSome { it in groups } -> 2
            region in WORLD -> 3
            else -> OTHER_GROUPS + group.fold({ Group.entries.size }, Group::ordinal)
        }
    }

    /**
     * Whether [image]'s region is the game's own, for a game of [game]'s regions: one of them, or the
     * zone holding one of them (a French game's are France's and Europe's, never Germany's, nor a
     * zone's umbrella for a country outside it: Japan is not a Korean game's); no region named is
     * never own, the world only a world release's.
     */
    fun isOwn(game: List<String>, image: String): Boolean {
        val region = same(image)
        return region.isNotEmpty() && game.any { own -> region == same(own) || ZONES.getOrNone(same(own)).isSome { it == region } }
    }

    /**
     * Regions closest to [game]'s first ([rank]); at equal rank a zone's own name (an umbrella) before its other
     * countries, so that a game of the world shows North America's scan before Brazil's.
     */
    fun closestTo(game: List<String>): Comparator<String> = compareBy({ rank(game, it) }, { same(it) !in umbrellas })

    /**
     * Where [image]'s region comes for a user who prefers [preferred]'s images: 0 that region, 1 the zone holding it
     * (Europe for France), 2 the world or no region named, 3 any other.
     */
    fun preferredFirst(preferred: PreferredRegion, image: String): Int {
        val region = same(image)
        return when {
            region == preferred.region -> 0
            ZONES.getOrNone(preferred.region).isSome { it == region } -> 1
            region in WORLD -> 2
            else -> 3
        }
    }

    /** The groups of [game]'s regions that this table knows. */
    fun groupsOf(game: List<String>): List<Group> = game.flatMap { GROUPS.getOrNone(same(it)).toList() }

    /** The umbrella regions, in the order of their groups: North America, Europe, Japan. */
    val umbrellas: List<String> = Group.entries.map(Group::umbrella)

    /**
     * The umbrella region of the first of [game]'s regions whose group is known; none for the world or unknown
     * regions.
     */
    fun umbrellaOf(game: List<String>): Option<String> = groupsOf(game).firstOrNone().map(Group::umbrella)

    /** The name [region] goes by here, whichever source named it (`USA` is `North America`). */
    fun same(region: String): String = SAME.getOrElse(region) { region }
}
