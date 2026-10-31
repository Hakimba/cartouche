# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidServices
extends Node
## Typed access to Cartouche's Kotlin plugin (`kotlin/android`), registered as the `Android`
## autoload. This is the only file that talks to the plugin: everything else gets the typed values
## of [AndroidWire].
##
## Getters answer at once, and [method prepare_titles] only starts its work. Operations are coroutines
## (`await Android.list_folder(folder)`), and [AndroidServices.Asked] asks one early. Without the
## plugin (editor, desktop), [DesktopPlugin] answers in its place.

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
## Every operation's answer; callers await the one carrying their request id.
signal _answered(payload: Dictionary)

const _SINGLETON := &"CartoucheAndroid"
const _PLATFORM_DEFINITIONS := "res://data/platforms/daijishou"
## Cartouche's own definitions, for platforms Daijishō has none of.
const _OWN_PLATFORM_DEFINITIONS := "res://data/platforms/cartouche"
const _PLATFORM_PROFILES := "res://data/platforms/profiles.json"
## One reference list per platform, named after its id (`ps2.tsv`).
const _TITLE_LISTS := "res://data/titles"
const _DATA_FOLDERS := "res://data/scan/data_folders.json"
const _CURTAINS := "res://data/launch/curtains.json"
## One art extract per platform, named after its id (`ps2.tsv`).
const _ART := "res://data/art"
## The prints of each cartridge platform's games, named after its id (`nes.tsv`).
const _PRINTS := "res://data/prints"
## ScreenScraper's texture table per platform, named after its id (`ps2.tsv`).
const _SCREENSCRAPER := "res://data/screenscraper"
## A start asked now that could only begin after this long is refused (`too_late`), as the carousel
## stops waiting for it a little later (see [constant GameLaunch.WAIT_TIMEOUT_S]).
const START_WITHIN_S := 4.5
const Result := AndroidWire.Result
const Document := AndroidWire.Document
const Folder := AndroidWire.Folder
const Entry := AndroidWire.Entry
const Candidate := AndroidWire.Candidate
const App := AndroidWire.App
const Battery := AndroidWire.Battery
const Platform := AndroidWire.Platform
const Player := AndroidWire.Player
const CatalogSummary := AndroidWire.CatalogSummary
const OfferedConsole := AndroidWire.OfferedConsole
const Placed := AndroidWire.Placed
const Pick := AndroidWire.Pick
const FolderList := AndroidWire.FolderList
const Listing := AndroidWire.Listing
const AppList := AndroidWire.AppList
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
		_plugin.connect(&"answered", _answered.emit)
		_plugin.connect(&"art_changed", func(payload: Dictionary) -> void: art_changed.emit(ArtChange.new(payload)))
		_plugin.connect(&"art_progress", func(payload: Dictionary) -> void: art_progress.emit(LabelDownload.new(payload)))
		_plugin.connect(&"label_variant_downloaded", func(payload: Dictionary) -> void:
			label_variant_downloaded.emit(LabelVariant.new(payload)))
		_plugin.connect(&"battery_changed", func(payload: Dictionary) -> void: battery_changed.emit(Battery.new(payload)))
	else:
		(_plugin as DesktopPlugin).load_snapshot(Diagnostics.argument("snapshot"))
	if OS.has_feature("android"):
		AndroidButtons.follow_android()
	_load_catalog()


func is_available() -> bool:
	return _plugin is not DesktopPlugin


## Whether the desktop shows a snapshot of a device's data (`--snapshot=DIR`).
func has_snapshot() -> bool:
	return _plugin is DesktopPlugin and (_plugin as DesktopPlugin).has_snapshot()


## Loads the bundled platform definitions, profiles, reference lists, art extracts, cartridge
## prints and texture tables into the plugin, once.
func _load_catalog() -> void:
	var started := Time.get_ticks_usec()
	var profiles := FileAccess.get_file_as_string(_PLATFORM_PROFILES)
	var definitions := platform_definitions()
	var titles := _files_in(_TITLE_LISTS, ".tsv", true)
	var data_folders := FileAccess.get_file_as_string(_DATA_FOLDERS)
	var curtains := FileAccess.get_file_as_string(_CURTAINS)
	var art := _files_in(_ART, ".tsv", true)
	var cartridge_prints := _files_in(_PRINTS, ".tsv", true)
	var textures := _files_in(_SCREENSCRAPER, ".tsv", true)
	var read := Time.get_ticks_usec()
	# The platforms with a console model, the one source of what a person may add.
	var supported := PackedStringArray(Appearance.defaults(ConsoleManifest.found()).keys())
	var summary: Dictionary = _query(&"loadCatalog",
		[definitions, profiles, titles, data_folders, curtains, art, cartridge_prints, textures, supported], {})
	catalog = CatalogSummary.new(summary)
	if Diagnostics.enabled:
		Diagnostics.trace("plugin", "catalog read in %.1f ms, loaded in %.1f ms" % [(read - started) / 1000.0,
			(Time.get_ticks_usec() - read) / 1000.0])


