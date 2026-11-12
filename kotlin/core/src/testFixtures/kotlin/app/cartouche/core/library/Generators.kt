// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.anyText
import app.cartouche.core.files.Shell
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import arrow.core.toOption
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.filter
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.katakana
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.orNull
import io.kotest.property.arbitrary.string

private val titles = Arb.element("0 Story", "Punisher, The", "Dragon Quest V", "Bleach - Blade Battlers", "Homebrew", "Dr. Muto")
private val tags = Arb.list(Arb.element("(Japan)", "(Europe)", "(EU)", "(En,Fr)", "(Disc 1)", "(Disc 2)", "(v1.1)", "(Beta)"), 0..3)
private val extensions = Arb.element(".chd", ".iso", ".cso", ".bin", ".json", ".txt", "")

/** File names as ROM folders hold them: Redump-style names, hidden files, BIOS files, anything. */
val fileNames: Arb<String> =
    Arb.choice(
        Arb.bind(Arb.element("", "", "", "._", "."), titles, tags, extensions) { hidden, title, t, ext ->
            "$hidden$title ${t.joinToString(" ")}".trim() + ext
        },
        Arb.element("scph39001.bin", "bios.bin", "ps2_bios.bin", "SCPH-70012_BIOS_V12_USA_200.BIN", "armsx2-settings.json"),
        anyText.filter { it.isNotEmpty() }.map { it.replace('/', '_') },
        // Names beyond ASCII: accents, composed or not, and Japanese.
        Arb.element("Pokémon Emerald (Europe).chd", "Poke\u0301mon (Europe).chd", "ドラゴンクエストV (Japan).chd"),
        Arb.string(1..12, Codepoint.katakana()).map { "$it.iso" },
    )

/** A folder's files: realistic names, many discs of the same games, sizes known or not, each a distinct document. */
val folderFiles: Arb<List<ListedFile>> =
    Arb.list(Arb.bind(fileNames, Arb.long(0L..2_000_000_000L).orNull(0.2), ::Pair), 0..12).map { files ->
        files.mapIndexed { i, (name, size) -> listed(name, id = "$i", size = size.toOption()) }
    }

/** A platform's choices: its folder, a chosen player or none, disc grouping and depth. */
val setups: Arb<PlatformSetup> =
    Arb.bind(anyText, Arb.boolean(), Arb.enum<DiscGrouping>(), Arb.enum<FolderDepth>()) { folder, chosen, discs, depth ->
        PlatformSetup(Some(uri("content://p/tree/$folder")), if (chosen) Some(PlayerId("ps2.com.armsx2")) else None, discs, depth)
    }

val skippedFolders: Arb<List<SkippedFolder>> =
    Arb.list(
        Arb.bind(anyText.map(::FolderPath), Arb.enum<SkipReason>(), ::SkippedFolder),
        0..3,
    )

// Never the name of an emulator data folder.
private val nodeNames = Arb.string(1..8, Codepoint.alphanumeric()).filter { FileName(it) !in testDataFolders }

/** Trees of visible, readable folders, three levels deep at most. */
val trees: Arb<List<Node>> = level(3)

private fun level(depth: Int): Arb<List<Node>> {
    val file = nodeNames.map(Node::File)
    val node = if (depth == 0) file else Arb.choice(file, Arb.bind(nodeNames, level(depth - 1), Node::Folder))
    return Arb.list(node, 0..4)
}

/** What a user may type as a game's name: blank, padded, accented, Japanese, far too long. */
val typedNames: Arb<String> =
    Arb.choice(
        Arb.element("", "   ", "Okage", "  Kingdom Hearts II  ", "Ōkami", "ファイナルファンタジーXII", "x".repeat(200), "a\tb"),
        // Spaces and breaks of every kind, and characters outside the basic plane, round the length limit.
        Arb.element("a\u00A0\u00A0b", "a\u3000b", "a\u2028b", "a\r\nb", "\uD83C\uDFAE".repeat(85), "x".repeat(79) + "\uD83C\uDFAE"),
        Arb.string(0..100, Codepoint.katakana()),
        anyText,
    )

/** Label choices: automatic, a region as the art sources name it (known or not, and none), or a picture of the user's own. */
val labelChoices: Arb<LabelChoice> =
    Arb.choice(
        Arb.constant(LabelChoice.Automatic),
        Arb.constant(LabelChoice.Own),
        Arb.element("Japan", "Europe", "North America", "", "Atlantis").map { LabelChoice.Region(LabelRegion(it)) },
        Arb.bind(Arb.element("Japan", "Europe"), Arb.enum<ArtSource>(), ::regionOf),
    )

private fun regionOf(region: String, source: ArtSource) = LabelChoice.Region(LabelRegion(region), source)

private val libraryPlatforms = listOf("ps2", "gba", "gbc", "gc").map(::PlatformId)

private val libraryGames: Arb<Game> =
    Arb.bind(
        Arb.choice(titles, Arb.element("Okage", "Pokémon Crystal", "ドラゴンクエストV")),
        Arb.element(libraryPlatforms),
        Arb.int(1..2),
        labelChoices,
        typedNames.map { DisplayName.of(it) },
        Arb.enum<Shell>(),
    ) { title, platform, discs, label, name, shell ->
        val files = (1..discs).map { Disc(if (discs == 1) None else Some(it), listed("$title $it.chd")) }
        game(title, platform.value, nonEmptyListOf(files.first(), *files.drop(1).toTypedArray()))
            .copy(lastDisc = discs - 1, label = label, displayName = name, shell = shell)
    }

/**
 * Whole libraries: every field a stored library holds, as a user's can after any mix of scans, choices and edits (a
 * label of each kind, a name, a shell, a last disc, ignored counts, skipped folders, an order, variants, a pending scan).
 */
val libraries: Arb<Library> =
    Arb.bind(
        Arb.list(libraryGames, 0..6),
        Arb.list(Arb.bind(Arb.element(libraryPlatforms), setups, ::Pair), 0..4),
        Arb.list(Arb.bind(Arb.element(libraryPlatforms), folderFiles, ::Pair), 0..2),
        Arb.list(Arb.bind(Arb.element(libraryPlatforms), skippedFolders, ::Pair), 0..2),
        Arb.list(Arb.element(libraryPlatforms), 0..4),
        Arb.list(Arb.enum<ConsoleVariant>(), 0..3),
    ) { games, setups, notGames, skipped, order, variants ->
        Library(
            setups = setups.toMap(),
            games = games.distinctBy { it.id },
            notGames = notGames.toMap(),
            ignoredCounts =
                notGames.toMap().mapValues { (_, files) ->
                    mapOf(CountedReason.HIDDEN to IgnoredCount.of(files), CountedReason.UNSUPPORTED to IgnoredCount.of(files.take(1)))
                },
            skippedFolders = skipped.toMap(),
            consoleOrder = order.distinct(),
            consoleVariants = variants.associateBy { it.platform },
            awaitingScan = setups.map { it.first }.take(1).toSet(),
        )
    }
