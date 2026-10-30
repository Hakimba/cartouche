// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/**
 * [library] runs every library call one at a time, [planning] plans the art looks one at a time in order,
 * [variants] downloads a label chooser's images a few at a time.
 */
internal class Threads(
    val scope: CoroutineScope,
    val library: CoroutineDispatcher,
    val planning: CoroutineDispatcher,
    val variants: CoroutineDispatcher,
) {
    companion object {
        private const val VARIANT_DOWNLOADS = 3

        fun create(): Threads = Threads(
            // A failure no operation stops is logged, and ends only its own coroutine.
            CoroutineScope(SupervisorJob() + Dispatchers.IO + CoroutineExceptionHandler { _, e -> unexpected(e) }),
            Dispatchers.IO.limitedParallelism(1),
            Dispatchers.IO.limitedParallelism(1),
            Dispatchers.IO.limitedParallelism(VARIANT_DOWNLOADS),
        )
    }
}
