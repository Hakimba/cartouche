// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.content.Intent
import android.graphics.ImageDecoder
import android.net.ConnectivityManager
import android.net.Network
import android.net.Uri
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
import app.cartouche.android.art.LabelChoices
import app.cartouche.android.art.OwnPictures
import app.cartouche.android.art.Scraper
import app.cartouche.android.art.StoredArt
import app.cartouche.android.art.VariantDownloads
import app.cartouche.android.art.VariantFailure
import app.cartouche.android.launch.Curtain
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.launch.Launcher
import app.cartouche.android.library.LaunchChoice
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.android.storage.SettingsStore
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.art.ArtIndex
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.LabelFraming
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.SerialScans
import app.cartouche.core.launch.GameFile
import app.cartouche.core.library.DataFolders
import app.cartouche.core.library.DemoLibrary
import app.cartouche.core.library.DiscGrouping
import app.cartouche.core.library.DisplayName
import app.cartouche.core.library.FolderDepth
import app.cartouche.core.library.Game
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
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
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
import app.cartouche.core.settings.Settings as AppSettings

/**
 * Cartouche's Android services, reached from GDScript as `Engine.get_singleton("CartoucheAndroid")`
 * and wrapped by `app/adapters/android/android_services.gd`. The wire format is described in
 * `Wire.kt`.
 *
 * Methods are called on Godot's render thread. Getters answer directly, and [prepareTitles] only
 * starts its work. Operations take a request id and answer it exactly once, later, through the
 * `answered` signal: their work runs in [scope] on the IO dispatcher (the folder pick on the main
 * thread), activity starts on the main thread, and every exception stops at [answer], except the
 * cancellation of [scope] when the activity is destroyed.
 */
public class CartouchePlugin(godot: Godot) : GodotPlugin(godot) {
    // A failure no operation stops is logged, and ends only its own coroutine.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO + CoroutineExceptionHandler { _, e -> unexpected(e) })
    private val folders by lazy { Folders(context) }
    private val launcher by lazy { Launcher(context, folders) }
    private val curtain by lazy { Curtain(context.applicationContext, scope) }
    private val pendingPick = PendingPick<Dictionary> { requestId, payload -> answer(requestId) { payload } }
    private val pendingPicture = PendingPick<Dictionary> { requestId, payload -> answer(requestId) { payload } }
    private val ownPictures by lazy { OwnPictures(File(context.cacheDir, "own-label")) }
    private val artStore by lazy { ArtStore(File(context.filesDir, "art")) }
    private val fetch by lazy { artFetch() }
    private val scraper by lazy { Scraper(artStore, fetch, scope, ::artChanged) }

    private val variantDownloads by lazy {
        VariantDownloads(artStore, fetch, scope, Dispatchers.IO.limitedParallelism(VARIANT_DOWNLOADS), ::variantDownloaded)
    }

    // Told on the render thread, after Godot has registered this plugin's signals there: at a cold
    // start, the battery's first broadcast can come before.
    private val batteryWatch = BatteryWatch { runOnRenderThread { emitSignal(BATTERY_SIGNAL, it.toWire()) } }

