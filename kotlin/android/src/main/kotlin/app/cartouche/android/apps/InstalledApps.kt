// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.apps

import android.content.pm.PackageManager
import android.os.Build
import app.cartouche.core.PackageName
import arrow.core.raise.catch

/**
 * Installed-app queries. Visibility of other apps comes from the `<queries>` launcher intent in the manifest, which
 * covers every emulator since they all have a launcher icon.
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
}
