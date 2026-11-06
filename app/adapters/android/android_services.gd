# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidServices
extends Node
## Typed access to Cartouche's Kotlin plugin (`kotlin/android`), registered as the `Android`
## autoload. This is the only file that talks to the plugin: it reads the JSON text the plugin sends
## into the typed values of [AndroidWire], which everything else gets.
##
## Getters answer at once, and [method prepare_tables] only starts its work. Operations are coroutines
## (`await Android.pick_folder()`), and [AndroidServices.Asked] asks one early. Without the
## plugin (editor, desktop), [DesktopPlugin] answers in its place, in the same JSON.

## Looking for the games' art went on: [param change] tells how, and the art just found or the
## game just found to have none, if any.
signal art_changed(change: ArtChange)
## One of the images [method label_variants] listed, not downloaded then, was downloaded or could
## not be.
signal label_variant_downloaded(variant: LabelVariant)
## The label of a game on screen downloads, or is done downloading: [param download] tells how far.
signal art_progress(download: LabelDownload)
## The battery's level, or whether the device is plugged in, changed.
signal battery_changed(battery: Battery)
## An answer told the games not seen yet, as the plugin now marks them.
signal arrivals_told(arrivals: Arrivals)
## Every operation's answer, read from its JSON; callers await the one carrying their request id.
signal _answered(payload: Dictionary)

const _SINGLETON := &"CartoucheAndroid"
const _PLATFORM_DEFINITIONS := "res://data/platforms/daijishou"
## Cartouche's own definitions, for platforms Daijishō has none of or names otherwise.
const _OWN_PLATFORM_DEFINITIONS := "res://data/platforms/cartouche"
const _PLATFORM_PROFILES := "res://data/platforms/profiles.json"
const _DATA_FOLDERS := "res://data/scan/data_folders.json"
const _CURTAINS := "res://data/launch/curtains.json"
## A start asked now that could only begin after this long is refused (`too_late`), as the carousel
## stops waiting for it a little later (see [constant GameLaunch.WAIT_TIMEOUT_S]).
const START_WITHIN_S := 4.5
## Texts longer than this have their reading traced: a library's.
const _TRACED_CHARACTERS := 10000
const Result := AndroidWire.Result
const Folder := AndroidWire.Folder
const Battery := AndroidWire.Battery
const BackdropAnswer := AndroidWire.BackdropAnswer
const Platform := AndroidWire.Platform
const Player := AndroidWire.Player
const CatalogSummary := AndroidWire.CatalogSummary
const OfferedConsole := AndroidWire.OfferedConsole
const Placed := AndroidWire.Placed
const Pick := AndroidWire.Pick
const FolderList := AndroidWire.FolderList
const PlatformSetup := AndroidWire.PlatformSetup
const Disc := AndroidWire.Disc
const Game := AndroidWire.Game
const SkippedFolder := AndroidWire.SkippedFolder
const IgnoredCount := AndroidWire.IgnoredCount
const Shelf := AndroidWire.Shelf
const Browse := AndroidWire.Browse
const Group := AndroidWire.Group
const Library := AndroidWire.Library
const LibraryAnswer := AndroidWire.LibraryAnswer
const ScanReport := AndroidWire.ScanReport
const PreviewAnswer := AndroidWire.PreviewAnswer
const SettingsAnswer := AndroidWire.SettingsAnswer
const ScanAnswer := AndroidWire.ScanAnswer
const Arrivals := AndroidWire.Arrivals
const ArrivalsAnswer := AndroidWire.ArrivalsAnswer
const RefreshAnswer := AndroidWire.RefreshAnswer
const RescrapeAnswer := AndroidWire.RescrapeAnswer
const Art := AndroidWire.Art
const ArtProgress := AndroidWire.ArtProgress
const ArtChange := AndroidWire.ArtChange
const LabelDownload := AndroidWire.LabelDownload
const LabelVariant := AndroidWire.LabelVariant
const LabelVariants := AndroidWire.LabelVariants
const Renamed := AndroidWire.Renamed
const LabelPicture := AndroidWire.LabelPicture
const ArtAnswer := AndroidWire.ArtAnswer

## The catalog, loaded when the app starts.
var catalog := CatalogSummary.new({})
## The library's revision, as the latest answer told it: one more at each write of the plugin.
var library_revision := 0

