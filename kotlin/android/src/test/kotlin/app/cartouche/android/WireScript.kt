// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import app.cartouche.core.library.PlatformSetup
import arrow.core.Either
import arrow.core.None
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.StructureKind
import kotlinx.serialization.descriptors.elementDescriptors
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.serializer
import app.cartouche.core.settings.Settings as AppSettings

/**
 * Writes `app/adapters/android/android_wire.gd` from the types of [Sent]: a GDScript class per type, a typed field per
 * property under its key, `has_<key>` beside an [arrow.core.Option], and the members a class has by hand kept as they
 * are (the lines from [BY_HAND] up to its `_init`, which ends by calling their `_finish` when they have one).
 */
@OptIn(ExperimentalSerializationApi::class)
internal object WireScript {
    const val BY_HAND = "\t# By hand, up to _init: kept as is by WireScriptTest."

    /** A type sent alone: a getter's value or a signal's, or an operation's answer, read with its [Result]. */
    class Root(val serializer: KSerializer<*>, val answer: Boolean = false)

    val roots: List<Root> =
        listOf(
            Root(Sent.CatalogSummary.serializer()),
            Root(Sent.Players.serializer()),
            Root(Sent.Browse.serializer()),
            Root(Sent.Marks.serializer()),
            Root(Sent.BackdropAnswer.serializer()),
            Root(Sent.Battery.serializer()),
            Root(Sent.ArtChange.serializer()),
            Root(Sent.LabelDownload.serializer()),
            Root(Sent.LabelVariant.serializer()),
            Root(Sent.Pick.serializer(), answer = true),
            Root(Sent.FolderList.serializer(), answer = true),
            Root(Sent.Placed.serializer(), answer = true),
            Root(Sent.LibraryAnswer.serializer(), answer = true),
            Root(Sent.RefreshAnswer.serializer(), answer = true),
            Root(Sent.ArrivalsAnswer.serializer(), answer = true),
            Root(Sent.ScanAnswer.serializer(), answer = true),
            Root(Sent.PreviewAnswer.serializer(), answer = true),
            Root(Sent.RescrapeAnswer.serializer(), answer = true),
            Root(Sent.SettingsAnswer.serializer(), answer = true),
            Root(Sent.LabelVariants.serializer(), answer = true),
            Root(Sent.Renamed.serializer(), answer = true),
            Root(Sent.LabelPicture.serializer(), answer = true),
            Root(Sent.ArtAnswer.serializer(), answer = true),
        )

    /**
     * What an absent key reads as where it is not its type's zero: the values a fresh install has, so that a value the
     * plugin leaves out, or an answer that failed, reads as the plugin's own default.
     */
    private val defaults: Map<String, JsonObject> =
        listOf(
            jsonOf(AppSettings().sentBackdrop()) to Sent.BackdropAnswer.serializer().descriptor,
            jsonOf(AppSettings().sent(firstLaunch = false)) to Sent.SettingsAnswer.serializer().descriptor,
            jsonOf(PlatformSetup().sent(None)) to Sent.PlatformSetup.serializer().descriptor,
        ).associate { (json, descriptor) ->
            // Lists read empty: their entries are the plugin's to tell.
            name(descriptor) to JsonObject(wireJson.parseToJsonElement(json).jsonObject.filterValues { it is JsonPrimitive })
        }

    /** The script for [roots], keeping the members by hand that [current] (the file as it is) has. */
    fun generate(current: String, roots: List<Root> = this.roots): String {
        val byHand = byHand(current)
        val classes = LinkedHashMap<String, Pair<SerialDescriptor, Boolean>>()

        fun visit(descriptor: SerialDescriptor, answer: Boolean) {
            val found = unwrapped(descriptor)
            when (found.kind) {
                StructureKind.CLASS -> {
                    if (name(found) !in classes) {
                        if (name(found) !in defaults) checkZeroDefaults(found)
                        classes[name(found)] = found to answer
                        found.elementDescriptors.forEach { visit(it, false) }
                    }
                }
                StructureKind.LIST, StructureKind.MAP -> found.elementDescriptors.forEach { visit(it, false) }
                else -> Unit
            }
        }
        roots.forEach { visit(it.serializer.descriptor, it.answer) }
        val failed = Failed.serializer().descriptor
        val codes = (0 until failed.getElementDescriptor(0).elementsCount).map { failed.getElementDescriptor(0).getElementName(it) }
        return buildString {
            append(HEADER)
            append(result(codes))
            classes.forEach { (name, found) -> append("\n\n").append(type(name, found.first, found.second, byHand[name].orEmpty())) }
        }
    }

