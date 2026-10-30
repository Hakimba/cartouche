// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.Folding

/**
 * The letter the index files a title under: its first character's, accents left out, `A` to `Z`; [OTHERS] for a title
 * that starts with a digit, a sign or another script.
 */
public object TitleLetter {
    public const val OTHERS: Char = '#'

    public fun of(title: String): Char = (if (title.isEmpty()) "" else Folding.of(title.codePointAt(0)))
        .let { if (it.isNotEmpty() && it[0] in 'a'..'z') it[0].uppercaseChar() else OTHERS }
}
