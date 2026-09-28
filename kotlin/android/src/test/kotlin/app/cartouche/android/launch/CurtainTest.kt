// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.app.Activity
import android.graphics.PixelFormat
import android.os.Looper
import android.view.View
import android.view.WindowManager.LayoutParams
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.left
import arrow.core.right
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowSettings
import org.robolectric.shadows.ShadowWindowManagerImpl
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import kotlin.time.toJavaDuration

@RunWith(RobolectricTestRunner::class)
class CurtainTest {
    private sealed interface Step {
        data class Raise(val millis: Long) : Step

        data object Lower : Step

        data class Wait(val millis: Long) : Step

        data class Allow(val allowed: Boolean) : Step
    }

    private val activity = Robolectric.buildActivity(Activity::class.java).setup().get()

    // As the plugin makes it: on the application, which outlives the activity.
    private val curtain = Curtain(activity.applicationContext, CoroutineScope(Dispatchers.Main))

    private val steps: Arb<Step> =
        Arb.choice(
            Arb.choice(Arb.constant(0L), Arb.long(1L..3_000L)).map(Step::Raise),
            Arb.constant(Step.Lower),
            Arb.long(0L..3_000L).map(Step::Wait),
            Arb.boolean().map(Step::Allow),
        )

    private fun curtains(): List<View> = Shadow.extract<ShadowWindowManagerImpl>(activity.windowManager).views.filter {
        (it.layoutParams as LayoutParams).type == LayoutParams.TYPE_APPLICATION_OVERLAY
    }

    private fun idle(millis: Long) = shadowOf(Looper.getMainLooper()).idleFor(millis.milliseconds.toJavaDuration())

    @After
    fun lowered() = curtain.lower()

    @Test
    fun `without the permission, no curtain is raised`() {
        ShadowSettings.setCanDrawOverlays(false)
        curtain.raise(2.seconds)
        curtains() shouldHaveSize 0
    }

    @Test
    fun `a curtain of no time is none`() {
        ShadowSettings.setCanDrawOverlays(true)
        curtain.raise(Duration.ZERO)
        curtains() shouldHaveSize 0
    }

    @Test
    fun `a curtain is an opaque window over the whole screen that leaves the controller to the emulator`() {
        ShadowSettings.setCanDrawOverlays(true)
        curtain.raise(2.seconds)
        val layout = curtains().single().layoutParams as LayoutParams
        (layout.flags and LayoutParams.FLAG_NOT_FOCUSABLE) shouldBe LayoutParams.FLAG_NOT_FOCUSABLE
        // Touchable: a window touches go through is capped at 80 % opacity.
        (layout.flags and LayoutParams.FLAG_NOT_TOUCHABLE) shouldBe 0
        layout.format shouldBe PixelFormat.OPAQUE
        layout.width shouldBe LayoutParams.MATCH_PARENT
        layout.height shouldBe LayoutParams.MATCH_PARENT
    }

    @Test
    fun `INV-E3-06 a start runs under its curtain, which comes down at once if the start fails`() {
        ShadowSettings.setCanDrawOverlays(true)
        var upDuringStart = 0
        curtain.over(2.seconds) { "refused".left().also { upDuringStart = curtains().size } }
        upDuringStart shouldBe 1
        curtains() shouldHaveSize 0
        curtain.over(2.seconds) { Unit.right() }
        curtains() shouldHaveSize 1
    }

    @Test
    fun `INV-E3-06 whatever happens, a curtain is up exactly until its time is up or it is lowered, and never two`() = runBlocking<Unit> {
        var raised = 0
        checkAll(Arb.list(steps, 1..12)) { script ->
            ShadowSettings.setCanDrawOverlays(true)
            curtain.lower()
            var allowed = true
            // The model: when the curtain up comes down; none when no curtain is up.
            var now = 0L
            var downAt: Option<Long> = None
            script.forEach { step ->
                when (step) {
                    is Step.Raise -> {
                        curtain.raise(step.millis.milliseconds)
                        if (allowed && step.millis > 0 && downAt.isNone()) downAt = Some(now + step.millis)
                    }
                    Step.Lower -> {
                        curtain.lower()
                        downAt = None
                    }
                    is Step.Wait -> {
                        idle(step.millis)
                        now += step.millis
                        downAt = downAt.filter { now < it }
                    }
                    is Step.Allow -> {
                        ShadowSettings.setCanDrawOverlays(step.allowed)
                        allowed = step.allowed
                    }
                }
                curtains() shouldHaveSize (if (downAt.isSome()) 1 else 0)
                raised += curtains().size
            }
        }
        raised shouldBeGreaterThan 0
    }
}
