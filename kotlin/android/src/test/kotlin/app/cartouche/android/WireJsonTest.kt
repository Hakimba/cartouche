// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.FileName
import app.cartouche.core.library.ArtSource
import app.cartouche.core.library.ConsoleVariant
import app.cartouche.core.library.CountedReason
import app.cartouche.core.library.Disc
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderPath
import app.cartouche.core.library.Game
import app.cartouche.core.library.GameId
import app.cartouche.core.library.IgnoredCount
import app.cartouche.core.library.LabelChoice
import app.cartouche.core.library.LabelRegion
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.SkipReason
import app.cartouche.core.library.SkippedFolder
import app.cartouche.core.library.listed
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.catalog
import app.cartouche.core.platforms.definition
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.Shelves
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.toOption
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.arbitrary
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class WireJsonTest {
    private val ps2 = catalog(definition())

    // Everything JSON escapes, the edges of what it does not, and text outside ASCII, a lone surrogate included.
    private val pieces =
        listOf("a", "Z", " ", "\"", "\\", "/", "\n", "\t", "\u0000", "\u001f", "\u007f", "\u0080", "é", "日", "😀", "\ud800", " ")
    private val text: Arb<String> = Arb.list(Arb.element(pieces), 0..6).map { it.joinToString("") }

    private val platforms = listOf(PlatformId("ps2"), PlatformId("gba"), PlatformId("unlisted"))

    private fun <T> Arb<T>.optional(): Arb<Option<T>> =
        Arb.boolean().let { some -> arbitrary { rs -> if (some.sample(rs).value) Some(sample(rs).value) else None } }

    private fun <T> Arb<T>.few(): Arb<List<T>> = Arb.list(this, 0..3)

    private val disc =
        arbitrary { rs ->
            Disc(Arb.int(0..9).optional().sample(rs).value, listed(text.sample(rs).value, "d${rs.random.nextInt()}"))
        }

    private val game: Arb<Game> =
        arbitrary { rs ->
            val chosen = rs.random.nextInt(platforms.size)
            val title = text.sample(rs).value
            Game(
                GameId("${platforms[chosen].value}/${rs.random.nextInt()}"),
                platforms[chosen],
                title,
                text.few().sample(rs).value,
                text.few().sample(rs).value,
                text.optional().sample(rs).value,
                text.few().sample(rs).value,
                text.optional().sample(rs).value,
                nonEmptyListOf(disc.sample(rs).value, *Arb.list(disc, 0..2).sample(rs).value.toTypedArray()),
                (0..2).random(rs.random),
                Arb
                    .element(
                        LabelChoice.Automatic,
                        LabelChoice.Own,
                        LabelChoice.Region(LabelRegion("Japan"), ArtSource.SCREENSCRAPER),
                        LabelChoice.Region(LabelRegion("USA")),
                    ).sample(rs)
                    .value,
                text.optional().sample(rs).value.flatMap { DisplayName.of(it) },
            )
        }

    private val library: Arb<Library> =
        arbitrary { rs ->
            val withSetups = platforms.filter { rs.random.nextBoolean() }
            Library(
                setups =
                    withSetups.associateWith {
                        PlatformSetup(
                            text
                                .optional()
                                .sample(rs)
                                .value
                                .flatMap {
                                    it.takeIf(String::isNotBlank).toOption()
                                }.map { app.cartouche.core.uri("content://p/${it.length}") },
                        )
                    },
                games = Arb.list(game, 0..8).sample(rs).value,
                notGames = withSetups.associateWith { Arb.list(text, 0..3).sample(rs).value.map { listed(it, "n${rs.random.nextInt()}") } },
                ignoredCounts =
                    withSetups.associateWith {
                        CountedReason.entries.associateWith {
                            IgnoredCount(
                                (0..99).random(rs.random),
                                Arb
                                    .list(
                                        text,
                                        0..3,
                                    ).sample(rs)
                                    .value
                                    .map(::FileName),
                            )
                        }
                    },
                skippedFolders =
                    withSetups.associateWith {
                        Arb.list(text, 0..2).sample(rs).value.map { SkippedFolder(FolderPath(it), SkipReason.HIDDEN) }
                    },
                consoleVariants = if (rs.random.nextBoolean()) mapOf(PlatformId("ps2") to ConsoleVariant.PS2_FAT) else emptyMap(),
            )
        }

    private fun Library.shelves(catalog: Catalog) = Shelves.of(this, catalog.platforms.map { it.id }, Selection())

    @Test
    fun `INV-23 the library's JSON is character for character what the tree of elements wrote, for any library`(): Unit = runBlocking {
        var withGames = 0
        var withShelves = 0
        checkAll(300, library) { library ->
            val shelves = library.shelves(ps2)
            library.toWireJson(shelves, ps2) shouldBe library.toWireJsonTree(shelves, ps2)
            library.toWireJson(None, ps2) shouldBe library.toWireJsonTree(None, ps2)
            if (library.games.isNotEmpty()) withGames++
            if (shelves.isSome()) withShelves++
        }
        (withGames > 100 && withShelves > 0) shouldBe true
    }
}