var _plugin: Object = Engine.get_singleton(_SINGLETON) if Engine.has_singleton(_SINGLETON) else DesktopPlugin.new()
var _last_request_id := 0
## The system's font list, read on a worker while the main scene loads (nothing shapes text before the
## tree starts): read on first need instead, by the first text with a letter its font lacks, such as a
## Japanese title, it stalls that frame (about 200 ms on a handheld).
var _system_fonts_read := WorkerThreadPool.add_task(OS.get_system_fonts)


func _enter_tree() -> void:
	WorkerThreadPool.wait_for_task_completion(_system_fonts_read)


func _ready() -> void:
	if is_available():
		_plugin.connect(&"answered", func(text: String) -> void: _answered.emit(_object(text)))
		_plugin.connect(&"art_changed", func(text: String) -> void: art_changed.emit(ArtChange.new(_object(text))))
		_plugin.connect(&"art_progress", func(text: String) -> void: art_progress.emit(LabelDownload.new(_object(text))))
		_plugin.connect(&"label_variant_downloaded", func(text: String) -> void:
			label_variant_downloaded.emit(LabelVariant.new(_object(text))))
		_plugin.connect(&"battery_changed", func(text: String) -> void: battery_changed.emit(Battery.new(_object(text))))
	else:
		(_plugin as DesktopPlugin).load_snapshot(Diagnostics.argument("snapshot"))
		(_plugin as DesktopPlugin).start_with_backdrop(Diagnostics.argument("backdrop"), Diagnostics.argument("pixel-veil"))
		(_plugin as DesktopPlugin).start_with_arrivals(Diagnostics.argument("new-games"))
	if OS.has_feature("android"):
		AndroidButtons.follow_android()
	_load_catalog()


func is_available() -> bool:
	return _plugin is not DesktopPlugin


## Whether the desktop shows a snapshot of a device's data (`--snapshot=DIR`).
func has_snapshot() -> bool:
	return _plugin is DesktopPlugin and (_plugin as DesktopPlugin).has_snapshot()


## Loads the bundled platform definitions, profiles, data folders and curtain times into the plugin, once. The
## plugin reads a platform's tables (`res://data/titles`, `art`, `prints`, `screenscraper`) itself, off this thread,
## as the platform first needs them.
func _load_catalog() -> void:
	var started := Time.get_ticks_usec()
	var profiles := FileAccess.get_file_as_string(_PLATFORM_PROFILES)
	var definitions := platform_definitions()
	var data_folders := FileAccess.get_file_as_string(_DATA_FOLDERS)
	var curtains := FileAccess.get_file_as_string(_CURTAINS)
	var read := Time.get_ticks_usec()
	# The platforms with a console model, the one source of what a person may add, and the models not ready yet.
	var supported := PackedStringArray(Appearance.defaults(ConsoleManifest.found()).keys())
	var coming := PackedStringArray(ConsoleManifest.found().filter(func(model: ConsoleManifest) -> bool:
		return model.is_coming()).map(ConsoleManifest.folder_of))
	catalog = CatalogSummary.new(_object(_query(&"loadCatalog",
		[definitions, profiles, data_folders, curtains, supported, coming])))
	if Diagnostics.enabled:
		Diagnostics.trace("plugin", "catalog read in %.1f ms, loaded in %.1f ms" % [(read - started) / 1000.0,
			(Time.get_ticks_usec() - read) / 1000.0])


## Installed players of [param platform_id], in definition order.
func installed_players(platform_id: String) -> Array[Player]:
	return AndroidWire.Players.new(_object(_query(&"installedPlayers", [platform_id]))).players


## What the carousel shows of [param platform_id]'s shelf (see [Browse]): the games found for
## [param typed], or with nothing typed the index by `title` or `region` ([param order]).
func browse(platform_id: String, order: StringName, typed: String) -> Browse:
	return Browse.new(_object(browse_text(platform_id, order, typed)))


## [method browse]'s answer as the plugin gives it.
func browse_text(platform_id: String, order: StringName, typed: String) -> String:
	return _query(&"browse", [platform_id, String(order), typed])


## Where the words of [param typed] are in the title of the game at [param position] of
## [param platform_id]'s shelf, as (start, length) in characters; none when it is not found.
func title_marks(platform_id: String, position: int, typed: String) -> Array[Vector2i]:
	var marks: Array[Vector2i] = []
	for mark in AndroidWire.Marks.new(_object(_query(&"titleMarks", [platform_id, position, typed]))).marks:
		marks.append(Vector2i(mark.start, mark.length))
	return marks


