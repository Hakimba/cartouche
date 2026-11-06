// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.storage

import app.cartouche.core.library.Arrivals
import app.cartouche.core.library.ArrivalsFormat
import app.cartouche.core.library.GameId
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.settings.SettingsFormat
import app.cartouche.core.settings.settings
import app.cartouche.core.shelves.SelectedGame
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.SelectionFormat
import app.cartouche.core.shelves.selectedLibraries
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.withClue
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.flatMap
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.arbitrary.subsequence
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class VersionedJsonTest {
    private val arrivals =
        selectedLibraries.flatMap { (library, _) ->
            Arb.subsequence(library.games).map { games ->
                Arrivals(games.mapTo(HashSet()) { it.id }, games.groupBy({ it.platform }, { it.id }).mapValues { (_, ids) -> ids.toSet() })
            }
        }

    @Test
    fun `INV-15 INV-25 a stored state reads back the same, and a damaged file or one of another format is not read`() = runBlocking<Unit> {
        laws(SelectionFormat, "selection", 1, selectedLibraries.map { it.second })
        laws(SettingsFormat, "settings", 2, settings)
        laws(ArrivalsFormat, "arrivals", 1, arrivals)
    }

    @Test
    fun `INV-15 INV-25 a selection and arrivals stored on devices in format 1 read back, and are written again byte for byte`() {
        val okage = GameId("ps2/Okage")
        val okami = GameId("ps2/Ōkami")
        golden(
            SelectionFormat,
            """{"version":1,"selection":{"platform":"ps2","games":{"ps2":{"id":"ps2/Ōkami","title":"Ōkami"}}}}""",
            Selection(Some(PlatformId("ps2")), mapOf(PlatformId("ps2") to SelectedGame(okami, "Ōkami"))),
        )
        golden(
            ArrivalsFormat,
            """{"version":1,"arrivals":{"unseen":["ps2/Okage","ps2/Ōkami"],"announced":{"ps2":["ps2/Ōkami"]}}}""",
            Arrivals(setOf(okage, okami), mapOf(PlatformId("ps2") to setOf(okami))),
        )
    }

    private fun <T> golden(format: VersionedJson<T>, stored: String, state: T) {
        format.decode(stored).shouldBeRight(state)
        format.encode(state) shouldBe stored
    }

    private suspend fun <T> laws(format: VersionedJson<T>, field: String, version: Int, states: Arb<T>) = withClue(field) {
        checkAll(states, Arb.int(0..400), Arb.string(0..20)) { state, cut, noise ->
            val text = format.encode(state)
            format.decode(text).shouldBeRight(state)
            // A file cut short is refused; one whole, whatever follows it, reads as it was stored or is refused.
            if (cut < text.length) format.decode(text.take(cut)).shouldBeLeft()
            format.decode(text + noise).onRight { it shouldBe state }
        }
        listOf(
            "",
            "not json",
            """{"version":$version}""",
            """{"$field":{}}""",
            """{"version":${version - 1},"$field":{}}""",
            """{"version":${version + 1},"$field":{}}""",
            """{"version":$version,"$field":{},"other":{}}""",
        ).forEach { format.decode(it).shouldBeLeft() }
    }
}