## Installed players of [param platform_id], in definition order.
func installed_players(platform_id: String) -> Array[Player]:
	var found: Array[Player] = []
	for item: Dictionary in _query(&"installedPlayers", [platform_id], []):
		found.append(Player.new(item))
	return found


## What the carousel shows of [param platform_id]'s shelf (see [Browse]): the games found for
## [param typed], or with nothing typed the index by `title` or `region` ([param order]).
func browse(platform_id: String, order: StringName, typed: String) -> Browse:
	var view: Dictionary = JSON.parse_string(browse_text(platform_id, order, typed))
	return Browse.new(view)


## [method browse]'s answer as the plugin gives it.
func browse_text(platform_id: String, order: StringName, typed: String) -> String:
	return _query(&"browse", [platform_id, String(order), typed], "{}")


## Where the words of [param typed] are in the title of the game at [param position] of
## [param platform_id]'s shelf, as (start, length) in characters; none when it is not found.
func title_marks(platform_id: String, position: int, typed: String) -> Array[Vector2i]:
	var text: String = _query(&"titleMarks", [platform_id, position, typed], "[]")
	var found: Array = JSON.parse_string(text)
	var marks: Array[Vector2i] = []
	for mark: Array in found:
		var start: int = mark[0]
		var length: int = mark[1]
		marks.append(Vector2i(start, length))
	return marks


## Installed players able to open [param file_name], in definition order.
func candidates(file_name: String) -> Array[Candidate]:
	var found: Array[Candidate] = []
	for item: Dictionary in _query(&"candidates", [file_name], []):
		found.append(Candidate.new(item))
	return found


func has_all_files_access() -> bool:
	# The bridge may hand the answer over as an int; the typed variable converts it.
	var granted: bool = _query(&"hasAllFilesAccess", [], false)
	return granted


## Whether a curtain can hide an emulator until its game shows: Cartouche may display over other
## apps.
func curtain_allowed() -> bool:
	var granted: bool = _query(&"curtainAllowed", [], false)
	return granted


func battery() -> Battery:
	var state: Dictionary = _query(&"battery", [], {})
	return Battery.new(state)


## The manufacturer, model and Android version, such as "Acme Handheld 2, Android 13".
func device_name() -> String:
	return _query(&"deviceName", [], "")


## Debug builds: the arguments the app was started with (see `launchArguments` in the plugin).
func launch_arguments() -> PackedStringArray:
	return _query(&"launchArguments", [], PackedStringArray())


func request_all_files_access() -> Result:
	return Result.new(await _request(&"requestAllFilesAccess"))


## Opens the system screen letting Cartouche display over other apps, for the curtain.
func request_curtain_permission() -> Result:
	return Result.new(await _request(&"requestCurtainPermission"))


## Opens the system folder picker; answers once the user granted a folder or gave up.
func pick_folder() -> Pick:
	return Pick.new(await _request(&"pickFolder"))


## Folders whose access survived until now.
func persisted_folders() -> FolderList:
	return FolderList.new(await _request(&"persistedFolders"))


## Lists the root of [param folder].
func list_folder(folder: Folder) -> Listing:
	return Listing.new(await _request(&"listFolder", [{"tree_uri": folder.uri}]))


## Lists [param sub_folder], a directory entry of [param folder].
func list_sub_folder(folder: Folder, sub_folder: Entry) -> Listing:
	var location := {"tree_uri": folder.uri, "document_id": sub_folder.document_id}
	return Listing.new(await _request(&"listFolder", [location]))


func list_apps() -> AppList:
	return AppList.new(await _request(&"listLaunchableApps"))


func launch_app(package_name: String) -> Result:
	return Result.new(await _request(&"launchApp", [package_name]))


## Launches [param file] with [param player_id], outside the library.
func launch_file(player_id: String, file: Entry) -> Result:
	var game := {"name": file.name, "uri": file.uri}
	if file.has_path:
		game["path"] = file.path
	return Result.new(await _request(&"launchFile", [player_id, game]))


## The library, read from its file on first use, with the art stored for its games; looking for
## the others' art starts, as [signal art_changed] tells.
func library() -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"library"))


## Stores the choices made for [param platform_id].
func set_up_platform(platform_id: String, setup: PlatformSetup) -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"setUpPlatform", [platform_id, setup.to_wire()]))


