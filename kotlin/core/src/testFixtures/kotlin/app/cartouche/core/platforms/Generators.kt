// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list

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
