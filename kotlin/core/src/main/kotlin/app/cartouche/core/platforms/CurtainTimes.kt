// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.platforms

import app.cartouche.core.PackageName
import arrow.core.Either
import arrow.core.Option
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.either
import arrow.core.raise.ensure
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.MissingFieldException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

/**
 * How long the curtain, a black screen over every app, stays up once a game's emulator is started:
 * long enough for the emulator's own screens (its splash, its game list) to pass unseen, so that the
 * launch animation's black gives way to the game itself. Measured per emulator; a time of zero
 * raises no curtain.
 */
public class CurtainTimes private constructor(private val default: Duration, private val emulators: Map<PackageName, Duration>) {
    /** The time for [emulator]; an implicit launch, whose emulator Android picks, gets the default one. */
    public fun timeFor(emulator: Option<PackageName>): Duration = emulator.flatMap { emulators.getOrNone(it) }.getOrElse { default }

    public companion object {
        public val NONE: CurtainTimes = CurtainTimes(Duration.ZERO, emptyMap())

        /** No emulator takes longer to show its game; a longer time would be a mistake, keeping the screen black. */
        public val LONGEST: Duration = 10_000.milliseconds

        /**
         * Reads `{"default_ms": time, "emulators": {package name: time}}`, times in milliseconds from zero to
         * [LONGEST].
         */
        @OptIn(ExperimentalSerializationApi::class)
        public fun parse(source: DefinitionSource): Either<CatalogError, CurtainTimes> = either {
            val file =
                Either
                    .catch { Json.decodeFromString<CurtainFile>(source.text) }
                    .mapLeft { e ->
                        if (e is MissingFieldException) {
                            CatalogError.MissingField(source.name, e.missingFields.joinToString())
                        } else {
                            CatalogError.InvalidJson(source.name, e.toString())
                        }
                    }.bind()

            fun time(key: String, millis: Long): Duration = millis.milliseconds.also {
                ensure(it in Duration.ZERO..LONGEST) {
                    CatalogError.InvalidValue(source.name, key, "$millis ms is not between 0 and $LONGEST")
                }
            }
            val emulators =
                file.emulators.entries.associate { (name, millis) ->
                    val emulator =
                        PackageName.parse(name).getOrElse { raise(CatalogError.InvalidValue(source.name, name, "not a package name")) }
                    emulator to time(name, millis)
                }
            CurtainTimes(time("default_ms", file.defaultMs), emulators)
        }
    }
}

@Serializable
private data class CurtainFile(
    @SerialName("default_ms") val defaultMs: Long,
    val emulators: Map<String, Long>,
)
