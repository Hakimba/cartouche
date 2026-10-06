// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.LabelRegion
import kotlinx.serialization.Serializable

/** Where a source serves a scan of a game's medium, its printed face: an `https://` URL. */
@JvmInline public value class ArtUrl(public val value: String)

/**
 * The version of an art extract: the date of the database it comes from, such as `2026-09-28`.
 * Art no source has is looked for again once it changes.
 */
@Serializable @JvmInline
public value class ArtVersion(public val date: String)

/** The disc scan a source has for one [region] of a game. */
public data class ArtVariant(public val region: LabelRegion, public val url: ArtUrl)
