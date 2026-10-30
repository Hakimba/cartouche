// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import arrow.core.Option

/** What to do with an emulator instance still running in the background when a new game starts. */
public enum class RunningInstance { KEEP, STOP }

/**
 * A game file as the launcher sees it. [uri] is readable once granted; [path] is its filesystem path, when it has one
 * (templates using `{file.path}` need it).
 */
public data class GameFile(public val name: FileName, public val uri: ContentUri, public val path: Option<FilePath>) {
    /** Values of the template placeholders; `file.path` is absent without a path. */
    internal val placeholders: Map<String, String>
        get() = mapOf("file.uri" to uri.value) + path.map { "file.path" to it.value }.toList()
}
