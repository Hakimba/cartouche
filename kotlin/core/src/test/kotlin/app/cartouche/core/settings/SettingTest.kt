// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.regions.PreferredRegion
import arrow.core.Either
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.descriptors.elementNames
import org.junit.Test

class SettingTest {
    private val upper = Regex("[A-Z]")

    @Test
    fun `INV-15 each field of the settings is declared once, and its value sent and taken back gives it again`() = runBlocking<Unit> {
        val keys = Settings.serializer().descriptor.elementNames.map { field -> field.replace(upper) { "_${it.value.lowercase()}" } }
        Setting.all.map { it.key } shouldContainExactlyInAnyOrder keys
        checkAll(settings) { settings ->
            Setting.all
                .fold(Settings()) { rebuilt, setting ->
                    setting.valueIn(settings).fold({ rebuilt }) { Setting.change(rebuilt, setting.key, it.written).shouldBeRight() }
                }.shouldBe(settings)
        }
    }

    @Test
    fun `a value of another kind, out of range, of no choice or for no setting is refused`() {
        listOf(
            "sound_level" to "11",
            "sound_level" to "-1",
            "sound_level" to "4.5",
            "sound_level" to "true",
            "pixel_veil" to "on",
            "pixel_veil" to "1",
            "backdrop" to "sepia",
            "backdrop" to "",
            "button_style" to "",
            "language" to "tlh",
            "preferred_region" to "japan",
        ).forEach { (key, written) -> Setting.change(Settings(), key, written) shouldBe Either.Left(SettingRefused.Invalid(key, written)) }
        Setting.change(Settings(), "brightness", "3").shouldBeLeft(SettingRefused.Unknown("brightness"))
    }

    @Test
    fun `an empty name clears the region and the language, and a choice's names are those the file stores`() {
        val chosen = Settings(preferredRegion = Some(PreferredRegion.JAPAN), language = Some(Language.GERMAN))
        Setting.change(chosen, "preferred_region", "").shouldBeRight(chosen.copy(preferredRegion = None))
        Setting.change(chosen, "language", "").shouldBeRight(chosen.copy(language = None))
        Setting.PREFERRED_REGION.names shouldBe PreferredRegion.entries.map { it.region }
        Setting.LANGUAGE.names shouldBe listOf("en", "fr", "de", "es", "it", "pt", "pt_BR", "ja")
        Setting.GAMES_FLOAT.names shouldBe emptyList()
    }
}
