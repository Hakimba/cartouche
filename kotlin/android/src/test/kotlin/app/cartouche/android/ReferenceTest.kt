// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlatformId
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrNone
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.collections.shouldNotBeEmpty
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.pair
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Callable
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** Tables held as texts, `table to platform to text`. */
internal fun tableTexts(vararg texts: Pair<Pair<Table, PlatformId>, String>): TableFiles {
    val held = texts.toMap()
    return TableFiles { table, platform -> held.getOrNone(table to platform).map { it.byteInputStream() } }
}

/** A platform's tables, read from the app's files where the plugin reads them in the APK. */
@RunWith(RobolectricTestRunner::class)
class ReferenceTest {
    private val app = File(checkNotNull(System.getProperty("cartouche.app")) { "Run the tests through Gradle" })
    private val shipped = TableFiles(::shippedFile)

    private val catalog: Catalog by lazy {
        val data = File(app, "data/platforms")
        val definitions =
            listOf("daijishou", "cartouche")
                .flatMap { data.resolve(it).listFiles { file -> file.extension == "json" }.orEmpty().toList() }
                .associateBy { it.name }
                .toSortedMap()
                .values
                .map { DefinitionSource(it.name, it.readText()) }
        Catalog.parse(definitions, DefinitionSource("profiles.json", data.resolve("profiles.json").readText()))
    }

    private fun shippedFile(table: Table, platform: PlatformId): Option<InputStream> =
        Some(File(app, table.path(platform))).filter(File::exists).map(File::inputStream)

    private fun platformsIn(table: Table): List<PlatformId> = File(app, table.path(PlatformId("")).substringBeforeLast('/'))
        .listFiles { file -> file.extension == "tsv" }
        .orEmpty()
        .map { PlatformId(it.nameWithoutExtension) }

    @Test
    fun `every table the app ships is where the plugin reads it, and its version read from first lines is its sources'`() {
        Table.entries.forEach { platformsIn(it).shouldNotBeEmpty() }
        val reference = Reference(catalog, files = shipped)
        Table.entries.flatMap(::platformsIn).distinct().forEach { platform ->
            reference.artVersion(platform) shouldBe reference.sources(platform, None).version
        }
    }

    @Test
    fun `a table the app lacks is none, one failing to be read fails the ask, read again on the next ask`() {
        var failing = true
        val files = TableFiles.at { path -> if (failing) throw IOException(path) else File(app, path).inputStream() }
        val reference = Reference(catalog, files = files)
        shouldThrow<IOException> { reference.titles(PlatformId("ps2")) }
        failing = false
        reference.titles(PlatformId("ps2")).size shouldBeGreaterThan 0
        reference.titles(PlatformId("none")).size shouldBe 0
    }

    @Test
    fun `a platform's tables are read once, by whichever thread asks first, and only those of the platforms asked for`() =
        runBlocking<Unit> {
            val platforms = Table.entries.flatMap(::platformsIn).distinct() + PlatformId("none")
            val pool = Executors.newFixedThreadPool(4)
            checkAll(20, Arb.list(Arb.pair(Arb.element(platforms), Arb.element(Ask.entries)), 0..12)) { asks ->
                val opened = ConcurrentHashMap<Pair<Table, PlatformId>, AtomicInteger>()
                val counted =
                    TableFiles { table, platform ->
                        shipped.open(table, platform).onSome { opened.getOrPut(table to platform, ::AtomicInteger).incrementAndGet() }
                    }
                val reference = Reference(catalog, files = counted)
                pool.invokeAll(asks.map { (platform, ask) -> Callable { ask.of(reference, platform) } }).forEach { it.get() }
                // Each kind of ask reads its tables once, whichever thread asks first.
                val expected =
                    Table.entries
                        .flatMap { table ->
                            platforms.map { platform ->
                                (table to platform) to
                                    asks.filter { it.first == platform }.map { it.second }.toSet().count { table in it.reads }
                            }
                        }.filter { (read, times) -> times > 0 && File(app, read.first.path(read.second)).exists() }
                        .toMap()
                opened.mapValues { it.value.get() } shouldBe expected
            }
            pool.shutdown()
        }

    /** What is asked of a platform, and the tables it reads. */
    private enum class Ask(val reads: Set<Table>) {
        TITLES(setOf(Table.TITLES, Table.PRINTS)),
        SOURCES(setOf(Table.ART, Table.TEXTURES)),
        VERSION(setOf(Table.ART, Table.TEXTURES)),
        ;

        fun of(reference: Reference, platform: PlatformId): Any = when (this) {
            TITLES -> reference.titles(platform)
            SOURCES -> reference.sources(platform, None)
            VERSION -> reference.artVersion(platform)
        }
    }
}
