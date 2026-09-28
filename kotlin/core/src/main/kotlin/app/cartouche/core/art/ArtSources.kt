// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.Game
import arrow.core.Option
import arrow.core.toNonEmptyListOrNone

/** Where one platform's disc scans are looked for: its LaunchBox extract by title, then its [bySerial] source. */
public class ArtSources(private val index: ArtIndex, private val bySerial: Option<SerialScans>) {
    /** The extract's version, which each request carries. */
    public val version: Option<ArtVersion> get() = index.version

    /** How many games the extract knows. */
    public val size: Int get() = index.size

    /**
     * Where to look for [game]'s disc scan: the extract's, closest to its regions first, then the
     * scans of its serials; none when no source can have one.
     */
    public fun requestFor(game: Game): Option<ArtRequest> =
        (index.scansOf(game.title, game.regions) + bySerial.fold({ emptyList() }) { it.scansOf(game.serials) })
            .toNonEmptyListOrNone()
            .map { ArtRequest(game.id, game.title, it, version) }
}