    /**
     * Fails when a property of [descriptor] has another default than its type's zero: left out at its default, it
     * would read in GDScript as the zero.
     */
    private fun checkZeroDefaults(descriptor: SerialDescriptor) {
        val type = serializerOf(descriptor)
        val written = everything.encodeToJsonElement(type, everything.decodeFromJsonElement(type, least(descriptor))).jsonObject
        (0 until descriptor.elementsCount).filter(descriptor::isElementOptional).forEach { index ->
            val key = descriptor.getElementName(index)
            check(written.getValue(key) in ZEROS) { "${descriptor.serialName}.$key: another default than its type's zero reads as zero" }
        }
    }

    /** The value of [descriptor] with only its required properties, each at its least. */
    private fun least(descriptor: SerialDescriptor): JsonElement = if (descriptor.isInline) {
        least(descriptor.getElementDescriptor(0))
    } else {
        when (descriptor.kind) {
            StructureKind.CLASS ->
                JsonObject(
                    (0 until descriptor.elementsCount).filterNot(descriptor::isElementOptional).associate { index ->
                        val element = descriptor.getElementDescriptor(index)
                        descriptor.getElementName(index) to if (element.isNullable) JsonNull else least(element)
                    },
                )
            StructureKind.LIST -> JsonArray(emptyList())
            SerialKind.ENUM -> JsonPrimitive(descriptor.getElementName(0))
            PrimitiveKind.STRING -> JsonPrimitive("")
            PrimitiveKind.BOOLEAN -> JsonPrimitive(false)
            is PrimitiveKind -> JsonPrimitive(0)
            else -> JsonObject(emptyMap())
        }
    }

    /** The class [descriptor] describes, found by its name: a nested class's name is its outer's, a dot, its own. */
    private fun serializerOf(descriptor: SerialDescriptor): KSerializer<Any> {
        val parts = descriptor.serialName.removeSuffix("?").split('.')
        return (parts.size - 1 downTo 1)
            .map { split -> parts.take(split).joinToString(".") + "." + parts.drop(split).joinToString("$") }
            .flatMap { Either.catch { Class.forName(it) }.getOrNone().toList() }
            .firstOrNone()
            .getOrElse { error("${descriptor.serialName}: no class of that name") }
            .let(::serializer)
    }

    private fun byHand(current: String): Map<String, String> {
        val lines = current.lines()
        return lines.indices.filter { lines[it] == BY_HAND }.associate { start ->
            val name = lines.subList(0, start).last { it.startsWith("class ") }.removePrefix("class ").takeWhile { it.isLetterOrDigit() }
            val end = (start until lines.size).first { lines[it].startsWith("\tfunc _init(") }
            name to lines.subList(start, end).joinToString("\n").trimEnd() + "\n"
        }
    }

    private fun result(codes: List<String>): String =
        """
        |## An operation's answer: [member ok], or the [member code] of its failure.
        |class Result:
        |	var ok: bool
        |	## ${wrapped(
            "One of ${codes.joinToString(", ") { "`$it`" }}; `unavailable` without the plugin, `rehearsed` for a launch rehearsed.",
            "\t## ",
        )}
        |	var code: StringName
        |	## English, for logs.
        |	var detail: String
        |
        |	func _init(item: Dictionary = {}) -> void:
        |		ok = item.get("ok", false)
        |		code = item.get("code", &"")
        |		detail = item.get("detail", "")
        |
        """.trimMargin()

