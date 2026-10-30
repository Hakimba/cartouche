// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.content.Intent
import android.graphics.ImageDecoder
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import app.cartouche.android.apps.InstalledApps
import app.cartouche.android.art.ArtService
import app.cartouche.android.art.ArtStore
import app.cartouche.android.art.Credentials
import app.cartouche.android.art.FoundArt
import app.cartouche.android.art.LabelChoices
import app.cartouche.android.art.OwnPictures
import app.cartouche.android.art.Textures
import app.cartouche.android.art.artFetch
import app.cartouche.android.art.screenScraperFetch
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
import app.cartouche.core.art.LabelFraming
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
import app.cartouche.core.search.Finders
import app.cartouche.core.search.Order
import app.cartouche.core.search.View
import app.cartouche.core.settings.ButtonStyle
import app.cartouche.core.settings.EdgeSmoothing
import app.cartouche.core.settings.SoundLevel
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.merge
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.recover
import arrow.core.separateEither
import arrow.core.toOption
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
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
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.time.TimeSource
import app.cartouche.core.settings.Settings as AppSettings

/**
 * Cartouche's Android services, wrapped by `app/adapters/android/android_services.gd`; the wire format is in `Wire.kt`.
 * Getters answer directly; operations answer their request id once through the `answered` signal,
 * and every exception stops at [answer] but the scope's cancellation.
 */
public class CartouchePlugin internal constructor(godot: Godot, private val threads: Threads) : GodotPlugin(godot) {
    public constructor(godot: Godot) : this(godot, Threads.create())

    private val scope = threads.scope
    private val folders by lazy { Folders(context) }
    private val launcher by lazy { Launcher(context, folders) }
    private val curtain by lazy { Curtain(context.applicationContext, scope) }
    private val pendingPick = pendingPicker()
    private val pendingPicture = pendingPicker()
    private val ownPictures by lazy { OwnPictures(File(context.cacheDir, "own-label")) }
    private val debug by lazy { DebugOptions(launchArguments().asList()) }

    private val artService =
        lazy {
            val screenScraper = screenScraperFetch(debug, File(context.filesDir, "art/screenscraper.json"))
            ArtService(
                threads,
                ArtStore(File(context.filesDir, "art")),
                { library.value },
                { reference },
                { storedSettings().preferredRegion },
                artFetch(debug, screenScraper),
                screenScraper.getOrElse { Textures.NONE },
                { context.getSystemService(ConnectivityManager::class.java) },
            ) { signal, payload -> emitSignal(signal, payload) }
        }
    private val art by artService

    // Told on the render thread: at a cold start the first broadcast can come before Godot registers the signals.
    // Told on the render thread, after Godot has registered this plugin's signals there: at a cold start, the battery's
    // first broadcast can come before.
    private val batteryWatch = BatteryWatch { runOnRenderThread { emitSignal(BATTERY_SIGNAL, it.toWire()) } }

    /** Written on the render thread, read by operations too; immutable, so publishing it is enough. */
    @Volatile private var reference = Reference()

    private val catalog: Catalog get() = reference.catalog

    private val preparing =
        Executors
            .newSingleThreadExecutor {
                Thread(it, "finders").apply { priority = Thread.MIN_PRIORITY }
            }.asCoroutineDispatcher()

