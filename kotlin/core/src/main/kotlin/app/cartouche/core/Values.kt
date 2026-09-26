// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import arrow.core.Option
import arrow.core.Some

/** An Android application id, such as `org.dolphinemu.dolphinemu`. */
@JvmInline public value class PackageName private constructor(public val value: String) {
    public companion object {
        /** Android's rule: at least two dot-separated segments, each a letter then letters, digits or `_`. */
        private val SYNTAX = Regex("""[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+""")

        public fun parse(text: String): Option<PackageName> = Some(text).filter(SYNTAX::matches).map(::PackageName)
    }
}

/** A `content://` URI, readable by the app that holds (or is granted) access to it. */
@JvmInline public value class ContentUri private constructor(public val value: String) {
    public companion object {
        public fun parse(text: String): Option<ContentUri> = Some(text).filter { it.startsWith("content://") }.map(::ContentUri)
    }
}

/** An absolute filesystem path, such as `/storage/1A2B-3C4D/ROMs/ps2/Game.chd`. */
@JvmInline public value class FilePath(public val value: String)

/** A file name as the user sees it, such as `Game (Europe).chd`. */
@JvmInline public value class FileName(public val value: String) {
    /** Dot files and macOS `._` resource forks: never games. */
    public val isHidden: Boolean get() = value.startsWith('.')
}
