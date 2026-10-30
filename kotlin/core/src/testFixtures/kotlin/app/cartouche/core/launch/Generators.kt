// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import arrow.core.flatMap
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll

private val values: Arb<String> =
    Arb.choice(
        // The game itself, often enough for launches handing it to be common.
        Arb.constant("{file.uri}"),
        Arb.element(
            "{file.uri}",
            GAME_URI,
            "{file.uri}.sav",
            "{file.path}",
            " CONTENT://x",
            "content://evil/document/x",
            "content://com.android.externalstorage.documents/tree/X",
            "file:///x",
        ),
        Arb.string(0..12),
    )

// The extra keys Android copies into the intent's ClipData, where it grants them.
private val extraKeys: Arb<String> = Arb.choice(Arb.element("android.intent.extra.STREAM", "output"), Arb.string(1..6))

private val options: Arb<List<String>> =
    Arb.choice(
        Arb.bind(
            Arb.element("-e", "--es", "--ez", "--ei", "--eu", "--esa"),
            extraKeys,
            values,
        ) { option, key, value -> listOf(option, key, value) },
        Arb.bind(Arb.element("-a", "-d", "-t", "-c", "-f"), values) { option, value -> listOf(option, value) },
        Arb.element(ActivitySwitch.entries.map { listOf(it.option) }),
        Arb.constant(listOf("--esn", "key")),
    )

private val targets: Arb<List<String>> =
    Arb.element(
        listOf("-n", "com.a/.Main"),
        listOf("-n", "b.c/d.E"),
        listOf("-a", "android.intent.action.VIEW"),
        listOf("-a", "android.intent.action.SEND"),
        listOf("-a", "android.media.action.IMAGE_CAPTURE"),
    )

/**
 * Templates built from the grammar: most of them valid, with placeholders, literal URIs (the game's
 * written by hand among them) and the actions and extras Android grants URIs for.
 */
val templates: Arb<String> =
    Arb.bind(targets, Arb.list(options, 0..8)) { target, options ->
        (target + options.flatten()).joinToString(" ") {
            "'${it.replace("'", "")}'"
        }
    }

/** Runs [property] on the launches that generated templates resolve to for [game]; fails when too few resolve to say anything. */
suspend fun forEveryResolvedTemplate(game: GameFile = sdGame, property: suspend (Template, LaunchSpec) -> Unit) {
    var resolved = 0
    checkAll(templates) { text ->
        LaunchTemplate.parse(text).flatMap { template -> template.resolve(game).map { template to it } }.onRight { (template, spec) ->
            resolved++
            property(template, spec)
        }
    }
    check(resolved >= RESOLVED_AT_LEAST) { "Only $resolved generated templates resolved" }
}

/** Of the 100 cases an ordinary property runs. */
private const val RESOLVED_AT_LEAST = 30