    /**
     * Used on the library thread, which [useDemoLibrary] replaces it on; read from Godot's thread
     * too, by [browse] and [titleMarks], for the finders it publishes.
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
        art.start()
        batteryWatch.follow(context)
    }

    // A game is played meanwhile: nothing is downloaded, and the battery not followed.
    override fun onMainPause() {
        art.stop()
        batteryWatch.stop(context)
    }

    override fun onMainDestroy() {
        curtain.lower()
        if (artService.isInitialized()) art.close()
        scope.cancel()
    }

    /**
     * Loads Daijishō definitions given as `{file name: JSON text}` (read in file name order), the profiles file's text, the emulator
     * data folder names (`data_folders.json`), the curtain times (`curtains.json`), and the reference lists, art extracts, cartridge
     * prints and ScreenScraper texture tables, each as `{platform id: text}`; [supported] names the platforms with a console model.
     * Returns the catalog summary, with the platforms a person may add under `offered` (see [Catalog.offered]).
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
        supported: Array<String>,
    ): Dictionary {
        val (notText, sources) =
            definitions.keys.sorted().separateEither { name ->
                definitions.text(name).map { DefinitionSource(name, it) }.toEither { CatalogError.InvalidJson(name, "not text") }
            }
        val folderNames = DataFolders.parse(DefinitionSource("data_folders.json", dataFolderNames))
        val times = CurtainTimes.parse(DefinitionSource("curtains.json", curtains))
        val parsed =
            Catalog.parse(sources, DefinitionSource("profiles.json", profiles), supported.map(::PlatformId).toSet()).let {
                it.copy(rejected = notText + folderNames.swap().getOrNone().toList() + times.swap().getOrNone().toList() + it.rejected)
            }
        reference =
            Reference(
                parsed,
                titles.textsByPlatform(),
                prints.textsByPlatform(),
                folderNames.getOrElse { DataFolders.NONE },
                times.getOrElse { CurtainTimes.NONE },
                art.textsByPlatform(),
                // Without ScreenScraper's key no texture is offered: a miss would be remembered once a keyed build is installed.
                // A build without ScreenScraper's key offers no texture: one answered as not found would be remembered
                // missing, and stay so once a build with the key is installed over it.
                Credentials.fromBuild().fold({ emptyMap() }) { textures.textsByPlatform() },
            )
        return parsed.toWire()
    }

    /** Moves the art requests of [gameIds] (the game on screen and its neighbours) to the front of the run. */
    @UsedByGodot
    public fun artFocus(gameIds: Array<String>): Unit = art.focus(gameIds.map(::GameId))

    /** Hands the memory the app freed back to the system, off Godot's thread: it takes tens of ms. */
    @UsedByGodot
    public fun releaseMemory() {
        scope.launch { NativeHeap.release() }
    }

    /** Indexes the reference lists in the background, so the first count of a folder does not wait. */
    @UsedByGodot
    public fun prepareTitles() {
        val loaded = reference
        scope.launch { loaded.titledPlatforms.forEach(loaded::titles) }
    }

    /** The shelf's view for [typed], or the index by `title` or `region` [order] when nothing is typed; JSON, at once. */
    @UsedByGodot
    public fun browse(platformId: String, order: String, typed: String): String {
        val finders = library.value.finders
        val platform = PlatformId(platformId)
        return timed(
            "search",
            { (view, _): Pair<View, String>, took ->
                "'$typed' ($order): ${view.games.size} games, ${view.keys.size} keys in ${took.inWholeMicroseconds} µs"
            },
        ) {
            val view = finders.view(platform, if (order == "region") Order.REGION else Order.TITLE, typed)
            view to view.toWireJson(finders.size(platform))
        }.second
    }

    /** Where [typed] is in the title of the game at [position] on the shelf; JSON, at once. */
    @UsedByGodot
    public fun titleMarks(platformId: String, position: Int, typed: String): String =
        library.value.finders.marks(PlatformId(platformId), position, typed).toWireJson()

    /** Installed players able to open [fileName], in definition order. */
    @UsedByGodot
    public fun candidates(fileName: String): Array<Any> =
        catalog.candidates(FileName(fileName)).filter { isAvailable(it.player) }.toWireArray { it.toWire() }

    /**
     * The installed players of [platformId], in definition order: `[{"player_id", "player_name", "emulator_name",
     * "extensions"?}]`.
     */
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

    /** Debug builds only: the launch intent's `arguments` extra, a PackedStringArray in GDScript. */
    @UsedByGodot
    public fun launchArguments(): Array<String> = activity
        .toOption()
        .flatMap { it.intent.getStringArrayExtra("arguments").toOption() }
        .filter { BuildConfig.DEBUG }
        .getOrElse { emptyArray() }

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

