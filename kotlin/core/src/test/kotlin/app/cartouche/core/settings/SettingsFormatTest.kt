// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.string.shouldContain
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SettingsFormatTest {
    @Test
    fun `INV-15 stored settings read back the same`() = runBlocking<Unit> {
        checkAll(settings) { settings -> SettingsFormat.decode(SettingsFormat.encode(settings)).shouldBeRight(settings) }
    }

    @Test
    fun `INV-15 a settings file that is damaged, of another format or names an unknown style is not read`() {
        listOf(
            "",
            "not json",
            """{"version":1}""",
            """{"version":1,"settings":{"controls":{"style":"letters","layout":"standard"}}}""",
            """{"version":3,"settings":{}}""",
            """{"version":2,"settings":{"buttonStyle":"sega"}}""",
            """{"version":2,"settings":{"edgeSmoothing":"8x"}}""",
            """{"version":2,"settings":{"preferredRegion":"Atlantis"}}""",
            """{"version":2,"settings":{"language":"tlh"}}""",
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
    fun `INV-15 reading a settings file is total, whatever is left of it`() = runBlocking<Unit> {
        checkAll(settings, Arb.int(0..200), Arb.string(0..20)) { settings, cut, noise ->
            val text = SettingsFormat.encode(settings)
            val read = SettingsFormat.decode(text.take(cut) + noise)
            if (cut >= text.length && noise.isEmpty()) read.shouldBeRight(settings)
        }
    }
}