## Whether a curtain can hide an emulator until its game shows: Cartouche may display over other
## apps.
func curtain_allowed() -> bool:
	return JSON.parse_string(_query(&"curtainAllowed", [], "false")) == true


## The backdrop stored, at once: the first frame is drawn on it.
func backdrop() -> BackdropAnswer:
	return BackdropAnswer.new(_object(_query(&"backdrop", [])))


func battery() -> Battery:
	return Battery.new(_object(_query(&"battery", [])))


## Debug builds: the arguments the app was started with (see `launchArguments` in the plugin).
func launch_arguments() -> PackedStringArray:
	var parsed: Variant = JSON.parse_string(_query(&"launchArguments", [], "[]"))
	var arguments: Array = parsed if parsed is Array else []
	return PackedStringArray(arguments)


## Opens the system screen letting Cartouche display over other apps, for the curtain.
func request_curtain_permission() -> Result:
	return Result.new(await _request(&"requestCurtainPermission"))


## Opens the system folder picker; answers once the user granted a folder or gave up.
func pick_folder() -> Pick:
	return Pick.new(await _request(&"pickFolder"))


## Folders whose access survived until now.
func persisted_folders() -> FolderList:
	return FolderList.new(await _request(&"persistedFolders"))


## The library, read from its file on first use, with the art stored for its games; looking for
## the others' art starts, as [signal art_changed] tells.
func library() -> LibraryAnswer:
	return _typed(await _request(&"library"))


## Stores the choices made for [param platform_id].
func set_up_platform(platform_id: String, setup: PlatformSetup) -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"setUpPlatform", [platform_id, setup.to_wire()]))


## Looks for the art of [param games] (the game on screen and its neighbours) before the others'.
func art_focus(games: Array[AndroidServices.Game]) -> void:
	var ids := PackedStringArray()
	for game in games:
		ids.append(game.id)
	_query(&"artFocus", [ids])


## Hands the memory the app freed back to the system: as the screen comes to rest, and as the app leaves the screen.
func release_memory() -> void:
	_query(&"releaseMemory", [])


## Prepares in the background what looking at a folder of [param platform_id] needs (its tables, read and
## indexed), as a console is about to be added or changed.
func prepare_tables(platform_id: String) -> void:
	_query(&"prepareTables", [platform_id])


## How many games a scan of [param platform_id] with [param setup] would find, without saving
## anything; its scan after [method set_up_platform] finds the same.
func preview_platform(platform_id: String, setup: PlatformSetup) -> PreviewAnswer:
	return PreviewAnswer.new(await _request(&"previewPlatform", [platform_id, setup.to_wire()]))


func settings() -> SettingsAnswer:
	return SettingsAnswer.new(await _request(&"settings"))


## Stores [param value] as the setting [param key] (as [SettingsAnswer] names both): a choice's name, a switch's
## bool or a level's int, sent as [method @GlobalScope.str] writes it. The plugin refuses a key or a value its
## settings do not declare; a preferred region changed looks again for the labels it changes, as
## [signal art_changed] tells.
func save_setting(key: StringName, value: Variant) -> Result:
	return Result.new(await _request(&"saveSetting", [String(key), str(value)]))


## Scans the folder of [param platform_id] and replaces its games.
func scan_platform(platform_id: String) -> ScanAnswer:
	return ScanAnswer.new(await _request(&"scanPlatform", [platform_id]))


## Reads the folder of [param platform_id] again, the user not asking: its games change as a scan's, and those it
## brings are marked as new.
func refresh_platform(platform_id: String) -> RefreshAnswer:
	return RefreshAnswer.new(await _request(&"refreshPlatform", [platform_id]))


## The user entered [param platform_id]'s console: it announces no new game any more ([signal arrivals_told]).
func enter_console(platform_id: String) -> ArrivalsAnswer:
	return ArrivalsAnswer.new(await _request(&"enterConsole", [platform_id]))


## The user left [param game] on its shelf: it is not new any more ([signal arrivals_told]).
func leave_game(game: Game) -> ArrivalsAnswer:
	return ArrivalsAnswer.new(await _request(&"leaveGame", [game.id]))


## The library as the plugin now stores it.
func current_library() -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"currentLibrary"))


## Removes [param platform_id] from the library: its choices, games and art, and the access to its
## folder unless another platform uses it. The game files stay.
func remove_platform(platform_id: String) -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"removePlatform", [platform_id]))


