// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class)

package app.cartouche.core.platforms

import app.cartouche.core.FileName
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.LaunchSpec
import app.cartouche.core.launch.LaunchTemplate
import app.cartouche.core.launch.RunningInstance
import app.cartouche.core.launch.Template
import app.cartouche.core.launch.TemplateError
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.ensureNotNull
import arrow.core.raise.withError
import arrow.core.separateEither
import arrow.core.serialization.OptionSerializer
import arrow.core.toOption
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull

@Serializable @JvmInline
public value class PlatformId(public val value: String)

@Serializable @JvmInline
public value class PlayerId(public val value: String)

/** A Daijishō file name pattern, matched case-insensitively (ROM sets mix `.chd` and `.CHD`). */
public class FileNamePattern private constructor(public val source: String, private val regex: Regex) {
    public fun matches(name: FileName): Boolean = regex.matches(name.value)

    override fun equals(other: Any?): Boolean = other is FileNamePattern && other.source == source

    override fun hashCode(): Int = source.hashCode()

    override fun toString(): String = source

    /**
     * The file extensions the pattern accepts, when it reads like the definitions' usual
     * `….(?:iso|chd|bin)$` and accepts any name with them; none for any other pattern.
     */
    public val extensions: Option<List<String>>
        get() =
            EXTENSIONS
                .find(source)
                .toOption()
                .map { found -> found.groupValues[1].split('|') }
                .filter { extensions -> extensions.all { matches(FileName("Game.$it")) } }

    public companion object {
        private val EXTENSIONS = Regex("""\\?\.\(\?:([A-Za-z0-9]+(?:\|[A-Za-z0-9]+)*)\)\$$""")

        public fun of(source: String): Option<FileNamePattern> =
            Either.catch { FileNamePattern(source, Regex(source, RegexOption.IGNORE_CASE)) }.getOrNone()
    }
}

/** A way to run games of a platform: an emulator (or one of its cores) and its launch template. */
public data class Player(
    public val id: PlayerId,
    public val name: String,
    public val template: Template,
    public val runningInstance: RunningInstance,
    public val accepts: FileNamePattern,
) {
    /** The name without the platform the definitions put first: `ps2 - ARMSX2 (Nightly)` is `ARMSX2 (Nightly)`. */
    public val emulatorName: String
        get() = name.substringAfter(" - ")
}

public data class Platform(
    public val id: PlatformId,
    public val name: String,
    public val players: List<Player>,
    public val accepts: FileNamePattern,
    public val profile: PlatformProfile,
)

@Serializable
public enum class MediaType {
    @SerialName("dvd")
    DVD,

    @SerialName("cartridge")
    CARTRIDGE,

    @SerialName("minidisc")
    MINIDISC,
}

/**
 * What Cartouche adds to a Daijishō platform, from `app/data/platforms/profiles.json`: the physical
 * medium its games are shown as, the size under which an unknown file is not taken for a game, and
 * where its disc scans are named after their serial, if anywhere (see `SerialScans`).
 */
@Serializable
public data class PlatformProfile(
    public val media: MediaType,
    public val minimumGameBytes: Long,
    public val scansBySerial: Option<String> = None,
)

/** A player able to open a given file, with its platform. */
public data class Candidate(public val platform: Platform, public val player: Player)

public data class Launch(public val spec: LaunchSpec, public val runningInstance: RunningInstance)

/** One definition file, as read from disk. */
public data class DefinitionSource(public val name: String, public val text: String)

public sealed interface LaunchError {
    public data class UnknownPlayer(public val id: PlayerId) : LaunchError

    public data class UnsupportedFile(public val player: PlayerId, public val file: FileName) : LaunchError

    public data class InvalidTemplate(public val error: TemplateError) : LaunchError

    /** English description, for logs. */
    public val message: String
        get() =
            when (this) {
                is UnknownPlayer -> "No player ${id.value}"
                is UnsupportedFile -> "${player.value} cannot open ${file.value}"
                is InvalidTemplate -> error.message
            }
}

public sealed interface CatalogError {
    public val source: String

    public data class InvalidJson(override val source: String, public val detail: String) : CatalogError

    public data class MissingField(override val source: String, public val key: String) : CatalogError

    public data class InvalidPattern(override val source: String, public val pattern: String) : CatalogError

    public data class InvalidTemplate(override val source: String, public val player: PlayerId, public val error: TemplateError) :
        CatalogError

    public data class DuplicatePlatform(override val source: String, public val platform: PlatformId) : CatalogError

    public data class DuplicatePlayer(override val source: String, public val player: PlayerId) : CatalogError

    public data class MissingProfile(override val source: String, public val platform: PlatformId) : CatalogError

    /** The value under [key] is not one the file allows. */
    public data class InvalidValue(override val source: String, public val key: String, public val detail: String) : CatalogError

    /** English description, for logs. */
    public val message: String
        get() =
            when (this) {
                is InvalidJson -> "Not valid JSON: $detail"
                is MissingField -> "Missing or mistyped field \"$key\""
                is InvalidPattern -> "Invalid file name pattern $pattern"
                is InvalidTemplate -> "Player ${player.value}: ${error.message}"
                is DuplicatePlatform -> "Platform ${platform.value} is already defined"
                is DuplicatePlayer -> "Player ${player.value} is already defined"
                is MissingProfile -> "Platform ${platform.value} has no Cartouche profile"
                is InvalidValue -> "Invalid value for \"$key\": $detail"
            }
}

/**
 * The platforms and players Cartouche knows, read from Daijishō definition files (a `platform`
 * object and a `playerList` array, see `app/data/platforms/daijishou/`) and Cartouche's own
 * profiles ([PlatformProfile]). Adding a platform takes data only: a definition and a profile.
 *
 * A broken or duplicate player is rejected on its own and the rest of its platform is kept; a broken
 * or duplicate platform file, or one without a profile, is rejected whole. Every rejection is kept in [rejected]: bad data is visible, never
 * silently missing. Hidden files are never offered to a player, whatever the patterns say.
 */
