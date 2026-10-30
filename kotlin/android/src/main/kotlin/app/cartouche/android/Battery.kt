// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.toOption

/** The battery as the top bar shows it: its level when known, and whether a charger is plugged in. */
internal data class BatteryState(val levelPercent: Option<Int>, val plugged: Boolean) {
    companion object {
        /** Nothing known: no battery, or nothing said about it yet. */
        val NONE = BatteryState(None, plugged = false)

        /**
         * Plugged means into any charger, charging or full. A level without its scale, or at 0 (what some devices report
         * when unknown), is unknown.
         */
        fun of(broadcast: Intent): BatteryState {
            if (!broadcast.getBooleanExtra(BatteryManager.EXTRA_PRESENT, true)) return NONE
            val level = broadcast.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = broadcast.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val percent = if (level in 1..scale) Some(level * 100 / scale) else None
            return BatteryState(percent, broadcast.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0)
        }

        fun now(context: Context): BatteryState = context.registerReceiver(null, BATTERY).toOption().fold({ NONE }, ::of)

        private val BATTERY = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
    }
}

/**
 * Tells [changed] each new state, the system's last broadcast first; the broadcast also repeats for
 * temperature or voltage alone, which tells nothing new.
 * Main thread only.
 */
internal class BatteryWatch(private val changed: (BatteryState) -> Unit) : BroadcastReceiver() {
    private var told: Option<BatteryState> = None
    private var following = false

    fun follow(context: Context) {
        if (!following) context.registerReceiver(this, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        following = true
    }

    fun stop(context: Context) {
        if (following) context.unregisterReceiver(this)
        following = false
    }

    override fun onReceive(context: Context, intent: Intent) {
        val state = BatteryState.of(intent)
        if (told != Some(state)) {
            told = Some(state)
            changed(state)
        }
    }
}
