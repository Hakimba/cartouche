// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.library.Library
import app.cartouche.core.library.setups
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Some
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SettingsTest {
    /** Libraries with one platform set up or more, whatever their choices. */
    private val setUpLibraries: Arb<Library> =
        Arb.list(Arb.bind(Arb.element("ps2", "gc", "gba").map(::PlatformId), setups, ::Pair), 1..3).map { platforms ->
            platforms.fold(Library()) { library, (id, setup) -> library.withSetup(id, setup) }
        }

    @Test
    fun `INV-E6-05 an app with a platform set up is past its first launch, whatever its settings`() = runBlocking<Unit> {
        checkAll(settings, setUpLibraries) { settings, library -> settings.isFirstLaunch(library) shouldBe false }
    }

    @Test
    fun `INV-E6-05 once a button style is chosen, the first launch is over, even with no platform yet`() = runBlocking<Unit> {
        checkAll(Arb.enum<ButtonStyle>()) { style -> Settings(Some(style)).isFirstLaunch(Library()) shouldBe false }
    }

    @Test
    fun `a sound level is one of 0 to 10, full until turned down`() = runBlocking<Unit> {
        checkAll(Arb.int(-50..50)) { steps -> SoundLevel.of(steps).map { it.steps } shouldBe (if (steps in 0..10) Some(steps) else None) }
        Settings().soundLevel shouldBe SoundLevel.FULL
        SoundLevel.FULL.steps shouldBe SoundLevel.MAX
    }

    @Test
    fun `INV-E6-05 a fresh install, with no settings and no platform, is on its first launch`() {
        Settings().isFirstLaunch(Library()) shouldBe true
    }

    @Test
    fun `INV-E8-02 a fresh install smooths the edges 4x`() {
        Settings().edgeSmoothing shouldBe EdgeSmoothing.FOUR_TIMES
    }

    @Test
    fun `INV-E12-C1-02 games float off by default`() {
        Settings().gamesFloat shouldBe false
    }
}
