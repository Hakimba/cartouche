// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
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
        ).forEach { SettingsFormat.decode(it).shouldBeLeft() }
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
