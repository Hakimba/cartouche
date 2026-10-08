// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.content.Intent
import android.os.BatteryManager
import android.os.Looper
import arrow.core.Some
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class BatteryTest {
    private val context = RuntimeEnvironment.getApplication()

    // No charger, each kind, two at once and one this Android does not name.
    private val chargers =
        Arb.element(
            0,
            BatteryManager.BATTERY_PLUGGED_AC,
            BatteryManager.BATTERY_PLUGGED_USB,
            BatteryManager.BATTERY_PLUGGED_WIRELESS,
            BatteryManager.BATTERY_PLUGGED_DOCK,
            BatteryManager.BATTERY_PLUGGED_AC or BatteryManager.BATTERY_PLUGGED_USB,
            16,
        )

    // What the broadcast also carries, changing between two that tell the same.
    private fun broadcast(level: Int, scale: Int, plugged: Int, temperature: Int = 250) = Intent(Intent.ACTION_BATTERY_CHANGED)
        .putExtra(BatteryManager.EXTRA_LEVEL, level)
        .putExtra(BatteryManager.EXTRA_SCALE, scale)
        .putExtra(BatteryManager.EXTRA_PLUGGED, plugged)
        .putExtra(BatteryManager.EXTRA_TEMPERATURE, temperature)
        .putExtra(BatteryManager.EXTRA_VOLTAGE, 4000 + temperature)

    @Test
    fun `the bolt shows exactly while a charger is plugged in, the level as a part of its scale`() = runBlocking<Unit> {
        var known = 0
        checkAll(Arb.int(-5..300), Arb.int(-5..300), chargers) { level, scale, plugged ->
            val state = BatteryState.of(broadcast(level, scale, plugged))
            val wire = state.toWire()
            wire["plugged"] shouldBe (plugged != 0)
            // Known for a level within its scale, but for 0: the whole percentage it reaches.
            state.levelPercent.isSome() shouldBe (scale > 0 && level in 1..scale)
            state.levelPercent.onSome { percent ->
                known++
                wire["level_percent"] shouldBe percent
                (percent * scale <= level * 100 && level * 100 < (percent + 1) * scale) shouldBe true
            }
            wire.containsKey("level_percent") shouldBe state.levelPercent.isSome()
        }
        known shouldBeGreaterThan 100
    }

    @Test
    fun `a broadcast without its battery's extras, or from a device without a battery, tells nothing`() {
        BatteryState.of(Intent(Intent.ACTION_BATTERY_CHANGED)) shouldBe BatteryState.NONE
        val noBattery = broadcast(50, 100, BatteryManager.BATTERY_PLUGGED_AC).putExtra(BatteryManager.EXTRA_PRESENT, false)
        BatteryState.of(noBattery) shouldBe BatteryState.NONE
    }

    @Test
    fun `each change is told as it is heard, and nothing else`() = runBlocking<Unit> {
        val heard = Arb.list(Arb.element(Pair(40, 0), Pair(40, 1), Pair(41, 1), Pair(41, 2)), 0..12)
        checkAll(heard, Arb.list(Arb.int(200..400), 12..12)) { states, temperatures ->
            val told = mutableListOf<BatteryState>()
            val watch = BatteryWatch { told.add(it) }
            states.forEachIndexed { i, (level, plugged) -> watch.onReceive(context, broadcast(level, 100, plugged, temperatures[i])) }
            // The states heard, each told once as it first comes after another.
            val expected = states.map { (level, plugged) -> BatteryState(Some(level), plugged != 0) }
            told shouldBe expected.filterIndexed { i, state -> i == 0 || state != expected[i - 1] }
        }
    }

    @Test
    fun `followed, the battery is told at once then as it changes, and nothing once stopped`() {
        val told = mutableListOf<BatteryState>()
        val watch = BatteryWatch { told.add(it) }
        val send = { level: Int, plugged: Int ->
            @Suppress("DEPRECATION")
            context.sendStickyBroadcast(broadcast(level, 100, plugged))
            shadowOf(Looper.getMainLooper()).idle()
        }
        val registered = { shadowOf(context).registeredReceivers.count { it.broadcastReceiver === watch } }
        // Stopped before ever followed, as a pause before the first resume: nothing to undo.
        watch.stop(context)
        send(57, BatteryManager.BATTERY_PLUGGED_USB)
        // Followed twice, as by two resumes: registered once.
        watch.follow(context)
        watch.follow(context)
        registered() shouldBe 1
        shadowOf(Looper.getMainLooper()).idle()
        told shouldBe listOf(BatteryState(Some(57), plugged = true))
        BatteryState.now(context) shouldBe BatteryState(Some(57), plugged = true)
        send(57, 0)
        told.last() shouldBe BatteryState(Some(57), plugged = false)
        watch.stop(context)
        registered() shouldBe 0
        send(58, 0)
        told.size shouldBe 2
        // Followed again: what changed meanwhile is told, once.
        watch.follow(context)
        shadowOf(Looper.getMainLooper()).idle()
        told shouldBe
            listOf(BatteryState(Some(57), plugged = true), BatteryState(Some(57), plugged = false), BatteryState(Some(58), plugged = false))
        watch.stop(context)
        watch.follow(context)
        shadowOf(Looper.getMainLooper()).idle()
        told.size shouldBe 3
        watch.stop(context)
    }
}
