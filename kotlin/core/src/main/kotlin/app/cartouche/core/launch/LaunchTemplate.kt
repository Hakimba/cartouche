// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import app.cartouche.core.PackageName
import app.cartouche.core.longOrNone
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.toOption

/**
 * Launch templates are the `am start`-style argument strings that Daijishō player definitions use to
 * describe how an emulator opens a game:
 *
 * ```
 * -n org.dolphinemu.dolphinemu/.ui.main.MainActivity
 * -a android.intent.action.MAIN
 * -e AutoStartFile {file.uri}
 * ```
 *
 * A template is parsed once ([LaunchTemplate.parse]), which checks the grammar, then resolved for each
 * game ([Template.resolve]), which fills in the placeholders and types the extras. Both are pure and
 * total.
 *
 * Grammar, a subset of `am start` with its value syntax:
 * - tokens are separated by whitespace; `'…'` is literal, `"…"` honours `\"` and `\\`, and outside
 *   quotes `\` escapes the next character;
 * - options: `-n` component, `-a` action, `-d` data URI, `-t` MIME type, `-c` category, `-f` flags
 *   (the last one wins; unlike `am`, it keeps the switches' flags whatever the order), extras
 *   `-e`/`--es`, `--esn`, `--ez`, `--ei`, `--el`, `--ef`, `--eu`, `--esa` (comma-separated, `\,` for
 *   a comma; placeholder values may contain commas), and the [ActivitySwitch] options, whose flags
 *   add to `-f`;
 * - `{file.uri}` and `{file.path}` in any value except the component are placeholders ([GameFile]).
 *
 * Templates are third-party data, so they never decide URI permissions: `--grant-*` switches and
 * [GrantFlags] bits in `-f` are rejected, and the only content URI a launch may hand where Android
 * grants access with the intent (data, `--eu`) is the game's own, through `{file.uri}` exactly.
 */
public object LaunchTemplate {
    public fun parse(text: String): Either<TemplateError, Template> = either { parseTokens(tokenize(text).bind()) }

    // A character scanner reads best with a cursor; the mutation never leaves this function.
    internal fun tokenize(text: String): Either<TemplateError, List<String>> = either {
        val tokens = mutableListOf<String>()
        val current = StringBuilder()
        var inToken = false
        var i = 0
        while (i < text.length) {
            val c = text[i]
            if (c.isWhitespace()) {
                if (inToken) tokens += current.toString()
                current.clear()
                inToken = false
            } else {
                inToken = true
                when (c) {
                    '\\' -> {
                        ensure(i + 1 < text.length) { TemplateError.DanglingEscape }
                        current.append(text[++i])
                    }
                    '\'' -> {
                        val end = text.indexOf('\'', i + 1)
                        ensure(end >= 0) { TemplateError.UnclosedQuote }
                        current.append(text, i + 1, end)
                        i = end
                    }
                    '"' -> {
                        i++
                        while (i < text.length && text[i] != '"') {
                            if (text[i] == '\\' && i + 1 < text.length && text[i + 1] in "\"\\") i++
                            current.append(text[i++])
                        }
                        ensure(i < text.length) { TemplateError.UnclosedQuote }
                    }
                    else -> current.append(c)
                }
            }
            i++
        }
        if (inToken) tokens += current.toString()
        tokens
    }

    private tailrec fun Raise<TemplateError>.parseTokens(tokens: List<String>, acc: Template = Template.EMPTY): Template =
        if (tokens.isEmpty()) {
            ensure(acc.component.isSome() || acc.action.isSome()) { TemplateError.MissingTarget }
            acc
        } else {
            val (next, rest) = parseOption(tokens.first(), tokens.drop(1), acc)
            parseTokens(rest, next)
        }

    private fun Raise<TemplateError>.parseOption(option: String, args: List<String>, acc: Template): Pair<Template, List<String>> {
        fun arg(index: Int): String = args.getOrElse(index) { raise(TemplateError.MissingValue(option)) }

        fun takeOne(update: (String) -> Template): Pair<Template, List<String>> = update(arg(0)) to args.drop(1)

        return when (option) {
            "-n" -> takeOne { acc.copy(component = Some(Component.parse(it).getOrElse { raise(TemplateError.InvalidComponent(it)) })) }
            "-a" -> takeOne { acc.copy(action = Some(it)) }
            "-d" -> takeOne { acc.copy(data = Some(it)) }
            "-t" -> takeOne { acc.copy(type = Some(it)) }
            "-c" -> takeOne { acc.copy(categories = acc.categories + it) }
            "-f" ->
                takeOne { raw ->
                    val flags = decodeInt(raw).getOrElse { raise(TemplateError.InvalidValue(option, raw)) }
                    ensure(flags and GrantFlags.ALL == 0) { TemplateError.ForbiddenFlags(flags) }
                    acc.copy(flags = flags)
                }
            "--esn" -> takeOne { acc.copy(extras = acc.extras + RawExtra(option, it, ExtraKind.EMPTY_STRING, "")) }
            else -> {
                ensure(!option.startsWith("--grant-")) { TemplateError.ForbiddenOption(option) }
                EXTRA_OPTIONS.getOrNone(option).fold(
                    {
                        val switch = ActivitySwitch.byOption.getOrNone(option).getOrElse { raise(TemplateError.UnknownOption(option)) }
                        acc.copy(switches = acc.switches + switch) to args
                    },
                    { kind -> acc.copy(extras = acc.extras + RawExtra(option, arg(0), kind, arg(1))) to args.drop(2) },
                )
            }
        }
    }

