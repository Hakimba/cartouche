// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.launch

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.provider.Settings
import android.view.Display
import android.view.View
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import app.cartouche.android.trace
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.raise.catch
import arrow.core.raise.either
import arrow.core.toOption
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.time.Duration

/** Why a curtain could not be raised; the launch goes on without it. */
internal data class CurtainRefused(val reason: String)

/**
 * A black window over every app while an emulator starts, lowered after
 * [app.cartouche.core.platforms.CurtainTimes] or when Cartouche is back.
 * It does not take focus, so the controller reaches the emulator, but it takes touches: Android 12+ caps a window letting touches through
 * at 80 % opacity. Needs the "display over other apps" permission. Main thread only.
 */
internal class Curtain(private val context: Context, private val scope: CoroutineScope) {
    private data class Raised(val manager: WindowManager, val view: View, val timer: Job)

    private var raised: Option<Raised> = None

    val isAllowed: Boolean get() = Settings.canDrawOverlays(context)

    /** Runs [start] under a curtain raised for [time], lowered at once if [start] fails. */
    fun <E, T> over(time: Duration, start: () -> Either<E, T>): Either<E, T> {
        raise(time)
        return start().onLeft { lower() }
    }

    /** Raises the curtain over the main display, where emulators start, for [time]: none for a time of zero. */
    fun raise(time: Duration) {
        when {
            !isAllowed -> trace("curtain") { "not allowed" }
            time == Duration.ZERO -> trace("curtain") { "none for this emulator" }
            raised.isSome() -> trace("curtain") { "up already" }
            else ->
                window()
                    .onLeft { trace("curtain") { "not raised: ${it.reason}" } }
                    .onRight { (manager, view) ->
                        raised = Some(Raised(manager, view, scope.launch(Dispatchers.Main) { delay(time).also { lower() } }))
                        trace("curtain") { "raised for ${time.inWholeMilliseconds} ms" }
                    }
        }
    }

    /**
     * Lowers the curtain, if it is up: at once, since what it uncovers is black too, the game starting or Cartouche's
     * screen.
     */
    fun lower() {
        raised.onSome { (manager, view, timer) ->
            timer.cancel()
            manager.removeView(view)
            trace("curtain") { "lowered" }
        }
        raised = None
    }

    /** A black window added over every app; the permission can be withdrawn at any time, and a display go away. */
    private fun window(): Either<CurtainRefused, Pair<WindowManager, View>> = either {
        catch({
            val display =
                context
                    .getSystemService(DisplayManager::class.java)
                    .toOption()
                    .flatMap { it.getDisplay(Display.DEFAULT_DISPLAY).toOption() }
                    .getOrElse { raise(CurtainRefused("no main display")) }
            val window = context.createDisplayContext(display).createWindowContext(LayoutParams.TYPE_APPLICATION_OVERLAY, null)
            val manager =
                window.getSystemService(WindowManager::class.java).toOption().getOrElse { raise(CurtainRefused("no window manager")) }
            val view = View(window).apply { setBackgroundColor(Color.BLACK) }
            manager.addView(view, layout())
            manager to view
        }) { e: RuntimeException ->
            when (e) {
                is WindowManager.BadTokenException, is SecurityException, is UnsupportedOperationException ->
                    raise(CurtainRefused(e.toString()))
                else -> throw e
            }
        }
    }

    private companion object {
        // A window keeps the parameters it was added with: each gets its own. Emulators run full
        // screen: the curtain is laid out over the whole display, cutout included.
        fun layout() = LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT,
            LayoutParams.TYPE_APPLICATION_OVERLAY,
            LayoutParams.FLAG_NOT_FOCUSABLE or LayoutParams.FLAG_LAYOUT_IN_SCREEN or LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.OPAQUE,
        ).apply {
            fitInsetsTypes = 0
            layoutInDisplayCutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }
}