    private fun type(name: String, descriptor: SerialDescriptor, answer: Boolean, byHand: String): String = buildString {
        val fields = (0 until descriptor.elementsCount).map { Field(descriptor, it, defaults.getOrElse(name) { JsonObject(emptyMap()) }) }
        append("class $name").append(if (answer) " extends Result" else "").append(":\n")
        fields.forEach { field -> field.declarations.forEach { append("\t$it\n") } }
        if (byHand.isNotEmpty()) append(byHand)
        append("\n\tfunc _init(item: Dictionary = {}) -> void:\n")
        if (answer) append("\t\tsuper(item)\n")
        fields.forEach { field -> field.reads.forEach { append("\t\t$it\n") } }
        if ("func _finish(" in byHand) append("\t\t_finish(item)\n")
    }

    /** The field of [descriptor]'s property [index], [defaults] holding what its absence reads as. */
    private class Field(descriptor: SerialDescriptor, index: Int, defaults: JsonObject) {
        val key =
            descriptor.getElementName(index).also {
                check(it.matches(SNAKE_CASE)) { "${descriptor.serialName}.$it: a key is in snake_case, the property's @SerialName" }
            }
        private val element = descriptor.getElementDescriptor(index)
        private val optional =
            element.isNullable.also {
                check(!it || descriptor.isElementOptional(index)) { "${descriptor.serialName}.$key: an Option is None by default" }
            }
        private val value = unwrapped(element)
        private val type = gdType(value)

        // A JSON number reads as a float: a typed variable turns it into an int.
        private val zero: String =
            defaults.getOrNone(key).map { literal(it.jsonPrimitive, type) }.getOrElse {
                when (type) {
                    "String" -> "\"\""
                    "StringName" -> "&\"\""
                    "int" -> "0"
                    "float" -> "0.0"
                    "bool" -> "false"
                    else -> "{}"
                }
            }

        val declarations: List<String> =
            (if (optional) listOf("var has_$key: bool") else emptyList()) +
                when {
                    type.startsWith(
                        "Array",
                    ) ||
                        type.startsWith("Dictionary") -> "var $key: $type = ${if (type.startsWith("Array")) "[]" else "{}"}"
                    else -> "var $key: $type"
                }

        val reads: List<String> =
            (if (optional) listOf("has_$key = item.has(\"$key\")") else emptyList()) + read()

        private fun read(): List<String> = when (value.kind) {
            StructureKind.CLASS ->
                if (optional) {
                    listOf("if has_$key:", "\tvar raw_$key: Dictionary = item[\"$key\"]", "\t$key = $type.new(raw_$key)")
                } else {
                    listOf("var raw_$key: Dictionary = item.get(\"$key\", {})", "$key = $type.new(raw_$key)")
                }
            StructureKind.LIST ->
                when (type) {
                    "PackedStringArray" -> listOf("$key = AndroidWire._strings(item, \"$key\")")
                    "PackedInt32Array" -> listOf("$key = AndroidWire._ints(item, \"$key\")")
                    else -> listOf("for each: Dictionary in item.get(\"$key\", []):", "\t$key.append(${elementType()}.new(each))")
                }
            StructureKind.MAP -> {
                val values = unwrapped(value.getElementDescriptor(1))
                val valueType = gdType(values)
                listOf("var raw_$key: Dictionary = item.get(\"$key\", {})", "for key: String in raw_$key:") +
                    when {
                        values.kind == StructureKind.CLASS ->
                            listOf(
                                "\tvar value: Dictionary = raw_$key[key]",
                                "\t$key[key] = $valueType.new(value)",
                            )
                        valueType == "PackedStringArray" -> listOf("\t$key[key] = AndroidWire._strings(raw_$key, key)")
                        values.kind == StructureKind.LIST -> {
                            val each = gdType(unwrapped(values.getElementDescriptor(0)))
                            listOf(
                                "\tvar list: $valueType = []",
                                "\tfor each: Dictionary in raw_$key[key]:",
                                "\t\tlist.append($each.new(each))",
                                "\t$key[key] = list",
                            )
                        }
                        else -> listOf("\tvar value: $valueType = raw_$key[key]", "\t$key[key] = value")
                    }
            }
            else -> listOf("$key = item.get(\"$key\", $zero)")
        }

        private fun elementType(): String = gdType(unwrapped(value.getElementDescriptor(0)))
    }

