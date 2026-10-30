// SPDX-License-Identifier: GPL-3.0-or-later
@file:UseSerializers(OptionSerializer::class, NonEmptyListSerializer::class)

package app.cartouche.core.library

import app.cartouche.core.platforms.PlatformId
import arrow.core.Either
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.serialization.NonEmptyListSerializer
import arrow.core.serialization.OptionSerializer
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers

/** A variant belongs to its console and can only change once that console is set up. */
public sealed interface VariantError {
    public data class Unknown(public val platform: PlatformId, public val id: String) : VariantError

    public data class NotInLibrary(public val platform: PlatformId) : VariantError
}

/**
 * Why a console was not placed. [NotInLibrary]: it is not set up, has no games yet or is not among the platforms
 * shown.
 */
public sealed interface PlacementError {
    public data class NotInLibrary(public val platform: PlatformId) : PlacementError

    /** [gap] is not from 0 to [consoles], the number of the other consoles. */
    public data class GapOutOfRange(public val gap: Int, public val consoles: Int) : PlacementError
}

/**
 * The games of every platform, the user's choices for each platform, and what its last scan set aside. Its size
 * follows the games, not the folders: hidden and unsupported files are only counted, since a folder may hold tens of
 * thousands of them.
 */
@Serializable
public data class Library(
    public val setups: Map<PlatformId, PlatformSetup> = emptyMap(),
    public val games: List<Game> = emptyList(),
    /**
     * Files a player of the platform opens that were not taken for games (a BIOS, too small): all of them, as one may
     * be a game.
     */
    public val notGames: Map<PlatformId, List<ListedFile>> = emptyMap(),
    public val ignoredCounts: Map<PlatformId, Map<CountedReason, IgnoredCount>> = emptyMap(),
    public val skippedFolders: Map<PlatformId, List<SkippedFolder>> = emptyMap(),
    /**
     * The names the user gave consoles, shown in place of their own; left out of the stored library while there is
     * none.
     */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val consoleNames: Map<PlatformId, DisplayName> = emptyMap(),
    /** The order the user put consoles in; left out of the stored library while they put none anywhere. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val consoleOrder: List<PlatformId> = emptyList(),
    /** Each console's chosen model; libraries without choices keep the base models. */
    @OptIn(ExperimentalSerializationApi::class)
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    public val consoleVariants: Map<PlatformId, ConsoleVariant> = emptyMap(),
) {
    public fun setup(platform: PlatformId): PlatformSetup = setups.getOrElse(platform) { PlatformSetup() }

    public fun variantOf(platform: PlatformId): Option<ConsoleVariant> =
        consoleVariants.getOrNone(platform).fold({ ConsoleVariant.base(platform) }, ::Some)

    /** Changes only the model of a console already set up; unknown or foreign ids leave it unchanged. */
    public fun withVariant(platform: PlatformId, id: String): Either<VariantError, Library> = either {
        ensure(platform in setups) { VariantError.NotInLibrary(platform) }
        val variant = ConsoleVariant.of(platform, id).bind()
        copy(consoleVariants = consoleVariants + (platform to variant))
    }

    public fun game(id: GameId): Option<Game> = games.firstOrNone { it.id == id }

    public fun withSetup(platform: PlatformId, setup: PlatformSetup): Library = copy(setups = setups + (platform to setup))

    /** Replaces [platform]'s games with [scan]'s, keeping what the user chose for games still there. */
    public fun withScan(platform: PlatformId, scan: Scan): Library {
        val previous = games.filter { it.platform == platform }.associateBy { it.id }
        val scanned =
            scan.games.map { game ->
                previous.getOrNone(game.id).fold({ game }) { kept ->
                    game.copy(lastDisc = kept.lastDisc.coerceIn(game.discs.indices), label = kept.label, displayName = kept.displayName)
                }
            }
        return copy(
            games = games.filter { it.platform != platform } + scanned,
            skippedFolders = skippedFolders + (platform to scan.skippedFolders),
        ).withIgnored(platform, scan.ignored)
    }

    /** Keeps [platform]'s files that are not games, and counts the others. */
    internal fun withIgnored(platform: PlatformId, ignored: List<IgnoredFile>): Library {
        val byReason = ignored.groupBy({ it.reason }, { it.file })
        val counts =
            byReason.entries.flatMap { (reason, files) ->
                when (reason) {
                    IgnoreReason.HIDDEN -> listOf(CountedReason.HIDDEN to IgnoredCount.of(files))
                    IgnoreReason.UNSUPPORTED -> listOf(CountedReason.UNSUPPORTED to IgnoredCount.of(files))
                    IgnoreReason.NOT_A_GAME -> emptyList()
                }
            }
        return copy(
            notGames = notGames + (platform to byReason.getOrElse(IgnoreReason.NOT_A_GAME) { emptyList() }),
            ignoredCounts = ignoredCounts + (platform to counts.toMap()),
        )
    }

    /**
     * The library without [platform]: its choices, its games and what its scans set aside. The others are untouched.
     */
    public fun without(platform: PlatformId): Library = copy(
        setups = setups - platform,
        games = games.filter { it.platform != platform },
        notGames = notGames - platform,
        ignoredCounts = ignoredCounts - platform,
        skippedFolders = skippedFolders - platform,
        consoleNames = consoleNames - platform,
        consoleOrder = consoleOrder - platform,
        consoleVariants = consoleVariants - platform,
    )

    /**
     * Consoles shown in [order] from now on; those put somewhere before and not in it follow, in their order. A
     * console without games is not shown ([shown]), so a position given to one only takes effect once it has games.
     */
    public fun withConsoleOrder(order: List<PlatformId>): Library = copy(consoleOrder = (order + consoleOrder).distinct())

    /** [platforms] in the order the user put their consoles in: those put somewhere first, then the others as given. */
    public fun inConsoleOrder(platforms: List<PlatformId>): List<PlatformId> =
        (consoleOrder.filter { it in platforms } + platforms).distinct()

    /**
     * The consoles with games of [platforms] as the carousel shows them: [inConsoleOrder], those without games left
     * out.
     */
    public fun shown(platforms: List<PlatformId>): List<PlatformId> =
        inConsoleOrder(platforms).filter { platform -> games.any { it.platform == platform } }

    /**
     * [platform]'s console, which must be shown (set up, with games, among [platforms]), put between the consoles of
     * [shown] ([platforms] as [inConsoleOrder] takes them) at `gap - 1` and `gap`, the others keeping their order;
     * [gap] counts from 0 to the number of the other consoles, which the end of the row reaches.
     */
    public fun withConsoleAt(platform: PlatformId, gap: Int, platforms: List<PlatformId>): Either<PlacementError, Library> = either {
        val consoles = shown(platforms)
        ensure(platform in setups && platform in consoles) { PlacementError.NotInLibrary(platform) }
        val others = consoles - platform
        ensure(gap in 0..others.size) { PlacementError.GapOutOfRange(gap, others.size) }
        withConsoleOrder(others.take(gap) + platform + others.drop(gap))
    }

    /** Records [disc] (an index into the game's discs, kept within them) as the one launched last. */
    public fun withLastDisc(id: GameId, disc: Int): Library = withGame(id) { it.copy(lastDisc = disc.coerceIn(it.discs.indices)) }

    /** Records which image game [id]'s label shows; the other games are untouched. */
    public fun withLabel(id: GameId, label: LabelChoice): Library = withGame(id) { it.copy(label = label) }

    /** Game [id] shown as [name], or as its title again when none or when [name] is its title. */
    public fun withDisplayName(id: GameId, name: Option<DisplayName>): Library =
        withGame(id) { game -> game.copy(displayName = name.filter { it.text != game.title }) }

    private fun withGame(id: GameId, change: (Game) -> Game): Library = copy(games = games.map { if (it.id == id) change(it) else it })
}
