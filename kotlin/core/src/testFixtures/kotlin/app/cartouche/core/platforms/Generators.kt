// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string

private val jsonValues: Arb<String> = Arb.element("\"x\"", "\"^.*$\"", "\"(\"", "1", "true", "null", "[]", "{}", "\"-n a.b/.C\"")

private val players: Arb<String> =
    Arb.bind(
        Arb.list(Arb.element("uniqueId", "name", "acceptedFilenameRegex", "amStartArguments", "killPackageProcesses")),
        jsonValues,
        Arb.boolean(),
    ) { keys, value, flag ->
        keys.joinToString(prefix = "{", postfix = "}") { key -> "\"$key\": ${if (key == "killPackageProcesses") flag else value}" }
    }

/** Definition files built from the Daijishō structure, with fields missing, mistyped or invalid. */
val definitionTexts: Arb<String> =
    Arb.bind(jsonValues, Arb.list(players, 0..4)) { value, players ->
        """{"platform": {"uniqueId": $value, "name": "P", "acceptedFilenameRegex": $value}, "playerList": [${players.joinToString()}]}"""
    }

/** Package names such as `org.a1x`. */
val packageNames: Arb<String> = Arb.string(1..8, Codepoint.alphanumeric()).map { "org.a$it" }

/** Curtain times the curtain file accepts, in milliseconds, from none to the longest. */
val curtainMillis: Arb<Long> = Arb.long(0L..CurtainTimes.LONGEST.inWholeMilliseconds)
