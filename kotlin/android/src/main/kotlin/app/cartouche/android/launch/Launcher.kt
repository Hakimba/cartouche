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
import app.cartouche.android.storage.Folders
import app.cartouche.android.trace
import app.cartouche.core.ContentUri
import app.cartouche.core.PackageName
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.platforms.Launch
import app.cartouche.core.platforms.LaunchError
import app.cartouche.core.platforms.PlatformId
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

    /** No installed player of [platform] opens the game. */
    data class NoPlayer(val platform: PlatformId) : LaunchFailure

    /** The game file is gone, or its storage cannot be read. */
    data class GameMissing(val file: ContentUri) : LaunchFailure

    val message: String
        get() =
            when (this) {
                is Rejected -> error.message
                is NotInstalled -> "${packageName.value} is not installed"
                is ActivityNotFound -> "No activity for $target"
                is PermissionDenied -> "Permission denied: $reason"
                is NoPlayer -> "No installed emulator for ${platform.value} opens this game"
                is GameMissing -> "The game file ${file.value} is missing or cannot be read"
            }
}

/**
 * Preparing an intent does IO and runs off the main thread; [start] and the pickers run on the main thread.
 * Never grants a URI to a package directly: only the documents provider could revoke it, so it would last until reboot.
 */
internal class Launcher(
    private val context: Context,
    private val folders: Folders,
    /** Stops the background processes of an emulator: a port, for tests to see what a launch stops. */
    private val stopInstance: (PackageName) -> Unit = { stopBackgroundInstance(context, it) },
) {
    /**
     * Starts and stops nothing, so a game can be checked before the launch animation plays; Android's transition is
     * left out as the animation ends on black.
     */
    fun checkGame(launch: Launch, game: ContentUri): Either<LaunchFailure, Intent> = either {
        launch.spec.targetPackage.onSome { packageName ->
            ensure(InstalledApps.isInstalled(context.packageManager, packageName)) { LaunchFailure.NotInstalled(packageName) }
        }
        val present = folders.exists(game).getOrElse { failure -> false.also { trace("launch") { "game unreadable: ${failure.message}" } } }
        ensure(present) { LaunchFailure.GameMissing(game) }
        IntentMapper.toIntent(launch.spec).addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
    }

    /** [checkGame], then stops a lingering instance of the emulator when its definition asks to. */
    fun prepareGame(launch: Launch, game: ContentUri): Either<LaunchFailure, Intent> = checkGame(launch, game).onRight {
        if (launch.runningInstance == RunningInstance.STOP) launch.spec.targetPackage.onSome(stopInstance)
    }

    fun appIntent(packageName: PackageName): Either<LaunchFailure, Intent> = either {
        ensureNotNull(context.packageManager.getLaunchIntentForPackage(packageName.value)) { LaunchFailure.NotInstalled(packageName) }
    }

    fun start(activity: Activity, intent: Intent): Either<LaunchFailure, Unit> = starting(intent) { activity.startActivity(intent) }

    /** Opens the system folder picker; the choice arrives in the activity result for [requestCode]. */
    fun pickFolder(activity: Activity, requestCode: Int): Either<LaunchFailure, Unit> =
        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).let { starting(it) { activity.startActivityForResult(it, requestCode) } }

    /**
     * Opens the system document picker on images (the gallery, the device's folders, its other sources); the choice
     * arrives in the activity result for [requestCode].
     */
    fun pickPicture(activity: Activity, requestCode: Int): Either<LaunchFailure, Unit> = Intent(Intent.ACTION_OPEN_DOCUMENT)
        .addCategory(Intent.CATEGORY_OPENABLE)
        .setType("image/*")
        .let { starting(it) { activity.startActivityForResult(it, requestCode) } }

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

/**
 * Emulators like RetroArch resume the previous game while kept in the background. Stopping them only works
 * up to Android 13; newer devices rely on the template's clear-task switches.
 */
private fun stopBackgroundInstance(context: Context, packageName: PackageName) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
    trace("stop") { packageName.value }
    context.getSystemService(ActivityManager::class.java).toOption().onSome { it.killBackgroundProcesses(packageName.value) }
}
