// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.settings.Settings
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
class SettingsStoreTest {
    private val file = File(RuntimeEnvironment.getApplication().filesDir, "settings.json")

    @Test
    fun `saved settings load back, and no file means none set`() {
        val settings = Settings(Some(ButtonStyle.PLAYSTATION), EdgeSmoothing.OFF)
        SettingsStore(file).load().shouldBeRight(Settings())
        SettingsStore(file).save(settings).shouldBeRight()
        SettingsStore(file).load().shouldBeRight(settings)
    }

    @Test
    fun `a damaged settings file is reported, and replaced by the next save`() {
        file.writeText("{")
        SettingsStore(file).load().shouldBeLeft()
        SettingsStore(file).save(Settings()).shouldBeRight()
        SettingsStore(file).load().shouldBeRight(Settings())
    }
}
