// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.library.game
import app.cartouche.core.shelves.Selection
import app.cartouche.core.shelves.SelectionFormat
import app.cartouche.core.storage.StateUnreadable
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@Config(sdk = [30, 34])
@RunWith(RobolectricTestRunner::class)
class StateFileTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "state")
    private val file = File(folder, "selection.json")
    private val selection = Selection().with(game("A")).with(game("B", platform = "gba"))
    private val problems = mutableListOf<StateUnreadable>()

    /** A new one reads the file again, as at the next start. */
    private fun state() = StateFile(file, Selection(), SelectionFormat::decode, SelectionFormat::encode) { problems += it }

    @Test
    fun `INV-15 a saved state reads back at the next start, and no file means the empty state`() {
        state().get() shouldBe Selection()
        state().set(selection).shouldBeRight()
        state().get() shouldBe selection
        problems shouldBe emptyList()
    }

    @Test
    fun `INV-15 a state whose last write was interrupted on Android 11 reads from its backup`() {
        state().set(selection).shouldBeRight()
        // Android 11's AtomicFile moves the file to a backup before writing; a write cut short leaves only the backup.
        file.renameTo(File(file.path + ".bak"))
        state().get() shouldBe selection
    }

    @Test
    fun `INV-15 a damaged file is told and read as the empty state, and replaced by the next save`() {
        folder.mkdirs()
        file.writeText("{")
        state().get() shouldBe Selection()
        problems shouldHaveSize 1
        state().set(selection).shouldBeRight()
        state().get() shouldBe selection
    }

    @Test
    fun `a cleared state leaves no file and reads as the empty state`() {
        val state = state().also { it.set(selection).shouldBeRight() }
        state.clear()
        state.get() shouldBe Selection()
        state().get() shouldBe Selection()
        file.exists() shouldBe false
    }
}
