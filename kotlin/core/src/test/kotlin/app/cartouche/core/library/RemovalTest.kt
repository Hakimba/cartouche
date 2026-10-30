// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.FileName
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.shelves.Shelves
import app.cartouche.core.shelves.selectedLibraries
import app.cartouche.core.shelves.shelfPlatforms
import io.kotest.matchers.collections.shouldNotContain
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldNotContain
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.element
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class RemovalTest {
    private val platforms = shelfPlatforms + PlatformId("other")

    /** A library and its selection, with choices, files set aside and counts for every platform. */
    private val libraries =
        Arb.bind(selectedLibraries, setups) { (library, selection), setup ->
            platforms
                .fold(library) { built, platform ->
                    built.withSetup(platform, setup).copy(
                        notGames = built.notGames + (platform to listOf(listed("bios ${platform.value}.bin"))),
                        ignoredCounts =
                            built.ignoredCounts + (platform to mapOf(CountedReason.HIDDEN to IgnoredCount(1, listOf(FileName(".x"))))),
                        skippedFolders = built.skippedFolders + (platform to listOf(SkippedFolder(FolderPath(".x"), SkipReason.HIDDEN))),
                    )
                }.withConsoleOrder(platforms.reversed()) to selection
        }

    @Test
    fun `INV-13 a removed platform leaves nothing in the library or the selection, and the others are as they were`() = runBlocking<Unit> {
        // "never" is a platform never set up: removing it changes nothing.
        checkAll(libraries, Arb.element(platforms + PlatformId("never"))) { (library, selection), platform ->
            val removed = library.without(platform)
            val forgotten = selection.without(platform)
            // Nothing of it: no key, no game, no id, as stored.
            LibraryFormat.encode(removed).let { stored ->
                stored shouldNotContain "\"${platform.value}\""
                stored shouldNotContain "\"${platform.value}/"
            }
            Shelves.of(removed, platforms, forgotten).onSome { found -> found.shelves.map { it.platform } shouldNotContain platform }

            // The others untouched.
            fun others(of: Library) = listOf(of.setups, of.notGames, of.ignoredCounts, of.skippedFolders).map { it - platform }
            others(removed) shouldBe others(library)
            removed.games shouldBe library.games.filter { it.platform != platform }
            removed.consoleOrder shouldBe library.consoleOrder - platform
            forgotten.games shouldBe selection.games - platform
            forgotten.platform shouldBe selection.platform.filter { it != platform }
        }
    }
}