    /** Answers with `{"folder"}` once picked. */
    @UsedByGodot
    public fun pickFolder(requestId: Int): Unit = picking(requestId, pendingPick) { launcher.pickFolder(it, REQUEST_PICK_FOLDER) }

    /** Answers with `{"picture": {"path", "width", "height"}}`, the app's upright copy of the picked image. */
    @UsedByGodot
    public fun pickLabelPicture(requestId: Int): Unit =
        picking(requestId, pendingPicture) { launcher.pickPicture(it, REQUEST_PICK_PICTURE) }

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

    // A result reaching a restarted process belongs to no request: nothing is copied.
    private fun picturePicked(picked: Option<Uri>) = pendingPicture.end().onSome { requestId ->
        scope.launch {
            timed("art", { _: Unit, took -> "picture picked and copied in ${took.inWholeMilliseconds} ms" }) {
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
            }
        }
    }

    /** Puts the last picked picture on [gameId]'s label, framed per [LabelFraming]; answers `{"art": {"game_id", "path"}}`. */
    @UsedByGodot
    public fun keepOwnLabel(requestId: Int, gameId: String, zoom: Double, x: Double, y: Double, proportion: Double): Unit =
        answering(requestId) {
            val started = TimeSource.Monotonic.markNow()
            val image = ownPictures.framed(LabelFraming(zoom, x, y, proportion)).mapLeft { it.toWire() }.bind()
            withContext(threads.library) {
                val game = game(GameId(gameId))
                val kept = LabelChoices(library.value, art.store).keepOwn(game, image).mapLeft { it.toWire() }.bind()
                trace("art") { "${game.title}: own label kept in ${started.elapsedNow().inWholeMilliseconds} ms" }
                success("art" to FoundArt(game.id, kept).toWire())
            }
        }

    /** Answers with `{"folders"}`, the folders whose access survived until now. */
    @UsedByGodot
    public fun persistedFolders(requestId: Int): Unit = answering(requestId) {
        folders.persisted().fold({ it.toWire() }, { list -> success("folders" to list.toWireArray { it.toWire() }) })
    }

    /**
     * Lists one level of `{"tree_uri", "document_id"?}` (its root without a document id); answers with `{"entries"}`.
     */
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

    /** Answers with `{"library", "art", "absent"}`, then looks for the art of the others. */
    @UsedByGodot
    public fun library(requestId: Int) {
        val asked = TimeSource.Monotonic.markNow()
        val since = { asked.elapsedNow().inWholeMilliseconds }
        onLibrary(requestId) {
            val started = since()
            library.value.run {
                val loaded = since()
                val (stored, absent) = art.store.labelsOf(library().games, reference::artVersion)
                val found = since()
                success("library" to wire(this), "art" to stored.artWireJson(), "absent" to absent.toTypedArray())
                    .putSome("load_problem", loadProblem)
                    .also {
                        trace("library") {
                            "answered ${since()} ms after asked: started at $started ms, library at $loaded ms, stored and absent art at $found ms"
                        }
                    }
            }
        }
        art.lookForArt()
    }

    /**
     * Stores the choices `{"folder_uri"?, "player_id"?, "disc_grouping", "folder_depth"}` for [platformId]; answers
     * with `{"library"}`.
     */
    @UsedByGodot
    public fun setUpPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = onLibrary(requestId) {
        val platform = platform(PlatformId(platformId))
        val choices = setupOf(setup)
        inLibrary { setUp(platform.id, choices, setup.text("variant")) }
        success("library" to wire(library.value))
    }

    /** Stores [variant] as [platformId]'s model and answers with the library. */
    @UsedByGodot
    public fun setVariant(requestId: Int, platformId: String, variant: String): Unit = onLibrary(requestId) {
        inLibrary { setVariant(PlatformId(platformId), variant) }
        trace("console") { "variant=$variant of $platformId" }
        success("library" to wire(library.value))
    }

