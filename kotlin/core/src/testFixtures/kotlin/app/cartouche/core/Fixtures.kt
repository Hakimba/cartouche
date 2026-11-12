// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import arrow.core.getOrElse
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.printableAscii
import io.kotest.property.arbitrary.string

/** A content URI written by hand in a test. */
fun uri(text: String): ContentUri = ContentUri.parse(text).getOrElse { error("Not a content URI: $text") }

/**
 * Any text: ASCII, tabs and line breaks, controls, accents, CJK, astral characters. Kotest's `Arb.string()` draws
 * printable ASCII only, which never reaches the guards of a parser.
 */
val anyText: Arb<String> =
    Arb.string(
        0..60,
        Arb.choice(
            Codepoint.printableAscii(),
            Arb.element('\t'.code, '\n'.code, '\r'.code, 0, 0x7F, 0xA0, 0x301, 0xE9, 0x3000, 0x30C9, 0x1F3AE).map(::Codepoint),
        ),
    )
