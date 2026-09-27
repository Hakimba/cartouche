// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.library.game
import app.cartouche.core.shelves.Selection
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
class SelectionStoreTest {
    private val file = File(RuntimeEnvironment.getApplication().filesDir, "selection.json")

    @Test
    fun `INV-E2-05 a saved selection loads back, and no file means no selection`() {
        val selection = Selection().with(game("A")).with(game("B", platform = "gba"))
        SelectionStore(file).load().shouldBeRight(Selection())
        SelectionStore(file).save(selection).shouldBeRight()
        SelectionStore(file).load().shouldBeRight(selection)
    }

    @Test
    fun `INV-E2-05 a selection whose last write was interrupted on Android 11 loads from its backup`() {
        val selection = Selection().with(game("A"))
        SelectionStore(file).save(selection).shouldBeRight()
        // Android 11's AtomicFile moves the file to a backup before writing; a write cut short leaves only the backup.
        file.renameTo(File(file.path + ".bak"))
        SelectionStore(file).load().shouldBeRight(selection)
    }

    @Test
    fun `INV-E2-05 a damaged selection file is reported, and replaced by the next save`() {
        file.writeText("{")
        SelectionStore(file).load().shouldBeLeft()
        SelectionStore(file).save(Selection()).shouldBeRight()
        SelectionStore(file).load().shouldBeRight(Selection())
    }
}
