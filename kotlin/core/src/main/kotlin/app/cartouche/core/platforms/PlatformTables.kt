// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import arrow.core.None
import arrow.core.Option

/**
 * One platform's bundled data tables, each the text of its file (`app/data/<table>/<platform>.tsv`), none when the
 * app has no such table for it: its reference list of [titles], its cartridges' [prints], its LaunchBox [art]
 * extract and ScreenScraper's [textures] table.
 */
public data class PlatformTables(
    val titles: Option<String> = None,
    val prints: Option<String> = None,
    val art: Option<String> = None,
    val textures: Option<String> = None,
)
