// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import app.cartouche.android.apps.InstalledApps
import app.cartouche.android.art.ArtStore
import app.cartouche.android.art.Fetch
import app.cartouche.android.art.FetchFailure
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.HttpFetch
import app.cartouche.android.art.Scraper
import app.cartouche.android.launch.Curtain
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.launch.Launcher
import app.cartouche.android.library.LaunchChoice
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.art.ArtIndex
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.SerialScans
import app.cartouche.core.launch.GameFile
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.DemoLibrary
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.GameId
import app.cartouche.core.library.LibraryFormat
import app.cartouche.core.library.PlatformSetup
import app.cartouche.core.library.TitleIndex
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.CatalogError
import app.cartouche.core.platforms.CurtainTimes
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.Launch
import app.cartouche.core.platforms.Platform
import app.cartouche.core.platforms.PlatformId
import app.cartouche.core.platforms.Player
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.left
import arrow.core.merge
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.recover
import arrow.core.separateEither
import arrow.core.toOption
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.time.TimeSource

/**
 * Cartouche's Android services, reached from GDScript as `Engine.get_singleton("CartoucheAndroid")`
 * and wrapped by `app/adapters/android/android_services.gd`. The wire format is described in
 * `Wire.kt`.
 *
 * Methods are called on Godot's render thread. Getters answer directly. Operations take a request id
 * and answer it exactly once, later, through the `answered` signal: their work runs in [scope] on the
 * IO dispatcher (the folder pick on the main thread), activity starts on the main thread, and every
 * exception stops at [answer], except the cancellation of [scope] when the activity is destroyed.
 */
