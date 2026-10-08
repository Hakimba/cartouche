// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import arrow.core.None
import arrow.core.Some
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.map

/** Settings with or without a button style chosen, with any edge smoothing. */
val settings: Arb<Settings> =
    Arb.bind(
        Arb.choice(Arb.enum<ButtonStyle>().map { Some(it) }, Arb.constant(None)),
        Arb.enum<EdgeSmoothing>(),
        ::Settings,
    )
