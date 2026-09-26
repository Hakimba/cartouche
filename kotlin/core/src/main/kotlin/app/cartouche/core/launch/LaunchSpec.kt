// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import app.cartouche.core.ContentUri
import app.cartouche.core.PackageName
import arrow.core.Option
import arrow.core.raise.ensure
import arrow.core.raise.option

/** Explicit activity target, as written after `-n`: `package/class` or `package/.RelativeClass`. */
public data class Component(public val packageName: PackageName, public val className: String) {
    public companion object {
        public fun parse(text: String): Option<Component> = option {
            val parts = text.split('/')
            ensure(parts.size == 2)
            val (pkg, raw) = parts
            ensure(raw.isNotEmpty() && raw.none { it.isWhitespace() || it in "{}" })
            Component(PackageName.parse(pkg).bind(), if (raw.startsWith('.')) pkg + raw else raw)
        }
    }
}

public sealed interface ExtraValue {
    public data class Text(public val value: String) : ExtraValue

    /** `--esn`: the key is present with no value, which some apps test for. */
    public data object EmptyText : ExtraValue

    public data class Flag(public val value: Boolean) : ExtraValue

    public data class IntNumber(public val value: Int) : ExtraValue

    public data class LongNumber(public val value: Long) : ExtraValue

    public data class FloatNumber(public val value: Float) : ExtraValue

    public data class UriText(public val value: String) : ExtraValue

    public data class TextArray(public val values: List<String>) : ExtraValue
}

public data class Extra(public val key: String, public val value: ExtraValue)

/** The `am start` switches a template may use; the Android adapter maps each to its Intent flag. */
public enum class ActivitySwitch(public val option: String) {
    BROUGHT_TO_FRONT("--activity-brought-to-front"),
    CLEAR_TASK("--activity-clear-task"),
    CLEAR_TOP("--activity-clear-top"),
    EXCLUDE_FROM_RECENTS("--activity-exclude-from-recents"),
    LAUNCHED_FROM_HISTORY("--activity-launched-from-history"),
    MULTIPLE_TASK("--activity-multiple-task"),
    NEW_TASK("--activity-new-task"),
    NO_ANIMATION("--activity-no-animation"),
    NO_HISTORY("--activity-no-history"),
    NO_USER_ACTION("--activity-no-user-action"),
    PREVIOUS_IS_TOP("--activity-previous-is-top"),
    REORDER_TO_FRONT("--activity-reorder-to-front"),
    RESET_TASK_IF_NEEDED("--activity-reset-task-if-needed"),
    SINGLE_TOP("--activity-single-top"),
    TASK_ON_HOME("--activity-task-on-home"),
    INCLUDE_STOPPED_PACKAGES("--include-stopped-packages"),
    EXCLUDE_STOPPED_PACKAGES("--exclude-stopped-packages"),
    ;

    internal companion object {
        val byOption: Map<String, ActivitySwitch> = entries.associateBy { it.option }
    }
}

/** URI grant bits of `android.content.Intent`, which templates must not set through `-f`. */
public object GrantFlags {
    public const val READ: Int = 0x1
    public const val WRITE: Int = 0x2
    public const val PERSISTABLE: Int = 0x40
    public const val PREFIX: Int = 0x80
    public const val ALL: Int = READ or WRITE or PERSISTABLE or PREFIX
}

/**
 * A fully resolved launch. Only [Template.resolve] builds one, which guarantees that [flags] carries
 * no [GrantFlags] bit, that [grant] is the launched game's own URI, and that no other content URI is
 * handed where Android grants access along with the intent ([data], [ExtraValue.UriText]).
 */
@ConsistentCopyVisibility
public data class LaunchSpec internal constructor(
    public val component: Option<Component>,
    public val action: Option<String>,
    public val data: Option<String>,
    public val type: Option<String>,
    public val categories: List<String>,
    public val flags: Int,
    public val switches: Set<ActivitySwitch>,
    public val extras: List<Extra>,
    /** The game's URI when the launch hands it to the target, which then needs read access to it. */
    public val grant: Option<ContentUri>,
) {
    /** Package that receives the launch; none for an implicit intent resolved by the system. */
    public val targetPackage: Option<PackageName> get() = component.map { it.packageName }
}

public sealed interface TemplateError {
    public data object UnclosedQuote : TemplateError

    public data object DanglingEscape : TemplateError

    public data object MissingTarget : TemplateError

    public data class MissingValue(public val option: String) : TemplateError

    public data class UnknownOption(public val option: String) : TemplateError

    public data class ForbiddenOption(public val option: String) : TemplateError

    public data class ForbiddenFlags(public val flags: Int) : TemplateError

    public data class InvalidComponent(public val value: String) : TemplateError

    public data class InvalidValue(public val option: String, public val value: String) : TemplateError

    public data class UnknownPlaceholder(public val name: String) : TemplateError

    public data class ForeignUri(public val uri: String) : TemplateError

    /** English description, for logs. */
    public val message: String
        get() =
            when (this) {
                UnclosedQuote -> "Unclosed quote"
                DanglingEscape -> "Backslash at the end of the template"
                MissingTarget -> "A template needs -n (component) or -a (action)"
                is MissingValue -> "Missing value after $option"
                is UnknownOption -> "Unsupported option $option"
                is ForbiddenOption -> "$option is not allowed: URI permissions are granted by the launcher"
                is ForbiddenFlags -> "-f must not contain URI grant flags (0x${flags.toString(16)})"
                is InvalidComponent -> "Invalid component \"$value\" (expected package/class)"
                is InvalidValue -> "Invalid value \"$value\" for $option"
                is UnknownPlaceholder -> "No value for placeholder {$name}"
                is ForeignUri -> "$uri: the only content URI a launch may hand over is the game's"
            }
}
