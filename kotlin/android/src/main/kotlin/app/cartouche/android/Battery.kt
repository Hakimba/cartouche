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
         * As a battery broadcast ([Intent.ACTION_BATTERY_CHANGED]) tells it. Plugged means into any
         * charger, charging or full, as the system's own bolt shows. A device without a battery tells
         * nothing; a level without its scale, or at 0 (what some devices report when they do not know),
         * is unknown.
         */
        fun of(broadcast: Intent): BatteryState {
            if (!broadcast.getBooleanExtra(BatteryManager.EXTRA_PRESENT, true)) return NONE
            val level = broadcast.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = broadcast.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val percent = if (level in 1..scale) Some(level * 100 / scale) else None
            return BatteryState(percent, broadcast.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0)
        }

        /** The battery now, from the system's last battery broadcast. */
        fun now(context: Context): BatteryState = context.registerReceiver(null, BATTERY).toOption().fold({ NONE }, ::of)

        private val BATTERY = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
    }
}

/**
 * Follows the battery from [follow] to [stop] and tells [changed] each new state, as soon as the
 * system knows it: the system's last battery broadcast comes at once, then each new one. The
 * broadcast also repeats for the temperature or the voltage alone, several times a minute, which
 * tells nothing new. Only used on the main thread, where broadcasts arrive.
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
