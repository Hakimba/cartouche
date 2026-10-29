// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.settings

import app.cartouche.core.regions.PreferredRegion
import arrow.core.None
import arrow.core.Some
import arrow.core.getOrElse
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.constant
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.map

/** Settings with or without a button style chosen and a preferred region, with any edge smoothing, games floating or not, and any sound level. */
val settings: Arb<Settings> =
    Arb.bind(
        Arb.choice(Arb.enum<ButtonStyle>().map { Some(it) }, Arb.constant(None)),
        Arb.enum<EdgeSmoothing>(),
        Arb.choice(Arb.enum<PreferredRegion>().map { Some(it) }, Arb.constant(None)),
        Arb.boolean(),
        Arb.int(0..SoundLevel.MAX).map { steps -> SoundLevel.of(steps).getOrElse { SoundLevel.FULL } },
        ::Settings,
    )
