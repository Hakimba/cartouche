// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import arrow.core.Some
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.map

/** Settings with or without a button style chosen. */
val settings: Arb<Settings> = Arb.choice(Arb.enum<ButtonStyle>().map { Settings(Some(it)) }, Arb.constant(Settings()))
