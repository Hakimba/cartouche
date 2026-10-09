// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import arrow.core.Option
import arrow.core.Some

/**
 * What is typed on the ribbon, read as titles are ([Words]): the words already typed, [done], and
 * the one being typed, [typing], empty right after a space. Each word typed is the start of another
 * word of a title, in any order: "ace dist" and "dist ace" both find "Ace Combat - Distant Thunder".
 */
public class Query private constructor(internal val done: List<String>, internal val typing: String) {
    /** Every word typed, the one being typed included unless it is still empty. */
    internal val prefixes: List<String> get() = if (typing.isEmpty()) done else done + typing

    /** What is typed, read: the words one space apart, a space after the last one when one was typed. */
    internal val text: String get() = (done + typing).joinToString(" ")

    public companion object {
        /** [typed] as a query; none when nothing but spaces and signs is typed. */
        public fun of(typed: String): Option<Query> {
            val folded = Words.folded(typed).trimStart()
            val done = folded.substringBeforeLast(' ', "").split(' ').filter(String::isNotEmpty)
            return Some(Query(done, folded.substringAfterLast(' '))).filter { it.prefixes.isNotEmpty() }
        }
    }
}