## Keeps the selected model of a set-up console.
func set_variant(platform_id: String, variant: String) -> LibraryAnswer:
	var answer := LibraryAnswer.new(await _request(&"setVariant", [platform_id, variant]))
	if answer.ok:
		Diagnostics.trace("console", "variant=%s of %s" % [variant, platform_id])
	return answer


## Looks for the art of [param games] (the game on screen and its neighbours) before the others'.
func art_focus(games: Array[AndroidServices.Game]) -> void:
	var ids := PackedStringArray()
	for game in games:
		ids.append(game.id)
	_query(&"artFocus", [ids], null)


## Hands the memory the app freed back to the system: as the screen comes to rest, and as the app leaves the screen.
func release_memory() -> void:
	_query(&"releaseMemory", [], null)


## Prepares in the background what looking at a folder needs (the reference lists' indexes), as a
## console is about to be added or changed.
func prepare_titles() -> void:
	_query(&"prepareTitles", [], null)


## How many games a scan of [param platform_id] with [param setup] would find, without saving
## anything; its scan after [method set_up_platform] finds the same.
func preview_platform(platform_id: String, setup: PlatformSetup) -> PreviewAnswer:
	return PreviewAnswer.new(await _request(&"previewPlatform", [platform_id, setup.to_wire()]))


func settings() -> SettingsAnswer:
	return SettingsAnswer.new(await _request(&"settings"))


## Stores the button style the user chose, [param style] as [SettingsAnswer] names it.
func save_button_style(style: StringName) -> Result:
	return Result.new(await _request(&"saveButtonStyle", [style]))


## Stores the language the app's text is written in, [param language] one of
## [member SettingsAnswer.languages] (empty follows the device's).
func save_language(language: String) -> Result:
	return Result.new(await _request(&"saveLanguage", [language]))


## Stores the edge smoothing the user chose, [param smoothing] as [SettingsAnswer] names it.
func save_edge_smoothing(smoothing: StringName) -> Result:
	return Result.new(await _request(&"saveEdgeSmoothing", [smoothing]))


## Stores whether the selected game sways and bobs ([param floating]); the consoles never do.
func save_games_float(floating: bool) -> Result:
	return Result.new(await _request(&"saveGamesFloat", [floating]))


## Stores how loud the sounds play, [param steps] from 0 (silenced) to [constant SoundEffects.LEVELS].
func save_sound_level(steps: int) -> Result:
	return Result.new(await _request(&"saveSoundLevel", [steps]))


## Stores the region labels' images prefer, [param region] one of
## [member SettingsAnswer.preferred_regions] (empty for none); the labels it changes are looked for
## again, as [signal art_changed] tells.
func save_preferred_region(region: String) -> Result:
	return Result.new(await _request(&"savePreferredRegion", [region]))


## Scans the folder of [param platform_id] and replaces its games.
func scan_platform(platform_id: String) -> ScanAnswer:
	return ScanAnswer.new(await _request(&"scanPlatform", [platform_id]))


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
	return LibraryAnswer.new(await _request(&"useDemoLibrary", [games, platform_id]))


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


## The definition files sent to the plugin, Daijishō's and Cartouche's own, by file name.
static func platform_definitions() -> Dictionary:
	return _files_in(_PLATFORM_DEFINITIONS, ".json").merged(_files_in(_OWN_PLATFORM_DEFINITIONS, ".json"))


## `{file name or base name: text}` for the files of [param folder] ending with [param extension].
static func _files_in(folder: String, extension: String, by_base_name := false) -> Dictionary:
	var texts := {}
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(extension):
			var key := file_name.get_basename() if by_base_name else file_name
			texts[key] = FileAccess.get_file_as_string(folder.path_join(file_name))
	return texts


## Asks the plugin; [param nothing] when it is the desktop stand-in and that has no answer.
func _query(method: StringName, args: Array, nothing: Variant) -> Variant:
	var value: Variant = _plugin.callv(method, args) if _answers(method) else nothing
	# The catalog's arguments are the whole data files, a shelf's view thousands of positions: not
	# worth formatting (the plugin traces the view's size).
	if Diagnostics.enabled and method not in [&"loadCatalog", &"browse"]:
		Diagnostics.trace("plugin", "%s%s = %s" % [method, args, value])
	return value


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
	var payload: Dictionary = at_once if at_once != null else await _answer_to(id)
	if Diagnostics.enabled:
		var elapsed := Time.get_ticks_msec() - started
		# The library is traced once read (LibraryAnswer): here it would cost as much as the games.
		var shown := payload.duplicate()
		shown.erase("library")
		Diagnostics.trace("plugin", "#%d answered in %d ms: %s" % [id, elapsed, shown])
	return payload


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
