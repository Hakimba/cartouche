// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.library.game
import app.cartouche.core.shelves.Selection
import io.kotest.assertions.arrow.core.shouldBeRight
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@Config(sdk = [30, 34])
@RunWith(RobolectricTestRunner::class)
class SelectionStoreTest {
    private val file = File(RuntimeEnvironment.getApplication().filesDir, "selection.json")

    @Test
    fun `INV-15 a saved selection loads back, and no file means no selection`() {
        val selection = Selection().with(game("A")).with(game("B", platform = "gba"))
        SelectionStore(file).load().shouldBeRight(Selection())
        SelectionStore(file).save(selection).shouldBeRight()
        SelectionStore(file).load().shouldBeRight(selection)
    }

    @Test
    fun `INV-15 a selection whose last write was interrupted on Android 11 loads from its backup`() {
        val selection = Selection().with(game("A"))
        SelectionStore(file).save(selection).shouldBeRight()
        // Android 11's AtomicFile moves the file to a backup before writing; a write cut short leaves only the backup.
        file.renameTo(File(file.path + ".bak"))
        SelectionStore(file).load().shouldBeRight(selection)
    }
}
