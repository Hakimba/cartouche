// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.GameId
import app.cartouche.core.library.Library
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import io.kotest.matchers.shouldBe
import org.junit.Test

class FindersTest {
    private val library =
        Library(
            games =
                listOf("Okage", "Ico", "Zone").mapIndexed {
                    i,
                    title,
                    ->
                    game(title).copy(id = GameId("ps2/$i"), regions = listOf("Japan"))
                },
        )
    private val finders = Finders(library)
    private val ps2 = PlatformId("ps2")

    @Test
    fun `nothing typed, or only signs, is the index in the order asked, and something typed the games found`() {
        finders.view(ps2, Order.TITLE, " - ") shouldBe
            Finder.of(listOf("Ico", "Okage", "Zone").map { title -> library.games.first { it.title == title } }).index(Order.TITLE)
        finders.view(ps2, Order.REGION, "").groups shouldBe listOf(Group("Japan", 0))
        finders.view(ps2, Order.REGION, "o").games shouldBe listOf(1)
        finders.marks(ps2, 1, "o") shouldBe listOf(Mark(0, 1))
        finders.marks(ps2, 1, "") shouldBe emptyList()
        finders.size(ps2) shouldBe 3
    }

    @Test
    fun `a platform without games has no game, no key and no mark`() {
        val gba = PlatformId("gba")
        finders.view(gba, Order.TITLE, "o") shouldBe View(emptyList(), emptyList(), emptyMap())
        finders.size(gba) shouldBe 0
        finders.marks(gba, 0, "o") shouldBe emptyList()
    }

    @Test
    fun `finders are kept for a library that searches the same, and made anew when a title, a name, a region or a console changes`() {
        val launched = library.copy(games = library.games.map { it.copy(lastDisc = 0) })
        (finders.after(launched) === finders) shouldBe true
        listOf(
            library.withDisplayName(library.games[0].id, app.cartouche.core.library.DisplayName.of("Okage: Shadow King")),
            library.copy(games = library.games.map { it.copy(regions = listOf("Europe")) }),
            library.copy(games = library.games.drop(1)),
        ).forEach { (finders.after(it) === finders) shouldBe false }
    }
}
