// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

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
    private enum class Group(val umbrella: String) {
        NTSC_U("North America"),
        PAL("Europe"),
        NTSC_J("Japan"),
    }

    private val SAME: Map<String, String> =
        mapOf("USA" to "North America", "United States" to "North America", "UK" to "United Kingdom", "The Netherlands" to "Netherlands")

    private val GROUPS: Map<String, Group> =
        listOf(
            Group.NTSC_U to "North America, Canada, Brazil, Mexico, Latin America, South America",
            Group.PAL to
                """Europe, Australia, New Zealand, Oceania, South Africa, India, Austria, Belgium, Croatia, Denmark, Finland, France,
                Germany, Greece, Ireland, Italy, Netherlands, Norway, Poland, Portugal, Russia, Scandinavia, Spain, Sweden, Switzerland,
                United Kingdom""",
            Group.NTSC_J to "Japan, Asia, China, Hong Kong, Korea, Taiwan",
        ).flatMap { (group, names) -> names.split(',').map { it.trim() to group } }.toMap()

    private val WORLD = setOf("World", "")

    private const val OTHER_GROUPS = 4

    /** The rank of [image]'s region for a game of [game]'s regions: the lower, the closer. */
    fun rank(game: List<String>, image: String): Int {
        val region = same(image)
        val own = game.map(::same)
        val groups = own.flatMap { GROUPS.getOrNone(it).toList() }
        val group = GROUPS.getOrNone(region)
        return when {
            region in own -> 0
            groups.any { it.umbrella == region } -> 1
            group.isSome { it in groups } -> 2
            region in WORLD -> 3
            else -> OTHER_GROUPS + group.fold({ Group.entries.size }, Group::ordinal)
        }
    }

    /** The name [region] goes by here, whichever source named it (`USA` is `North America`). */
    fun same(region: String): String = SAME.getOrElse(region) { region }
}
