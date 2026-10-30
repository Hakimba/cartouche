// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import app.cartouche.core.launch.ActivitySwitch
import app.cartouche.core.launch.Extra
import app.cartouche.core.launch.ExtraValue
import app.cartouche.core.launch.LaunchSpec

/** Turns a resolved [LaunchSpec] into the [Intent] that starts it. */
internal object IntentMapper {
    fun toIntent(spec: LaunchSpec): Intent = Intent().apply {
        spec.action.onSome { action = it }
        spec.component.onSome { component = ComponentName(it.packageName.value, it.className) }
        // Android's own API models "no data" and "no type" as nulls.
        setDataAndType(spec.data.map(Uri::parse).getOrNull(), spec.type.getOrNull())
        spec.categories.forEach(::addCategory)
        spec.extras.forEach { put(it) }
        // `am start` always starts a new task, and templates written for it rely on that.
        flags = spec.switches.fold(spec.flags or Intent.FLAG_ACTIVITY_NEW_TASK) { acc, switch -> acc or switch.flag }
        // Emulators that read the game from an extra need it in ClipData; setting it also stops Android moving a `--eu` extra there.
        spec.grant.onSome {
            clipData = ClipData.newRawUri("", Uri.parse(it.value))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun Intent.put(extra: Extra) {
        when (val v = extra.value) {
            is ExtraValue.Text -> putExtra(extra.key, v.value)
            // `--esn`: key present, no value.
            ExtraValue.EmptyText -> putExtra(extra.key, null as String?)
            is ExtraValue.Flag -> putExtra(extra.key, v.value)
            is ExtraValue.IntNumber -> putExtra(extra.key, v.value)
            is ExtraValue.LongNumber -> putExtra(extra.key, v.value)
            is ExtraValue.FloatNumber -> putExtra(extra.key, v.value)
            is ExtraValue.UriText -> putExtra(extra.key, Uri.parse(v.value))
            is ExtraValue.TextArray -> putExtra(extra.key, v.values.toTypedArray())
        }
    }

    val ActivitySwitch.flag: Int
        get() =
            when (this) {
                ActivitySwitch.BROUGHT_TO_FRONT -> Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT
                ActivitySwitch.CLEAR_TASK -> Intent.FLAG_ACTIVITY_CLEAR_TASK
                ActivitySwitch.CLEAR_TOP -> Intent.FLAG_ACTIVITY_CLEAR_TOP
                ActivitySwitch.EXCLUDE_FROM_RECENTS -> Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                ActivitySwitch.LAUNCHED_FROM_HISTORY -> Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY
                ActivitySwitch.MULTIPLE_TASK -> Intent.FLAG_ACTIVITY_MULTIPLE_TASK
                ActivitySwitch.NEW_TASK -> Intent.FLAG_ACTIVITY_NEW_TASK
                ActivitySwitch.NO_ANIMATION -> Intent.FLAG_ACTIVITY_NO_ANIMATION
                ActivitySwitch.NO_HISTORY -> Intent.FLAG_ACTIVITY_NO_HISTORY
                ActivitySwitch.NO_USER_ACTION -> Intent.FLAG_ACTIVITY_NO_USER_ACTION
                ActivitySwitch.PREVIOUS_IS_TOP -> Intent.FLAG_ACTIVITY_PREVIOUS_IS_TOP
                ActivitySwitch.REORDER_TO_FRONT -> Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                ActivitySwitch.RESET_TASK_IF_NEEDED -> Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                ActivitySwitch.SINGLE_TOP -> Intent.FLAG_ACTIVITY_SINGLE_TOP
                ActivitySwitch.TASK_ON_HOME -> Intent.FLAG_ACTIVITY_TASK_ON_HOME
                ActivitySwitch.INCLUDE_STOPPED_PACKAGES -> Intent.FLAG_INCLUDE_STOPPED_PACKAGES
                ActivitySwitch.EXCLUDE_STOPPED_PACKAGES -> Intent.FLAG_EXCLUDE_STOPPED_PACKAGES
            }
}
