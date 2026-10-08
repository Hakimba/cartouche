// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.Context
import android.content.Intent
import app.cartouche.core.launch.GAME_URI
import app.cartouche.core.launch.LaunchTemplate
import app.cartouche.core.launch.forEveryResolvedTemplate
import app.cartouche.core.launch.sdGame
import arrow.core.toOption
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class IntentMapperTest {
    private val context = RuntimeEnvironment.getApplication()

    private fun intentFor(template: String): Intent =
        IntentMapper.toIntent(LaunchTemplate.parse(template).shouldBeRight().resolve(sdGame).shouldBeRight())

    @Test
    fun `INV-E0-12 the game URI handed to the emulator is covered by a read-only grant`() {
        val intent =
            intentFor("-n org.dolphinemu.dolphinemu/.ui.main.MainActivity -a android.intent.action.MAIN -e AutoStartFile {file.uri}")
        intent.clipData.shouldNotBeNull().getItemAt(0).uri.toString() shouldBe GAME_URI
        intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION shouldBe Intent.FLAG_GRANT_READ_URI_PERMISSION
    }

    @Test
    fun `INV-E0-12 whatever the template, an intent grants read access to the game URI and nothing else`() = runBlocking<Unit> {
        var handed = 0
        forEveryResolvedTemplate { _, spec ->
            // What startActivity does to the intent before the system reads its grants.
            val intent = IntentMapper.toIntent(spec).also { migrateExtraStreamToClipData.invoke(it, context) }
            val clip = intent.clipData.toOption().fold({ emptyList() }) { c -> (0 until c.itemCount).map { c.getItemAt(it).uri } }
            // Android only grants content URIs; a migrated file:// URI carries flags that grant nothing.
            val granted = (clip + intent.data.toOption().toList()).filter { it.scheme == "content" }.map { it.toString() }
            if (intent.flags and GRANT_FLAGS != 0 && granted.isNotEmpty()) {
                granted.distinct() shouldBe listOf(GAME_URI)
                intent.flags and GRANT_FLAGS shouldBe Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            spec.grant.isSome() shouldBe (GAME_URI in granted && intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
            if (spec.grant.isSome()) handed++
        }
        handed shouldBeGreaterThan 100
    }

    @Test
    fun `INV-E0-12 a launch that hands no URI grants nothing, even with a URI written in the template`() {
        val intent = intentFor("-n com.retroarch.aarch64/.Activity -e ROM {file.path} -e X content://other/document/y")
        intent.clipData.shouldBeNull()
        intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION shouldBe 0
        intent.getStringExtra("ROM") shouldBe "/storage/1A2B-3C4D/ROMs/ps2/Burnout 3 - Takedown (Europe).chd"
    }

    @Test
    fun `INV-E0-13 launches always start a new task and keep the template's switches`() = runBlocking<Unit> {
        val intent = intentFor("-n com.armsx2/.Main -a android.intent.action.VIEW -d {file.uri} --activity-clear-task")
        intent.component.shouldNotBeNull().className shouldBe "com.armsx2.Main"
        intent.data.toString() shouldBe GAME_URI
        intent.flags and (Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK) shouldBe
            (Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        forEveryResolvedTemplate { _, spec ->
            val expected =
                spec.switches.fold(Intent.FLAG_ACTIVITY_NEW_TASK) { flags, switch -> flags or with(IntentMapper) { switch.flag } }
            IntentMapper.toIntent(spec).flags and expected shouldBe expected
        }
    }

    private companion object {
        // Hidden API, called by Instrumentation.execStartActivity.
        val migrateExtraStreamToClipData = Intent::class.java.getMethod("migrateExtraStreamToClipData", Context::class.java)

        const val GRANT_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
    }
}
