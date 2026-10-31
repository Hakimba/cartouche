// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import app.cartouche.android.storage.AUTHORITY
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.fileRow
import app.cartouche.android.storage.installDocuments
import app.cartouche.android.storage.rows
import app.cartouche.core.FileName
import app.cartouche.core.PackageName
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.LaunchTemplate
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.platforms.Launch
import app.cartouche.core.uri
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.FileNotFoundException

@Config(sdk = [30, 33, 34])
@RunWith(RobolectricTestRunner::class)
class LauncherTest {
    private enum class Emulator { INSTALLED, DISABLED, ABSENT, IMPLICIT }

    // A file that is gone: GONE as documents providers usually say it (no cursor), STALE as Android's
    // external storage provider says it for a file of a picked folder, by an exception.
    private enum class GameFileState { PRESENT, GONE, STALE, NO_ROW, DENIED }

    private val context = RuntimeEnvironment.getApplication()
    private val stopped = mutableListOf<PackageName>()
    private val launcher = Launcher(context, Folders(context)) { stopped += it }
    private val game = GameFile(FileName("g.chd"), uri("content://$AUTHORITY/tree/root/document/root%2Fg.chd"), None)
    private val armsx2 = PackageName.parse("com.armsx2").shouldBeSome()

    private fun template(emulator: Emulator): String = when (emulator) {
        Emulator.IMPLICIT -> "-a android.intent.action.VIEW -d {file.uri}"
        Emulator.INSTALLED, Emulator.DISABLED, Emulator.ABSENT -> "-n com.armsx2/.Main -d {file.uri}"
    }

    private fun launch(emulator: Emulator, instance: RunningInstance = RunningInstance.STOP) =
        Launch(LaunchTemplate.parse(template(emulator)).shouldBeRight().resolve(game).shouldBeRight(), instance)

    private fun given(emulator: Emulator, file: GameFileState) {
        val packages = shadowOf(context.packageManager)
        packages.removePackage(armsx2.value)
        if (emulator == Emulator.INSTALLED || emulator == Emulator.DISABLED) {
            packages.installPackage(
                PackageInfo().apply {
                    packageName = armsx2.value
                    applicationInfo =
                        ApplicationInfo().apply {
                            packageName = armsx2.value
                            enabled = emulator == Emulator.INSTALLED
                        }
                },
            )
        }
        installDocuments(
            document = { id ->
                when (file) {
                    GameFileState.PRESENT -> rows(fileRow(id))
                    GameFileState.GONE -> throw FileNotFoundException(id)
                    GameFileState.STALE -> throw IllegalArgumentException("Failed to determine if $id is child of root")
                    GameFileState.NO_ROW -> rows()
                    GameFileState.DENIED -> throw SecurityException("revoked")
                }
            },
        ) { rows() }
    }

    @Test
    fun `a game launches only in an installed emulator`() {
        given(Emulator.INSTALLED, GameFileState.PRESENT)
        launcher.prepareGame(launch(Emulator.INSTALLED), game.uri) { true }.shouldBeRight().component.shouldNotBeNull().packageName shouldBe
            "com.armsx2"
        given(Emulator.ABSENT, GameFileState.PRESENT)
        launcher.prepareGame(launch(Emulator.ABSENT), game.uri) { true }.shouldBeLeft() shouldBe LaunchFailure.NotInstalled(armsx2)
        given(Emulator.DISABLED, GameFileState.PRESENT)
        launcher.prepareGame(launch(Emulator.DISABLED), game.uri) { true }.shouldBeLeft() shouldBe LaunchFailure.NotInstalled(armsx2)
    }

    /** Runs [check] in every state: each emulator, game file and running instance policy. */
    private fun everyState(check: (Emulator, GameFileState, RunningInstance) -> Unit) = Emulator.entries.forEach { emulator ->
        GameFileState.entries.forEach { file -> RunningInstance.entries.forEach { instance -> check(emulator, file, instance) } }
    }

    @Test
    fun `INV-05 checking a game starts nothing and stops nothing, whatever it finds`() = everyState { emulator, file, instance ->
        given(emulator, file)
        launcher.checkGame(launch(emulator, instance), game.uri)
        stopped.shouldBeEmpty()
        shadowOf(context).nextStartedActivity.shouldBeNull()
    }

    @Test
    fun `INV-05 a launch fails exactly as its check did, and goes ahead exactly when its check did`() {
        var ready = 0
        everyState { emulator, file, instance ->
            given(emulator, file)
            val checked = launcher.checkGame(launch(emulator, instance), game.uri)
            val prepared = launcher.prepareGame(launch(emulator, instance), game.uri) { true }
            prepared.map { it.toUri(0) } shouldBe checked.map { it.toUri(0) }
            if (prepared.isRight()) ready++
        }
        ready shouldBeGreaterThan 0
    }

    @Test
    fun `a launch stops a lingering emulator only when it goes ahead and the definition asks to`() = everyState {
        emulator,
        file,
        instance,
        ->
        given(emulator, file)
        stopped.clear()
        val prepared = launcher.prepareGame(launch(emulator, instance), game.uri) { true }
        val stops = prepared.isRight() && instance == RunningInstance.STOP && emulator != Emulator.IMPLICIT
        stopped shouldBe (if (stops) listOf(armsx2) else emptyList())
    }

    @Test
    fun `INV-21 a launch past its deadline stops no lingering emulator`() = everyState { emulator, file, instance ->
        given(emulator, file)
        stopped.clear()
        launcher.prepareGame(launch(emulator, instance), game.uri) { false }
        stopped.shouldBeEmpty()
    }

    @Test
    fun `INV-04 a game whose file is gone or unreadable never launches, and is reported so when its emulator is there`() =
        everyState { emulator, file, instance ->
            given(emulator, file)
            val prepared = launcher.prepareGame(launch(emulator, instance), game.uri) { true }
            if (file != GameFileState.PRESENT) prepared.isLeft() shouldBe true
            if (emulator == Emulator.INSTALLED || emulator == Emulator.IMPLICIT) {
                prepared.swap().getOrNone() shouldBe Some(LaunchFailure.GameMissing(game.uri)).filter { file != GameFileState.PRESENT }
            }
        }
}