    private val EXTRA_OPTIONS: Map<String, ExtraKind> =
        mapOf(
            "-e" to ExtraKind.STRING,
            "--es" to ExtraKind.STRING,
            "--ez" to ExtraKind.BOOLEAN,
            "--ei" to ExtraKind.INT,
            "--el" to ExtraKind.LONG,
            "--ef" to ExtraKind.FLOAT,
            "--eu" to ExtraKind.URI,
            "--esa" to ExtraKind.STRING_ARRAY,
        )
}

/** `am` reads integers with `Integer.decode`: decimal, `0x`/`0X`/`#` hexadecimal, `0` octal, signed. */
private fun decodeInt(text: String): Option<Int> = Either.catch { Integer.decode(text) }.getOrNone()

/** `am` accepts `true`/`t` and `false`/`f` in any case, and otherwise reads an integer (non-zero is true). */
private fun decodeBoolean(text: String): Option<Boolean> = when (text.lowercase()) {
    "true", "t" -> Some(true)
    "false", "f" -> Some(false)
    else -> decodeInt(text).map { it != 0 }
}

internal enum class ExtraKind { STRING, EMPTY_STRING, BOOLEAN, INT, LONG, FLOAT, URI, STRING_ARRAY }

/** An extra as written in the template ([option] keeps its spelling); [raw] may contain placeholders. */
internal data class RawExtra(val option: String, val key: String, val kind: ExtraKind, val raw: String)

/** A parsed template whose values may still contain placeholders. */
@ConsistentCopyVisibility
public data class Template internal constructor(
    internal val component: Option<Component>,
    internal val action: Option<String>,
    internal val data: Option<String>,
    internal val type: Option<String>,
    internal val categories: List<String>,
    internal val flags: Int,
    internal val switches: Set<ActivitySwitch>,
    internal val extras: List<RawExtra>,
) {
    /** Package that receives the launch; none for an implicit intent resolved by the system. */
    public val targetPackage: Option<PackageName> get() = component.map { it.packageName }

    private val handsGameUri: Boolean
        get() =
            (action.toList() + data.toList() + type.toList() + categories + extras.flatMap { listOf(it.key, it.raw) })
                .any { "{file.uri}" in it }

    public fun resolve(file: GameFile): Either<TemplateError, LaunchSpec> = either {
        val values = file.placeholders

        // One pass: `replace` visits placeholders in order, so the first missing one is reported.
        fun fill(text: String): String = PLACEHOLDER.replace(text) { match ->
            values.getOrNone(match.groupValues[1]).getOrElse { raise(TemplateError.UnknownPlaceholder(match.groupValues[1])) }
        }

        // Android grants the intent's URI permissions on these URIs too, so they must not reach other
        // files. Only `{file.uri}` itself may be a content URI: that also sets the grant, whose
        // ClipData stops Android from granting an extra URI on its own (see IntentMapper).
        fun uri(text: String): String = fill(text).also {
            ensure(text == "{file.uri}" || !it.trimStart().startsWith("content:", ignoreCase = true)) { TemplateError.ForeignUri(it) }
        }

        fun typed(extra: RawExtra, decode: (String) -> Option<ExtraValue>): ExtraValue =
            fill(extra.raw).let { raw -> decode(raw).getOrElse { raise(TemplateError.InvalidValue(extra.option, raw)) } }

        fun resolveExtra(extra: RawExtra): Extra = Extra(
            fill(extra.key),
            when (extra.kind) {
                ExtraKind.STRING -> ExtraValue.Text(fill(extra.raw))
                ExtraKind.EMPTY_STRING -> ExtraValue.EmptyText
                ExtraKind.BOOLEAN -> typed(extra) { decodeBoolean(it).map(ExtraValue::Flag) }
                ExtraKind.INT -> typed(extra) { decodeInt(it).map(ExtraValue::IntNumber) }
                ExtraKind.LONG -> typed(extra) { it.longOrNone().map(ExtraValue::LongNumber) }
                ExtraKind.FLOAT -> typed(extra) { it.toFloatOrNull().toOption().map(ExtraValue::FloatNumber) }
                ExtraKind.URI -> ExtraValue.UriText(uri(extra.raw))
                // Split the template text, then fill: a file name with commas stays one item.
                ExtraKind.STRING_ARRAY -> ExtraValue.TextArray(extra.raw.split(UNESCAPED_COMMA).map { fill(it.replace("\\,", ",")) })
            },
        )

        LaunchSpec(
            component = component,
            action = action.map(::fill),
            data = data.map(::uri),
            type = type.map(::fill),
            categories = categories.map(::fill),
            flags = flags,
            switches = switches,
            extras = extras.map(::resolveExtra),
            grant = Some(file.uri).filter { handsGameUri },
        )
    }

    internal companion object {
        val EMPTY: Template = Template(None, None, None, None, emptyList(), 0, emptySet(), emptyList())

        private val PLACEHOLDER = Regex("""\{([A-Za-z_][A-Za-z0-9_.]*)\}""")

        private val UNESCAPED_COMMA = Regex("""(?<!\\),""")
    }
}
