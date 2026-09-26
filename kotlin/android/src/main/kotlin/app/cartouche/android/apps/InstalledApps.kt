// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.apps

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import app.cartouche.core.PackageName
import arrow.core.filterOption
import arrow.core.raise.catch
import arrow.core.raise.option

internal data class LaunchableApp(val packageName: PackageName, val label: String)

/**
 * Installed-app queries. Visibility of other apps comes from the `<queries>` launcher intent in the
 * manifest, which covers every emulator since they all have a launcher icon.
 */
internal object InstalledApps {
    /** Whether [packageName] is installed and enabled: a disabled app cannot be started. */
    fun isInstalled(packageManager: PackageManager, packageName: PackageName): Boolean = catch({
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getApplicationInfo(packageName.value, PackageManager.ApplicationInfoFlags.of(0)).enabled
        } else {
            @Suppress("DEPRECATION") // Replaced by the ApplicationInfoFlags overload from API 33.
            packageManager.getApplicationInfo(packageName.value, 0).enabled
        }
    }) { _: PackageManager.NameNotFoundException -> false }

    /** Apps with a launcher icon, sorted by label. Loading labels is slow: call off the main thread. */
    fun launchable(packageManager: PackageManager): List<LaunchableApp> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(launcher, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION") // Replaced by the ResolveInfoFlags overload from API 33.
                packageManager.queryIntentActivities(launcher, 0)
            }
        return activities
            .map { option { LaunchableApp(PackageName.parse(it.activityInfo.packageName).bind(), "${it.loadLabel(packageManager)}") } }
            .filterOption()
            .distinctBy { it.packageName }
            .sortedBy { it.label.lowercase() }
    }
}
