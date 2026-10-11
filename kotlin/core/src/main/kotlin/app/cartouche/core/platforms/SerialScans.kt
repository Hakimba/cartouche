// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.ParsedSerializer
import arrow.core.Either
import arrow.core.Option
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable

/**
 * A source of scans named after a game's serial, such as
 * `https://psxdatacenter.com/psx2/images2/covers/{serial}/{serial}-D-ALL.jpg`: exact for its release,
 * as a serial is, where a title is ambiguous across regions and romanisations. Its platform's
 * profile gives its URL and the [serial] form its serials take (`[A-Z]{4}-\d{5}` for the PlayStation).
 */
@Serializable(with = SerialScansSerializer::class)
public class SerialScans private constructor(internal val template: String, internal val serial: Regex) {
    override fun equals(other: Any?): Boolean = other is SerialScans && other.template == template && other.serial.pattern == serial.pattern

    override fun hashCode(): Int = 31 * template.hashCode() + serial.pattern.hashCode()

    public companion object {
        /** Where [template] names the serial. */
        internal const val PLACE = "{serial}"

        /** The source at [template], an `https://` URL naming the serial as `{serial}`, of serials matching [serial]; none otherwise. */
        public fun of(template: String, serial: String): Option<SerialScans> = Either
            .catch { SerialScans(template, Regex(serial)) }
            .getOrNone()
            .filter { template.startsWith("https://") && PLACE in template }
    }
}

@Serializable
private data class SerialSource(val url: String, val serial: String)

private object SerialScansSerializer : KSerializer<SerialScans> by ParsedSerializer(
    "source of scans by serial",
    SerialSource.serializer(),
    { SerialScans.of(it.url, it.serial) },
    { SerialSource(it.template, it.serial.pattern) },
)
