// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.content.Intent
import android.graphics.ImageDecoder
import android.net.ConnectivityManager
import android.net.Uri
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
import app.cartouche.android.launch.startInTime
import app.cartouche.android.library.LaunchChoice
import app.cartouche.android.library.LibraryFailure
import app.cartouche.android.library.LibraryService
import app.cartouche.android.storage.FactsStore
import app.cartouche.android.storage.Folders
import app.cartouche.android.storage.LibraryStore
import app.cartouche.android.storage.StateFile
import app.cartouche.core.ContentUri
import app.cartouche.core.PackageName
import app.cartouche.core.art.LabelFraming
import app.cartouche.core.launch.GameFile
import app.cartouche.core.launch.StartDeadline
import app.cartouche.core.library.Coming
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
import app.cartouche.core.search.Finders
import app.cartouche.core.search.Order
import app.cartouche.core.search.View
import app.cartouche.core.serialName
import app.cartouche.core.settings.Setting
import app.cartouche.core.settings.SettingsFormat
import arrow.core.Either
import arrow.core.None
import arrow.core.Option
import arrow.core.Some
import arrow.core.firstOrNone
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.getOrNone
import arrow.core.raise.Raise
import arrow.core.raise.either
import arrow.core.raise.ensure
import arrow.core.recover
import arrow.core.separateEither
import arrow.core.toOption
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
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
    private val debug by lazy { DebugOptions(arguments()) }

    private val artService =
        lazy {
            val screenScraper = screenScraperFetch(debug, File(context.filesDir, "art/screenscraper.json"))
            ArtService(
                threads,
                ArtStore(File(context.filesDir, "art")),
                { library.value },
                { reference },
                { storedSettings.get().preferredRegion },
                artFetch(debug, screenScraper),
                screenScraper.getOrElse { Textures.NONE },
                { context.getSystemService(ConnectivityManager::class.java) },
            ) { signal, payload -> emitSignal(signal, payload) }
        }
    private val art by artService

    // Told on the render thread, after Godot has registered this plugin's signals there: at a cold start, the battery's
    // first broadcast can come before.
    private val batteryWatch = BatteryWatch { runOnRenderThread { emitSignal(BATTERY_SIGNAL, jsonOf(it.sent())) } }

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

    /**
     * Used on [libraryThread], and by [backdrop] as the app starts, before any request is sent there; unreadable
     * settings only mean starting without any.
     */
    private val storedSettings by lazy {
        StateFile(File(context.filesDir, "settings.json"), AppSettings(), SettingsFormat::decode, SettingsFormat::encode) { problem ->
            trace("settings") { "not read, starting without: ${problem.detail}" }
        }
    }

    /** Whether each package is installed, forgotten on resume since apps may be installed meanwhile. */
    private val installed = ConcurrentHashMap<PackageName, Boolean>()

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        ANSWERED_SIGNAL,
        ART_SIGNAL,
        ART_PROGRESS_SIGNAL,
        VARIANT_SIGNAL,
        BATTERY_SIGNAL,
    ).map { SignalInfo(it, String::class.java) }.toSet()

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
     * data folder names (`data_folders.json`) and the curtain times (`curtains.json`); [supported] names the platforms with a console
     * model, [coming] the console folders not fully supported yet ([Coming]). Each platform's tables are read later, as it needs them
     * ([Reference]). Returns the catalog summary ([Sent.CatalogSummary]), with the platforms a person may add under `offered` (see
     * [Catalog.offered]).
     */
    @UsedByGodot
    public fun loadCatalog(
        definitions: Dictionary,
        profiles: String,
        dataFolderNames: String,
        curtains: String,
        supported: Array<String>,
        coming: Array<String>,
    ): String {
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
        val notReady = Coming.of(coming.toList())
        reference =
            Reference(parsed, notReady, folderNames.getOrElse { DataFolders.NONE }, times.getOrElse { CurtainTimes.NONE }, tableFiles())
        return jsonOf(parsed.sent(notReady))
    }

    /** Moves the art requests of [gameIds] (the game on screen and its neighbours) to the front of the run. */
    @UsedByGodot
    public fun artFocus(gameIds: Array<String>): Unit = art.focus(gameIds.map(::GameId))

    /** Hands the memory the app freed back to the system, off Godot's thread: it takes tens of ms. */
    @UsedByGodot
    public fun releaseMemory() {
        scope.launch { NativeHeap.release() }
    }

    /** Reads and indexes [platformId]'s tables in the background, so the first count of its folder does not wait. */
    @UsedByGodot
    public fun prepareTables(platformId: String) {
        val loaded = reference
        scope.launch { loaded.titles(PlatformId(platformId)) }
    }

    /** The shelf's view for [typed], or the index by `title` or `region` [order] when nothing is typed ([Sent.Browse]), at once. */
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
            view to jsonOf(view.sent(finders.size(platform)))
        }.second
    }

    /** Where [typed] is in the title of the game at [position] on the shelf ([Sent.Marks]), at once. */
    @UsedByGodot
    public fun titleMarks(platformId: String, position: Int, typed: String): String =
        jsonOf(library.value.finders.marks(PlatformId(platformId), position, typed).sent())

    /** The installed players of [platformId], in definition order ([Sent.Players]). */
    @UsedByGodot
    public fun installedPlayers(platformId: String): String = jsonOf(
        Sent.Players(
            catalog.platform(PlatformId(platformId)).fold({ emptyList() }) { it.players.filter(::isAvailable).map(Player::sent) },
        ),
    )

    /** Whether a curtain can hide an emulator until its game shows: the "display over other apps" permission. */
    @UsedByGodot
    public fun curtainAllowed(): String = jsonOf(curtain.isAllowed)

    /** The battery now ([Sent.Battery]); then [BATTERY_SIGNAL] tells each change. */
    @UsedByGodot
    public fun battery(): String = jsonOf(BatteryState.now(context).sent())

    /** Debug builds only: the launch intent's `arguments` extra, as a list of texts. */
    @UsedByGodot
    public fun launchArguments(): String = jsonOf(arguments())

    private fun arguments(): List<String> = activity
        .toOption()
        .flatMap { it.intent.getStringArrayExtra("arguments").toOption() }
        .filter { BuildConfig.DEBUG }
        .fold({ emptyList() }) { it.toList() }

    /** Opens the system screen granting "display over other apps", which the curtain needs ([curtainAllowed]). */
    @UsedByGodot
    public fun requestCurtainPermission(requestId: Int): Unit =
        openSetting(requestId, Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Settings.ACTION_MANAGE_OVERLAY_PERMISSION)

    /** Answers with [Sent.Pick] once picked. */
    @UsedByGodot
    public fun pickFolder(requestId: Int): Unit = picking(requestId, pendingPick) { launcher.pickFolder(it, REQUEST_PICK_FOLDER) }

    /** Answers with [Sent.LabelPicture], the app's upright copy of the picked image. */
    @UsedByGodot
    public fun pickLabelPicture(requestId: Int): Unit =
        picking(requestId, pendingPicture) { launcher.pickPicture(it, REQUEST_PICK_PICTURE) }

    private fun picking(requestId: Int, pending: PendingPick<Failed>, open: (Activity) -> Either<LaunchFailure, Unit>): Unit =
        onActivity(requestId) { act ->
            scope.launch(Dispatchers.Main) {
                pending.start(requestId, Failed(Code.CANCELLED, "Replaced by a new pick")) {
                    Either.catch { open(act) }.fold({ Some(unexpected(it)) }) { opened -> opened.swap().getOrNone().map { it.failed } }
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
                    picked
                        .toEither { Failed(Code.CANCELLED, "Picker closed without a folder") }
                        .flatMap { uri -> folders.keepAccess(uri).mapLeft { it.failed } }
                        .map { payload(Sent.Pick(it.sent())) }
                }
            requestId.onSome { answer(it, None) { result } }
        }
    }

    // A result reaching a restarted process belongs to no request: nothing is copied.
    private fun picturePicked(picked: Option<Uri>) = pendingPicture.end().onSome { requestId ->
        scope.launch {
            timed("art", { _: Unit, took -> "picture picked and copied in ${took.inWholeMilliseconds} ms" }) {
                answer(requestId, None) {
                    picked
                        .toEither { Failed(Code.CANCELLED, "Picker closed without a picture") }
                        .flatMap { uri -> ownPictures.keep(ImageDecoder.createSource(context.contentResolver, uri)).mapLeft { it.failed } }
                        .map { payload(it.sent()) }
                }
            }
        }
    }

    /** Puts the last picked picture on [gameId]'s label, framed per [LabelFraming]; answers with [Sent.ArtAnswer]. */
    @UsedByGodot
    public fun keepOwnLabel(requestId: Int, gameId: String, zoom: Double, x: Double, y: Double, proportion: Double): Unit =
        answering(requestId) {
            val started = TimeSource.Monotonic.markNow()
            val image = ownPictures.framed(LabelFraming(zoom, x, y, proportion)).mapLeft { it.failed }.bind()
            withContext(threads.library) {
                val game = game(GameId(gameId))
                val kept = LabelChoices(library.value, art.store).keepOwn(game, image).mapLeft { it.failed }.bind()
                trace("art") { "${game.title}: own label kept in ${started.elapsedNow().inWholeMilliseconds} ms" }
                payload(Sent.ArtAnswer(FoundArt(game.id, kept).sent()))
            }
        }

    /** Answers with [Sent.FolderList], the folders whose access survived until now. */
    @UsedByGodot
    public fun persistedFolders(requestId: Int): Unit = answering(requestId) {
        payload(Sent.FolderList(folders.persisted().mapLeft { it.failed }.bind().map { it.sent() }))
    }

    /** Answers with [Sent.LibraryAnswer], its art and arrivals, then looks for the art of the others. */
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
                payload(Sent.LibraryAnswer(sentLibrary(this), stored.map { it.sent() }, absent, Some(arrivals().sent()), loadProblem))
                    .also {
                        trace("library") {
                            "answered ${since()} ms after asked: started at $started ms, library at $loaded ms, stored and absent art at $found ms"
                        }
                    }
            }
        }
        art.lookForArt()
    }

    /** Stores the choices for [platformId], as [Sent.PlatformSetup] names them; answers with [Sent.LibraryAnswer]. */
    @UsedByGodot
    public fun setUpPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = onLibrary(requestId) {
        val platform = platform(PlatformId(platformId))
        val choices = setupOf(setup)
        inLibrary { setUp(platform.id, choices, setup.text("variant_id"), reference.coming) }
        payload(Sent.LibraryAnswer(sentLibrary(library.value)))
    }

    /** Scans without reading game files or saving: its files are known by the last scan's facts ([LibraryService.preview]). */
    @UsedByGodot
    public fun previewPlatform(requestId: Int, platformId: String, setup: Dictionary): Unit = onLibrary(requestId) {
        val loaded = reference
        val platform = platform(PlatformId(platformId), loaded)
        val choices = setupOf(setup)
        payload(Sent.PreviewAnswer(inLibrary { preview(platform, choices, loaded.titles(platform.id), loaded.dataFolders) }.sent()))
    }

    /**
     * The backdrop stored ([Sent.BackdropAnswer]), at once: the app's first frame is drawn on it, without waiting for
     * the library that [settings] reads. Asked once, as the app starts, before any request.
     */
    @UsedByGodot
    public fun backdrop(): String = jsonOf(storedSettings.get().sentBackdrop())

    @UsedByGodot
    public fun settings(requestId: Int): Unit = onLibrary(requestId) {
        val settings = storedSettings.get()
        trace("settings") { "games_float=${settings.gamesFloat}" }
        payload(settings.sent(settings.isFirstLaunch(library.value.library())))
    }

    /**
     * Stores the setting [key] (one of [Setting.all]) as [value] writes it: a choice's name, `true` or `false`, a
     * number; a key or a value its declaration does not take is refused and the settings kept. A preferred region
     * changed looks again for the automatic labels whose first image it changes.
     */
    @UsedByGodot
    public fun saveSetting(requestId: Int, key: String, value: String): Unit = onLibrary(requestId) {
        val before = storedSettings.get()
        val after = Setting.change(before, key, value).mapLeft { invalid(it.detail) }.bind()
        storedSettings.set(after).mapLeft { it.failed }.bind()
        trace("settings") { "$key=$value" }
        art.preferredRegionChanged(before.preferredRegion, after.preferredRegion)
        Payload.NONE
    }

    /** Scans [platformId]'s folder; answers with [Sent.ScanAnswer]. */
    @UsedByGodot
    public fun scanPlatform(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        val loaded = reference
        val platform = platform(PlatformId(platformId), loaded)
        val before = library.value.library().games
        val report = inLibrary { scan(platform, loaded.titles(platform.id), loaded.dataFolders) }.second
        payload(
            Sent.ScanAnswer(sentLibrary(library.value), report.sent(), library.value.arrivals().sent()),
        ).also { art.recutAfterScan(before) }
    }

    /**
     * Re-reads [platformId]'s folder as the app comes to the screen, the user not asking ([LibraryService.reread]):
     * one console a request, so that a launch asked meanwhile waits for one console's read at most. Answers with
     * [Sent.RefreshAnswer], the library only when the re-read changed it.
     */
    @UsedByGodot
    public fun refreshPlatform(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        val loaded = reference
        val platform = platform(PlatformId(platformId), loaded)
        val before = library.value.library().games
        val reread = inLibrary { reread(platform, loaded.titles(platform.id), loaded.dataFolders) }
        reread.library.onSome { art.recutAfterScan(before) }
        payload(Sent.RefreshAnswer(reread.arrivals.sent(), reread.library.map { sentLibrary(library.value) }))
    }

    /** The user entered [platformId]'s console: it announces no new game any more. Answers with [Sent.ArrivalsAnswer]. */
    @UsedByGodot
    public fun enterConsole(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        payload(Sent.ArrivalsAnswer(inLibrary { enter(PlatformId(platformId)) }.sent()))
    }

    /** The user left [gameId] on its shelf: it is not new any more. Answers with [Sent.ArrivalsAnswer]. */
    @UsedByGodot
    public fun leaveGame(requestId: Int, gameId: String): Unit = onLibrary(requestId) {
        payload(Sent.ArrivalsAnswer(inLibrary { leave(GameId(gameId)) }.sent()))
    }

    /**
     * Removes [platformId] from the library (see [LibraryService.remove]), then the art of its games; answers with
     * [Sent.LibraryAnswer] and its arrivals.
     */
    @UsedByGodot
    public fun removePlatform(requestId: Int, platformId: String): Unit = onLibrary(requestId) {
        inLibrary { remove(PlatformId(platformId)) }
        trace("library") { "$platformId removed" }
        payload(Sent.LibraryAnswer(sentLibrary(library.value), arrivals = Some(library.value.arrivals().sent()))).also { art.lookForArt() }
    }

    /** The library as it now stands; answers with [Sent.LibraryAnswer]. */
    @UsedByGodot
    public fun currentLibrary(requestId: Int): Unit = onLibrary(requestId) {
        payload(Sent.LibraryAnswer(sentLibrary(library.value)))
    }

    /** Remembers [gameId] as the selected game of its platform, and that platform as the one shown. */
    @UsedByGodot
    public fun selectGame(requestId: Int, gameId: String): Unit = onLibrary(requestId) {
        inLibrary { select(GameId(gameId)) }
        Payload.NONE
    }

    /** Debug builds only: a made-up library of [games] games (all on [platformId] unless empty), stored apart from the user's. */
    @UsedByGodot
    public fun useDemoLibrary(requestId: Int, games: Int, platformId: String): Unit = onLibrary(requestId) {
        ensure(BuildConfig.DEBUG) { invalid("The demo library only exists in debug builds") }
        val loaded = reference
        val platforms =
            if (platformId.isEmpty()) {
                loaded.catalog.offered
                    .map {
                        it.platform
                    }.filter { it !in loaded.coming }
            } else {
                listOf(platform(PlatformId(platformId), loaded).id)
            }
        // Named after the library format: a library saved by an older build is never measured again.
        val name = "demo-${LibraryFormat.VERSION}-$games" + if (platformId.isEmpty()) "" else "-$platformId"
        val folder = File(context.filesDir, name).apply { mkdirs() }
        val store = LibraryStore(File(folder, LIBRARY_FILE))
        if (store.load().fold({ true }) { it.library.games.isEmpty() }) {
            store.save(DemoLibrary.of(games, platforms)).mapLeft { it.failed }.bind()
        }
        library = lazyOf(libraryIn(folder))
        art.demo = true
        art.forgetLooks()
        payload(Sent.LibraryAnswer(sentLibrary(library.value)))
    }

    /**
     * Debug builds only: scans every console again, forgets the absent art and looks every automatic label up again;
     * answers with [Sent.RescrapeAnswer] once all were looked for.
     */
    @UsedByGodot
    public fun rescrape(requestId: Int): Unit = onLibrary(requestId) {
        ensure(BuildConfig.DEBUG) { invalid("Scraping again only exists in debug builds") }
        ensure(!art.demo) { invalid("The demo library is shown: it has no folders to scan") }
        val service = library.value
        val loaded = reference
        service.forgetFacts().mapLeft { it.failed }.bind()
        val failures =
            service.library().setups.filterValues { it.folder.isSome() }.keys.flatMap { id ->
                loaded.catalog
                    .platform(id)
                    .toEither { LibraryFailure.UnknownPlatform(id) }
                    .flatMap { service.scan(it, loaded.titles(id), loaded.dataFolders) }
                    .fold({ listOf("${id.value}: ${it.message}") }) { emptyList() }
            }
        val labels = art.lookAgain(service.library().games).bind()
        payload(Sent.RescrapeAnswer(sentLibrary(service), service.library().games.size, labels, failures))
    }

    /**
     * Answers with [Sent.LabelVariants] for [gameId]'s label (see [ArtService.offered]), in the order they are tried:
     * `source` names the source for [chooseLabel], `path` the images already downloaded. Then downloads the others,
     * each told by `label_variant_downloaded` with its `path` or its `failure`.
     */
    @UsedByGodot
    public fun labelVariants(requestId: Int, gameId: String): Unit =
        onLibrary(requestId) { payload(art.labelVariants(game(GameId(gameId)))) }

    /**
     * Shows the image of [region] at [source] (as [labelVariants] names them, downloaded) on [gameId]'s label from
     * now on, and remembers the choice (see [LabelChoices]); answers with [Sent.ArtAnswer].
     */
    @UsedByGodot
    public fun chooseLabel(requestId: Int, gameId: String, region: String, source: String): Unit = onLibrary(requestId) {
        payload(art.chooseLabel(game(GameId(gameId)), region, source).bind())
    }

    /** A blank [name] restores the title; answers with [Sent.Renamed]. */
    @UsedByGodot
    public fun renameGame(requestId: Int, gameId: String, name: String): Unit = onLibrary(requestId) {
        val game = library.value.rename(GameId(gameId), DisplayName.of(name)).mapLeft { it.failed }.bind()
        trace("library") { "${game.title}: shown as '${game.shownTitle}'" }
        payload(Sent.Renamed(game.shownTitle, game.displayName.map { game.title }))
    }

    /** Shows the consoles of [platformIds] in that order from now on, on the consoles screen and after a restart. */
    @UsedByGodot
    public fun orderConsoles(requestId: Int, platformIds: Array<String>): Unit = onLibrary(requestId) {
        library.value.orderConsoles(platformIds.map(::PlatformId)).mapLeft { it.failed }.bind()
        trace("library") { "consoles ordered: ${platformIds.joinToString()}" }
        Payload.NONE
    }

    /** Puts [platformId] at [gap] among the consoles; answers with [Sent.Placed]. */
    @UsedByGodot
    public fun placeConsole(requestId: Int, platformId: String, gap: Int): Unit = onLibrary(requestId) {
        val platforms = catalog.shown
        val placed =
            library.value
                .placeConsole(PlatformId(platformId), gap, platforms)
                .onLeft { trace("library") { "console $platformId not placed at $gap: ${it.message}" } }
                .mapLeft { it.failed }
                .bind()
        val order = placed.shown(platforms).map { it.value }
        trace("library") { "console $platformId placed at $gap: ${order.joinToString()}" }
        payload(Sent.Placed(order))
    }

    /** Checks that the game `{"game_id", "disc"?}` can launch as [launchGame] would; starts and stops nothing. */
    @UsedByGodot
    public fun checkLaunch(requestId: Int, request: Dictionary): Unit = onLibrary(requestId) {
        val (choice, launch) = libraryLaunch(request)
        launcher.checkGame(launch, choice.file.uri).mapLeft { it.failed }.bind()
        Payload.NONE
    }

    /**
     * Launches the game `{"game_id", "disc"?, "within_ms"}` under the curtain when allowed. A start that could only begin
     * `within_ms` or more after it was asked is refused (`too_late`): nothing stopped, no curtain, nothing recorded.
     */
    @UsedByGodot
    public fun launchGame(requestId: Int, request: Dictionary): Unit = onActivity(requestId) { act ->
        // Taken on Godot's thread, as the request is made: the wait for the library thread counts too.
        val asked = TimeSource.Monotonic.markNow()
        onLibrary(requestId) {
            val deadline = request.integer("within_ms").flatMap(StartDeadline::ofMillis).getOrElse { raise(invalid("No valid within_ms")) }
            val (choice, launch) = libraryLaunch(request)
            val emulator = launch.spec.targetPackage
            trace("launch") { "${choice.file.name.value} in ${emulator.fold({ "the app Android picks" }) { it.value }}" }
            delay(debug.launchSlow)
            val inTime = { deadline.allows(asked.elapsedNow()) }
            val intent = launcher.prepareGame(launch, choice.file.uri, inTime).mapLeft { it.failed }.bind()
            onMain {
                deadline.startInTime(asked) { curtain.over(reference.curtainTimes.timeFor(emulator)) { launcher.start(act, intent) } }
            }.mapLeft { it.failed }.bind()
            // Answered at once so the black lasts no longer than the start; a disc not saved is no failed launch.
            scope.launch(threads.library) {
                library.value.recordLaunch(choice.game.id, choice.disc).onLeft { trace("library") { "last disc not saved: ${it.message}" } }
            }
            Payload.NONE
        }
    }

    private fun libraryIn(folder: File): LibraryService = LibraryService(
        LibraryStore(File(folder, LIBRARY_FILE)),
        File(folder, "selection.json"),
        File(folder, "arrivals.json"),
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

    private suspend fun <T> Raise<Failed>.inLibrary(block: LibraryService.() -> Either<LibraryFailure, T>): T =
        withContext(threads.library) { library.value.block() }.mapLeft { it.failed }.bind()

    /**
     * Answers [requestId] with what [work] returns, or with the failure it raises. Library calls start on
     * [libraryThread] itself, which runs them in the order they arrive.
     */
    private fun answering(requestId: Int, on: CoroutineDispatcher = Dispatchers.IO, work: suspend Raise<Failed>.() -> Payload) {
        scope.launch(on) { answer(requestId, None) { either { work() } } }
    }

    /**
     * Every library call's answer tells the library's `"revision"` ([LibraryService.revision]): Godot shows a library
     * sent before only when no answer told a newer one since.
     */
    private fun onLibrary(requestId: Int, work: suspend Raise<Failed>.() -> Payload) {
        scope.launch(threads.library) {
            val result = guarded { either { work() } }
            emitSignal(ANSWERED_SIGNAL, answered(requestId, Some(library.value.revision), result))
        }
    }

    private fun pendingPicker() = PendingPick<Failed> { requestId, failed -> answer(requestId, None) { Either.Left(failed) } }

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

    private suspend fun Raise<Failed>.libraryLaunch(request: Dictionary): Pair<LaunchChoice, Launch> {
        val id = request.text("game_id").map(::GameId).getOrElse { raise(invalid("the request needs a game_id")) }
        val choice = inLibrary { launchChoice(id, request.integer("disc")) }
        val platform = platform(choice.game.platform)
        val player =
            choice.setup.playerFor(platform, choice.file.name, ::isAvailable).getOrElse {
                raise(LaunchFailure.NoPlayer(platform.id).failed)
            }
        return choice to launchOf(player.id, choice.file.asGameFile).mapLeft { it.failed }.bind()
    }

    /** The choices sent for a platform, as [Sent.PlatformSetup] names them. */
    private fun Raise<Failed>.setupOf(setup: Dictionary): PlatformSetup {
        val folder = setup.text("folder_uri").map { ContentUri.parse(it).getOrElse { raise(invalid("folder_uri is not a content URI")) } }
        return PlatformSetup(
            folder,
            setup.text("player_id").map(::PlayerId),
            code("disc_grouping", setup.text("disc_grouping"), DiscGrouping.entries) { it.serialName },
            code("folder_depth", setup.text("folder_depth"), FolderDepth.entries) { it.serialName },
        )
    }

    /** The value of [values] named [text] on the wire, sent as [key]; an invalid request when there is none. */
    private fun <T> Raise<Failed>.code(key: String, text: Option<String>, values: List<T>, wire: (T) -> String): T =
        text.flatMap { name -> values.firstOrNone { wire(it) == name } }.getOrElse { raise(invalid("$key is missing or unknown")) }

    private fun Raise<Failed>.game(id: GameId): Game =
        library.value.library().game(id).getOrElse { raise(LibraryFailure.UnknownGame(id).failed) }

    private fun Raise<Failed>.platform(id: PlatformId, loaded: Reference = reference): Platform =
        loaded.catalog.platform(id).getOrElse { raise(Failed(Code.UNKNOWN_PLATFORM, "No platform ${id.value}")) }

    private fun sentLibrary(service: LibraryService): Sent.Library = timed(
        "library",
        { sent: Sent.Library, took -> "${sent.games.size} games made ready to send in ${took.inWholeMilliseconds} ms" },
    ) { with(reference.catalog) { service.library().sent(service.revision, service.shelves(shown), this) } }

    /**
     * The tables as the app holds them: Godot's Android export stores the project's files as the APK's assets, `res://` at their root.
     * A build without ScreenScraper's key offers no texture: one answered as not found would be remembered missing, and stay so once a
     * build with the key is installed over it.
     */
    private fun tableFiles(): TableFiles {
        val withTextures = Credentials.fromBuild().isSome()
        val assets = TableFiles.at(context.assets::open)
        return TableFiles { table, platform -> if (table == Table.TEXTURES && !withTextures) None else assets.open(table, platform) }
    }

    // The system resolves implicit intents, so they are always available.
    private fun isAvailable(player: Player): Boolean = player.template.targetPackage.fold({ true }) {
        installed.getOrPut(it) {
            InstalledApps.isInstalled(context.packageManager, it).also { yes -> trace("installed") { "${it.value}: $yes" } }
        }
    }

    private fun withActivity(requestId: Int, work: suspend (Activity) -> Either<LaunchFailure, Unit>): Unit =
        onActivity(requestId) { act -> answering(requestId) { work(act).mapLeft { it.failed }.bind().let { Payload.NONE } } }

    private fun onActivity(requestId: Int, work: (Activity) -> Unit): Unit =
        activity.toOption().fold({ answer(requestId, None) { Either.Left(Failed(Code.NO_ACTIVITY, "No activity")) } }, work)

    private suspend fun <T> onMain(block: () -> T): T = withContext(Dispatchers.Main) { block() }

    private inline fun answer(requestId: Int, revision: Option<Int>, work: () -> Either<Failed, Payload>) {
        emitSignal(ANSWERED_SIGNAL, answered(requestId, revision, guarded(work)))
    }

    /** The single place where unexpected exceptions stop. */
    private inline fun guarded(work: () -> Either<Failed, Payload>): Either<Failed, Payload> =
        Either.catch(work).fold({ Either.Left(unexpected(it)) }, { it })

    private companion object {
        // Godot forwards every activity result to every plugin: unique among the bundled plugins.
        const val REQUEST_PICK_FOLDER = 0xCA27

        const val REQUEST_PICK_PICTURE = 0xCA28

        const val LIBRARY_FILE = "library.json"
    }
}