    /** Scans without reading game files or saving: its files are known by the last scan's facts ([LibraryService.preview]). */
    @UsedByGodot
    public fun previewPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = onLibrary(requestId) {
        val loaded = reference
        val platform = platform(PlatformId(platformId), loaded)
        val choices = setupOf(setup)
        success("report" to inLibrary { preview(platform, choices, loaded.titles(platform.id), loaded.dataFolders) }.toWire())
    }

    @UsedByGodot
    public fun settings(requestId: Int): Unit = onLibrary(requestId) {
        val settings = storedSettings()
        trace("settings") { "games_float=${settings.gamesFloat}" }
        success().apply { putAll(settings.toWire(settings.isFirstLaunch(library.value.library()))) }
    }

    @UsedByGodot
    public fun saveButtonStyle(requestId: Int, style: String): Unit = onLibrary(requestId) {
        val chosen = code("button_style", Some(style), ButtonStyle.entries) { it.wire }
        save("button style: $style") { it.copy(buttonStyle = Some(chosen)) }
        success()
    }

    @UsedByGodot
    public fun saveEdgeSmoothing(requestId: Int, smoothing: String): Unit = onLibrary(requestId) {
        val chosen = code("edge_smoothing", Some(smoothing), EdgeSmoothing.entries) { it.wire }
        save("edge smoothing: $smoothing") { it.copy(edgeSmoothing = chosen) }
        success()
    }

    /** Stores whether the selected game sways and bobs ([floating]); the consoles never do. */
    @UsedByGodot
    public fun saveGamesFloat(requestId: Int, floating: Boolean): Unit = onLibrary(requestId) {
        save("games_float=$floating") { it.copy(gamesFloat = floating) }
        success()
    }

    /** Stores how loud the sounds play, [steps] from 0 (silenced) to [SoundLevel.MAX]. */
    @UsedByGodot
    public fun saveSoundLevel(requestId: Int, steps: Int): Unit = onLibrary(requestId) {
        val level = SoundLevel.of(steps).getOrElse { raise(invalid("sound_level is out of 0 to ${SoundLevel.MAX}")) }
        save("sound_level=$steps") { it.copy(soundLevel = level) }
        success()
    }

    /** [region] as named in `preferred_regions`, empty for none; the automatic labels whose first image it changes are looked up again. */
    @UsedByGodot
    public fun savePreferredRegion(requestId: Int, region: String): Unit = onLibrary(requestId) {
        val chosen =
            region.takeIf(String::isNotEmpty).toOption().map {
                code("preferred_region", Some(it), PreferredRegion.entries) { r -> r.region }
            }
        val before = save("preferred region: ${region.ifEmpty { "none" }}") { it.copy(preferredRegion = chosen) }
        art.preferredRegionChanged(before.preferredRegion, chosen)
        success()
    }

    /** Scans [platformId]'s folder; answers with `{"library", "report"}`. */
    @UsedByGodot
    public fun scanPlatform(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        val loaded = reference
        val platform = platform(PlatformId(platformId), loaded)
        val before = library.value.library().games
        val report = inLibrary { scan(platform, loaded.titles(platform.id), loaded.dataFolders) }.second
        success("library" to wire(library.value), "report" to report.toWire()).also { art.recutAfterScan(before) }
    }

    /**
     * Removes [platformId] from the library (see [LibraryService.remove]), then the art of its games; answers with
     * `{"library"}`.
     */
    @UsedByGodot
    public fun removePlatform(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        inLibrary { remove(PlatformId(platformId)) }
        trace("library") { "$platformId removed" }
        success("library" to wire(library.value)).also { art.lookForArt() }
    }

    /** Remembers [gameId] as the selected game of its platform, and that platform as the one shown. */
    @UsedByGodot
    public fun selectGame(requestId: Int, gameId: String): Unit = onLibrary(requestId) {
        inLibrary { select(GameId(gameId)) }
        success()
    }

