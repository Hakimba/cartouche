// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.platforms.ScreenScraperSystem
import arrow.core.Option
import arrow.core.toNonEmptyListOrNone
import kotlinx.serialization.Serializable

/** Where a source serves a scan of a game's medium (see [LabelCut]): an `https://` URL. */
@JvmInline public value class ArtUrl(public val value: String)

/**
 * The version of a platform's art sources: the dates of its extract and of its texture table, such
 * as `2026-09-28 2026-10-18`. Art no source has is looked for again once it changes.
 */
@Serializable @JvmInline
public value class ArtVersion(public val date: String) {
    public companion object {
        /** The version of sources of these versions, dated or not; none when none is dated. */
        public fun of(vararg sources: Option<ArtVersion>): Option<ArtVersion> =
            sources.flatMap { it.toList() }.toNonEmptyListOrNone().map { dated -> ArtVersion(dated.joinToString(" ") { it.date }) }
    }
}

/** A game as ScreenScraper numbers it (`jeuid`). */
@JvmInline public value class ScreenScraperGame(public val id: Int)

/** A ScreenScraper media name, such as `support-texture(jp)[2]`: a texture of one region, of one disc of a multi-disc game. */
@JvmInline public value class TextureMedia(public val name: String)

/**
 * What names a candidate in the store, the traces and what is remembered of it: a scan's URL, a
 * texture's `ss:<system>:<game>:<media>`; never a URL carrying credentials.
 */
@Serializable @JvmInline
public value class Identity(public val value: String) {
    override fun toString(): String = value
}

/**
 * An image a source may have of a game's medium, and how to ask for it: its [identity] names it,
 * its [source] is what the chooser names it by beside its region, and a chosen label remembers.
 */
public sealed interface Candidate {
    /** The region the image is of, as its source names it (`Regions` reads every source's names); empty when none is stated. */
    public val region: String

    public val identity: Identity

    public val source: ArtSource

    /** A scan served at [url], as LaunchBox's extract and the serial sources name theirs. */
    public data class Web(public val url: ArtUrl, override val region: String, override val source: ArtSource) : Candidate {
        override val identity: Identity get() = Identity(url.value)
    }

    /** ScreenScraper's texture [media] of [game] on [system]: the printed label itself, downloaded with the app's key. */
    public data class Texture(
        public val system: ScreenScraperSystem,
        public val game: ScreenScraperGame,
        public val media: TextureMedia,
        override val region: String,
    ) : Candidate {
        override val identity: Identity get() = Identity("ss:${system.id}:${game.id}:${media.name}")

        override val source: ArtSource get() = ArtSource.SCREENSCRAPER
    }
}

/** The image a source has for one [region] of a game. */
public data class ArtVariant(public val region: LabelRegion, public val candidate: Candidate)
