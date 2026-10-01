// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.settings

import app.cartouche.core.library.Library
import arrow.core.None
import arrow.core.Option
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers

/**
 * How the face buttons are drawn on screen: Xbox's letters (A at the bottom), Nintendo's (A on the
 * right) or PlayStation's shapes. It changes no action: confirming and going back follow the buttons
 * as the device sends them.
 */
@Serializable
public enum class ButtonStyle {
    @SerialName("xbox")
    XBOX,

    @SerialName("nintendo")
    NINTENDO,

    @SerialName("playstation")
    PLAYSTATION,
}

/** The app's own settings, apart from the library. */
@Serializable
public data class Settings(public val buttonStyle: Option<ButtonStyle> = None) {
    /**
     * Whether the first launch is still to do: no button style chosen and no platform set up. An
     * app updated from a build without settings, already set up, does not see it again.
     */
    public fun isFirstLaunch(library: Library): Boolean = buttonStyle.isNone() && library.setups.isEmpty()
}