public class CartouchePlugin(godot: Godot) : GodotPlugin(godot) {
    // A failure no operation stops is logged, and ends only its own coroutine.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO + CoroutineExceptionHandler { _, e -> unexpected(e) })
    private val folders by lazy { Folders(context) }
    private val launcher by lazy { Launcher(context, folders) }
    private val curtain by lazy { Curtain(context.applicationContext, scope) }
    private val pendingPick = PendingPick<Dictionary> { requestId, payload -> answer(requestId) { payload } }
    private val artStore by lazy { ArtStore(File(context.filesDir, "art")) }
    private val scraper by lazy { Scraper(artStore, artFetch(), scope, ::artChanged) }
    private val network =
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = scraper.networkBack()
        }

    /** Watches the network from the first art looked for on, to resume as soon as it comes back. */
    private val watchingNetwork = lazy { Either.catch { connectivity.registerDefaultNetworkCallback(network) }.isRight() }

    private val connectivity by lazy { context.getSystemService(ConnectivityManager::class.java) }

    /** Written on the render thread, read by operations too; immutable, so publishing it is enough. */
    @Volatile private var catalog = Catalog()

    /** Reference lists by platform, as loaded; each is indexed on its first scan. */
    @Volatile private var titleLists: Map<PlatformId, String> = emptyMap()

    @Volatile private var titleIndexes = ConcurrentHashMap<PlatformId, TitleIndex>()

    @Volatile private var dataFolders = DataFolders.NONE

    @Volatile private var curtainTimes = CurtainTimes.NONE

    /** Art extracts by platform, as loaded; each is indexed on first use. */
    @Volatile private var artLists: Map<PlatformId, String> = emptyMap()

    @Volatile private var artSources = ConcurrentHashMap<PlatformId, ArtSources>()

    /** Whether the library shown is a demo one, whose games have no art to look for. */
    @Volatile private var demo = false

    /** Runs every library call, one at a time (see [LibraryService]). */
    private val libraryThread = Dispatchers.IO.limitedParallelism(1)

    /** Only used on [libraryThread], which [useDemoLibrary] replaces it on. */
    private var library: Lazy<LibraryService> = lazy { libraryIn(context.filesDir) }

    /** Whether each package is installed, forgotten on resume since apps may be installed meanwhile. */
    private val installed = ConcurrentHashMap<PackageName, Boolean>()

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> =
        setOf(SignalInfo(ANSWERED_SIGNAL, Dictionary::class.java), SignalInfo(ART_SIGNAL, Dictionary::class.java))

    override fun onMainResume() {
        installed.clear()
        curtain.lower()
        scraper.start()
    }

    // Nothing is downloaded while a game is played.
    override fun onMainPause(): Unit = scraper.stop()

    override fun onMainDestroy() {
        curtain.lower()
        if (watchingNetwork.isInitialized() && watchingNetwork.value) {
            Either.catch { connectivity.unregisterNetworkCallback(network) }
        }
        scope.cancel()
    }

    // Getters

    /**
     * Loads Daijishō definitions given as `{file name: JSON text}` (read in file name order), the
     * profiles file's text, the reference lists as `{platform id: text}`, the emulator data folder
     * names (`data_folders.json`), the curtain times (`curtains.json`) and the art extracts as
     * `{platform id: text}`; returns the catalog summary.
     */
    @UsedByGodot
    public fun loadCatalog(
        definitions: Dictionary,
        profiles: String,
        titles: Dictionary,
        dataFolderNames: String,
        curtains: String,
        art: Dictionary,
    ): Dictionary {
        val (notText, sources) =
            definitions.keys.sorted().separateEither { name ->
                definitions.text(name).map { DefinitionSource(name, it) }.toEither { CatalogError.InvalidJson(name, "not text") }
            }
        titleLists = titles.textsByPlatform()
        titleIndexes = ConcurrentHashMap()
        artLists = art.textsByPlatform()
        artSources = ConcurrentHashMap()
        val folderNames = DataFolders.parse(DefinitionSource("data_folders.json", dataFolderNames))
        dataFolders = folderNames.getOrElse { DataFolders.NONE }
        val times = CurtainTimes.parse(DefinitionSource("curtains.json", curtains))
        curtainTimes = times.getOrElse { CurtainTimes.NONE }
        catalog =
            Catalog.parse(sources, DefinitionSource("profiles.json", profiles)).let {
                it.copy(rejected = notText + folderNames.swap().getOrNone().toList() + times.swap().getOrNone().toList() + it.rejected)
            }
        // Indexing takes a second or so on a handheld: done now, the first scan does not wait for it.
        scope.launch { Either.catch { titleLists.keys.forEach(::titles) }.onLeft(::unexpected) }
        return catalog.toWire()
    }

    /** Installed players able to open [fileName], in definition order. */
    @UsedByGodot
    public fun candidates(fileName: String): Array<Any> =
        catalog.candidates(FileName(fileName)).filter { isAvailable(it.player) }.toWireArray { it.toWire() }

    /** The installed players of [platformId], in definition order: `[{"player_id", "player_name"}]`. */
    @UsedByGodot
    public fun installedPlayers(platformId: String): Array<Any> = catalog
        .platform(PlatformId(platformId))
        .fold({ emptyList() }) { it.players.filter(::isAvailable) }
        .toWireArray { dictionary("player_id" to it.id.value, "player_name" to it.name) }

    @UsedByGodot
    public fun hasAllFilesAccess(): Boolean = Environment.isExternalStorageManager()

    /** Whether a curtain can hide an emulator until its game shows: the "display over other apps" permission. */
    @UsedByGodot
    public fun curtainAllowed(): Boolean = curtain.isAllowed

    /** `{"level_percent": int (absent when unknown), "charging": bool}` */
    @UsedByGodot
    public fun battery(): Dictionary {
        val manager = context.getSystemService(BatteryManager::class.java).toOption()
        // An unsupported capacity reads as Int.MIN_VALUE, or 0 on some devices.
        val level = manager.map { it.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) }.filter { it in 1..100 }
        return dictionary("charging" to manager.isSome { it.isCharging }).putSome("level_percent", level)
    }

    /** Such as `Acme Handheld 2, Android 13`. */
    @UsedByGodot
    public fun deviceName(): String = "${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE}"

    /**
     * Debug builds only: the `arguments` string array extra of the launch intent, such as
     * `am start -n app.cartouche/com.godot.game.GodotAppLauncher --esa arguments --demo-games=150`,
     * which sets up measurements. Godot's own command line is not passed through the launcher. A
     * `String[]` reaches GDScript as a PackedStringArray.
     */
    @UsedByGodot
    public fun launchArguments(): Array<String> = activity
        .toOption()
        .flatMap { it.intent.getStringArrayExtra("arguments").toOption() }
        .filter { BuildConfig.DEBUG }
        .getOrElse { emptyArray() }

    // Operations

    /** Opens the system screen granting "All files access". */
    @UsedByGodot
    public fun requestAllFilesAccess(requestId: Int): Unit = openSetting(
        requestId,
        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
        Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION,
    )

    /** Opens the system screen granting "display over other apps", which the curtain needs ([curtainAllowed]). */
    @UsedByGodot
    public fun requestCurtainPermission(requestId: Int): Unit =
        openSetting(requestId, Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Settings.ACTION_MANAGE_OVERLAY_PERMISSION)

    /** Opens the folder picker; answers with `{"folder"}` once the user picked one. */
    @UsedByGodot
    public fun pickFolder(requestId: Int): Unit = onActivity(requestId) { act ->
        scope.launch(Dispatchers.Main) {
            pendingPick.start(requestId, failure(ErrorCode.CANCELLED, "Replaced by a new pick")) {
                Either.catch { launcher.pickFolder(act, REQUEST_PICK_FOLDER) }.fold({ Some(unexpected(it)) }) { opened ->
                    opened.swap().getOrNone().map { it.toWire() }
                }
            }
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        trace("activity result") { "request $requestCode, result $resultCode, data ${data.toOption().flatMap { it.data.toOption() }}" }
        if (requestCode != REQUEST_PICK_FOLDER) return
        val requestId = pendingPick.end()
        val picked = data.toOption().flatMap { it.data.toOption() }.filter { resultCode == Activity.RESULT_OK }
        scope.launch {
            // A result reaching a restarted process belongs to no request; the folder is still kept.
            val result =
                guarded {
                    picked.fold(
                        { failure(ErrorCode.CANCELLED, "Picker closed without a folder") },
                        { uri -> folders.keepAccess(uri).fold({ it.toWire() }, { success("folder" to it.toWire()) }) },
                    )
                }
            requestId.onSome { answer(it) { result } }
        }
    }

    /** Answers with `{"folders"}`, the folders whose access survived until now. */
    @UsedByGodot
    public fun persistedFolders(requestId: Int): Unit = inBackground(requestId) {
        folders.persisted().fold({ it.toWire() }, { list -> success("folders" to list.toWireArray { it.toWire() }) })
    }

    /** Lists one level of `{"tree_uri", "document_id"?}` (its root without a document id); answers with `{"entries"}`. */
    @UsedByGodot
    public fun listFolder(requestId: Int, location: Dictionary): Unit = inBackground(requestId) {
        val tree = location.text("tree_uri").flatMap(ContentUri::parse)
        tree.fold({ invalid("listFolder needs a tree URI") }) { uri ->
            folders
                .list(uri, location.text("document_id").map(::DocumentId))
                .fold({ it.toWire() }, { entries -> success("entries" to entries.toWireArray { it.toWire() }) })
        }
    }

    /** Answers with `{"apps"}`, the apps with a launcher icon. */
    @UsedByGodot
    public fun listLaunchableApps(requestId: Int): Unit = inBackground(requestId) {
        success("apps" to InstalledApps.launchable(context.packageManager).toWireArray { it.toWire() })
    }

    @UsedByGodot
    public fun launchApp(requestId: Int, packageName: String): Unit =
        PackageName.parse(packageName).fold({ answer(requestId) { invalid("Invalid package $packageName") } }) {
            withActivity(requestId) { act -> start(act, launcher.appIntent(it)) }
        }

    /**
     * Answers with `{"library", "art"}`, the library read from its file on first use and the label
     * images stored for its games (see [artWireJson]); then looks for the others' art.
     */
    @UsedByGodot
    public fun library(requestId: Int) {
        answering(requestId, libraryThread) {
            library.value.run {
                val stored = library().games.flatMap { game -> artStore.stored(game.id).map { FoundArt(game.id, it) }.toList() }
                success("library" to wire(this), "art" to stored.artWireJson()).putSome("load_problem", loadProblem)
            }
        }
        lookForArt()
    }

    /**
     * Stores the choices `{"folder_uri"?, "player_id"?, "disc_grouping", "folder_depth"}` for
     * [platformId]; answers with `{"library"}`.
     */
    @UsedByGodot
    public fun setUpPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = answering(requestId, libraryThread) {
        val platform = platform(PlatformId(platformId))

        fun <T> code(key: String, values: List<T>, wire: (T) -> String): T = setup
            .text(key)
            .flatMap { text ->
                values.firstOrNone { wire(it) == text }
            }.getOrElse { raise(invalid("$key is missing or unknown")) }
        val folder = setup.text("folder_uri").map { ContentUri.parse(it).getOrElse { raise(invalid("folder_uri is not a content URI")) } }
        val discs = code("disc_grouping", DiscGrouping.entries) { it.wire }
        val depth = code("folder_depth", FolderDepth.entries) { it.wire }
        val choices = PlatformSetup(folder, setup.text("player_id").map(::PlayerId), discs, depth)
        inLibrary { setUp(platform.id, choices) }
        success("library" to wire(library.value))
    }

    /** Scans [platformId]'s folder; answers with `{"library", "report"}`. */
    @UsedByGodot
    public fun scanPlatform(requestId: Int, platformId: String): Unit = answering(requestId, libraryThread) {
        val platform = platform(PlatformId(platformId))
        val titles = titles(platform.id)
        val report = inLibrary { scan(platform, titles, dataFolders) }.second
        success("library" to wire(library.value), "report" to report.toWire()).also { lookForArt() }
    }

    /** Remembers [gameId] as the selected game of its platform, and that platform as the one shown. */
    @UsedByGodot
    public fun selectGame(requestId: Int, gameId: String): Unit = answering(requestId, libraryThread) {
        inLibrary { select(GameId(gameId)) }
        success()
    }

    /**
     * Debug builds only: replaces the library with a made-up one of [games] games spread over the
     * catalog's platforms, stored apart (the user's library is left alone), for measuring at
     * scale; answers with `{"library"}`.
     */
    @UsedByGodot
    public fun useDemoLibrary(requestId: Int, games: Int): Unit = answering(requestId, libraryThread) {
        ensure(BuildConfig.DEBUG) { invalid("The demo library only exists in debug builds") }
        // Named after the library format: a library saved by an older build is never measured again.
        val folder = File(context.filesDir, "demo-${LibraryFormat.VERSION}-$games").apply { mkdirs() }
        val store = LibraryStore(File(folder, LIBRARY_FILE))
        if (store.load().fold({ true }) { it.library.games.isEmpty() }) {
            store.save(DemoLibrary.of(games, catalog.platforms.map { it.id })).mapLeft { it.toWire() }.bind()
        }
        library = lazyOf(libraryIn(folder))
        demo = true
        scraper.lookFor(emptyList())
        success("library" to wire(library.value))
    }

    /**
     * Checks that the library game `{"game_id", "disc"?}` can launch, as [launchGame] would, and
     * answers with its failure if it cannot; starts and stops nothing.
     */
    @UsedByGodot
    public fun checkLaunch(requestId: Int, request: Dictionary): Unit = answering(requestId, libraryThread) {
        val (choice, launch) = libraryLaunch(request)
        launcher.checkGame(launch, choice.file.uri).mapLeft { it.toWire() }.bind()
        success()
    }

    /**
     * Launches the library game `{"game_id", "disc"?}` (a disc index; the last launched by default)
     * with its platform's player, under the curtain when it is allowed.
     */
    @UsedByGodot
    public fun launchGame(requestId: Int, request: Dictionary): Unit = onActivity(requestId) { act ->
        answering(requestId, libraryThread) {
            val (choice, launch) = libraryLaunch(request)
            trace("launch") { "${choice.file.name.value} in ${launch.spec.targetPackage.fold({ "the app Android picks" }) { it.value }}" }
            val intent = launcher.prepareGame(launch, choice.file.uri).mapLeft { it.toWire() }.bind()
            onMain {
                curtain.over(
                    curtainTimes.timeFor(launch.spec.targetPackage),
                ) { launcher.start(act, intent) }
            }.mapLeft { it.toWire() }.bind()
            // Answered at once, for the black to last no longer than the start; a failure to
            // remember the disc must not report the launch as failed.
            scope.launch(libraryThread) {
                Either
                    .catch { library.value.recordLaunch(choice.game.id, choice.disc) }
                    .onLeft(::unexpected)
                    .onRight { saved -> saved.onLeft { trace("library") { "last disc not saved: ${it.message}" } } }
            }
            success()
        }
    }

    /** Launches the file `{"name", "uri", "path"?}` with [playerId], outside the library. */
    @UsedByGodot
    public fun launchFile(requestId: Int, playerId: String, file: Dictionary) {
        val game =
            option {
                GameFile(
                    FileName(file.text("name").bind()),
                    ContentUri.parse(file.text("uri").bind()).bind(),
                    file.text("path").map(::FilePath),
                )
            }
        game.fold({ answer(requestId) { invalid("launchFile needs a name and a content URI") } }) {
            withActivity(requestId) { act -> start(act, prepared(PlayerId(playerId), it)) }
        }
    }

    // Plumbing

    /**
     * Looks for the art of the library's games that have none, in library order, on [libraryThread]
     * after the calls already there: an answer never waits for it, and its failure fails no answer.
     */
    private fun lookForArt() {
        scope.launch(libraryThread) {
            if (demo) return@launch
            val requests =
                library.value.library().games.flatMap { game ->
                    sources(game.platform).requestFor(game).toList()
                }
            scraper.lookFor(requests)
            if (!watchingNetwork.value) trace("art") { "the network is not watched: retries only follow their delay" }
        }
    }

    private fun artChanged(run: Scraping, found: Option<FoundArt>): Unit =
        emitSignal(ART_SIGNAL, run.toWire().putSome("found", found.map { it.toWire() }))

    private fun sources(platform: PlatformId): ArtSources = artSources.computeIfAbsent(platform) {
        val started = TimeSource.Monotonic.markNow()
        val bySerial = catalog.platform(platform).flatMap { it.profile.scansBySerial }.flatMap(SerialScans::of)
        ArtSources(artLists.getOrNone(platform).fold({ ArtIndex.EMPTY }, ArtIndex::parse), bySerial).also {
            trace("art") { "${platform.value}: ${it.size} games indexed in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
    }

    /** Downloads over HTTP; in debug builds, `--art-refused` makes every server refuse, to try the message and the retries. */
    private fun artFetch(): Fetch = if (BuildConfig.DEBUG &&
        "--art-refused" in launchArguments()
    ) {
        Fetch { FetchFailure.Refused(503).left() }
    } else {
        HttpFetch("Cartouche")
    }

    private suspend fun <T> onLibrary(block: LibraryService.() -> T): T = withContext(libraryThread) { library.value.block() }

    private fun libraryIn(folder: File): LibraryService =
        LibraryService(LibraryStore(File(folder, LIBRARY_FILE)), SelectionStore(File(folder, "selection.json")), folders)

    /** [onLibrary] for a call that can fail: its failure becomes the answer. */
    private suspend fun <T> Raise<Dictionary>.inLibrary(block: LibraryService.() -> Either<LibraryFailure, T>): T =
        onLibrary(block).mapLeft { it.toWire() }.bind()

    /**
     * Answers [requestId] with what [work] returns, or with the failure it raises. Library calls
     * start on [libraryThread] itself, which runs them in the order they arrive.
     */
    private fun answering(requestId: Int, on: CoroutineDispatcher = Dispatchers.IO, work: suspend Raise<Dictionary>.() -> Dictionary) {
        scope.launch(on) { answer(requestId) { either { work() }.merge() } }
    }

    private fun prepared(player: PlayerId, file: GameFile): Either<LaunchFailure, Intent> =
        launchOf(player, file).flatMap { launcher.prepareGame(it, file.uri) }

    private fun launchOf(player: PlayerId, file: GameFile): Either<LaunchFailure, Launch> =
        catalog.launch(player, file).mapLeft(LaunchFailure::Rejected)

    /** Opens the settings screen [forCartouche], or [forEveryApp] on the Android builds that only offer the screen listing every app. */
    private fun openSetting(requestId: Int, forCartouche: String, forEveryApp: String): Unit = withActivity(requestId) { act ->
        onMain {
            launcher.start(act, Intent(forCartouche, Uri.parse("package:${act.packageName}"))).recover { failure ->
                ensure(failure is LaunchFailure.ActivityNotFound) { failure }
                launcher.start(act, Intent(forEveryApp)).bind()
            }
        }
    }

    /** What launching the library game `{"game_id", "disc"?}` takes: its choice and its launch with its platform's player. */
    private suspend fun Raise<Dictionary>.libraryLaunch(request: Dictionary): Pair<LaunchChoice, Launch> {
        val id = request.text("game_id").map(::GameId).getOrElse { raise(invalid("the request needs a game_id")) }
        val choice = inLibrary { launchChoice(id, request.integer("disc")) }
        val platform = platform(choice.game.platform)
        val player =
            choice.setup.playerFor(platform, choice.file.name, ::isAvailable).getOrElse {
                raise(LaunchFailure.NoPlayer(platform.id).toWire())
            }
        return choice to launchOf(player.id, choice.file.asGameFile).mapLeft { it.toWire() }.bind()
    }

    private fun Raise<Dictionary>.platform(id: PlatformId): Platform =
        catalog.platform(id).getOrElse { raise(failure(ErrorCode.UNKNOWN_PLATFORM, "No platform ${id.value}")) }

    private fun titles(platform: PlatformId): TitleIndex = titleIndexes.computeIfAbsent(platform) {
        val started = TimeSource.Monotonic.markNow()
        titleLists.getOrNone(platform).fold({ TitleIndex.EMPTY }, TitleIndex::parse).also {
            trace("titles") { "${platform.value}: ${it.size} indexed in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
    }

    /** The library of [service] and its shelves, for Godot. */
    private fun wire(service: LibraryService): String {
        val started = TimeSource.Monotonic.markNow()
        return service.library().toWireJson(service.shelves(catalog.platforms.map { it.id })).also {
            trace("library") { "${it.length} characters of JSON in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
    }

    /** `{platform id: text}` as sent by the adapter, texts of another type left out. */
    private fun Dictionary.textsByPlatform(): Map<PlatformId, String> = keys
        .flatMap { id ->
            text(id).map { PlatformId(id) to it }.toList()
        }.toMap()

    private fun invalid(detail: String): Dictionary = failure(ErrorCode.INVALID_REQUEST, detail)

    // The system resolves implicit intents, so they are always available.
    private fun isAvailable(player: Player): Boolean =
        player.template.targetPackage.fold({ true }) { installed.getOrPut(it) { isInstalled(it) } }

    private fun isInstalled(packageName: PackageName): Boolean =
        InstalledApps.isInstalled(context.packageManager, packageName).also { trace("installed") { "${packageName.value}: $it" } }

    private fun inBackground(requestId: Int, work: suspend () -> Dictionary) {
        scope.launch { answer(requestId) { work() } }
    }

    /** Runs [work] in the background with the current activity; activity starts go through [onMain]. */
    private fun withActivity(requestId: Int, work: suspend (Activity) -> Either<LaunchFailure, Unit>): Unit =
        onActivity(requestId) { act -> inBackground(requestId) { work(act).toWire() } }

    private fun onActivity(requestId: Int, work: (Activity) -> Unit): Unit =
        activity.toOption().fold({ answer(requestId) { failure(ErrorCode.NO_ACTIVITY, "No activity") } }, work)

    private suspend fun start(activity: Activity, intent: Either<LaunchFailure, Intent>): Either<LaunchFailure, Unit> =
        intent.flatMap { onMain { launcher.start(activity, it) } }

    private suspend fun <T> onMain(block: () -> T): T = withContext(Dispatchers.Main) { block() }

    private inline fun answer(requestId: Int, work: () -> Dictionary) {
        emitSignal(ANSWERED_SIGNAL, guarded(work).apply { put("request_id", requestId) })
    }

    /** The single place where unexpected exceptions stop. */
    private inline fun guarded(work: () -> Dictionary): Dictionary = Either.catch(work).getOrElse(::unexpected)

    private fun unexpected(e: Throwable): Dictionary {
        Log.e(TAG, "Unexpected failure", e)
        return failure(ErrorCode.UNEXPECTED, e.toString())
    }

    private companion object {
        // Godot forwards every activity result to every plugin: this code only has to be unique
        // among the plugins bundled with the app.
        const val REQUEST_PICK_FOLDER = 0xCA27

        const val LIBRARY_FILE = "library.json"

        const val ART_SIGNAL = "art_changed"
    }
}
