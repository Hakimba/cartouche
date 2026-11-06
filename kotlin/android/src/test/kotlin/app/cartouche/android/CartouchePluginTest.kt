// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.android.storage.LibraryStore
import app.cartouche.core.library.Library
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.settings.Setting
import app.cartouche.core.settings.Settings
import app.cartouche.core.settings.SettingsFormat
import app.cartouche.core.settings.settings
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.SignalInfo
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
            plugin.loadCatalog(definitions, """{"ps2": $profile}""", "", "", arrayOf("ps2"), coming)
        }

        fun settings(): Settings = File(files, "settings.json").let {
            if (it.exists()) SettingsFormat.decode(it.readText()).shouldBeRight() else Settings()
        }

        fun backdrop() = Json.parseToJsonElement(plugin.backdrop()).jsonObject

        fun done() {
            scope.runCurrent()
            scope.cancel()
        }
    }

    private fun JsonObject.text(key: String) = getValue(key).jsonPrimitive.content

    @Test
    fun `INV-23 every signal of the plugin hands Godot JSON text`() {
        val h = Plugin()
        val types = SignalInfo::class.java.getDeclaredMethod("getParamTypes").apply { isAccessible = true }
        h.plugin.pluginSignals.map { (types.invoke(it) as Array<*>).toList() }.distinct() shouldBe listOf(listOf(String::class.java))
        h.done()
    }

    @Test
    fun `INV-15 any setting saved is stored and drawn from at the next start, and a value it does not take changes nothing`() =
        runBlocking<Unit> {
            val h = Plugin()
            var request = 0

            fun save(setting: Setting, written: String) {
                h.plugin.saveSetting(++request, setting.key, written)
                h.scope.runCurrent()
            }
            checkAll(20, settings, Arb.string(0..6)) { wanted, junk ->
                Setting.all.forEach { setting ->
                    setting.valueIn(wanted).onSome { value ->
                        val before = h.settings()
                        save(setting, value.written)
                        h.settings() shouldBe setting.change(before, value.written).shouldBeRight()
                    }
                    val kept = h.settings()
                    if (setting.change(kept, junk).isLeft()) {
                        save(setting, junk)
                        h.settings() shouldBe kept
                    }
                }
                h.backdrop() shouldBe Json.parseToJsonElement(jsonOf(h.settings().sentBackdrop())).jsonObject
            }
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
