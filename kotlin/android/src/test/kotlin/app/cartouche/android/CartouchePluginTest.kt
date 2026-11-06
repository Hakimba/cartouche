// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SettingsStore
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.settings.Backdrop
import app.cartouche.core.settings.Language
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.util.concurrent.Executor

/** The plugin's operations, answered on the test's scheduler, read back from the files they write. */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class CartouchePluginTest {
    private val context = RuntimeEnvironment.getApplication()

    private inner class Plugin(coming: Array<String> = arrayOf()) {
        val scope = TestScope(StandardTestDispatcher())

        // Godot's instance, made once, keeps the context of the first test: the plugin's files are there.
        private val godot = Godot.getInstance(context)
        val files: File = godot.context.filesDir
        private val scheduled = StandardTestDispatcher(scope.testScheduler)

        // Planning never runs: no art is looked for, and nothing reaches the network.
        val plugin = CartouchePlugin(godot, Threads(scope, scheduled, Executor { }.asCoroutineDispatcher(), scheduled))

        init {
            files.listFiles().orEmpty().forEach { it.deleteRecursively() }
            LibraryStore(File(files, "library.json")).save(Library(games = listOf(game("Okage")))).shouldBeRight()
            val definitions = Dictionary().apply { definition(playerJson("p")).let { put(it.name, it.text) } }
            val profile = """{"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1}"""
            plugin.loadCatalog(
                definitions,
                """{"ps2": $profile}""",
                Dictionary(),
                "",
                "",
                Dictionary(),
                Dictionary(),
                Dictionary(),
                arrayOf("ps2"),
                coming,
            )
        }

        fun settings() = SettingsStore(File(files, "settings.json")).load().shouldBeRight()

        fun done() {
            scope.runCurrent()
            scope.cancel()
        }
    }

    @Test
    fun `INV-15 a sound level is stored once saved, one out of range refused and the level kept`() {
        val h = Plugin()
        h.plugin.saveSetting(1, "sound_level", "4")
        h.scope.runCurrent()
        h.settings().soundLevel.steps shouldBe 4
        h.plugin.saveSetting(2, "sound_level", "11")
        h.scope.runCurrent()
        h.settings().soundLevel.steps shouldBe 4
        h.done()
    }

    @Test
    fun `INV-15 a backdrop is stored once saved, an unknown one refused and the backdrop kept, the next start drawn on it`() {
        val h = Plugin()
        h.plugin.backdrop()["backdrop"] shouldBe "light"
        h.plugin.saveSetting(1, "backdrop", "light_grey")
        h.scope.runCurrent()
        h.settings().backdrop shouldBe Backdrop.LIGHT_GREY
        h.plugin.saveSetting(2, "backdrop", "sepia")
        h.scope.runCurrent()
        h.settings().backdrop shouldBe Backdrop.LIGHT_GREY
        h.plugin.backdrop()["backdrop"] shouldBe "light_grey"
        h.done()
    }

    @Test
    fun `INV-15 the pixel veil is on until switched off, and stored`() {
        val h = Plugin()
        h.settings().pixelVeil shouldBe true
        h.plugin.saveSetting(1, "pixel_veil", "false")
        h.scope.runCurrent()
        h.settings().pixelVeil shouldBe false
        h.plugin.backdrop()["pixel_veil"] shouldBe false
        h.done()
    }

    @Test
    fun `INV-15 a language is stored once saved, an unknown one refused and the language kept, and none follows the device`() {
        val h = Plugin()
        h.plugin.saveSetting(1, "language", "pt_BR")
        h.scope.runCurrent()
        h.settings().language shouldBe Some(Language.BRAZILIAN_PORTUGUESE)
        h.plugin.saveSetting(2, "language", "tlh")
        h.scope.runCurrent()
        h.settings().language shouldBe Some(Language.BRAZILIAN_PORTUGUESE)
        h.plugin.saveSetting(3, "language", "")
        h.scope.runCurrent()
        h.settings().language shouldBe None
        h.done()
    }

    @Test
    fun `a console whose model the app names coming is not added, and one ready is`() {
        val setup =
            Dictionary().apply {
                put("disc_grouping", "grouped")
                put("folder_depth", "subfolders")
            }
        for ((coming, added) in listOf(arrayOf("ps2_slim") to false, arrayOf("ps2_fat") to true)) {
            val h = Plugin(coming)
            h.plugin.setUpPlatform(1, "ps2", setup)
            h.scope.runCurrent()
            val store = LibraryStore(File(h.files, "library.json"))
            (PlatformId("ps2") in store.load().shouldBeRight().library.setups) shouldBe added
            h.done()
        }
    }

    @Test
    fun `INV-15 a console is placed once asked, kept after a restart, and a gap out of range changes nothing`() {
        val h = Plugin()
        val store = LibraryStore(File(h.files, "library.json"))
        store.save(store.load().shouldBeRight().library.withSetup(PlatformId("ps2"), PlatformSetup())).shouldBeRight()
        h.plugin.placeConsole(1, "ps2", 5)
        h.scope.runCurrent()
        store.load().shouldBeRight().library.consoleOrder.shouldBeEmpty()
        h.plugin.placeConsole(2, "ps2", 0)
        h.scope.runCurrent()
        store.load().shouldBeRight().library.consoleOrder shouldBe listOf(PlatformId("ps2"))
        h.done()
    }
}