## Remembers [param game] as the selected game of its platform, and that platform as the one shown.
func select_game(game: Game) -> Result:
	return Result.new(await _request(&"selectGame", [game.id]))


## Debug builds only: replaces the library with a made-up one of [param games] games, spread over
## the platforms or all on [param platform_id], stored apart from the user's, for measuring at
## scale.
func use_demo_library(games: int, platform_id := "") -> LibraryAnswer:
	return _typed(await _request(&"useDemoLibrary", [games, platform_id]))


## Debug builds only: scans every console again, reading all of their game files anew, and looks
## every automatic label up again (never one the user chose: their own picture or a region's
## image); answers once every label was looked for, so not while offline or while a game is played.
func rescrape() -> RescrapeAnswer:
	return RescrapeAnswer.new(await _request(&"rescrape"))


## The images the art sources have for [param game]'s label, every one of both sources, each with
## its region and source, in the order they are tried; those not downloaded yet then arrive
## through [signal label_variant_downloaded].
func label_variants(game: Game) -> LabelVariants:
	return LabelVariants.new(await _request(&"labelVariants", [game.id]))


## Shows the image of [param region] at [param source] (downloaded, as [method label_variants]
## names them) on [param game]'s label from now on.
func choose_label(game: Game, region: String, source: String) -> ArtAnswer:
	return ArtAnswer.new(await _request(&"chooseLabel", [game.id, region, source]))


## Shows [param game] as [param shown] from now on (trimmed, cut at 80 characters), or as its own
## title again when [param shown] is blank.
func rename_game(game: Game, shown: String) -> Renamed:
	return Renamed.new(await _request(&"renameGame", [game.id, shown]))


## Shows the consoles of [param platform_ids] in that order from now on, after a restart too.
func order_consoles(platform_ids: PackedStringArray) -> Result:
	return Result.new(await _request(&"orderConsoles", [platform_ids]))


## Puts [param platform_id]'s console at [param gap] among the others as the consoles screen
## shows them, the others keeping their order: [param gap] counts from 0 to their number. The
## answer carries the order of all the consoles; a gap out of range or a console not in the library
## keeps the order (codes `gap_out_of_range`, `not_in_library`).
func place_console(platform_id: String, gap: int) -> Placed:
	return Placed.new(await _request(&"placeConsole", [platform_id, gap]))


## Opens the system's picker on images, for a picture of the user's own to put on a label; the app
## keeps a copy of the one picked, to be framed. Cancelled when the user leaves the picker.
func pick_label_picture() -> LabelPicture:
	return LabelPicture.new(await _request(&"pickLabelPicture"))


## Shows the picture picked last on [param game]'s label from now on, as [param framing] frames it.
func keep_own_label(game: Game, framing: LabelFraming) -> ArtAnswer:
	return ArtAnswer.new(await _request(&"keepOwnLabel", [game.id, framing.zoom, framing.centre.x, framing.centre.y,
		framing.proportion]))


## Whether disc [param disc] of [param game] can launch (its emulator is installed, its file still
## there), with the failure [method launch_game] would give; starts and stops nothing. Rehearsing
## (see [method launch_game]), every game can: the insertion plays.
func check_launch(game: Game, disc: int) -> Result:
	if _rehearsing():
		return Result.new({"ok": true})
	return Result.new(await _request(&"checkLaunch", [{"game_id": game.id, "disc": disc}]))


## Launches disc [param disc] (an index into [member Game.discs]) of [param game], hiding the
## emulator under a black curtain until its game shows when [method curtain_allowed]. Debug builds
## started with `--launch=rehearse` start nothing and fail with `rehearsed`: the insertion plays
## whether an emulator is installed or not, then the carousel shows again. Fails with `too_late`
## when the emulator could only start after [constant START_WITHIN_S]: it is not started.
func launch_game(game: Game, disc: int) -> Result:
	if _rehearsing():
		return Result.new({"ok": false, "code": &"rehearsed"})
	return Result.new(await _request(&"launchGame", [{"game_id": game.id, "disc": disc, "within_ms": int(START_WITHIN_S * 1000)}]))


func _rehearsing() -> bool:
	return Diagnostics.argument("launch") == "rehearse"


## The definition files sent to the plugin, Daijishō's and Cartouche's own, by file name: one of Cartouche's
## replaces Daijishō's of the same name.
static func platform_definitions() -> Dictionary:
	return _files_in(_PLATFORM_DEFINITIONS, ".json").merged(_files_in(_OWN_PLATFORM_DEFINITIONS, ".json"), true)


