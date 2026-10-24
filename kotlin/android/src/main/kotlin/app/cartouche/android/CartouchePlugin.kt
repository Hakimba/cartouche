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
import app.cartouche.android.art.Answer
import app.cartouche.android.art.ArtStore
import app.cartouche.android.art.Credentials
import app.cartouche.android.art.Fetch
import app.cartouche.android.art.FetchFailure
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.Http
import app.cartouche.android.art.HttpFetch
import app.cartouche.android.art.JavaHttp
import app.cartouche.android.art.LabelChoices
import app.cartouche.android.art.LabelDownload
import app.cartouche.android.art.LabelNews
import app.cartouche.android.art.OwnPictures
import app.cartouche.android.art.Scraper
import app.cartouche.android.art.ScreenScraperFetch
import app.cartouche.android.art.StoredArt
import app.cartouche.android.art.Textures
import app.cartouche.android.art.VariantDownloads
import app.cartouche.android.art.VariantFailure
import app.cartouche.android.launch.Curtain
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.launch.Launcher
import app.cartouche.android.library.LaunchChoice
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.SelectionStore
import app.cartouche.android.storage.SettingsStore
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.art.ArtSources
import app.cartouche.core.art.ArtVariant
import app.cartouche.core.art.ArtVersion
import app.cartouche.core.art.Candidate
import app.cartouche.core.art.Day
import app.cartouche.core.art.LabelFraming
import app.cartouche.core.art.Scraping
import app.cartouche.core.art.ScreenScraperState
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
import app.cartouche.core.regions.PreferredRegion
import app.cartouche.core.search.Finder
import app.cartouche.core.search.Finders
import app.cartouche.core.search.Order
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.None
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
import arrow.core.right
import arrow.core.separateEither
import arrow.core.toOption
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.net.HttpURLConnection
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
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
    private val screenScraper by lazy { screenScraperFetch() }
    private val textures by lazy { screenScraper.getOrElse { Textures.NONE } }
    private val fetch by lazy { artFetch() }
    private val scraper by lazy { Scraper(artStore, fetch, scope, textures, ::artDownloading, ::artChanged) }

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

    /** The prints of cartridge platforms' games, as loaded, indexed with their reference lists. */
    @Volatile private var printLists: Map<PlatformId, String> = emptyMap()

    @Volatile private var titleIndexes = ConcurrentHashMap<PlatformId, TitleIndex>()

    @Volatile private var dataFolders = DataFolders.NONE

    @Volatile private var curtainTimes = CurtainTimes.NONE

    /** Art extracts and ScreenScraper's texture tables by platform, as loaded; each is indexed on first use. */
    @Volatile private var artLists: Map<PlatformId, String> = emptyMap()

    @Volatile private var textureLists: Map<PlatformId, String> = emptyMap()

    @Volatile private var artSources = ConcurrentHashMap<PlatformId, ArtSources>()

    /** Whether the library shown is a demo one, whose games have no art to look for. */
    @Volatile private var demo = false

    /** Runs every library call, one at a time (see [LibraryService]). */
    private val libraryThread = Dispatchers.IO.limitedParallelism(1)

    /** Makes the finders of each library kept, one at a time (see [prepare]). */
    private val preparing =
        Executors
            .newSingleThreadExecutor {
                Thread(it, "finders").apply { priority = Thread.MIN_PRIORITY }
            }.asCoroutineDispatcher()

    /** Plans each look for art, one at a time, in the order asked. */
    private val artPlanning = Dispatchers.IO.limitedParallelism(1)

    /**
     * Used on [libraryThread], which [useDemoLibrary] replaces it on; read from Godot's thread too,
     * by [browse] and [titleMarks], for the finders it publishes.
     */
    @Volatile private var library: Lazy<LibraryService> = lazy { libraryIn(context.filesDir) }

    /** Only used on [libraryThread]. */
    private val settingsStore by lazy { SettingsStore(File(context.filesDir, "settings.json")) }

    /** Whether each package is installed, forgotten on resume since apps may be installed meanwhile. */
    private val installed = ConcurrentHashMap<PackageName, Boolean>()

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(ANSWERED_SIGNAL, Dictionary::class.java),
        SignalInfo(ART_SIGNAL, Dictionary::class.java),
        SignalInfo(ART_PROGRESS_SIGNAL, Dictionary::class.java),
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
     * names (`data_folders.json`), the curtain times (`curtains.json`), the art extracts, the
     * cartridge prints and ScreenScraper's texture tables, each as `{platform id: text}`; returns
     * the catalog summary.
     */
    @UsedByGodot
    public fun loadCatalog(
        definitions: Dictionary,
        profiles: String,
        titles: Dictionary,
        dataFolderNames: String,
        curtains: String,
        art: Dictionary,
        prints: Dictionary,
        textures: Dictionary,
    ): Dictionary {
        val (notText, sources) =
            definitions.keys.sorted().separateEither { name ->
                definitions.text(name).map { DefinitionSource(name, it) }.toEither { CatalogError.InvalidJson(name, "not text") }
            }
        titleLists = titles.textsByPlatform()
        printLists = prints.textsByPlatform()
        titleIndexes = ConcurrentHashMap()
        artLists = art.textsByPlatform()
        // A build without ScreenScraper's key offers no texture: one answered as not found would be remembered
        // missing, and stay so once a build with the key is installed over it.
        textureLists = Credentials.fromBuild().fold({ emptyMap() }) { textures.textsByPlatform() }
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
     * Looks for the art of [gameIds] (the game on screen and its neighbours) before the others':
     * their requests, when still waiting, go to the front of the run, now and at each new plan.
     */
    @UsedByGodot
    public fun artFocus(gameIds: Array<String>) {
        val games = gameIds.map(::GameId)
        scope.launch(artPlanning) { scraper.focus(games) }
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

    /**
     * What the carousel shows of [platformId]'s shelf (see [View.toWireJson]): the games found for
     * [typed], or with nothing typed the index by `title` or by `region` ([order]). Answers at once,
     * from the library last kept; a platform without games has none.
     */
    @UsedByGodot
    public fun browse(platformId: String, order: String, typed: String): String {
        val started = TimeSource.Monotonic.markNow()
        val finders = library.value.finders
        val platform = PlatformId(platformId)
        val view = finders.view(platform, if (order == "region") Order.REGION else Order.TITLE, typed)
        return view.toWireJson(finders.size(platform)).also {
            val spent = started.elapsedNow().inWholeMicroseconds
            trace("search") { "'$typed' ($order): ${view.games.size} games, ${view.keys.size} keys in $spent µs" }
        }
    }

    /** Where [typed] is in the title of the game at [position] on [platformId]'s shelf (see [Finder.marks]): JSON text, at once. */
    @UsedByGodot
    public fun titleMarks(platformId: String, position: Int, typed: String): String =
        library.value.finders.marks(PlatformId(platformId), position, typed).toWireJson()

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
     * now on, framed [zoom] times closer than the largest rectangle of the label's [proportion] (its
     * width over its height) that fits, and centred at [x], [y] (see [LabelFraming]), and remembers the choice (see [LabelChoices]); answers with
     * `{"art": {"game_id", "path"}}`. The picture is cut in the background, the library only waiting
     * for the choice to be recorded.
     */
    @UsedByGodot
    public fun keepOwnLabel(requestId: Int, gameId: String, zoom: Double, x: Double, y: Double, proportion: Double): Unit =
        answering(requestId) {
            val started = System.nanoTime()
            val image = ownPictures.framed(LabelFraming(zoom, x, y, proportion)).mapLeft { it.toWire() }.bind()
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
     * Answers with `{"library", "art", "absent"}`, the library read from its file on first use, the
     * label images stored for its games (see [artWireJson]) and the ids of those without one that no
     * source had art for when they were last looked for, in their sources' current version; then
     * looks for the others' art.
     */
    @UsedByGodot
    public fun library(requestId: Int) {
        val asked = TimeSource.Monotonic.markNow()
        answering(requestId, libraryThread) {
            val started = asked.elapsedNow().inWholeMilliseconds
            library.value.run {
                val loaded = asked.elapsedNow().inWholeMilliseconds
                val stored = library().games.flatMap { game -> artStore.stored(game.id).map { FoundArt(game.id, it) }.toList() }
                val absent = absentLabels(library().games)
                val found = asked.elapsedNow().inWholeMilliseconds
                success("library" to wire(this), "art" to stored.artWireJson(), "absent" to absent.toTypedArray())
                    .putSome("load_problem", loadProblem)
                    .also {
                        trace("library") {
                            "answered ${asked.elapsedNow().inWholeMilliseconds} ms after asked: started at $started ms, " +
                                "library at $loaded ms, stored and absent art at $found ms"
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
     * Scans the folder of the choices [setup] (as [setUpPlatform] takes them) for [platformId]
     * without reading a game file or saving anything; answers with `{"report"}`. Its files are known
     * by what they told at the last scan ([LibraryService.preview]): the scan after saving the choices
     * finds the same games but for files it reads for the first time, which their content may group
     * or name otherwise.
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

    /**
     * Stores the region whose images labels show first when nothing settles a game's own, [region]
     * as [settings] names it among `preferred_regions` (empty for none), and answers; then looks up
     * again the automatic labels whose first image it changes, planned as [lookForArt] plans; a
     * label the user chose stays.
     */
    @UsedByGodot
    public fun savePreferredRegion(requestId: Int, region: String): Unit = answering(requestId, libraryThread) {
        val chosen =
            if (region.isEmpty()) {
                None
            } else {
                Some(
                    code("preferred_region", Some(region), PreferredRegion.entries, PreferredRegion::region),
                )
            }
        val before = storedSettings()
        settingsStore.save(before.copy(preferredRegion = chosen)).mapLeft { it.toWire() }.bind()
        trace("settings") { "preferred region: ${region.ifEmpty { "none" }}" }
        if (chosen != before.preferredRegion) {
            lookForArt { games ->
                ArtSources
                    .reordered(games, { sources(it, before.preferredRegion) }, { sources(it, chosen) }) { candidate, version ->
                        !artStore.isMissing(candidate, version)
                    }.also { trace("art") { "${it.size} labels to look up again in the preferred region's order" } }
            }
        }
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
     * catalog's platforms, or all on [platformId] unless it is empty (one shelf at fan size), stored
     * apart (the user's library is left alone), for measuring at scale; answers with `{"library"}`.
     */
    @UsedByGodot
    public fun useDemoLibrary(requestId: Int, games: Int, platformId: String): Unit = answering(requestId, libraryThread) {
        ensure(BuildConfig.DEBUG) { invalid("The demo library only exists in debug builds") }
        val platforms = if (platformId.isEmpty()) catalog.platforms.map { it.id } else listOf(platform(PlatformId(platformId)).id)
        // Named after the library format: a library saved by an older build is never measured again.
        val name = "demo-${LibraryFormat.VERSION}-$games" + if (platformId.isEmpty()) "" else "-$platformId"
        val folder = File(context.filesDir, name).apply { mkdirs() }
        val store = LibraryStore(File(folder, LIBRARY_FILE))
        if (store.load().fold({ true }) { it.library.games.isEmpty() }) {
            store.save(DemoLibrary.of(games, platforms)).mapLeft { it.toWire() }.bind()
        }
        library = lazyOf(libraryIn(folder))
        demo = true
        withContext(artPlanning) { scraper.lookFor(emptyList()) }
        success("library" to wire(library.value))
    }

    /**
     * Debug builds only: scans every console with a folder again, reading all of their game files
     * anew, forgets which games no source had art for, and looks every automatic label up again: the
     * image found replaces the one stored, none found removes it. A label the user chose, their own
     * picture or a region's image, is never touched. Answers once every label was looked for, so
     * never while the network is down or a game is played (the run waits for them), with
     * `{"library", "games", "labels", "failures"}`: how many games the library holds, how many of
     * those looked for have a label, and why the consoles that could not be scanned were not. The
     * images it removes are not told through [ART_SIGNAL]: it is asked from the device check, and
     * the carousel reads the stored images anew when it comes back.
     */
    @UsedByGodot
    public fun rescrape(requestId: Int): Unit = answering(requestId, libraryThread) {
        ensure(BuildConfig.DEBUG) { invalid("Scraping again only exists in debug builds") }
        ensure(!demo) { invalid("The demo library is shown: it has no folders to scan") }
        val service = library.value
        service.forgetFacts().mapLeft { it.toWire() }.bind()
        val failures =
            service.library().setups.filterValues { it.folder.isSome() }.keys.flatMap { id ->
                catalog
                    .platform(id)
                    .toEither { LibraryFailure.UnknownPlatform(id) }
                    .flatMap { service.scan(it, titles(id), dataFolders) }
                    .fold({ listOf("${id.value}: ${it.message}") }) { emptyList() }
            }
        val again = ArtSources.lookAgain(service.library().games) { sources(it, None) }
        artStore.lookAgain(again).mapLeft { it.toWire() }.bind()
        trace("art") { "${again.asked.size} labels looked up again, ${again.unfound.size} that no source can have removed" }
        lookForArt().join()
        scraper.awaitOver()
        val labels = again.asked.count { artStore.stored(it).isSome() }
        trace("art") { "scraped again: $labels labels found of ${again.asked.size}" }
        success("library" to wire(service)).apply { putAll(Rescraped(service.library().games.size, labels, failures).toWire()) }
    }

    /**
     * The images the art sources have for [gameId]'s label, every one of both sources (see
     * [offered]), in the order they are tried: answers with `{"variants": [{"region", "source",
     * "source_name", "path"?}]}`, `source` naming the source for [chooseLabel] (`launchbox`,
     * `screenscraper`), `source_name` as shown, `path` for the images already downloaded; then
     * downloads the others, each telling the `label_variant_downloaded` signal `{"game_id",
     * "region", "source", "path"}`, or `{"game_id", "region", "source", "failure"}` (`offline`,
     * `refused`, `not_found`, `unreadable`, `storage`).
     */
    @UsedByGodot
    public fun labelVariants(requestId: Int, gameId: String): Unit = answering(requestId, libraryThread) {
        val game = game(GameId(gameId))
        val sources = sources(game.platform, storedSettings().preferredRegion)
        val stored = sources.variantsOf(game, offered(sources.version)).map { it to artStore.variant(it.candidate) }
        val missing = stored.filter { it.second.isNone() }.map { it.first }
        trace("art") { "${game.title}: ${stored.size} images, ${missing.size} to download" }
        variantDownloads.download(game.id, missing, sources.cutOf(game), sources.version)
        success("variants" to stored.toWireArray { (variant, art) -> variant.toWire().putSome("path", art.map { it.file.path }) })
    }

    /**
     * Shows the image of [region] at [source] (as [labelVariants] names them, downloaded) on
     * [gameId]'s label from now on, and remembers the choice (see [LabelChoices]); answers with
     * `{"art": {"game_id", "path"}}`.
     */
    @UsedByGodot
    public fun chooseLabel(requestId: Int, gameId: String, region: String, source: String): Unit = answering(requestId, libraryThread) {
        val game = game(GameId(gameId))
        val sources = sources(game.platform, storedSettings().preferredRegion)
        val variant =
            sources
                .variantsOf(game, offered(sources.version))
                .firstOrNone { it.region.name == region && it.candidate.source.wire == source }
                .getOrElse { raise(failure(ErrorCode.NO_IMAGE, "No image of ${game.title} for region '$region' at '$source'")) }
        val art = LabelChoices(library.value, artStore).choose(game, variant).mapLeft { it.toWire() }.bind()
        trace("art") { "${game.title}: label of region '$region' at '$source' chosen" }
        success("art" to FoundArt(game.id, art).toWire())
    }

    /**
     * Which of a game's images the chooser offers: not a texture ScreenScraper answered it has none
     * of (INV-E11-04), and no texture while ScreenScraper is not open or the app has no key: the
     * region's scan alone then (INV-E7-03).
     */
    private fun offered(version: Option<ArtVersion>): (Candidate) -> Boolean = { candidate ->
        !artStore.isMissing(candidate, version) &&
            when (candidate) {
                is Candidate.Web -> true
                is Candidate.Texture -> textures.open
            }
    }

    private fun ArtVariant.toWire(): Dictionary =
        dictionary("region" to region.name, "source" to candidate.source.wire, "source_name" to candidate.source.label)

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
     * there, then looks for the art of its games that have none, and of those [again] picks among
     * them, in library order, planned on [artPlanning]: an answer never waits for it, and its
     * failure fails no answer. The automatic labels no source can have art for are known absent
     * then. Done once the scraper has the games to look for.
     */
    private fun lookForArt(again: (List<Game>) -> Set<GameId> = { emptySet() }): Job = scope.launch(libraryThread) {
        if (demo) return@launch
        library.value.gamesWithArt().onSome { kept ->
            artStore
                .keepOnly(kept)
                .onRight { deleted -> if (deleted > 0) trace("art") { "$deleted images of games no longer in the library deleted" } }
                .onLeft { trace("art") { "images of games no longer in the library not deleted: ${it.message}" } }
        }
        val games = library.value.library().games
        val preferred = storedSettings().preferredRegion
        // A child: the look is over once the scraper has its requests, but this thread is free at once.
        launch(artPlanning) {
            val versionOf = { platform: PlatformId -> ArtSources.versionOf(catalog, artLists, textureLists, platform) }
            val asked = again(games)
            val wants = { game: GameId, version: Option<ArtVersion> -> game in asked || artStore.wants(game, version) }
            val plan = ArtSources.requests(games, wants, { artStore.provisional(it).isSome() }, versionOf) { sources(it, preferred) }
            scraper.absent(plan.unfound)
            scraper.lookFor(plan.requests, asked)
        }
        if (!watchingNetwork.value) trace("art") { "the network is not watched: retries only follow their delay" }
    }

    private fun variantDownloaded(game: GameId, variant: ArtVariant, kept: Either<VariantFailure, StoredArt>) {
        trace("art") {
            "${variant.region.name} image of ${game.value} at ${variant.candidate.source.wire}: ${kept.fold({ it.wire }) { "downloaded" }}"
        }
        val told = variant.toWire().apply { put("game_id", game.value) }
        kept.fold({ told.put("failure", it.wire) }) { told.put("path", it.file.path) }
        emitSignal(VARIANT_SIGNAL, told)
    }

    private fun artChanged(run: Scraping, news: Option<LabelNews>): Unit = emitSignal(ART_SIGNAL, run.toWire(news))

    /** The ids of [games] without a label that no source had art for when last looked for, in their sources' current version. */
    private fun absentLabels(games: List<Game>): List<String> = games.groupBy { it.platform }.flatMap { (platform, games) ->
        val version = ArtSources.versionOf(catalog, artLists, textureLists, platform)
        games.filter { artStore.stored(it.id).isNone() && artStore.isAbsent(it.id, version) }.map { it.id.value }
    }

    private fun artDownloading(game: GameId, download: LabelDownload): Unit = emitSignal(ART_PROGRESS_SIGNAL, download.toWire(game))

    /** [platform]'s sources, indexed once, for a user who prefers [preferred]'s images. */
    private fun sources(platform: PlatformId, preferred: Option<PreferredRegion>): ArtSources = artSources
        .computeIfAbsent(platform) {
            val started = TimeSource.Monotonic.markNow()
            ArtSources
                .of(catalog, artLists, textureLists, platform)
                .also {
                    trace(
                        "art",
                    ) {
                        "${platform.value}: ${it.size} games, ${it.releases} releases indexed in ${started.elapsedNow().inWholeMilliseconds} ms"
                    }
                }
        }.preferring(preferred)

    /** Downloads over HTTP; in debug builds, `--art-refused` makes every server refuse, to try the message and the retries. */
    private fun artFetch(): Fetch {
        if ("--art-refused" in launchArguments()) return Fetch { _, _ -> FetchFailure.Refused(503).left() }
        val scans = HttpFetch(http())
        return Fetch { candidate, progress ->
            when (candidate) {
                is Candidate.Web -> scans.get(candidate.url, progress)
                is Candidate.Texture -> screenScraper.fold({ FetchFailure.NotFound.left() }) { it.get(candidate, progress) }
            }
        }
    }

    /** HTTP for images; in debug builds, `--art-slow=MS` waits MS milliseconds after each chunk read, to see a download's progress. */
    private fun http(): JavaHttp = JavaHttp(
        USER_AGENT,
        launchArguments()
            .asList()
            .firstOrNone { it.startsWith(ART_SLOW_ARGUMENT) }
            .flatMap { it.removePrefix(ART_SLOW_ARGUMENT).toLongOrNull().toOption() }
            .fold({ Duration.ZERO }) { it.milliseconds },
    )

    /** ScreenScraper with the credentials built into the app; none without a key, and the textures are then images no server gives. */
    private fun screenScraperFetch(): Option<ScreenScraperFetch> = Credentials.fromBuild().map { credentials ->
        // The device's local day: the quota resets on the server's day, so a closure may lift a few hours early or late.
        val today = { Day(LocalDate.now().toString()) }
        ScreenScraperFetch(
            screenScraperHttp(),
            credentials,
            File(context.filesDir, "art/screenscraper.json"),
            System::currentTimeMillis,
            today,
        ) { trace("art") { "ScreenScraper: $it" } }
    }

    /**
     * Debug builds: `--screenscraper=quota` makes ScreenScraper answer that the day's quota is spent,
     * `--screenscraper=wrong-key` that the app's key is refused, `--screenscraper=wrong-account` that
     * the member is, to try each state on the device.
     */
    private fun screenScraperHttp(): Http {
        val real = http()
        val simulated =
            launchArguments()
                .asList()
                .firstOrNone {
                    it.startsWith(SCREENSCRAPER_ARGUMENT)
                }.map { it.removePrefix(SCREENSCRAPER_ARGUMENT) }
        return when (simulated) {
            Some("quota") -> Http { _, _ -> Answer(ScreenScraperState.QUOTA_SPENT, None).right() }
            Some(
                "wrong-key",
            ),
            -> Http { _, _ -> Answer(HttpURLConnection.HTTP_OK, Some(ScreenScraperFetch.LOGIN_REFUSED.encodeToByteArray())).right() }
            Some("wrong-account") ->
                Http { url, progress ->
                    if ("ssuserInfos" in url) Answer(HttpURLConnection.HTTP_FORBIDDEN, None).right() else real.get(url, progress)
                }
            else -> real
        }
    }

    private fun libraryIn(folder: File): LibraryService = LibraryService(
        LibraryStore(File(folder, LIBRARY_FILE)),
        SelectionStore(File(folder, "selection.json")),
        folders,
        FactsStore(File(folder, "facts")),
        ::prepare,
    )

    /**
     * Makes [finders] in the background, once the library call that kept them is over (its answer
     * is not slowed down), on a thread of low priority that leaves the first frames their time: the
     * first search of a shelf of thousands then answers at once.
     */
    private fun prepare(finders: Finders) {
        scope.launch(preparing) {
            // Queued after the call under way on the library's single thread.
            withContext(libraryThread) {}
            val started = TimeSource.Monotonic.markNow()
            finders.prepare()
            trace("search") { "finders made in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
    }

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
        titleLists.getOrNone(platform).fold({ TitleIndex.EMPTY }) { TitleIndex.parse(it, printLists.getOrElse(platform) { "" }) }.also {
            trace("titles") { "${platform.value}: ${it.size} indexed in ${started.elapsedNow().inWholeMilliseconds} ms" }
        }
    }

    /** The library of [service] and its shelves, for Godot. */
    private fun wire(service: LibraryService): String {
        val started = TimeSource.Monotonic.markNow()
        return service.library().toWireJson(service.shelves(catalog.platforms.map { it.id }), catalog).also {
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

        /** How the download of a game's label on screen goes ([LabelDownload.toWire]). */
        const val ART_PROGRESS_SIGNAL = "art_progress"

        const val VARIANT_SIGNAL = "label_variant_downloaded"

        const val USER_AGENT = "Cartouche"

        const val SCREENSCRAPER_ARGUMENT = "--screenscraper="

        const val ART_SLOW_ARGUMENT = "--art-slow="

        /** The battery's level, or whether a charger is plugged in, changed. */
        const val BATTERY_SIGNAL = "battery_changed"

        const val VARIANT_DOWNLOADS = 3
    }
}
