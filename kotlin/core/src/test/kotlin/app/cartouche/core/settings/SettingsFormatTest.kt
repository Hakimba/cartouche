// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

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
    fun `stored settings read back the same`() = runBlocking<Unit> {
        checkAll(settings) { settings -> SettingsFormat.decode(SettingsFormat.encode(settings)).shouldBeRight(settings) }
    }

    @Test
    fun `a settings file that is damaged, of another format or names an unknown style is not read`() {
        listOf(
            "",
            "not json",
            """{"version":1}""",
            """{"version":1,"settings":{"controls":{"style":"letters","layout":"standard"}}}""",
            """{"version":3,"settings":{}}""",
            """{"version":2,"settings":{"buttonStyle":"sega"}}""",
            """{"version":2,"settings":{"edgeSmoothing":"8x"}}""",
        ).forEach { SettingsFormat.decode(it).shouldBeLeft() }
    }

    @Test
    fun `INV-E8-02 settings stored before the edge smoothing existed read with 4x, the style kept`() {
        SettingsFormat
            .decode("""{"version":2,"settings":{"buttonStyle":"nintendo"}}""")
            .shouldBeRight(Settings(Some(ButtonStyle.NINTENDO), EdgeSmoothing.FOUR_TIMES))
        SettingsFormat.decode("""{"version":2,"settings":{}}""").shouldBeRight(Settings(None, EdgeSmoothing.FOUR_TIMES))
    }

    @Test
    fun `INV-E8-02 each edge smoothing is stored under its own name`() {
        mapOf(EdgeSmoothing.FOUR_TIMES to "4x", EdgeSmoothing.TWICE to "2x", EdgeSmoothing.OFF to "off").forEach { (smoothing, name) ->
            SettingsFormat.encode(Settings(edgeSmoothing = smoothing)) shouldContain """"edgeSmoothing":"$name""""
        }
    }

    @Test
    fun `reading a settings file is total, whatever is left of it`() = runBlocking<Unit> {
        checkAll(settings, Arb.int(0..200), Arb.string(0..20)) { settings, cut, noise ->
            val text = SettingsFormat.encode(settings)
            val read = SettingsFormat.decode(text.take(cut) + noise)
            if (cut >= text.length && noise.isEmpty()) read.shouldBeRight(settings)
        }
    }
}
