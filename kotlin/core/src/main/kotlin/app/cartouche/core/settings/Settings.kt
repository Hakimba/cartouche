// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.settings

import app.cartouche.core.library.Library
import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers

/**
 * How the face buttons are drawn on screen: Xbox's letters (A at the bottom), Nintendo's (A on the right) or
 * PlayStation's shapes. It changes no action: confirming and going back follow the buttons as the device sends them.
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

/** How smooth the 3D's edges are drawn (multisample antialiasing); less asks less of the graphics card. */
@Serializable
public enum class EdgeSmoothing {
    @SerialName("4x")
    FOUR_TIMES,

    @SerialName("2x")
    TWICE,

    @SerialName("off")
    OFF,
}

/** How loud the app's sounds play, in [steps] from none (silenced) to [MAX]. */
@Serializable
@JvmInline
public value class SoundLevel private constructor(public val steps: Int) {
    public companion object {
        public const val MAX: Int = 10
        public val FULL: SoundLevel = SoundLevel(MAX)

        /** The level of [steps], none outside 0 to [MAX]. */
        public fun of(steps: Int): Option<SoundLevel> = if (steps in 0..MAX) Some(SoundLevel(steps)) else None
    }
}

/**
 * The app's own settings, apart from the library; [preferredRegion], none until the user chooses one, orders labels'
 * images; [gamesFloat] makes the selected game sway and bob (the consoles never do); [soundLevel] is how loud the
 * sounds play, full until the user turns them down.
 */
@Serializable
public data class Settings(
    public val buttonStyle: Option<ButtonStyle> = None,
    public val edgeSmoothing: EdgeSmoothing = EdgeSmoothing.FOUR_TIMES,
    public val preferredRegion: Option<PreferredRegion> = None,
    public val gamesFloat: Boolean = false,
    public val soundLevel: SoundLevel = SoundLevel.FULL,
) {
    /**
     * Whether the first launch is still to do: no button style chosen and no platform set up. An app updated from a
     * build without settings, already set up, does not see it again.
     */
    public fun isFirstLaunch(library: Library): Boolean = buttonStyle.isNone() && library.setups.isEmpty()
}
