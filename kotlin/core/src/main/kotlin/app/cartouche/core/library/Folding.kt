// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import java.util.concurrent.ConcurrentHashMap

/** Text as titles are filed and searched: lowercase Latin letters and digits, accents left out. */
internal object Folding {
    private val MARK = Regex("""\p{M}""")

    // Decomposing a character is slow, and thousands of titles share a few hundred of them: each
    // is decomposed once.
    private val folds = ConcurrentHashMap<Int, String>()

    /** The letters and digits [codePoint] reads as: one, a few for a ligature, or none. */
    fun of(codePoint: Int): String = when (codePoint) {
        in 'a'.code..'z'.code, in '0'.code..'9'.code -> codePoint.toChar().toString()
        in 'A'.code..'Z'.code -> codePoint.toChar().lowercase()
        in 0..0x7f -> ""
        else ->
            folds.getOrPut(codePoint) {
                LETTERS.getOrElse(codePoint) {
                    TitleKey
                        .unaccented(String(Character.toChars(codePoint)))
                        .lowercase()
                        .filter { it in 'a'..'z' || it in '0'..'9' }
                }
            }
    }

    /** Whether [codePoint] is an accent or another mark written apart, which belongs to the letter before it. */
    fun isMark(codePoint: Int): Boolean = codePoint > 0x7f && MARK.matches(String(Character.toChars(codePoint)))

    /** Latin letters that decomposing leaves whole, read as titles write them in plain letters. */
    private val LETTERS: Map<Int, String> =
        mapOf(
            "æ" to "ae",
            "Æ" to "ae",
            "œ" to "oe",
            "Œ" to "oe",
            "ø" to "o",
            "Ø" to "o",
            "ß" to "ss",
            "ł" to "l",
            "Ł" to "l",
            "đ" to "d",
            "Đ" to "d",
            "þ" to "th",
            "Þ" to "th",
        ).mapKeys { (letter, _) -> letter.codePointAt(0) }
}
