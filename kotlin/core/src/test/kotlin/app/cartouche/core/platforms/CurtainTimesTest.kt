// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.PackageName
import app.cartouche.core.anyText
import arrow.core.None
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import org.junit.Test
import kotlin.time.Duration.Companion.milliseconds

class CurtainTimesTest {
    private fun parse(text: String) = CurtainTimes.parse(DefinitionSource("curtains.json", text))

    private fun file(default: Long, emulators: Map<String, Long>) =
        """{"default_ms": $default, "emulators": {${emulators.entries.joinToString { (name, time) -> "\"$name\": $time" }}}}"""

    private val armsx2 = PackageName.parse("com.armsx2").shouldBeSome()

    @Test
    fun `every time of a valid file reads back as written`() = runBlocking<Unit> {
        checkAll(curtainMillis, Arb.map(packageNames, curtainMillis, maxSize = 6)) { default, emulators ->
            val read = parse(file(default, emulators)).shouldBeRight()
            read.timeFor(None) shouldBe default.milliseconds
            emulators.forEach { (name, time) -> read.timeFor(PackageName.parse(name)) shouldBe time.milliseconds }
        }
    }

    @Test
    fun `INV-07 one time out of bounds anywhere refuses the file, naming its key`() = runBlocking<Unit> {
        val outOfBounds =
            Arb.choice(
                Arb.long(Long.MIN_VALUE / 2..-1L),
                Arb.long(CurtainTimes.LONGEST.inWholeMilliseconds + 1..Long.MAX_VALUE / 2),
            )
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
        checkAll(anyText) { text -> parse(text) }
        checkAll(anyText) { junk ->
            val key = Json.encodeToString(String.serializer(), junk)
            parse("""{"default_ms": 1, "emulators": {$key: 1}, $key: 1}""")
        }
        checkAll(timeValues, timeValues, anyText) { default, time, junk ->
            val key = Json.encodeToString(String.serializer(), junk)
            parse("""{"default_ms": $default, "emulators": {$key: $time}}""")
        }
    }

    @Test
    fun `a package that is not one or a missing field is refused, naming it`() {
        parse(file(1500, mapOf("armsx2" to 2000))).shouldBeLeft() shouldBe
            CatalogError.InvalidValue("curtains.json", "armsx2", "not a package name")
        parse("""{"emulators": {}}""").shouldBeLeft() shouldBe CatalogError.MissingField("curtains.json", "default_ms")
        parse("""{"default_ms": 1}""").shouldBeLeft() shouldBe CatalogError.MissingField("curtains.json", "emulators")
    }

    private companion object {
        // A time as a file may hold it: in range, at and beyond the bound, negative, fractional, null, text, huge.
        val timeValues: Arb<String> = Arb.element("0", "1500", "2500", "2501", "-1", "1.5", "null", "\"7\"", "9223372036854775807")
    }
}
