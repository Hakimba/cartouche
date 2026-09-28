// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.PackageName
import app.cartouche.core.Shipped
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.comparables.shouldBeLessThanOrEqualTo
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

class CurtainTimesTest {
    private fun parse(text: String) = CurtainTimes.parse(DefinitionSource("curtains.json", text))

    private fun file(default: Long, emulators: Map<String, Long>) =
        """{"default_ms": $default, "emulators": {${emulators.entries.joinToString { (name, time) -> "\"$name\": $time" }}}}"""

    private val armsx2 = PackageName.parse("com.armsx2").shouldBeSome()

    @Test
    fun `an emulator gets its own time, any other and an implicit launch the default one`() {
        val times = parse(file(1500, mapOf("com.armsx2" to 2000))).shouldBeRight()
        times.timeFor(Some(armsx2)) shouldBe 2000.milliseconds
        times.timeFor(Some(PackageName.parse("org.other.emu").shouldBeSome())) shouldBe 1500.milliseconds
        times.timeFor(None) shouldBe 1500.milliseconds
    }

    @Test
    fun `every time of a valid file reads back as written`() = runBlocking<Unit> {
        checkAll(curtainMillis, Arb.map(packageNames, curtainMillis, maxSize = 6)) { default, emulators ->
            val read = parse(file(default, emulators)).shouldBeRight()
            read.timeFor(None) shouldBe default.milliseconds
            emulators.forEach { (name, time) -> read.timeFor(PackageName.parse(name)) shouldBe time.milliseconds }
        }
    }

    @Test
    fun `INV-E3-06 no curtain lasts longer than 10 s, whatever the file says`() = runBlocking<Unit> {
        CurtainTimes.LONGEST shouldBeLessThanOrEqualTo 10.seconds
        checkAll(
            Arb.long(0L..Long.MAX_VALUE / 2),
            Arb.map(packageNames, Arb.long(0L..Long.MAX_VALUE / 2), maxSize = 4),
        ) { default, emulators ->
            parse(file(default, emulators)).onRight { times ->
                (emulators.keys.map(PackageName::parse) + None).forEach { times.timeFor(it) shouldBeLessThanOrEqualTo 10.seconds }
            }
        }
    }

    @Test
    fun `INV-E3-06 one time out of bounds anywhere refuses the file, naming its key`() = runBlocking<Unit> {
        val outOfBounds = Arb.choice(Arb.long(Long.MIN_VALUE / 2..-1L), Arb.long(10_001L..Long.MAX_VALUE / 2))
        checkAll(
            curtainMillis,
            Arb.map(packageNames, curtainMillis, maxSize = 6),
            outOfBounds,
            Arb.int(),
        ) { default, emulators, wrong, pick ->
            val keys = listOf("default_ms") + emulators.keys
            val key = keys[Math.floorMod(pick, keys.size)]
            val text = if (key == "default_ms") file(wrong, emulators) else file(default, emulators + (key to wrong))
            parse(text).shouldBeLeft().shouldBeInstanceOf<CatalogError.InvalidValue>().key shouldBe key
        }
    }

    @Test
    fun `reading any text gives times or a typed error, never an exception`() = runBlocking<Unit> {
        checkAll(Arb.string(0..80)) { text -> parse(text) }
        checkAll(Arb.string(0..20)) { junk -> parse("""{"default_ms": 1, "emulators": {"$junk": 1}, "$junk": 1}""") }
    }

    @Test
    fun `a package that is not one or a missing field is refused, naming it`() {
        parse(file(1500, mapOf("armsx2" to 2000))).shouldBeLeft() shouldBe
            CatalogError.InvalidValue("curtains.json", "armsx2", "not a package name")
        parse("""{"emulators": {}}""").shouldBeLeft() shouldBe CatalogError.MissingField("curtains.json", "default_ms")
        parse("""{"default_ms": 1}""").shouldBeLeft() shouldBe CatalogError.MissingField("curtains.json", "emulators")
    }

    @Test
    fun `the shipped times are read`() {
        parse(Shipped.text("launch/curtains.json")).shouldBeRight().timeFor(Some(armsx2)) shouldBe 1500.milliseconds
    }
}
