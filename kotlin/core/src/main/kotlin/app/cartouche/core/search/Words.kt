// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.search

import app.cartouche.core.library.Folding
import arrow.core.None
import arrow.core.Option
import arrow.core.Some

/**
 * One word of a title as the search reads it: [text] in lowercase Latin letters and digits, accents left out, and
 * where it stands in the title, in code points: it starts at [start], and its first `n` letters end at `ends[n - 1]`
 * (a letter may come from a ligature, or carry its accent apart).
 */
internal data class Word(val text: String, val start: Int, val ends: List<Int>)

/** What the search reads and shows of titles and of what is typed. */
internal object Words {
    /** The words of [title], "the" left out: "The Lord of the Rings" is `lord`, `of`, `rings`. */
    fun of(title: String): List<Word> {
        // Read letter by letter, for thousands of titles at once: local buffers rather than copies.
        val words = mutableListOf<Word>()
        val text = StringBuilder()
        val ends = mutableListOf<Int>()
        var start = 0

        fun end() {
            if (text.isNotEmpty()) words += Word(text.toString(), start, ends.toList())
            text.clear()
            ends.clear()
        }
        title.codePoints().toArray().forEachIndexed { at, codePoint ->
            val letters = Folding.of(codePoint)
            when {
                letters.isNotEmpty() -> {
                    if (text.isEmpty()) start = at
                    text.append(letters)
                    repeat(letters.length) { ends += at + 1 }
                }
                // An accent written apart belongs to the letter before it.
                Folding.isMark(codePoint) -> if (ends.isNotEmpty()) ends[ends.lastIndex] = at + 1
                else -> end()
            }
        }
        end()
        return words.filter { it.text != "the" }
    }

    /** [text] the way titles are read: lowercase Latin letters and digits, every other character a space. */
    fun folded(text: String): String = text.codePoints().toArray().joinToString("") { codePoint -> Folding.of(codePoint).ifEmpty { " " } }

    /**
     * Prefixes typed, each on another of [words] (never on word [skip]), in any order: how many letters of each word
     * one took (0 for none), the first such choice; none when there is none.
     */
    fun taking(words: List<Word>, prefixes: List<String>, skip: Int = -1): Option<IntArray> {
        // Run on thousands of titles at each key typed: one array, filled and emptied as it goes.
        val taken = IntArray(words.size)
        if (skip in words.indices) taken[skip] = -1

        fun fill(at: Int): Boolean {
            if (at == prefixes.size) return true
            for (word in words.indices) {
                if (taken[word] != 0 || !words[word].text.startsWith(prefixes[at])) continue
                taken[word] = prefixes[at].length
                if (fill(at + 1)) return true
                taken[word] = 0
            }
            return false
        }
        return if (fill(0)) Some(taken) else None
    }
}
