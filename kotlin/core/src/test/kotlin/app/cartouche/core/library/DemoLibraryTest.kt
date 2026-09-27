// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import io.kotest.matchers.shouldBe
import org.junit.Test

class DemoLibraryTest {
    private val platforms = listOf("ps2", "gc", "gba").map(::PlatformId)

    @Test
    fun `a demo library has as many distinct games as asked for, spread evenly over the platforms`() {
        val library = DemoLibrary.of(1_000, platforms)
        library.games.map { it.id }.distinct().size shouldBe 1_000
        library.games.groupingBy { it.platform }.eachCount() shouldBe mapOf(platforms[0] to 334, platforms[1] to 333, platforms[2] to 333)
    }

    @Test
    fun `a demo library is always the same for the same arguments`() {
        DemoLibrary.of(1_000, platforms) shouldBe DemoLibrary.of(1_000, platforms)
    }

    @Test
    fun `a demo library without platforms is empty`() {
        DemoLibrary.of(10, emptyList()) shouldBe Library()
    }
}
