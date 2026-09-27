// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.shelves

import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SelectionFormatTest {
    @Test
    fun `INV-E2-05 a stored selection reads back the same`() = runBlocking<Unit> {
        checkAll(selectedLibraries) { (_, selection) ->
            SelectionFormat.decode(SelectionFormat.encode(selection)).shouldBeRight(selection)
        }
    }

    @Test
    fun `INV-E2-05 a selection file that is damaged or of another format is not read, whatever the reason`() {
        listOf(
            "",
            "not json",
            """{"version":1}""",
            """{"version":0,"selection":{}}""",
            """{"version":2,"selection":{}}""",
            """{"selection":{}}""",
        ).forEach { SelectionFormat.decode(it).shouldBeLeft() }
    }

    @Test
    fun `reading a selection file is total, whatever is left of it`() = runBlocking<Unit> {
        checkAll(selectedLibraries, Arb.int(0..400), Arb.string(0..20)) { (_, selection), cut, noise ->
            val text = SelectionFormat.encode(selection)
            val read = SelectionFormat.decode(text.take(cut) + noise)
            if (cut >= text.length && noise.isEmpty()) read.shouldBeRight(selection)
        }
    }
}