    private val network =
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = scraper.networkBack()
        }

    /** Watches the network from the first art looked for on, to resume as soon as it comes back. */
    private val watchingNetwork = lazy { Either.catch { connectivity.registerDefaultNetworkCallback(network) }.isRight() }

    private val connectivity by lazy { context.getSystemService(ConnectivityManager::class.java) }

    /** Written on the render thread, read by operations too; immutable, so publishing it is enough. */
    @Volatile private var catalog = Catalog()

    /** Reference lists by platform, as loaded; each is indexed on first use, or ahead by [prepareTitles]. */
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

    /** Plans each look for art, one at a time, in the order asked. */
    private val artPlanning = Dispatchers.IO.limitedParallelism(1)

    /** Only used on [libraryThread], which [useDemoLibrary] replaces it on. */
    private var library: Lazy<LibraryService> = lazy { libraryIn(context.filesDir) }

    /** Only used on [libraryThread]. */
    private val settingsStore by lazy { SettingsStore(File(context.filesDir, "settings.json")) }

    /** Whether each package is installed, forgotten on resume since apps may be installed meanwhile. */
    private val installed = ConcurrentHashMap<PackageName, Boolean>()

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(ANSWERED_SIGNAL, Dictionary::class.java),
        SignalInfo(ART_SIGNAL, Dictionary::class.java),
        SignalInfo(VARIANT_SIGNAL, Dictionary::class.java),
        SignalInfo(BATTERY_SIGNAL, Dictionary::class.java),
    )

    override fun onMainResume() {
        installed.clear()
        curtain.lower()
        scraper.start()
        batteryWatch.follow(context)
    }

    // Nothing is downloaded, and the battery not followed, while a game is played.
    override fun onMainPause() {
        scraper.stop()
        batteryWatch.stop(context)
    }

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
        return catalog.toWire()
    }

    /**
     * Indexes the reference lists in the background, as the settings or the form adding a console
     * open: a start that adds or changes no console does not pay for it, and the form's first count
     * of a folder does not wait for it.
     */
    @UsedByGodot
    public fun prepareTitles() {
        scope.launch { titleLists.keys.forEach(::titles) }
    }

    /** Installed players able to open [fileName], in definition order. */
    @UsedByGodot
    public fun candidates(fileName: String): Array<Any> =
        catalog.candidates(FileName(fileName)).filter { isAvailable(it.player) }.toWireArray { it.toWire() }

    /** The installed players of [platformId], in definition order: `[{"player_id", "player_name", "emulator_name", "extensions"?}]`. */
    @UsedByGodot
    public fun installedPlayers(platformId: String): Array<Any> = catalog
        .platform(PlatformId(platformId))
        .fold({ emptyList() }) { it.players.filter(::isAvailable) }
        .toWireArray { player ->
            dictionary("player_id" to player.id.value, "player_name" to player.name, "emulator_name" to player.emulatorName)
                .putSome("extensions", player.accepts.extensions.map { it.toTypedArray() })
        }

    @UsedByGodot
    public fun hasAllFilesAccess(): Boolean = Environment.isExternalStorageManager()

    /** Whether a curtain can hide an emulator until its game shows: the "display over other apps" permission. */
    @UsedByGodot
    public fun curtainAllowed(): Boolean = curtain.isAllowed

    /** The battery now, as [BatteryState.toWire] has it; then [BATTERY_SIGNAL] tells each change. */
    @UsedByGodot
    public fun battery(): Dictionary = BatteryState.now(context).toWire()

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
    public fun pickFolder(requestId: Int): Unit = picking(requestId, pendingPick) { launcher.pickFolder(it, REQUEST_PICK_FOLDER) }

    /** Opens a system picker with [open], on the main thread, as [pending]'s pick of [requestId]. */
    private fun picking(requestId: Int, pending: PendingPick<Dictionary>, open: (Activity) -> Either<LaunchFailure, Unit>): Unit =
        onActivity(requestId) { act ->
            scope.launch(Dispatchers.Main) {
                pending.start(requestId, failure(ErrorCode.CANCELLED, "Replaced by a new pick")) {
                    Either.catch { open(act) }.fold({ Some(unexpected(it)) }) { opened -> opened.swap().getOrNone().map { it.toWire() } }
                }
            }
        }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val uri = data.toOption().flatMap { it.data.toOption() }
        trace("activity result") { "request $requestCode, result $resultCode, data $uri" }
        val picked = uri.filter { resultCode == Activity.RESULT_OK }
        when (requestCode) {
            REQUEST_PICK_FOLDER -> folderPicked(picked)
            REQUEST_PICK_PICTURE -> picturePicked(picked)
        }
    }

    private fun folderPicked(picked: Option<Uri>) {
        val requestId = pendingPick.end()
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

    /**
     * Opens the system's picker on images, for a picture of the user's own to put on a label; once
     * one is picked, the app keeps an upright copy of it to be framed and answers with
     * `{"picture": {"path", "width", "height"}}`.
     */
    @UsedByGodot
    public fun pickLabelPicture(requestId: Int): Unit =
        picking(requestId, pendingPicture) { launcher.pickPicture(it, REQUEST_PICK_PICTURE) }

    // A result reaching a restarted process belongs to no request: nothing is copied.
    private fun picturePicked(picked: Option<Uri>) = pendingPicture.end().onSome { requestId ->
        scope.launch {
            val started = System.nanoTime()
            answer(requestId) {
                picked.fold(
                    { failure(ErrorCode.CANCELLED, "Picker closed without a picture") },
                    { uri ->
                        ownPictures
                            .keep(ImageDecoder.createSource(context.contentResolver, uri))
                            .fold({ it.toWire() }, { success("picture" to it.toWire()) })
                    },
                )
            }
            trace("art") { "picture picked and copied in ${(System.nanoTime() - started) / 1_000_000} ms" }
        }
    }

    /**
     * Shows the picture of the user's own picked last ([pickLabelPicture]) on [gameId]'s label from
     * now on, framed [zoom] times closer than the largest square that fits and centred at [x], [y]
     * (see [LabelFraming]), and remembers the choice (see [LabelChoices]); answers with
     * `{"art": {"game_id", "path"}}`. The picture is cut in the background, the library only waiting
     * for the choice to be recorded.
     */
    @UsedByGodot
    public fun keepOwnLabel(requestId: Int, gameId: String, zoom: Double, x: Double, y: Double): Unit = answering(requestId) {
        val started = System.nanoTime()
        val image = ownPictures.framed(LabelFraming(zoom, x, y)).mapLeft { it.toWire() }.bind()
        withContext(libraryThread) {
            val game = game(GameId(gameId))
            val art = LabelChoices(library.value, artStore).keepOwn(game, image).mapLeft { it.toWire() }.bind()
            trace("art") { "${game.title}: own label kept in ${(System.nanoTime() - started) / 1_000_000} ms" }
            success("art" to FoundArt(game.id, art).toWire())
        }
    }

    /** Answers with `{"folders"}`, the folders whose access survived until now. */
    @UsedByGodot
    public fun persistedFolders(requestId: Int): Unit = answering(requestId) {
        folders.persisted().fold({ it.toWire() }, { list -> success("folders" to list.toWireArray { it.toWire() }) })
    }

    /** Lists one level of `{"tree_uri", "document_id"?}` (its root without a document id); answers with `{"entries"}`. */
    @UsedByGodot
    public fun listFolder(requestId: Int, location: Dictionary): Unit = answering(requestId) {
        val tree = location.text("tree_uri").flatMap(ContentUri::parse)
        tree.fold({ invalid("listFolder needs a tree URI") }) { uri ->
            folders
                .list(uri, location.text("document_id").map(::DocumentId))
                .fold({ it.toWire() }, { entries -> success("entries" to entries.toWireArray { it.toWire() }) })
        }
    }

    /** Answers with `{"apps"}`, the apps with a launcher icon. */
    @UsedByGodot
    public fun listLaunchableApps(requestId: Int): Unit = answering(requestId) {
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
        val asked = TimeSource.Monotonic.markNow()
        answering(requestId, libraryThread) {
            val started = asked.elapsedNow().inWholeMilliseconds
            library.value.run {
                val loaded = asked.elapsedNow().inWholeMilliseconds
                val stored = library().games.flatMap { game -> artStore.stored(game.id).map { FoundArt(game.id, it) }.toList() }
                val found = asked.elapsedNow().inWholeMilliseconds
                success("library" to wire(this), "art" to stored.artWireJson()).putSome("load_problem", loadProblem).also {
                    trace("library") {
                        "answered ${asked.elapsedNow().inWholeMilliseconds} ms after asked: started at $started ms, " +
                            "library at $loaded ms, stored art at $found ms"
                    }
                }
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
        val choices = setupOf(setup)
        inLibrary { setUp(platform.id, choices) }
        success("library" to wire(library.value))
    }

    /**
     * Scans the folder of the choices [setup] (as [setUpPlatform] takes them) for [platformId] without
     * saving anything; answers with `{"report"}`, whose `games` the scan after saving them finds too.
     */
    @UsedByGodot
    public fun previewPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = answering(requestId, libraryThread) {
        val platform = platform(PlatformId(platformId))
        val choices = setupOf(setup)
        success("report" to inLibrary { preview(platform, choices, titles(platform.id), dataFolders) }.toWire())
    }

    /** Answers with the settings, as [AppSettings.toWire] has them. */
    @UsedByGodot
    public fun settings(requestId: Int): Unit = answering(requestId, libraryThread) {
        val settings = storedSettings()
        success().apply { putAll(settings.toWire(settings.isFirstLaunch(library.value.library()))) }
    }

    /** Stores the button style the user chose, [style] as [settings] names it. */
    @UsedByGodot
    public fun saveButtonStyle(requestId: Int, style: String): Unit = answering(requestId, libraryThread) {
        val chosen = code("button_style", Some(style), ButtonStyle.entries, ButtonStyle::wire)
        settingsStore.save(storedSettings().copy(buttonStyle = Some(chosen))).mapLeft { it.toWire() }.bind()
        trace("settings") { "button style: $style" }
        success()
    }

    /** Stores the edge smoothing the user chose, [smoothing] as [settings] names it. */
    @UsedByGodot
    public fun saveEdgeSmoothing(requestId: Int, smoothing: String): Unit = answering(requestId, libraryThread) {
        val chosen = code("edge_smoothing", Some(smoothing), EdgeSmoothing.entries, EdgeSmoothing::wire)
        settingsStore.save(storedSettings().copy(edgeSmoothing = chosen)).mapLeft { it.toWire() }.bind()
        trace("settings") { "edge smoothing: $smoothing" }
        success()
    }

    /** Scans [platformId]'s folder; answers with `{"library", "report"}`. */
    @UsedByGodot
    public fun scanPlatform(requestId: Int, platformId: String): Unit = answering(requestId, libraryThread) {
        val platform = platform(PlatformId(platformId))
        val titles = titles(platform.id)
        val report = inLibrary { scan(platform, titles, dataFolders) }.second
        success("library" to wire(library.value), "report" to report.toWire()).also { lookForArt() }
    }

    /**
     * Removes [platformId] from the library (see [LibraryService.remove]), then the art of its
     * games; answers with `{"library"}`.
     */
    @UsedByGodot
    public fun removePlatform(requestId: Int, platformId: String): Unit = answering(requestId, libraryThread) {
        inLibrary { remove(PlatformId(platformId)) }
        trace("library") { "$platformId removed" }
        success("library" to wire(library.value)).also { lookForArt() }
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
     * The images the art sources have for [gameId]'s label, one per region, closest to the game's own
     * first: answers with `{"variants": [{"region", "path"?}]}`, `path` for those already downloaded;
     * then downloads the others, each telling the `label_variant_downloaded` signal `{"game_id",
     * "region", "path"}`, or `{"game_id", "region", "failure"}` (`offline`, `refused`, `not_found`,
     * `unreadable`, `storage`).
     */
    @UsedByGodot
    public fun labelVariants(requestId: Int, gameId: String): Unit = answering(requestId, libraryThread) {
        val game = game(GameId(gameId))
        val stored = sources(game.platform).variantsOf(game).map { it to artStore.variant(it.url) }
        val missing = stored.filter { it.second.isNone() }.map { it.first }
        trace("art") { "${game.title}: ${stored.size} images, ${missing.size} to download" }
        variantDownloads.download(game.id, missing)
        success(
            "variants" to
                stored.toWireArray { (variant, art) ->
                    dictionary("region" to variant.region.name).putSome("path", art.map { it.file.path })
                },
        )
    }

    /**
     * Shows the image of [region] (as [labelVariants] names it, downloaded) on [gameId]'s label from
     * now on, and remembers the choice (see [LabelChoices]); answers with `{"art": {"game_id",
     * "path"}}`.
     */
    @UsedByGodot
    public fun chooseLabel(requestId: Int, gameId: String, region: String): Unit = answering(requestId, libraryThread) {
        val game = game(GameId(gameId))
        val variant =
            sources(game.platform).variantsOf(game).firstOrNone { it.region.name == region }.getOrElse {
                raise(failure(ErrorCode.NO_IMAGE, "No image of ${game.title} for region '$region'"))
            }
        val art = LabelChoices(library.value, artStore).choose(game, variant).mapLeft { it.toWire() }.bind()
        trace("art") { "${game.title}: label of region '$region' chosen" }
        success("art" to FoundArt(game.id, art).toWire())
    }

    /**
     * Shows [gameId] as [name] from now on (trimmed and cut, see [DisplayName]), or as its title
     * again when [name] is blank; answers with `{"title", "original_title"?}`, what the game is now
     * called and, once renamed, its title.
     */
    @UsedByGodot
    public fun renameGame(requestId: Int, gameId: String, name: String): Unit = answering(requestId, libraryThread) {
        val game = library.value.rename(GameId(gameId), DisplayName.of(name)).mapLeft { it.toWire() }.bind()
        trace("library") { "${game.title}: shown as '${game.shownTitle}'" }
        success("title" to game.shownTitle).putSome("original_title", game.displayName.map { game.title })
    }

    /**
     * Shows [platformId]'s console as [name] from now on (see [DisplayName]), or under its own name,
     * [own], again when [name] is blank or is it; answers with `{"name"?}`, the name kept.
     */
    @UsedByGodot
    public fun renameConsole(requestId: Int, platformId: String, name: String, own: String): Unit = answering(requestId, libraryThread) {
        val kept = library.value.renameConsole(PlatformId(platformId), DisplayName.of(name), own).mapLeft { it.toWire() }.bind()
        trace("library") { "console $platformId shown as '${kept.fold({ own }) { it.text }}'" }
        success().putSome("name", kept.map { it.text })
    }

    /** Shows the consoles of [platformIds] in that order from now on, on the consoles screen and after a restart. */
    @UsedByGodot
    public fun orderConsoles(requestId: Int, platformIds: Array<String>): Unit = answering(requestId, libraryThread) {
        library.value.orderConsoles(platformIds.map(::PlatformId)).mapLeft { it.toWire() }.bind()
        trace("library") { "consoles ordered: ${platformIds.joinToString()}" }
        success()
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
                curtain.over(curtainTimes.timeFor(launch.spec.targetPackage)) { launcher.start(act, intent) }
            }.mapLeft { it.toWire() }.bind()
            // Answered at once, for the black to last no longer than the start; a failure to
            // remember the disc must not report the launch as failed.
            scope.launch(libraryThread) {
                library.value.recordLaunch(choice.game.id, choice.disc).onLeft { trace("library") { "last disc not saved: ${it.message}" } }
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
     * Deletes the art of games no longer in the library, on [libraryThread] after the calls already
     * there, then looks for the art of its games that have none, in library order, planned on
     * [artPlanning]: an answer never waits for it, and its failure fails no answer.
     */
    private fun lookForArt() {
        scope.launch(libraryThread) {
            if (demo) return@launch
            library.value.gamesWithArt().onSome { kept ->
                artStore
                    .keepOnly(kept)
                    .onRight { deleted -> if (deleted > 0) trace("art") { "$deleted images of games no longer in the library deleted" } }
                    .onLeft { trace("art") { "images of games no longer in the library not deleted: ${it.message}" } }
            }
            val games = library.value.library().games
            scope.launch(artPlanning) {
                val versionOf = { platform: PlatformId -> artLists.getOrNone(platform).flatMap(ArtIndex::versionOf) }
                scraper.lookFor(ArtSources.requests(games, artStore::wants, versionOf, ::sources))
            }
            if (!watchingNetwork.value) trace("art") { "the network is not watched: retries only follow their delay" }
        }
    }

    private fun variantDownloaded(game: GameId, variant: ArtVariant, kept: Either<VariantFailure, StoredArt>) {
        trace("art") { "${variant.region.name} image of ${game.value}: ${kept.fold({ it.wire }) { "downloaded" }}" }
        val told = dictionary("game_id" to game.value, "region" to variant.region.name)
        kept.fold({ told.put("failure", it.wire) }) { told.put("path", it.file.path) }
        emitSignal(VARIANT_SIGNAL, told)
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
    private fun artFetch(): Fetch =
        if ("--art-refused" in launchArguments()) Fetch { FetchFailure.Refused(503).left() } else HttpFetch("Cartouche")

    private fun libraryIn(folder: File): LibraryService =
        LibraryService(LibraryStore(File(folder, LIBRARY_FILE)), SelectionStore(File(folder, "selection.json")), folders)

    /** Runs [block] on [libraryThread]; its failure becomes the answer. */
    private suspend fun <T> Raise<Dictionary>.inLibrary(block: LibraryService.() -> Either<LibraryFailure, T>): T =
        withContext(libraryThread) { library.value.block() }.mapLeft { it.toWire() }.bind()

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

    /** The choices `{"folder_uri"?, "player_id"?, "disc_grouping", "folder_depth"}` sent for a platform. */
    private fun Raise<Dictionary>.setupOf(setup: Dictionary): PlatformSetup {
        val folder = setup.text("folder_uri").map { ContentUri.parse(it).getOrElse { raise(invalid("folder_uri is not a content URI")) } }
        return PlatformSetup(
            folder,
            setup.text("player_id").map(::PlayerId),
            code("disc_grouping", setup.text("disc_grouping"), DiscGrouping.entries, DiscGrouping::wire),
            code("folder_depth", setup.text("folder_depth"), FolderDepth.entries, FolderDepth::wire),
        )
    }

    /** The value of [values] named [text] on the wire, sent as [key]; an invalid request when there is none. */
    private fun <T> Raise<Dictionary>.code(key: String, text: Option<String>, values: List<T>, wire: (T) -> String): T =
        text.flatMap { name -> values.firstOrNone { wire(it) == name } }.getOrElse { raise(invalid("$key is missing or unknown")) }

    /** The stored settings; unreadable ones only mean starting without any, as on a first launch. */
    private fun storedSettings(): AppSettings = settingsStore.load().getOrElse { problem ->
        trace("settings") { "not read, starting without: ${problem.detail}" }
        AppSettings()
    }

    private fun Raise<Dictionary>.game(id: GameId): Game =
        library.value.library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id).toWire()) }

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
    private fun Dictionary.textsByPlatform(): Map<PlatformId, String> =
        keys.flatMap { id -> text(id).map { PlatformId(id) to it }.toList() }.toMap()

    private fun invalid(detail: String): Dictionary = failure(ErrorCode.INVALID_REQUEST, detail)

    // The system resolves implicit intents, so they are always available.
    private fun isAvailable(player: Player): Boolean =
        player.template.targetPackage.fold({ true }) { installed.getOrPut(it) { isInstalled(it) } }

    private fun isInstalled(packageName: PackageName): Boolean =
        InstalledApps.isInstalled(context.packageManager, packageName).also { trace("installed") { "${packageName.value}: $it" } }

    /** Runs [work] in the background with the current activity; activity starts go through [onMain]. */
    private fun withActivity(requestId: Int, work: suspend (Activity) -> Either<LaunchFailure, Unit>): Unit =
        onActivity(requestId) { act -> answering(requestId) { work(act).toWire() } }

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

        const val REQUEST_PICK_PICTURE = 0xCA28

        const val LIBRARY_FILE = "library.json"

        const val ART_SIGNAL = "art_changed"

        const val VARIANT_SIGNAL = "label_variant_downloaded"

        /** The battery's level, or whether a charger is plugged in, changed. */
        const val BATTERY_SIGNAL = "battery_changed"

        const val VARIANT_DOWNLOADS = 3
    }
}
