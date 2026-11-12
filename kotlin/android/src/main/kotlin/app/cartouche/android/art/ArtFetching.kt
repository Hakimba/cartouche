// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.art

import app.cartouche.android.DebugOptions
import app.cartouche.android.trace
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.ScreenScraperState
import arrow.core.Option
import arrow.core.left
import arrow.core.right
import java.io.File
import java.net.HttpURLConnection
import java.time.LocalDate

private const val USER_AGENT = "Cartouche"

/**
 * Downloads over HTTP; in debug builds, `--art-refused` makes every server refuse, to try the message and the
 * retries.
 */
internal fun artFetch(debug: DebugOptions, screenScraper: Option<ScreenScraperFetch>): Fetch {
    if (debug.artRefused) return Fetch { _, _, _ -> FetchFailure.Refused(503).left() }
    val scans = HttpFetch(http(debug))
    return Fetch { candidate, progress, image ->
        when (candidate) {
            is Candidate.Web -> scans.get(candidate.url, progress, image)
            is Candidate.Texture -> screenScraper.fold({ FetchFailure.NotFound.left() }) { it.get(candidate, progress, image) }
        }
    }
}

/**
 * ScreenScraper with the credentials built into the app; none without a key, and the textures are then images no
 * server gives.
 */
internal fun screenScraperFetch(debug: DebugOptions, quotaFile: File): Option<ScreenScraperFetch> =
    Credentials.fromBuild().map { credentials ->
        // The device's local day: the quota resets on the server's day, so a closure may lift a few hours early or late.
        val today = { Day.of(LocalDate.now()) }
        ScreenScraperFetch(simulated(debug, http(debug)), credentials, quotaFile, System::currentTimeMillis, today) {
            trace("art") { "ScreenScraper: $it" }
        }
    }

/** HTTP for images; in debug builds, `--art-slow=MS` waits MS milliseconds after each chunk read, to see a download's progress. */
private fun http(debug: DebugOptions): JavaHttp = JavaHttp(USER_AGENT, debug.artSlow)

/**
 * Debug builds: `--screenscraper=quota` makes ScreenScraper answer that the day's quota is spent, `wrong-key` that the app's key is
 * refused, `wrong-account` that the member is, to try each state on a device.
 */
private fun simulated(debug: DebugOptions, real: Http): Http = debug.screenScraper.fold({ real }) { state ->
    when (state) {
        "quota" -> Http { _, _, _ -> Answer(ScreenScraperState.QUOTA_SPENT, kept = false).right() }
        "wrong-key" ->
            Http { _, _, body ->
                val text = ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray()
                Answer(HttpURLConnection.HTTP_OK, body.use { it.take(text, text.size) }).right()
            }
        "wrong-account" ->
            Http { url, progress, body ->
                if ("ssuserInfos" in url) Answer(HttpURLConnection.HTTP_FORBIDDEN, kept = false).right() else real.get(url, progress, body)
            }
        else -> real
    }
}
