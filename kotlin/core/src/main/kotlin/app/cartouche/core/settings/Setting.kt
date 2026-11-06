// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.serialName
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.flatMap
import kotlin.enums.enumEntries

/**
 * A setting's value as it is sent to the app's shell: a choice's name, a switch's state or a number of steps. The
 * shell sends one back [written] as text, which the setting's declaration reads.
 */
public sealed interface SettingValue {
    public val written: String

    @JvmInline
    public value class Name(public val name: String) : SettingValue {
        override val written: String get() = name
    }

    @JvmInline
    public value class Switch(public val on: Boolean) : SettingValue {
        override val written: String get() = on.toString()
    }

    @JvmInline
    public value class Steps(public val steps: Int) : SettingValue {
        override val written: String get() = steps.toString()
    }
}

/** Why a value sent for a setting was not taken; the settings stay as they were. */
public sealed interface SettingRefused {
    public val detail: String

    public data class Unknown(val key: String) : SettingRefused {
        override val detail: String get() = "no setting is named $key"
    }

    public data class Invalid(val key: String, val written: String) : SettingRefused {
        override val detail: String get() = "$key cannot be \"$written\""
    }
}

/**
 * One setting the user changes, declared once in [all]: its [key] on the bridge, the [names] a choice can take (as
 * stored, empty for a switch or a level), how its value in [Settings] is sent, and how a value sent back is checked
 * before it is kept. Its default is the one [Settings] gives its field.
 */
public class Setting private constructor(
    public val key: String,
    public val names: List<String>,
    private val sent: (Settings) -> Option<SettingValue>,
    private val taken: (Settings, String) -> Option<Settings>,
) {
    /** Its value in [settings]; none for a choice not made yet. */
    public fun valueIn(settings: Settings): Option<SettingValue> = sent(settings)

    /** [settings] with this setting [written] as [SettingValue.written] writes it, when it is a value it takes. */
    public fun change(settings: Settings, written: String): Either<SettingRefused, Settings> =
        taken(settings, written).toEither { SettingRefused.Invalid(key, written) }

    /** How a value of type [T] is sent and read back from its text; [names] are a choice's. */
    private class Form<T>(val names: List<String>, val sent: (T) -> Option<SettingValue>, val taken: (String) -> Option<T>) {
        /** Optional: none is sent as no value; [cleared] takes an empty name back as none, otherwise none is never taken. */
        fun optional(cleared: Boolean): Form<Option<T>> = Form(names, { it.flatMap(sent) }) { written ->
            if (cleared && written.isEmpty()) Some(None) else taken(written).map(::Some)
        }
    }

    public companion object {
        private fun <T> setting(key: String, form: Form<T>, get: (Settings) -> T, set: Settings.(T) -> Settings) =
            Setting(key, form.names, { form.sent(get(it)) }) { settings, written -> form.taken(written).map { settings.set(it) } }

        private val switch =
            Form<Boolean>(emptyList(), { Some(SettingValue.Switch(it)) }) { written ->
                listOf(true, false).firstOrNone { it.toString() == written }
            }

        private val level =
            Form<SoundLevel>(emptyList(), { Some(SettingValue.Steps(it.steps)) }) { written ->
                Option.fromNullable(written.toIntOrNull()).flatMap(SoundLevel::of)
            }

        /** One of [E]'s entries, named as the settings file stores it ([serialName]). */
        private inline fun <reified E : Enum<E>> choice(): Form<E> =
            Form(enumEntries<E>().map { it.serialName }, { Some(SettingValue.Name(it.serialName)) }) { written ->
                enumEntries<E>().firstOrNone { it.serialName == written }
            }

        public val BUTTON_STYLE: Setting =
            setting("button_style", choice<ButtonStyle>().optional(cleared = false), Settings::buttonStyle) {
                copy(buttonStyle = it)
            }
        public val EDGE_SMOOTHING: Setting = setting("edge_smoothing", choice(), Settings::edgeSmoothing) { copy(edgeSmoothing = it) }
        public val PREFERRED_REGION: Setting =
            setting("preferred_region", choice<PreferredRegion>().optional(cleared = true), Settings::preferredRegion) {
                copy(preferredRegion = it)
            }
        public val GAMES_FLOAT: Setting = setting("games_float", switch, Settings::gamesFloat) { copy(gamesFloat = it) }
        public val SOUND_LEVEL: Setting = setting("sound_level", level, Settings::soundLevel) { copy(soundLevel = it) }
        public val LANGUAGE: Setting =
            setting("language", choice<Language>().optional(cleared = true), Settings::language) {
                copy(language = it)
            }
        public val BACKDROP: Setting = setting("backdrop", choice(), Settings::backdrop) { copy(backdrop = it) }
        public val PIXEL_VEIL: Setting = setting("pixel_veil", switch, Settings::pixelVeil) { copy(pixelVeil = it) }

        /** Every setting, each field of [Settings] once. */
        public val all: List<Setting> =
            listOf(BUTTON_STYLE, EDGE_SMOOTHING, PREFERRED_REGION, GAMES_FLOAT, SOUND_LEVEL, LANGUAGE, BACKDROP, PIXEL_VEIL)

        /** [settings] with the setting named [key] set to the value [written] as text, when there is one and it takes it. */
        public fun change(settings: Settings, key: String, written: String): Either<SettingRefused, Settings> =
            all.firstOrNone { it.key == key }.toEither { SettingRefused.Unknown(key) }.flatMap { it.change(settings, written) }
    }
}
