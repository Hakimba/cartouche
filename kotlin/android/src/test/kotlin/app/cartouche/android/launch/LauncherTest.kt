// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.pm.PackageInfo
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.PackageName
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.LaunchTemplate
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.platforms.Launch
import arrow.core.None
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class LauncherTest {
    private val context = RuntimeEnvironment.getApplication()
    private val launcher = Launcher(context)
    private val game = GameFile(FileName("g.chd"), ContentUri.parse("content://p/document/g").shouldBeSome(), None)

    private fun launch(packageName: String) = Launch(
        LaunchTemplate.parse("-n $packageName/.Main -d {file.uri}").shouldBeRight().resolve(game).shouldBeRight(),
        RunningInstance.STOP,
    )

    @Test
    fun `a game launches only in an installed emulator`() {
        shadowOf(context.packageManager).installPackage(PackageInfo().apply { packageName = "com.armsx2" })
        launcher.prepareGame(launch("com.armsx2")).shouldBeRight().component.shouldNotBeNull().packageName shouldBe "com.armsx2"
        launcher.prepareGame(launch("not.installed")).shouldBeLeft() shouldBe
            LaunchFailure.NotInstalled(PackageName.parse("not.installed").shouldBeSome())
    }
}
