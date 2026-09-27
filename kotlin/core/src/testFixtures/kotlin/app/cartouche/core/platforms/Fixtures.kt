// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

/** A Daijishō player as JSON text. */
fun playerJson(id: String, template: String = "-n com.armsx2/.Main -d {file.uri}", pattern: String = "^.*\\\\.chd$"): String =
    """{"uniqueId": "$id", "name": "$id", "acceptedFilenameRegex": "$pattern", "amStartArguments": "$template", "killPackageProcesses": true}"""

/** A Daijishō definition file of [platform] with [players] (see [playerJson]). */
fun definition(vararg players: String, platform: String = "ps2", pattern: String = "^.*$", name: String = "test.json"): DefinitionSource =
    DefinitionSource(
        name,
        """{"platform": {"uniqueId": "$platform", "name": "$platform", "acceptedFilenameRegex": "$pattern"}, "playerList": [${players.joinToString()}]}""",
    )

/** The catalog of [definitions], with a DVD profile for the `ps2` and `test` platforms. */
fun catalog(vararg definitions: DefinitionSource, minimumGameBytes: Long = 1_000_000): Catalog {
    val profile = """{"media": "dvd", "minimumGameBytes": $minimumGameBytes}"""
    return Catalog.parse(definitions.toList(), DefinitionSource("profiles.json", """{"ps2": $profile, "test": $profile}"""))
}
