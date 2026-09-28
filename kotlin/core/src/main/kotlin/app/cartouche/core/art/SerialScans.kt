// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.art

import arrow.core.Option
import arrow.core.Some

/**
 * A source of disc scans named after a disc's serial, such as
 * `https://psxdatacenter.com/psx2/images2/covers/{serial}/{serial}-D-ALL.jpg`: exact for its release,
 * as a serial is, where a title is ambiguous across regions and romanisations.
 */
@JvmInline
public value class SerialScans private constructor(private val template: String) {
    /** The scans of [serials] (`SLPM-65688`), in order; serials of another form, as some lists hold, are left out. */
    public fun scansOf(serials: List<String>): List<ArtUrl> =
        serials.filter(SERIAL::matches).distinct().map { ArtUrl(template.replace(PLACE, it)) }

    public companion object {
        private const val PLACE = "{serial}"
        private val SERIAL = Regex("""[A-Z]{4}-\d{5}""")

        /** The source at [template], an `https://` URL naming the serial as `{serial}`; none otherwise. */
        public fun of(template: String): Option<SerialScans> =
            Some(template).filter { it.startsWith("https://") && PLACE in it }.map(::SerialScans)
    }
}