    /** Debug builds only: a made-up library of [games] games (all on [platformId] unless empty), stored apart from the user's. */
    @UsedByGodot
    public fun useDemoLibrary(requestId: Int, games: Int, platformId: String): Unit = onLibrary(requestId) {
        ensure(BuildConfig.DEBUG) { invalid("The demo library only exists in debug builds") }
        val loaded = reference
        val platforms =
            if (platformId.isEmpty()) loaded.catalog.offered.map { it.platform } else listOf(platform(PlatformId(platformId), loaded).id)
        // Named after the library format: a library saved by an older build is never measured again.
        val name = "demo-${LibraryFormat.VERSION}-$games" + if (platformId.isEmpty()) "" else "-$platformId"
        val folder = File(context.filesDir, name).apply { mkdirs() }
        val store = LibraryStore(File(folder, LIBRARY_FILE))
        if (store.load().fold({ true }) { it.library.games.isEmpty() }) {
            store.save(DemoLibrary.of(games, platforms)).mapLeft { it.toWire() }.bind()
        }
        library = lazyOf(libraryIn(folder))
        art.demo = true
        art.forgetLooks()
        success("library" to wire(library.value))
    }

    /**
     * Debug builds only: scans every console again, forgets the absent art and looks every automatic label up again;
     * answers `{"library", "games", "labels", "failures"}` once all were looked for.
     */
    @UsedByGodot
    public fun rescrape(requestId: Int): Unit = onLibrary(requestId) {
        ensure(BuildConfig.DEBUG) { invalid("Scraping again only exists in debug builds") }
        ensure(!art.demo) { invalid("The demo library is shown: it has no folders to scan") }
        val service = library.value
        val loaded = reference
        service.forgetFacts().mapLeft { it.toWire() }.bind()
        val failures =
            service.library().setups.filterValues { it.folder.isSome() }.keys.flatMap { id ->
                loaded.catalog
                    .platform(id)
                    .toEither { LibraryFailure.UnknownPlatform(id) }
                    .flatMap { service.scan(it, loaded.titles(id), loaded.dataFolders) }
                    .fold({ listOf("${id.value}: ${it.message}") }) { emptyList() }
            }
        val labels = art.lookAgain(service.library().games).bind()
        success("library" to wire(service)).apply { putAll(Rescraped(service.library().games.size, labels, failures).toWire()) }
    }

    /**
     * Answers with `{"variants": [{"region", "source", "source_name", "path"?}]}` for [gameId]'s label (see [ArtService.offered]), in
     * the order they are tried: `source` names the source for [chooseLabel] (`launchbox`, `screenscraper`), `source_name` as shown,
     * `path` for the images already downloaded. Then downloads the others, each told by `label_variant_downloaded` as
     * `{"game_id", "region", "source", "path"}`, or `{"game_id", "region", "source", "failure"}` (`offline`, `refused`,
     * `not_found`, `unreadable`, `storage`).
     */
    @UsedByGodot
    public fun labelVariants(requestId: Int, gameId: String): Unit = onLibrary(requestId) { art.labelVariants(game(GameId(gameId))) }

    /**
     * Shows the image of [region] at [source] (as [labelVariants] names them, downloaded) on [gameId]'s label from
     * now on, and remembers the choice (see [LabelChoices]); answers with `{"art": {"game_id", "path"}}`.
     */
    @UsedByGodot
    public fun chooseLabel(requestId: Int, gameId: String, region: String, source: String): Unit = onLibrary(requestId) {
        art.chooseLabel(game(GameId(gameId)), region, source).bind()
    }

    /** A blank [name] restores the title; answers with `{"title", "original_title"?}`. */
    @UsedByGodot
    public fun renameGame(requestId: Int, gameId: String, name: String): Unit = onLibrary(requestId) {
        val game = library.value.rename(GameId(gameId), DisplayName.of(name)).mapLeft { it.toWire() }.bind()
        trace("library") { "${game.title}: shown as '${game.shownTitle}'" }
        success("title" to game.shownTitle).putSome("original_title", game.displayName.map { game.title })
    }

