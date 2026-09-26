// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import android.net.Uri
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.Codepoint
import io.kotest.property.arbitrary.alphanumeric
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class FoldersTest {
    private val context = RuntimeEnvironment.getApplication()

    @Test
    fun `INV-E0-14 access to a picked folder is kept read-only`() {
        val tree = Uri.parse("content://com.android.externalstorage.documents/tree/1A2B-3C4D%3AROMs%2Fps2")
        Folders(context).keepAccess(tree).shouldBeRight().name shouldBe "ps2"
        context.contentResolver.persistedUriPermissions.map { Triple(it.uri, it.isReadPermission, it.isWritePermission) } shouldBe
            listOf(Triple(tree, true, false))
    }

    @Test
    fun `INV-E0-14 whatever folders are picked, none is kept writable`() = runBlocking<Unit> {
        checkAll(Arb.list(Arb.string(1..12, Codepoint.alphanumeric()), 1..4)) { names ->
            names.forEach { Folders(context).keepAccess(Uri.parse("content://com.android.externalstorage.documents/tree/primary%3A$it")) }
            context.contentResolver.persistedUriPermissions.forEach { it.isWritePermission shouldBe false }
        }
    }
}
