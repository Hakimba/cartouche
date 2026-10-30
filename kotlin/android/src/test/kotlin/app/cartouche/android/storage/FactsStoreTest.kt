// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android.storage

import app.cartouche.core.ContentUri
import app.cartouche.core.files.FileFacts
import app.cartouche.core.files.Shell
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.orNull
import io.kotest.property.arbitrary.string
import io.kotest.property.arbitrary.stringPattern
import io.kotest.property.arbitrary.uInt
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@Config(sdk = [30, 34])
@RunWith(RobolectricTestRunner::class)
class FactsStoreTest {
    private val folder = File(RuntimeEnvironment.getApplication().filesDir, "facts")
    private val ps2 = PlatformId("ps2")

    private fun stamps(): Arb<Option<Long>> = Arb.long().orNull(0.3).map { Option.fromNullable(it) }

    /** What files tell, those of the edges included: serials as discs and IDs write them, the smallest and largest prints. */
    private val facts: Arb<FileFacts> =
        Arb.choice(
            Arb.stringPattern("[A-Z]{4}[_-][0-9]{3}\\.[0-9]{2}").map(FileFacts::Serial),
            Arb.stringPattern("[A-Z0-9]{4}").map(FileFacts::Serial),
            Arb.element(0u, 0xFFFFFFFFu).map(FileFacts::Print),
            Arb.uInt().map(FileFacts::Print),
            Arb.constant(FileFacts.Silent),
        )

    private val known =
        Arb.bind(Arb.string(1..30), stamps(), stamps(), facts) { id, size, modified, told ->
            documentUri(id) to KnownFacts(FileStamp(size, modified), told)
        }

    @Test
    fun `what files told is read back as kept, whatever their stamps and facts`() = runBlocking<Unit> {
        var kept = 0
        checkAll(200, Arb.list(known, 0..8)) { entries ->
            val all = entries.toMap()
            FactsStore(folder).save(ps2, all).shouldBeRight()
            FactsStore(folder).load(ps2) shouldBe all
            kept += all.size
        }
        kept shouldBeGreaterThan 400
    }

    @Test
    fun `a file written by another version of the readers is read as nothing known`() {
        val uri = documentUri("root/a.iso")
        FactsStore(folder).save(ps2, mapOf(uri to KnownFacts(FileStamp(Some(1L), None), FileFacts.Silent))).shouldBeRight()
        val file = File(folder, "ps2.tsv")
        file.writeText(file.readText().replace("cartouche-facts\t1", "cartouche-facts\t2"))
        FactsStore(folder).load(ps2) shouldBe emptyMap()
    }

    @Test
    fun `a broken line is left out, the others kept`() {
        val (a, b) = listOf("root/a.iso", "root/b.iso").map(::documentUri)
        val told = mapOf(a to KnownFacts(FileStamp(Some(1L), Some(2L)), FileFacts.Serial("SLES_524.95")))
        File(folder.apply { mkdirs() }, "ps2.tsv").writeText(
            listOf(
                "cartouche-facts\t1",
                "${a.value}\t1\t2\tserial:SLES_524.95",
                "${b.value}\t1\t2\tprint:XYZ",
                "${b.value}\t1\t2\tprint:0000000A:box",
                "${b.value}\t1\t2\tsilence",
                "${b.value}\tone\t2\tsilent",
                "${b.value}\t1\tsilent",
                "not a uri\t1\t2\tsilent",
            ).joinToString("\n"),
        )
        FactsStore(folder).load(ps2) shouldBe told
    }

    @Test
    fun `a cache written before shells were told keeps every platform's facts but the Game Boy prints, read again`() {
        val (a, b) = listOf("root/a.iso", "root/b.gbc").map(::documentUri)
        val line = { uri: ContentUri, facts: String -> "${uri.value}\t1\t2\t$facts" }
        listOf(
            "ps2" to line(a, "serial:SLES_524.95"),
            "psx" to line(a, "print:0000000A"),
            "gbc" to line(b, "print:0000000A"),
            "gb" to line(a, "print:0000000A"),
            "gba" to line(b, "print:0000000A:unknown"),
        ).forEach { (platform, text) -> File(folder.apply { mkdirs() }, "$platform.tsv").writeText("cartouche-facts\t1\n$text") }
        val stamp = FileStamp(Some(1L), Some(2L))
        FactsStore(folder).load(ps2) shouldBe mapOf(a to KnownFacts(stamp, FileFacts.Serial("SLES_524.95")))
        FactsStore(folder).load(PlatformId("psx")) shouldBe mapOf(a to KnownFacts(stamp, FileFacts.Print(10u)))
        FactsStore(folder).load(PlatformId("gbc")) shouldBe emptyMap()
        FactsStore(folder).load(PlatformId("gb")) shouldBe emptyMap()
        FactsStore(folder).load(PlatformId("gba")) shouldBe mapOf(b to KnownFacts(stamp, FileFacts.Print(10u, Shell.UNKNOWN)))
    }

    @Test
    fun `each platform keeps its own files' facts, and a platform forgotten loses only its own`() {
        val uri = documentUri("root/a.iso")
        val told = mapOf(uri to KnownFacts(FileStamp(Some(1L), Some(2L)), FileFacts.Print(1u)))
        val gba = PlatformId("gba")
        FactsStore(folder).run {
            save(ps2, told).shouldBeRight()
            save(gba, told).shouldBeRight()
            forget(gba)
        }
        FactsStore(folder).load(ps2) shouldBe told
        FactsStore(folder).load(gba) shouldBe emptyMap()
        FactsStore(folder).forget().shouldBeRight()
        FactsStore(folder).load(ps2) shouldBe emptyMap()
    }
}
