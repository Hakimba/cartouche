// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.regions

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The region whose images the user would rather see on a label when nothing found in the game settles its own (see
 * `ArtSources.order`), named as [Regions] names it, stored and sent under that name.
 */
@Serializable
public enum class PreferredRegion(public val region: String) {
    @SerialName("Europe")
    EUROPE("Europe"),

    @SerialName("North America")
    NORTH_AMERICA("North America"),

    @SerialName("Japan")
    JAPAN("Japan"),

    @SerialName("France")
    FRANCE("France"),

    @SerialName("Germany")
    GERMANY("Germany"),

    @SerialName("United Kingdom")
    UNITED_KINGDOM("United Kingdom"),

    @SerialName("Spain")
    SPAIN("Spain"),

    @SerialName("Italy")
    ITALY("Italy"),

    @SerialName("Netherlands")
    NETHERLANDS("Netherlands"),

    @SerialName("Australia")
    AUSTRALIA("Australia"),

    @SerialName("Brazil")
    BRAZIL("Brazil"),

    @SerialName("Korea")
    KOREA("Korea"),

    @SerialName("China")
    CHINA("China"),

    @SerialName("Taiwan")
    TAIWAN("Taiwan"),

    @SerialName("World")
    WORLD("World"),
}
