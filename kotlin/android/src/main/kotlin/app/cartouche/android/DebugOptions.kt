// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.longOrNone
import arrow.core.Option
import arrow.core.firstOrNone
import arrow.core.getOrElse
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

/** Launch-intent switches read by debug builds only (see `CartouchePlugin.launchArguments`). */
internal class DebugOptions(private val arguments: List<String>) {
    private fun valueOf(name: String): Option<String> = arguments.firstOrNone { it.startsWith("$name=") }.map { it.removePrefix("$name=") }

    val artRefused: Boolean = "--art-refused" in arguments

    /** `--art-slow=MS`: a wait after each chunk read, to see a download's progress. */
    val artSlow: Duration = valueOf("--art-slow").flatMap { it.longOrNone() }.map { it.milliseconds }.getOrElse { Duration.ZERO }

    /** `--screenscraper=quota`, `wrong-key` or `wrong-account`. */
    val screenScraper: Option<String> = valueOf("--screenscraper")

    companion object {
        val NONE = DebugOptions(emptyList())
    }
}
