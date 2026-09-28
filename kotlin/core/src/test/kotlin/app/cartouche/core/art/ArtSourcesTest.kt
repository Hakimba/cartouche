// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.game
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeNone
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import org.junit.Test

class ArtSourcesTest {
    private val index = ArtIndex.parse(extract(listOf(ExtractGame("Okage", emptySet(), listOf("USA=na.png", "Japan=jp.png")))))

    private val bySerial = SerialScans.of("https://scans.test/{serial}.jpg")

    @Test
    fun `a game is looked for as the extract's scans, then those of its serials, in the sources' version`() {
        val okage = game("Okage").copy(serials = listOf("SCUS-97129"))
        val request = ArtSources(index, bySerial).requestFor(okage).shouldBeSome()
        request.title shouldBe "Okage"
        request.version shouldBe Some(ArtVersion("2026-09-28"))
        request.candidates.map { it.value.substringAfterLast('/') } shouldBe listOf("na.png", "jp.png", "SCUS-97129.jpg")
    }

    @Test
    fun `a game the extract does not know is looked for by its serials, and a game no source can have is not`() {
        ArtSources(index, bySerial).requestFor(game("Unknown").copy(serials = listOf("SLPS-25358"))).shouldBeSome().candidates.size shouldBe
            1
        ArtSources(index, bySerial).requestFor(game("Unknown")).shouldBeNone()
        ArtSources(index, None).requestFor(game("Unknown").copy(serials = listOf("SLPS-25358"))).shouldBeNone()
        ArtSources(ArtIndex.EMPTY, None).requestFor(game("Okage")).shouldBeNone()
    }
}
