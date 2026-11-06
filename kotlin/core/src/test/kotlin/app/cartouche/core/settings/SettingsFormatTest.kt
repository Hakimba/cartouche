// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Some
import arrow.core.getOrElse
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.Test

class SettingsFormatTest {
    @Test
    fun `INV-15 a settings file of the first format or naming an unknown choice is not read`() {
        listOf(
            """{"version":1,"settings":{"controls":{"style":"letters","layout":"standard"}}}""",
            """{"version":2,"settings":{"buttonStyle":"sega"}}""",
            """{"version":2,"settings":{"edgeSmoothing":"8x"}}""",
            """{"version":2,"settings":{"preferredRegion":"Atlantis"}}""",
            """{"version":2,"settings":{"language":"tlh"}}""",
            """{"version":2,"settings":{"backdrop":"sepia"}}""",
        ).forEach { SettingsFormat.decode(it).shouldBeLeft() }
    }

    @Test
    fun `INV-15 old files read with the choices they predate off, and the new choices are stored`() {
        fun read(settings: String) = SettingsFormat.decode("""{"version":2,"settings":{$settings}}""")
        read(""""buttonStyle":"nintendo"""").shouldBeRight(Settings(Some(ButtonStyle.NINTENDO), EdgeSmoothing.FOUR_TIMES))
        read("").shouldBeRight(Settings(None, EdgeSmoothing.FOUR_TIMES))
        read(""""buttonStyle":"xbox","edgeSmoothing":"2x"""")
            .shouldBeRight(Settings(Some(ButtonStyle.XBOX), EdgeSmoothing.TWICE, None, gamesFloat = false))
        mapOf(EdgeSmoothing.FOUR_TIMES to "4x", EdgeSmoothing.TWICE to "2x", EdgeSmoothing.OFF to "off").forEach { (smoothing, name) ->
            SettingsFormat.encode(Settings(edgeSmoothing = smoothing)) shouldContain """"edgeSmoothing":"$name""""
        }
        SettingsFormat.encode(Settings(preferredRegion = Some(PreferredRegion.UNITED_KINGDOM))) shouldContain
            """"preferredRegion":"United Kingdom""""
        SettingsFormat.encode(Settings(language = Some(Language.BRAZILIAN_PORTUGUESE))) shouldContain """"language":"pt_BR""""
    }

    @Test
    fun `INV-15 a settings file written by 0_3_0 reads back with every choice and is written again byte for byte`() {
        val stored =
            """{"version":2,"settings":{"buttonStyle":"nintendo","edgeSmoothing":"2x","preferredRegion":"Japan","gamesFloat":true,""" +
                """"soundLevel":4,"language":"pt_BR","backdrop":"anthracite","pixelVeil":false}}"""
        val settings =
            Settings(
                Some(ButtonStyle.NINTENDO),
                EdgeSmoothing.TWICE,
                Some(PreferredRegion.JAPAN),
                gamesFloat = true,
                soundLevel = SoundLevel.of(4).getOrElse { SoundLevel.FULL },
                language = Some(Language.BRAZILIAN_PORTUGUESE),
                backdrop = Backdrop.ANTHRACITE,
                pixelVeil = false,
            )
        SettingsFormat.decode(stored).shouldBeRight(settings)
        SettingsFormat.encode(settings) shouldBe stored
    }
}