    /** Shows the consoles of [platformIds] in that order from now on, on the consoles screen and after a restart. */
    @UsedByGodot
    public fun orderConsoles(requestId: Int, platformIds: Array<String>): Unit = onLibrary(requestId) {
        library.value.orderConsoles(platformIds.map(::PlatformId)).mapLeft { it.toWire() }.bind()
        trace("library") { "consoles ordered: ${platformIds.joinToString()}" }
        success()
    }

    /** Puts [platformId] at [gap] among the consoles; answers with `{"order"}`. */
    @UsedByGodot
    public fun placeConsole(requestId: Int, platformId: String, gap: Int): Unit = onLibrary(requestId) {
        val platforms = catalog.platforms.map { it.id }
        val placed =
            library.value
                .placeConsole(PlatformId(platformId), gap, platforms)
                .onLeft { trace("library") { "console $platformId not placed at $gap: ${it.message}" } }
                .mapLeft { it.toWire() }
                .bind()
        val order = placed.shown(platforms).map { it.value }
        trace("library") { "console $platformId placed at $gap: ${order.joinToString()}" }
        success("order" to order.toTypedArray())
    }

    /** Checks that the game `{"game_id", "disc"?}` can launch as [launchGame] would; starts and stops nothing. */
    @UsedByGodot
    public fun checkLaunch(requestId: Int, request: Dictionary): Unit = onLibrary(requestId) {
        val (choice, launch) = libraryLaunch(request)
        launcher.checkGame(launch, choice.file.uri).mapLeft { it.toWire() }.bind()
        success()
    }

