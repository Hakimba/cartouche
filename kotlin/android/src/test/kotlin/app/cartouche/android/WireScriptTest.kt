// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.android

import arrow.core.Option
import arrow.core.serialization.OptionSerializer
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.assertions.withClue
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import org.junit.Test
import java.io.File

class WireScriptTest {
    private val script =
        File(checkNotNull(System.getProperty("cartouche.app")) { "Run the tests through Gradle" }, "adapters/android/android_wire.gd")

    @Serializable
    class NoneNotDefault(val maker: Option<String>)

    @Serializable
    class TrueByDefault(val coming: Boolean = true)

    @Test
    fun `INV-23 the GDScript reading what the plugin sends is generated from the types it sends`() {
        val current = if (script.exists()) script.readText() else ""
        val generated = WireScript.generate(current)
        if (System.getProperty("cartouche.wire.write") == "true") script.writeText(generated)
        withClue("android_wire.gd is out of date: run this test with -Pwire.write=true") { script.readText() shouldBe generated }
    }

    @Test
    fun `INV-23 a type whose absent key GDScript would misread is refused`() {
        fun refused(type: KSerializer<*>) =
            shouldThrow<IllegalStateException> { WireScript.generate("", listOf(WireScript.Root(type))) }.message
        refused(NoneNotDefault.serializer()).orEmpty() shouldContain "maker"
        refused(TrueByDefault.serializer()).orEmpty() shouldContain "coming"
    }
}
