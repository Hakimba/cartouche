// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.Shipped
import arrow.core.None
import arrow.core.Some
import arrow.core.getOrElse
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldNotBeBlank
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.filter
import io.kotest.property.arbitrary.printableAscii
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import java.text.Normalizer

class GameNameTest {
    @Test
    fun `tags are classified and the title is what remains`() {
        GameName.parse("Burnout 3 - Takedown (Europe) (En,Es,Nl,Sv)") shouldBe
            GameName("Burnout 3 - Takedown", listOf("Europe"), listOf("En", "Es", "Nl", "Sv"), emptyList(), None, emptyList())
        GameName.parse("0 Story (Japan, Asia) (Disc 2) (v1.02) (Beta)") shouldBe
            GameName("0 Story", listOf("Japan", "Asia"), emptyList(), listOf("v1.02"), Some(2), listOf("Beta"))
        GameName.parse("Urban Reign (EU)").regions shouldBe listOf("Europe")
        GameName.parse("Game (USA) (v3.00) (Rev 1)").version shouldBe Some("v3.00 Rev 1")
        GameName.parse("Revenge (USA)").otherTags shouldBe emptyList()
        GameName.parse("Game (Revenge Edition)").version shouldBe None
        GameName.parse("One Piece - Pirates Carnival (Japan) (Multi Tap (SCPH-10090) Doukonban)").let {
            it.title shouldBe "One Piece - Pirates Carnival"
            it.otherTags shouldBe listOf("Multi Tap (SCPH-10090) Doukonban")
        }
    }

    @Test
    fun `display titles put articles back and keys ignore case, accents and punctuation`() {
        GameName.parse("Punisher, The (Europe)").displayTitle shouldBe "The Punisher"
        GameName.parse("Legend of Aang, The - Into the Inferno").displayTitle shouldBe "The Legend of Aang - Into the Inferno"
        GameName.parse("Dr. Muto (Europe)").key shouldBe GameName.parse("DR MUTO").key
        GameName.parse("Pokémon").key shouldBe GameName.parse("Pokemon").key
        GameName.parse("Let's Ansatsu!_ Nerawareta").key shouldBe GameName.parse("Let's Ansatsu! Nerawareta").key
    }

    @Test
    fun `a name is filed from its title alone under the keys its whole reading has`() = runBlocking<Unit> {
        fun filedAsRead(text: String) = GameName.parse(text).let { GameName.Filing(it.key, it.mainKey.getOrElse { it.key }) }
        Shipped.text("titles/ps2.tsv").lines().map { it.substringBefore('\t') }.forEach { GameName.filing(it) shouldBe filedAsRead(it) }
        checkAll(Arb.choice(fileNames, Arb.string())) { text -> GameName.filing(text) shouldBe filedAsRead(text) }
    }

    @Test
    fun `INV-03 reading names is total, never gives a blank title, and is idempotent on titles`() = runBlocking<Unit> {
        checkAll(Arb.string().filter { it.isNotBlank() }) { text ->
            val name = GameName.parse(text)
            name.displayTitle.shouldNotBeBlank()
            GameName.parse(name.title).title shouldBe name.title
        }
    }

    @Test
    fun `leaving accents out of a title gives what decomposing it and dropping its marks gave`() = runBlocking<Unit> {
        val written = Arb.string(0..30, Codepoint.printableAscii())
        val accented =
            Arb.string(
                0..30,
                Arb.element(
                    listOf("a", "é", "ﬁ", "日", "\u0301", "😀", "Z", " ", "(")
                        .map {
                            it.codePointAt(0)
                        }.map(::Codepoint),
                ),
            )
        checkAll(Arb.choice(written, accented)) { text ->
            TitleKey.unaccented(text) shouldBe Regex("""\p{M}+""").replace(Normalizer.normalize(text, Normalizer.Form.NFKD), "")
        }
    }
}
