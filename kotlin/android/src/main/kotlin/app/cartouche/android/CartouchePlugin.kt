// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import app.cartouche.android.apps.InstalledApps
import app.cartouche.android.launch.LaunchFailure
import app.cartouche.android.launch.Launcher
import app.cartouche.android.storage.Folders
import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import app.cartouche.core.PackageName
import app.cartouche.core.launch.GameFile
import app.cartouche.core.platforms.Candidate
import app.cartouche.core.platforms.Catalog
import app.cartouche.core.platforms.CatalogError
import app.cartouche.core.platforms.DefinitionSource
import app.cartouche.core.platforms.PlayerId
import app.cartouche.core.storage.DocumentId
import arrow.core.Either
import arrow.core.Some
import arrow.core.flatMap
import arrow.core.getOrElse
import arrow.core.raise.ensure
import arrow.core.raise.option
import arrow.core.recover
import arrow.core.separateEither
import arrow.core.toOption
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
import java.util.concurrent.ConcurrentHashMap

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
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val folders by lazy { Folders(context) }
    private val launcher by lazy { Launcher(context) }
    private val pendingPick = PendingPick<Dictionary> { requestId, payload -> answer(requestId) { payload } }

    /** Only read and written on the render thread. */
    private var catalog = Catalog()

    /** Whether each package is installed, forgotten on resume since apps may be installed meanwhile. */
    private val installed = ConcurrentHashMap<PackageName, Boolean>()

    override fun getPluginName(): String = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo(ANSWERED_SIGNAL, Dictionary::class.java))

    override fun onMainResume(): Unit = installed.clear()

    override fun onMainDestroy(): Unit = scope.cancel()

    // Getters

    /** Loads platform definitions given as `{file name: JSON text}`, in file name order; returns the catalog summary. */
    @UsedByGodot
    public fun loadCatalog(sources: Dictionary): Dictionary {
        val (notText, definitions) =
            sources.keys.sorted().separateEither { name ->
                sources.text(name).map { DefinitionSource(name, it) }.toEither { CatalogError.InvalidJson(name, "not text") }
            }
        catalog = Catalog.parse(definitions).let { it.copy(rejected = notText + it.rejected) }
        return catalog.toWire()
    }

    /** Installed players able to open [fileName], in definition order. */
    @UsedByGodot
    public fun candidates(fileName: String): Array<Any> =
        catalog.candidates(FileName(fileName)).filter(::isAvailable).toWireArray { it.toWire() }

    @UsedByGodot
    public fun hasAllFilesAccess(): Boolean = Environment.isExternalStorageManager()

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

    // Operations

    /** Opens the system screen granting "All files access". */
    @UsedByGodot
    public fun requestAllFilesAccess(requestId: Int): Unit = withActivity(requestId) { act ->
        onMain {
            launcher
                .start(act, Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${act.packageName}")))
                .recover { failure ->
                    // Some Android builds only offer the screen listing every app.
                    ensure(failure is LaunchFailure.ActivityNotFound) { failure }
                    launcher.start(act, Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)).bind()
                }
        }
    }

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
        tree.fold({ failure(ErrorCode.INVALID_REQUEST, "listFolder needs a tree URI") }) { uri ->
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
        PackageName.parse(packageName).fold({ answer(requestId) { failure(ErrorCode.INVALID_REQUEST, "Invalid package $packageName") } }) {
            withActivity(requestId) { act -> start(act, launcher.appIntent(it)) }
        }

    /** Launches the game `{"name", "uri", "path"?}` with [playerId]. */
    @UsedByGodot
    public fun launchGame(requestId: Int, playerId: String, file: Dictionary) {
        val game =
            option {
                GameFile(
                    FileName(file.text("name").bind()),
                    ContentUri.parse(file.text("uri").bind()).bind(),
                    file.text("path").map(::FilePath),
                )
            }
        game.fold({ answer(requestId) { failure(ErrorCode.INVALID_REQUEST, "launchGame needs a name and a content URI") } }) {
            val launch = catalog.launch(PlayerId(playerId), it).mapLeft(LaunchFailure::Rejected)
            withActivity(requestId) { act -> start(act, launch.flatMap(launcher::prepareGame)) }
        }
    }

    // Plumbing

    // The system resolves implicit intents, so they are always available.
    private fun isAvailable(candidate: Candidate): Boolean =
        candidate.player.template.targetPackage.fold({ true }) { installed.getOrPut(it) { isInstalled(it) } }

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
    }
}
