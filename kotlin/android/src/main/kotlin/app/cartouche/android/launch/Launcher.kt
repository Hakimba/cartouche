// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.FileUriExposedException
import app.cartouche.android.apps.InstalledApps
import app.cartouche.android.trace
import app.cartouche.core.PackageName
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.platforms.Launch
import app.cartouche.core.platforms.LaunchError
import arrow.core.Either
import arrow.core.getOrElse
import arrow.core.raise.catch
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.ensureNotNull
import arrow.core.toOption

internal sealed interface LaunchFailure {
    data class Rejected(val error: LaunchError) : LaunchFailure

    data class NotInstalled(val packageName: PackageName) : LaunchFailure

    data class ActivityNotFound(val target: String) : LaunchFailure

    data class PermissionDenied(val reason: String) : LaunchFailure

    val message: String
        get() =
            when (this) {
                is Rejected -> error.message
                is NotInstalled -> "${packageName.value} is not installed"
                is ActivityNotFound -> "No activity for $target"
                is PermissionDenied -> "Permission denied: $reason"
            }
}

/**
 * Starts emulators, apps and system screens. Preparing an intent does IO and runs off the main
 * thread; [start] and [pickFolder] run on the main thread, which owns activity starts.
 *
 * Never grants a URI to a package directly: only the documents provider could revoke such a grant,
 * so it would last until reboot. The intent's own grant ([IntentMapper]) ends with the emulator.
 */
internal class Launcher(private val context: Context) {
    /** Checks the emulator is installed and stops a lingering instance, then returns the launch intent. */
    fun prepareGame(launch: Launch): Either<LaunchFailure, Intent> = either {
        launch.spec.targetPackage.onSome { packageName ->
            ensure(InstalledApps.isInstalled(context.packageManager, packageName)) { LaunchFailure.NotInstalled(packageName) }
            if (launch.runningInstance == RunningInstance.STOP) stopBackgroundInstance(packageName)
        }
        IntentMapper.toIntent(launch.spec)
    }

    fun appIntent(packageName: PackageName): Either<LaunchFailure, Intent> = either {
        ensureNotNull(context.packageManager.getLaunchIntentForPackage(packageName.value)) { LaunchFailure.NotInstalled(packageName) }
    }

    fun start(activity: Activity, intent: Intent): Either<LaunchFailure, Unit> = starting(intent) { activity.startActivity(intent) }

    /** Opens the system folder picker; the choice arrives in the activity result for [requestCode]. */
    fun pickFolder(activity: Activity, requestCode: Int): Either<LaunchFailure, Unit> =
        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).let { starting(it) { activity.startActivityForResult(it, requestCode) } }

    /**
     * Some emulators (RetroArch) keep running in the background and would resume the previous game
     * instead of loading the new one. Stopping them only works up to Android 13: from Android 14,
     * [ActivityManager.killBackgroundProcesses] can only stop the caller's own processes, so newer
     * devices rely on the template's clear-task switches.
     */
    private fun stopBackgroundInstance(packageName: PackageName) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        trace("stop") { packageName.value }
        context.getSystemService(ActivityManager::class.java).toOption().onSome { it.killBackgroundProcesses(packageName.value) }
    }

    private inline fun starting(intent: Intent, crossinline start: () -> Unit): Either<LaunchFailure, Unit> = either {
        trace("start") { intent.toUri(Intent.URI_INTENT_SCHEME) }
        catch({ start() }) { e: RuntimeException ->
            raise(
                when (e) {
                    is ActivityNotFoundException -> LaunchFailure.ActivityNotFound(label(intent))
                    is SecurityException, is FileUriExposedException -> LaunchFailure.PermissionDenied(e.toString())
                    else -> throw e
                },
            )
        }
    }

    private fun label(intent: Intent): String =
        intent.component.toOption().map { it.flattenToShortString() }.getOrElse { intent.action.orEmpty() }
}