## `{file name: text}` for the files of [param folder] ending with [param extension].
static func _files_in(folder: String, extension: String) -> Dictionary:
	var texts := {}
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(extension):
			texts[file_name] = FileAccess.get_file_as_string(folder.path_join(file_name))
	return texts


## Asks the plugin for its JSON text; [param nothing] when it is the desktop stand-in and that has no answer.
func _query(method: StringName, args: Array, nothing := "{}") -> String:
	var answered: Variant = _plugin.callv(method, args) if _answers(method) else nothing
	var value := str(answered) if answered != null else nothing
	# The catalog's arguments are whole data files, a shelf's view thousands of positions: not
	# worth formatting (the plugin traces the view's size).
	if Diagnostics.enabled and method not in [&"loadCatalog", &"browse"]:
		Diagnostics.trace("plugin", "%s%s = %s" % [method, args, value])
	return value


## The library answer read into its typed objects, timed: the start's library and the demo's.
func _typed(payload: Dictionary) -> LibraryAnswer:
	var started := Time.get_ticks_usec()
	var answer := LibraryAnswer.new(payload)
	Diagnostics.trace("library", "%d games typed in %.1f ms" % [answer.library.games.size(),
		(Time.get_ticks_usec() - started) / 1000.0])
	return answer


## Calls an operation (its first argument is the request id) and waits for its answer: the plugin
## answers later through [signal _answered], the desktop stand-in at once, or fails as unavailable.
func _request(method: StringName, args: Array = []) -> Dictionary:
	if not _answers(method):
		return {"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"}
	_last_request_id += 1
	var id := _last_request_id
	var started := Time.get_ticks_msec()
	if Diagnostics.enabled:
		Diagnostics.trace("plugin", "#%d %s%s" % [id, method, args])
	var at_once: Variant = _plugin.callv(method, [id] + args)
	var payload: Dictionary = _object(str(at_once)) if at_once is String else await _answer_to(id)
	if Diagnostics.enabled:
		var elapsed := Time.get_ticks_msec() - started
		# The library and its labels would cost as much to trace as their games: their counts stand for them.
		var shown := payload.duplicate()
		for key: String in ["library", "art", "absent"]:
			shown.erase(key)
		var sent: Dictionary = payload.get("library", {})
		var games: Array = sent.get("games", [])
		var art: Array = payload.get("art", [])
		Diagnostics.trace("plugin", "#%d answered in %d ms, %d games, %d labels: %s" % [id, elapsed, games.size(),
			art.size(), shown])
	_took(payload)
	return payload


## What any answer tells besides its own result, read as it comes, before the code awaiting it goes on: the library's
## revision, and the games not seen yet when the request changed them.
func _took(payload: Dictionary) -> void:
	library_revision = payload.get("revision", library_revision)
	if payload.has("arrivals"):
		var arrivals: Dictionary = payload["arrivals"]
		arrivals_told.emit(Arrivals.new(arrivals))


## The object [param text] holds, read once it has crossed; none when it holds no object.
static func _object(text: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var parsed: Variant = JSON.parse_string(text)
	var read: Dictionary = parsed if parsed is Dictionary else {}
	if Diagnostics.enabled and text.length() > _TRACED_CHARACTERS:
		# A library's parse is traced apart: `scripts/bench.sh` measures it.
		Diagnostics.trace("library" if read.has("library") else "plugin", "%d characters read in %.1f ms" % [text.length(),
			(Time.get_ticks_usec() - started) / 1000.0])
	return read


func _answer_to(id: int) -> Dictionary:
	var payload: Dictionary = await _answered
	while payload.get("request_id") != id:
		payload = await _answered
	return payload


## Whether [member _plugin] answers [param method]: the plugin answers every call, its desktop stand-in only
## those it has a method for.
func _answers(method: StringName) -> bool:
	return _plugin is not DesktopPlugin or _plugin.has_method(method)


## An answer asked for now, with one of these operations, and taken later, once other work is done:
## the plugin answers meanwhile.
class Asked:
	signal arrived
	var value: Variant
	var has_arrived := false

	func _init(asking: Callable) -> void:
		_settle(asking)

	## The answer, once it has arrived.
	func taken() -> Variant:
		if not has_arrived:
			await arrived
		return value

	func _settle(asking: Callable) -> void:
		value = await asking.call()
		has_arrived = true
		arrived.emit()
