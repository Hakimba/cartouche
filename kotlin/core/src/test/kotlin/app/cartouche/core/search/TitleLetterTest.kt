// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import io.kotest.matchers.shouldBe
import org.junit.Test

class TitleLetterTest {
    @Test
    fun `a title is filed under its first letter, accents left out, else under the others`() {
        mapOf(
            "The Bouncer" to 'T',
            "Élan" to 'E',
            "Ōkami" to 'O',
            "Æon Flux" to 'A',
            "ﬁnal Fight" to 'F',
            ".hack//Infection" to '#',
            "007 - Nightfire" to '#',
            "ドラゴンクエスト" to '#',
            "" to '#',
        ).forEach { (title, letter) -> TitleLetter.of(title) shouldBe letter }
    }
}
