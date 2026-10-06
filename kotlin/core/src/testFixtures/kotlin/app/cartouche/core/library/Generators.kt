// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
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
        Arb.string(1..20).map { it.replace('/', '_') },
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
    Arb.bind(Arb.string(), Arb.boolean(), Arb.enum<DiscGrouping>(), Arb.enum<FolderDepth>()) { folder, chosen, discs, depth ->
        PlatformSetup(Some(uri("content://p/tree/$folder")), if (chosen) Some(PlayerId("ps2.com.armsx2")) else None, discs, depth)
    }

val skippedFolders: Arb<List<SkippedFolder>> =
    Arb.list(
        Arb.bind(Arb.string().map(::FolderPath), Arb.enum<SkipReason>(), ::SkippedFolder),
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
        Arb.string(0..100),
    )

/** Label choices: automatic, a region as the art sources name it (known or not, and none), or a picture of the user's own. */
val labelChoices: Arb<LabelChoice> =
    Arb.choice(
        Arb.constant(LabelChoice.Automatic),
        Arb.constant(LabelChoice.Own),
        Arb.element("Japan", "Europe", "North America", "", "Atlantis").map { LabelChoice.Region(LabelRegion(it)) },
    )