public data class Catalog(public val platforms: List<Platform> = emptyList(), public val rejected: List<CatalogError> = emptyList()) {
    private val all: List<Candidate> get() = platforms.flatMap { platform -> platform.players.map { Candidate(platform, it) } }

    /** Players able to open [file], in definition order. */
    public fun candidates(file: FileName): List<Candidate> =
        if (file.isHidden) emptyList() else all.filter { it.platform.accepts.matches(file) && it.player.accepts.matches(file) }

    public fun find(id: PlayerId): Option<Candidate> = all.firstOrNone { it.player.id == id }

    public fun platform(id: PlatformId): Option<Platform> = platforms.firstOrNone { it.id == id }

    /** Resolves how [id] opens [file]. */
    public fun launch(id: PlayerId, file: GameFile): Either<LaunchError, Launch> = either {
        val player = find(id).getOrElse { raise(LaunchError.UnknownPlayer(id)) }.player
        ensure(candidates(file.name).any { it.player.id == id }) { LaunchError.UnsupportedFile(id, file.name) }
        Launch(withError(LaunchError::InvalidTemplate) { player.template.resolve(file).bind() }, player.runningInstance)
    }

    public companion object {
        /** Reads the Daijishō [definitions] and the [profiles] file (`{platform id: profile}`). */
        public fun parse(definitions: List<DefinitionSource>, profiles: DefinitionSource): Catalog {
            val readProfiles =
                Either
                    .catch { Json.decodeFromString<Map<PlatformId, PlatformProfile>>(profiles.text) }
                    .mapLeft { CatalogError.InvalidJson(profiles.name, it.toString()) }
            val initial = Catalog(rejected = readProfiles.fold({ listOf(it) }, { emptyList() }))
            return definitions.fold(initial) { catalog, source ->
                either { DefinitionReader(source.name, readProfiles.getOrElse { emptyMap() }, this).platform(source.text) }.fold(
                    { catalog.copy(rejected = catalog.rejected + it) },
                    { (platform, rejectedPlayers) -> catalog.withPlatform(source.name, platform, rejectedPlayers) },
                )
            }
        }
    }

    /** Adds [platform], rejecting it if its id is taken, and its players whose id is taken. */
    private fun withPlatform(source: String, platform: Platform, rejectedPlayers: List<CatalogError>): Catalog =
        if (platforms.any { it.id == platform.id }) {
            copy(rejected = rejected + CatalogError.DuplicatePlatform(source, platform.id))
        } else {
            // `add` is false for an id taken by another platform or earlier in this one.
            val taken = all.map { it.player.id }.toMutableSet()
            val (kept, duplicates) = platform.players.partition { taken.add(it.id) }
            Catalog(
                platforms + platform.copy(players = kept),
                rejected + rejectedPlayers + duplicates.map { CatalogError.DuplicatePlayer(source, it.id) },
            )
        }
}

/** Reads one definition file; every missing or mistyped field raises a [CatalogError] naming it. */
private class DefinitionReader(val source: String, val profiles: Map<PlatformId, PlatformProfile>, raise: Raise<CatalogError>) :
    Raise<CatalogError> by raise {
    /** The platform and the players rejected from it. */
    fun platform(text: String): Pair<Platform, List<CatalogError>> {
        val root = Either.catch { Json.parseToJsonElement(text) }.getOrElse { raise(CatalogError.InvalidJson(source, it.toString())) }
        val platform = field(root, "platform") { it as? JsonObject }
        val (rejected, players) =
            field(root, "playerList") { it as? JsonArray }.separateEither { either { DefinitionReader(source, profiles, this).player(it) } }
        val id = PlatformId(text(platform, "uniqueId"))
        val profile = profiles.getOrElse(id) { raise(CatalogError.MissingProfile(source, id)) }
        return Platform(id, text(platform, "name"), players, pattern(platform, "acceptedFilenameRegex"), profile) to rejected
    }

    fun player(element: JsonElement): Player {
        val id = PlayerId(text(element, "uniqueId"))
        val arguments = text(element, "amStartArguments")
        val template = LaunchTemplate.parse(arguments).getOrElse { raise(CatalogError.InvalidTemplate(source, id, it)) }
        val stops = optional(element, "killPackageProcesses") { (it as? JsonPrimitive)?.booleanOrNull }.getOrElse { false }
        return Player(
            id = id,
            name = text(element, "name"),
            template = template,
            runningInstance = if (stops) RunningInstance.STOP else RunningInstance.KEEP,
            accepts = pattern(element, "acceptedFilenameRegex"),
        )
    }

    private fun text(parent: JsonElement, key: String): String =
        field(parent, key) { (it as? JsonPrimitive)?.takeIf(JsonPrimitive::isString)?.content }

    private fun pattern(parent: JsonElement, key: String): FileNamePattern =
        text(parent, key).let { regex -> FileNamePattern.of(regex).getOrElse { raise(CatalogError.InvalidPattern(source, regex)) } }

    private fun <T : Any> optional(parent: JsonElement, key: String, cast: (JsonElement) -> T?): Option<T> =
        if (parent is JsonObject && key in parent) Some(field(parent, key, cast)) else None

    // kotlinx.serialization reports absent or mistyped JSON values as nulls; they stop here.
    private fun <T : Any> field(parent: JsonElement, key: String, cast: (JsonElement) -> T?): T =
        ensureNotNull((parent as? JsonObject)?.get(key)?.let(cast)) { CatalogError.MissingField(source, key) }
}