    /** Launches the game `{"game_id", "disc"?}` under the curtain when allowed. */
    @UsedByGodot
    public fun launchGame(requestId: Int, request: Dictionary): Unit = onActivity(requestId) { act ->
        onLibrary(requestId) {
            val (choice, launch) = libraryLaunch(request)
            trace("launch") { "${choice.file.name.value} in ${launch.spec.targetPackage.fold({ "the app Android picks" }) { it.value }}" }
            val intent = launcher.prepareGame(launch, choice.file.uri).mapLeft { it.toWire() }.bind()
            onMain {
                curtain.over(reference.curtainTimes.timeFor(launch.spec.targetPackage)) { launcher.start(act, intent) }
            }.mapLeft { it.toWire() }.bind()
            // Answered at once so the black lasts no longer than the start; a disc not saved is no failed launch.
            scope.launch(threads.library) {
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
            withActivity(requestId) { act ->
                start(act, launchOf(PlayerId(playerId), it).flatMap { launch -> launcher.prepareGame(launch, it.uri) })
            }
        }
    }

    private fun libraryIn(folder: File): LibraryService = LibraryService(
        LibraryStore(File(folder, LIBRARY_FILE)),
        SelectionStore(File(folder, "selection.json")),
        folders,
        FactsStore(File(folder, "facts")),
        ::prepare,
    )

    /** Makes [finders] once the library call that kept them is over, at low priority, so the first frames keep their time. */
    private fun prepare(finders: Finders) {
        scope.launch(preparing) {
            // Queued after the call under way on the library's single thread.
            withContext(threads.library) {}
            timed("search", { _: Unit, took -> "finders made in ${took.inWholeMilliseconds} ms" }) { finders.prepare() }
        }
    }

    private suspend fun <T> Raise<Dictionary>.inLibrary(block: LibraryService.() -> Either<LibraryFailure, T>): T =
        withContext(threads.library) { library.value.block() }.mapLeft { it.toWire() }.bind()

    /**
     * Answers [requestId] with what [work] returns, or with the failure it raises. Library calls start on
     * [libraryThread] itself, which runs them in the order they arrive.
     */
    private fun answering(requestId: Int, on: CoroutineDispatcher = Dispatchers.IO, work: suspend Raise<Dictionary>.() -> Dictionary) {
        scope.launch(on) { answer(requestId) { either { work() }.merge() } }
    }

    private fun onLibrary(requestId: Int, work: suspend Raise<Dictionary>.() -> Dictionary) = answering(requestId, threads.library, work)

    private fun pendingPicker() = PendingPick<Dictionary> { requestId, payload -> answer(requestId) { payload } }

    private fun launchOf(player: PlayerId, file: GameFile): Either<LaunchFailure, Launch> =
        catalog.launch(player, file).mapLeft(LaunchFailure::Rejected)

    /**
     * Opens the settings screen [forCartouche], or [forEveryApp] on the Android builds that only offer the screen
     * listing every app.
     */
    private fun openSetting(requestId: Int, forCartouche: String, forEveryApp: String): Unit = withActivity(requestId) { act ->
        onMain {
            launcher.start(act, Intent(forCartouche, Uri.parse("package:${act.packageName}"))).recover { failure ->
                ensure(failure is LaunchFailure.ActivityNotFound) { failure }
                launcher.start(act, Intent(forEveryApp)).bind()
            }
        }
    }

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
            code("disc_grouping", setup.text("disc_grouping"), DiscGrouping.entries) { it.wire },
            code("folder_depth", setup.text("folder_depth"), FolderDepth.entries) { it.wire },
        )
    }

    /** The value of [values] named [text] on the wire, sent as [key]; an invalid request when there is none. */
    private fun <T> Raise<Dictionary>.code(key: String, text: Option<String>, values: List<T>, wire: (T) -> String): T =
        text.flatMap { name -> values.firstOrNone { wire(it) == name } }.getOrElse { raise(invalid("$key is missing or unknown")) }

    /** Unreadable settings only mean starting without any. */
    private fun storedSettings(): AppSettings = settingsStore.load().getOrElse { problem ->
        trace("settings") { "not read, starting without: ${problem.detail}" }
        AppSettings()
    }

    private fun Raise<Dictionary>.save(note: String, change: (AppSettings) -> AppSettings): AppSettings {
        val before = storedSettings()
        settingsStore.save(change(before)).mapLeft { it.toWire() }.bind()
        trace("settings") { note }
        return before
    }

    private fun Raise<Dictionary>.game(id: GameId): Game =
        library.value.library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id).toWire()) }

    private fun Raise<Dictionary>.platform(id: PlatformId, loaded: Reference = reference): Platform =
        loaded.catalog.platform(id).getOrElse { raise(failure(ErrorCode.UNKNOWN_PLATFORM, "No platform ${id.value}")) }

    private fun wire(service: LibraryService): String = timed(
        "library",
        { json: String, took -> "${json.length} characters of JSON in ${took.inWholeMilliseconds} ms" },
    ) { with(reference.catalog) { service.library().toWireJson(service.shelves(platforms.map { it.id }), this) } }

    /** `{platform id: text}` as sent by the adapter, texts of another type left out. */
    private fun Dictionary.textsByPlatform(): Map<PlatformId, String> =
        keys.flatMap { id -> text(id).map { PlatformId(id) to it }.toList() }.toMap()

    private fun invalid(detail: String): Dictionary = failure(ErrorCode.INVALID_REQUEST, detail)

    // The system resolves implicit intents, so they are always available.
    private fun isAvailable(player: Player): Boolean = player.template.targetPackage.fold({ true }) {
        installed.getOrPut(it) {
            InstalledApps.isInstalled(context.packageManager, it).also { yes -> trace("installed") { "${it.value}: $yes" } }
        }
    }

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

    private companion object {
        // Godot forwards every activity result to every plugin: unique among the bundled plugins.
        const val REQUEST_PICK_FOLDER = 0xCA27

        const val REQUEST_PICK_PICTURE = 0xCA28

        const val LIBRARY_FILE = "library.json"
    }
}
