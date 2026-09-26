// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.Context
import android.content.Intent
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.LaunchTemplate
import arrow.core.Some
import arrow.core.flatMap
import arrow.core.toOption
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class IntentMapperTest {
    private val context = RuntimeEnvironment.getApplication()
    private val uri = GAME_URI
    private val game = GameFile(FileName("g.chd"), ContentUri.parse(uri).shouldBeSome(), Some(FilePath("/storage/X/g.chd")))

    private fun intentFor(template: String): Intent =
        IntentMapper.toIntent(LaunchTemplate.parse(template).shouldBeRight().resolve(game).shouldBeRight())

    @Test
    fun `INV-E0-12 the game URI handed to the emulator is covered by a read-only grant`() {
        val intent =
            intentFor("-n org.dolphinemu.dolphinemu/.ui.main.MainActivity -a android.intent.action.MAIN -e AutoStartFile {file.uri}")
        intent.clipData.shouldNotBeNull().getItemAt(0).uri.toString() shouldBe uri
        intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION shouldBe Intent.FLAG_GRANT_READ_URI_PERMISSION
    }

    @Test
    fun `INV-E0-12 whatever the template, an intent grants read access to the game URI and nothing else`() = runBlocking<Unit> {
        checkAll(templates) { template ->
            LaunchTemplate.parse(template).flatMap { it.resolve(game) }.onRight { spec ->
                // What startActivity does to the intent before the system reads its grants.
                val intent = IntentMapper.toIntent(spec).also { migrateExtraStreamToClipData.invoke(it, context) }
                val clip = intent.clipData.toOption().fold({ emptyList() }) { c -> (0 until c.itemCount).map { c.getItemAt(it).uri } }
                // Android only grants content URIs; a migrated file:// URI carries flags that grant nothing.
                val granted = (clip + intent.data.toOption().toList()).filter { it.scheme == "content" }.map { it.toString() }
                if (intent.flags and GRANT_FLAGS != 0 && granted.isNotEmpty()) {
                    granted.distinct() shouldBe listOf(uri)
                    intent.flags and GRANT_FLAGS shouldBe Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                spec.grant.isSome() shouldBe (uri in granted && intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            }
        }
    }

    @Test
    fun `INV-E0-12 a launch that hands no URI grants nothing, even with a URI written in the template`() {
        val intent = intentFor("-n com.retroarch.aarch64/.Activity -e ROM {file.path} -e X content://other/document/y")
        intent.clipData.shouldBeNull()
        intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION shouldBe 0
        intent.getStringExtra("ROM") shouldBe "/storage/X/g.chd"
    }

    @Test
    fun `INV-E0-13 launches always start a new task and keep the template's switches`() = runBlocking<Unit> {
        val intent = intentFor("-n com.armsx2/.Main -a android.intent.action.VIEW -d {file.uri} --activity-clear-task")
        intent.component.shouldNotBeNull().className shouldBe "com.armsx2.Main"
        intent.data.toString() shouldBe uri
        intent.flags and (Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK) shouldBe
            (Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        checkAll(templates) { template ->
            LaunchTemplate.parse(template).flatMap { it.resolve(game) }.onRight { spec ->
                val expected =
                    spec.switches.fold(
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                    ) { acc, switch -> acc or with(IntentMapper) { switch.flag } }
                IntentMapper.toIntent(spec).flags and expected shouldBe expected
            }
        }
    }

    private companion object {
        // Hidden API, called by Instrumentation.execStartActivity.
        val migrateExtraStreamToClipData = Intent::class.java.getMethod("migrateExtraStreamToClipData", Context::class.java)

        const val GRANT_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION

        const val GAME_URI = "content://com.android.externalstorage.documents/tree/X/document/X%3Ag.chd"

        val values =
            Arb.element("{file.uri}", GAME_URI, "{file.uri}.sav", "{file.path}", "content://other/document/y", "file:///x", "x", "4")

        val option: Arb<List<String>> =
            Arb.choice(
                Arb.bind(Arb.element("-d", "-e X", "--eu android.intent.extra.STREAM", "--eu output", "--esa L", "-f"), values) { o, v ->
                    listOf(o, "'$v'")
                },
                Arb.element(listOf("--activity-clear-task"), listOf("--activity-no-history")),
            )

        /** Templates that may hand the game URI in any way, and other URIs where Android would grant them. */
        val templates =
            Arb.bind(
                Arb.element(
                    "-n com.a/.Main",
                    "-a android.intent.action.VIEW",
                    "-a android.intent.action.SEND",
                    "-a android.media.action.IMAGE_CAPTURE",
                ),
                Arb.list(option, 0..4),
            ) { target, options -> (listOf(target) + options.flatten()).joinToString(" ") }
    }
}