    private fun gdType(descriptor: SerialDescriptor): String = when (val kind = descriptor.kind) {
        PrimitiveKind.STRING -> "String"
        PrimitiveKind.INT, PrimitiveKind.LONG, PrimitiveKind.SHORT, PrimitiveKind.BYTE -> "int"
        PrimitiveKind.FLOAT, PrimitiveKind.DOUBLE -> "float"
        PrimitiveKind.BOOLEAN -> "bool"
        SerialKind.ENUM -> "StringName"
        StructureKind.CLASS -> name(descriptor)
        StructureKind.LIST ->
            unwrapped(descriptor.getElementDescriptor(0)).let { element ->
                when (element.kind) {
                    PrimitiveKind.STRING, SerialKind.ENUM -> "PackedStringArray"
                    PrimitiveKind.INT, PrimitiveKind.LONG -> "PackedInt32Array"
                    StructureKind.CLASS -> "Array[${name(element)}]"
                    else -> error("No GDScript list of ${element.serialName}")
                }
            }
        StructureKind.MAP -> {
            check(
                unwrapped(descriptor.getElementDescriptor(0)).kind == PrimitiveKind.STRING,
            ) { "Map keys cross as texts: ${descriptor.serialName}" }
            val values = unwrapped(descriptor.getElementDescriptor(1))
            // GDScript nests no typed collection in another: a map's lists of classes are plain Arrays.
            "Dictionary[String, ${if (values.kind == StructureKind.LIST &&
                gdType(
                    values,
                ).startsWith("Array")
            ) {
                "Array"
            } else {
                gdType(values)
            }}]"
        }
        else -> error("No GDScript type for ${descriptor.serialName} ($kind)")
    }

    private fun literal(value: JsonPrimitive, type: String): String = when (type) {
        "String" -> value.toString()
        "StringName" -> "&$value"
        else -> value.content
    }

    /** An inline value class as the value it wraps, an [arrow.core.Option] as its value. */
    private fun unwrapped(descriptor: SerialDescriptor): SerialDescriptor =
        if (descriptor.isInline) unwrapped(descriptor.getElementDescriptor(0)) else descriptor

    private fun name(descriptor: SerialDescriptor): String = descriptor.serialName.removeSuffix("?").substringAfterLast('.')

    private fun wrapped(text: String, prefix: String): String {
        val lines = mutableListOf("")
        text.split(' ').forEach { word ->
            if (lines.last().isNotEmpty() && prefix.length + lines.last().length + word.length + 1 > MAX_LINE) lines += ""
            lines[lines.size - 1] = if (lines.last().isEmpty()) word else "${lines.last()} $word"
        }
        return lines.joinToString("\n$prefix")
    }

    private const val MAX_LINE = 116

    /** Every property written, a [None] as null. */
    private val everything = Json { encodeDefaults = true }

    private val ZEROS =
        setOf(
            JsonNull,
            JsonPrimitive(""),
            JsonPrimitive(false),
            JsonPrimitive(0),
            JsonPrimitive(0.0),
            JsonArray(emptyList()),
            JsonObject(emptyMap()),
        )

    private val SNAKE_CASE = Regex("[a-z0-9]+(_[a-z0-9]+)*")

    private val HEADER =
        """
        |# SPDX-License-Identifier: GPL-3.0-or-later
        |# Generated from kotlin/android/src/main/kotlin/app/cartouche/android/Sent.kt by WireScriptTest; only the lines a class
        |# has by hand are edited here. After changing Sent.kt:
        |# kotlin/gradlew -p kotlin :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true
        |class_name AndroidWire
        |extends RefCounted
        |## The values the plugin sends, as JSON text ([AndroidServices] reads them): a class per type of `Sent.kt`, a field
        |## per property under its key. A value that may be missing is an absent key, surfaced as a `has_*` flag.
        |
        |
        |## The texts listed under [param key] of [param item]; none when it is absent.
        |static func _strings(item: Dictionary, key: String) -> PackedStringArray:
        |	var texts: Array = item.get(key, [])
        |	return PackedStringArray(texts)
        |
        |
        |static func _ints(item: Dictionary, key: String) -> PackedInt32Array:
        |	var numbers: Array = item.get(key, [])
        |	return PackedInt32Array(numbers)
        |
        |
        |
        """.trimMargin()
}
