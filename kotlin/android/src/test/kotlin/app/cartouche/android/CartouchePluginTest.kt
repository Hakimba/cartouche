// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.graphics.ImageDecoder
import android.os.Looper
import app.cartouche.android.art.OwnPictures
import app.cartouche.android.art.png
import app.cartouche.android.storage.AUTHORITY
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.fileRow
import app.cartouche.android.storage.installDocuments
import app.cartouche.android.storage.rows
import app.cartouche.core.FileName
import app.cartouche.core.library.Disc
import app.cartouche.core.library.Library
import app.cartouche.core.library.ListedFile
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.game
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.definition
import app.cartouche.core.platforms.playerJson
import app.cartouche.core.settings.Setting
import app.cartouche.core.settings.Settings
import app.cartouche.core.settings.SettingsFormat
import app.cartouche.core.settings.settings
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import arrow.core.nonEmptyListOf
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.withClue
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldNotContain
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.property.Arb
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotHost
import org.godotengine.godot.GodotRenderView
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.lang.reflect.Proxy
import java.nio.ByteBuffer
import java.util.concurrent.Executor

/** The plugin's operations, answered on the test's scheduler, read back from the files they write. */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CartouchePluginTest {
    private val context = RuntimeEnvironment.getApplication()

    private inner class Plugin(coming: Array<String> = arrayOf()) {
        val scope = TestScope(StandardTestDispatcher())

        // Godot's instance, made once, keeps the context of the first test: the plugin's files are there.
        private val godot = Godot.getInstance(context)
        val files: File = godot.context.filesDir
        val cache: File = godot.context.cacheDir

        // Every answer the plugin hands Godot, read back as JSON: the render thread's queue is where its signals go.
        val answers = mutableListOf<JsonObject>()
        private var requests = 0
        private val scheduled = StandardTestDispatcher(scope.testScheduler)

        // Planning never runs: no art is looked for, and nothing reaches the network.
        val plugin =
            CartouchePlugin(godot, Threads(scope, scheduled, Executor { }.asCoroutineDispatcher(), scheduled, Dispatchers.IO, scheduled))

        init {
            godot.renderView = queueReadingAnswers()
            // Godot registers the signals natively at start; here they are put where emitting looks them up.
            @Suppress("UNCHECKED_CAST")
            val registered =
                GodotPlugin::class.java
                    .getDeclaredField("registeredSignals")
                    .apply {
                        isAccessible = true
                    }.get(plugin) as MutableMap<String, SignalInfo>
            plugin.pluginSignals.forEach { registered[it.name] = it }
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

        /** The answer to the call [ask] makes with a fresh request id. */
        fun answerTo(ask: (Int) -> Unit): JsonObject {
            val id = ++requests
            ask(id)
            // A step on the main thread (a launch's start) runs in between.
            scope.runCurrent()
            shadowOf(Looper.getMainLooper()).idle()
            scope.runCurrent()
            return answers.last { it.getValue("request_id").jsonPrimitive.int == id }
        }

        // A signal's arguments are the lambda's captured array: its first one is the text Godot receives.
        private fun queueReadingAnswers(): GodotRenderView =
            Proxy.newProxyInstance(GodotRenderView::class.java.classLoader, arrayOf(GodotRenderView::class.java)) { _, method, args ->
                check(method.name == "queueOnRenderThread") { "The plugin used ${method.name}" }
                val event = args.single()
                val captured = event.javaClass.declaredFields.map { it.apply { isAccessible = true }.get(event) }
                (captured.filterIsInstance<Array<*>>().single().single() as String)
                    .let { answers += Json.parseToJsonElement(it).jsonObject }
                null
            } as GodotRenderView

        /** Godot hosted by [activity], as in the app: the plugin starts activities from it. */
        fun hostedBy(activity: Activity) {
            val host =
                Proxy.newProxyInstance(GodotHost::class.java.classLoader, arrayOf(GodotHost::class.java)) { _, method, _ ->
                    when (method.name) {
                        "getActivity" -> activity
                        "getGodot" -> godot
                        else -> null
                    }
                } as GodotHost
            primaryHost.set(godot, host)
        }

        private val primaryHost = Godot::class.java.getDeclaredField("primaryHost").apply { isAccessible = true }

        fun done() {
            scope.runCurrent()
            scope.cancel()
            godot.renderView = null
            primaryHost.set(godot, null)
        }
    }

    private fun JsonObject.text(key: String) = getValue(key).jsonPrimitive.content

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

    /** Calls that write the library, each as Godot makes it; the game and the console exist in the library already. */
    private fun Plugin.writingCalls(): List<Pair<String, (Int) -> Unit>> {
        val okage = "ps2/Okage"
        val setup =
            Dictionary().apply {
                put("disc_grouping", "grouped")
                put("folder_depth", "subfolders")
            }
        return listOf(
            "setUpPlatform" to { id -> plugin.setUpPlatform(id, "ps2", setup) },
            "renameGame" to { id -> plugin.renameGame(id, okage, "Okage, a shadow king") },
            "orderConsoles" to { id -> plugin.orderConsoles(id, arrayOf("ps2")) },
            "placeConsole" to { id -> plugin.placeConsole(id, "ps2", 0) },
            "removePlatform" to { id -> plugin.removePlatform(id, "ps2") },
        )
    }

    private fun Plugin.revisionTold(answer: JsonObject): Int = answer.getValue("revision").jsonPrimitive.int

    @Test
    fun `every call that writes the library answers the revision after its write`() {
        val h = Plugin()
        var told = h.revisionTold(h.answerTo(h.plugin::currentLibrary))
        for ((name, call) in h.writingCalls()) {
            val answer = h.answerTo(call)
            "$name ok" to answer.getValue("ok").jsonPrimitive.content shouldBe ("$name ok" to "true")
            "$name revision" to h.revisionTold(answer) shouldBe ("$name revision" to told + 1)
            told += 1
        }
        h.done()
    }

    @Test
    fun `a library file that cannot be read is answered empty with why, once, and kept aside`() {
        val h = Plugin()
        File(h.files, "library.json").writeText("{\"version\": 2, \"libr")
        val answer = h.answerTo(h.plugin::library)
        withClue(answer.toString()) { answer.getValue("load_problem").jsonPrimitive.content shouldContain "cannot be read" }
        answer.getValue("library").jsonObject.getValue("games").jsonArray.shouldBeEmpty()
        h.files.list().orEmpty().filter { it.startsWith("library.json.unreadable-") }.size shouldBe 1
        h.answerTo(h.plugin::currentLibrary).keys shouldNotContain "load_problem"
        h.done()
    }

    /** Without the revision, Godot would show a re-read's older library over the label just kept. */
    @Test
    fun `keeping an own label answers the revision after its write`() {
        val h = Plugin()
        val told = h.revisionTold(h.answerTo(h.plugin::currentLibrary))
        OwnPictures(File(h.cache, "own-label")).keep(ImageDecoder.createSource(ByteBuffer.wrap(png(400, 200)))).shouldBeRight()
        val answer = h.answerTo { h.plugin.keepOwnLabel(it, "ps2/Okage", 1.0, 0.5, 0.5, 1.0) }
        withClue(answer.toString()) { answer.getValue("ok").jsonPrimitive.content shouldBe "true" }
        h.revisionTold(answer) shouldBe told + 1
        h.done()
    }

    @Test
    fun `coming to the screen reads and deletes nothing of the art on the main thread before any art is asked`() {
        val h = Plugin()
        val left = File(File(h.files, "art/downloads").apply { mkdirs() }, "image.part")
        left.writeText("a download a stopped process left")
        h.plugin.onMainResume()
        h.plugin.onMainPause()
        h.plugin.onMainResume()
        left.exists() shouldBe true
        h.done()
    }

    @Test
    fun `INV-21 a launch whose start comes after the user left Cartouche starts nothing and is told too late`() {
        val h = Plugin()
        installDocuments(document = { rows(fileRow(it)) }) { rows() }
        val file = ListedFile(FileName("Okage.chd"), uri("content://$AUTHORITY/tree/root/document/root%2FOkage.chd"), None, Some(1L))
        LibraryStore(File(h.files, "library.json"))
            .save(Library(games = listOf(game("Okage", discs = nonEmptyListOf(Disc(None, file))))))
            .shouldBeRight()
        val definitions =
            Dictionary().apply {
                definition(playerJson("p", "-a android.intent.action.VIEW -d {file.uri}")).let { put(it.name, it.text) }
            }
        h.plugin.loadCatalog(
            definitions,
            """{"ps2": {"media": "dvd", "medium": {"default": "ps2_dvd"}, "minimumGameBytes": 1}}""",
            "",
            "",
            arrayOf("ps2"),
            arrayOf(),
        )
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        h.hostedBy(activity)
        val request =
            Dictionary().apply {
                put("game_id", "ps2/Okage")
                put("within_ms", 60_000)
            }
        // Asked while on screen, the game starts.
        h.answerTo { h.plugin.launchGame(it, request) }.text("ok") shouldBe "true"
        shadowOf(activity).nextStartedActivity.shouldNotBeNull()
        h.plugin.onMainResume()
        // Asked, then Home pressed before the library thread gets to it.
        val late =
            h.answerTo {
                h.plugin.launchGame(it, request)
                h.plugin.onMainPause()
            }
        late.text("code") shouldBe "too_late"
        shadowOf(activity).nextStartedActivity.shouldBeNull()
        h.done()
    }
}
