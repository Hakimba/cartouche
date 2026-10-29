# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidServices
extends Node
## Typed access to Cartouche's Kotlin plugin (`kotlin/android`), registered as the `Android`
## autoload. This is the only file that talks to the plugin: everything else gets the typed values
## below. The wire format is described in `Wire.kt`; a missing value is an absent key, surfaced
## here as a `has_*` flag.
##
## Getters answer at once, and [method prepare_titles] only starts its work. Operations are coroutines
## (`await Android.list_folder(folder)`), and [AndroidServices.Asked] asks one early; without
## the plugin (editor, desktop) they fail with `code == &"unavailable"` and getters return empty
## values, except the catalog and the demo library, read from [constant DESKTOP_DEMO], and the
## launch check, which lets every game's insertion play.

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
## The catalog and a demo library as the plugin sends them, for running without it: see
## `DesktopDemoTest.kt`, which keeps it up to date.
const DESKTOP_DEMO := "res://dev/demo/desktop.json"
const _DESKTOP_VARIANTS := "user://console-variants.json"

var _snapshot := {}

var _demo_settings := {"ok": true, "first_launch": false, "games_float": false, "sound_level": 10}

## The catalog, loaded when the app starts.
var catalog := CatalogSummary.new({})

var _plugin: Object
## The desktop demo's form story, read once.
var _story := {}
var _story_read := false
var _desktop_current := {}
var _last_request_id := 0


func _ready() -> void:
	if Engine.has_singleton(_SINGLETON):
		_plugin = Engine.get_singleton(_SINGLETON)
		_plugin.connect(&"answered", _answered.emit)
		_plugin.connect(&"art_changed", func(payload: Dictionary) -> void: art_changed.emit(ArtChange.new(payload)))
		_plugin.connect(&"art_progress", func(payload: Dictionary) -> void: art_progress.emit(LabelDownload.new(payload)))
		_plugin.connect(&"label_variant_downloaded", func(payload: Dictionary) -> void:
			label_variant_downloaded.emit(LabelVariant.new(payload)))
		_plugin.connect(&"battery_changed", func(payload: Dictionary) -> void: battery_changed.emit(Battery.new(payload)))
	if OS.has_feature("android"):
		AndroidButtons.follow_android()
	load_snapshot(Diagnostics.argument("snapshot"))
	_load_catalog()


func is_available() -> bool:
	return not _on_desktop()


func _on_desktop() -> bool:
	return _plugin == null


# Getters

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
		[definitions, profiles, titles, data_folders, curtains, art, cartridge_prints, textures, supported],
		_desktop_demo("catalog"))
	catalog = CatalogSummary.new(summary)
	if Diagnostics.enabled:
		Diagnostics.trace("plugin", "catalog read in %.1f ms, loaded in %.1f ms" % [(read - started) / 1000.0,
			(Time.get_ticks_usec() - read) / 1000.0])


## Installed players of [param platform_id], in definition order. Without the plugin, those of the
## desktop demo's form story for its type.
func installed_players(platform_id: String) -> Array[Player]:
	var found: Array[Player] = []
	var story := _desktop_form()
	var fallback: Array = story.get("players", []) if story.get("type") == platform_id else []
	for item: Dictionary in _query(&"installedPlayers", [platform_id], fallback):
		found.append(Player.new(item))
	return found


## What the carousel shows of [param platform_id]'s shelf (see [Browse]): the games found for
## [param typed], or with nothing typed the index by `title` or `region` ([param order]). Without
## the plugin, nothing.
func browse(platform_id: String, order: StringName, typed: String) -> Browse:
	var view: Dictionary = JSON.parse_string(browse_text(platform_id, order, typed))
	return Browse.new(view)


## [method browse]'s answer as the plugin gives it. Without the plugin, a snapshot's shelf unfiltered.
func browse_text(platform_id: String, order: StringName, typed: String) -> String:
	var shelves: Dictionary = _snapshot.get("browse", {})
	var recorded: Dictionary = shelves.get(platform_id, {}) if typed.is_empty() else {}
	return _query(&"browse", [platform_id, String(order), typed], recorded.get(String(order), "{}"))


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


## The battery; without the plugin, the desktop demo's (a full one, charging, as the design draws it).
func battery() -> Battery:
	var state: Dictionary = _query(&"battery", [], _desktop_demo("battery"))
	return Battery.new(state)


## The manufacturer, model and Android version, such as "Acme Handheld 2, Android 13"; the OS name
## without the plugin.
func device_name() -> String:
	return _query(&"deviceName", [], OS.get_name())


## Debug builds: the arguments the app was started with (see `launchArguments` in the plugin).
func launch_arguments() -> PackedStringArray:
	if _plugin == null and Engine.has_singleton(_SINGLETON):
		return Engine.get_singleton(_SINGLETON).call(&"launchArguments")
	return _query(&"launchArguments", [], PackedStringArray())


# Operations

func request_all_files_access() -> Result:
	return Result.new(await _request(&"requestAllFilesAccess"))


## Opens the system screen letting Cartouche display over other apps, for the curtain.
func request_curtain_permission() -> Result:
	return Result.new(await _request(&"requestCurtainPermission"))


## Opens the system folder picker; answers once the user granted a folder or gave up.
func pick_folder() -> Pick:
	return Pick.new(await _request(&"pickFolder", [], _form_answer({"folder": _desktop_form().get("folder", {})})))


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
	return LibraryAnswer.new(await _request(&"library", [], desktop_library() if not _snapshot.is_empty() else {}))


## Stores the choices made for [param platform_id].
func set_up_platform(platform_id: String, setup: PlatformSetup) -> LibraryAnswer:
	var answer := LibraryAnswer.new(await _request(&"setUpPlatform", [platform_id, setup.to_wire()],
		_form_answer({"library": _desktop_form().get("library", "{}")})))
	if answer.ok and _on_desktop():
		var story: String = _desktop_form().get("library", "{}")
		_desktop_current = JSON.parse_string(story)
		if not setup.variant_id.is_empty():
			return await set_variant(platform_id, setup.variant_id)
	return answer


## Keeps the selected model of a set-up console; the desktop stores it beside its other user files.
func set_variant(platform_id: String, variant: String) -> LibraryAnswer:
	var fallback := {}
	if _on_desktop():
		var library_data := _desktop_current.duplicate(true)
		if library_data.is_empty():
			library_data = _desktop_demo("library")
		var kept := _desktop_variants()
		kept[platform_id] = variant
		if not _snapshot.is_empty():
			_snapshot["variants"] = kept
			_desktop_current["console_variants"] = kept
			return LibraryAnswer.new(desktop_library())
		var file := FileAccess.open(_DESKTOP_VARIANTS, FileAccess.WRITE)
		if file == null:
			fallback = {"ok": false, "code": "permission_denied"}
		else:
			file.store_string(JSON.stringify(kept))
			file.close()
			library_data["console_variants"] = kept
			_desktop_current = library_data
			fallback = {"ok": true, "library": JSON.stringify(library_data)}
	var answer := LibraryAnswer.new(await _request(&"setVariant", [platform_id, variant], fallback))
	if answer.ok:
		Diagnostics.trace("console", "variant=%s of %s" % [variant, platform_id])
	return answer



func _desktop_variants() -> Dictionary:
	if not _snapshot.is_empty():
		return _snapshot.get("variants", {})
	if not FileAccess.file_exists(_DESKTOP_VARIANTS):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DESKTOP_VARIANTS))
	return data if data is Dictionary else {}


## Looks for the art of [param games] (the game on screen and its neighbours) before the others'.
func art_focus(games: Array[AndroidServices.Game]) -> void:
	var ids := PackedStringArray()
	for game in games:
		ids.append(game.id)
	_query(&"artFocus", [ids], null)


## Prepares in the background what looking at a folder needs (the reference lists' indexes), as a
## console is about to be added or changed.
func prepare_titles() -> void:
	_query(&"prepareTitles", [], null)


## How many games a scan of [param platform_id] with [param setup] would find, without saving
## anything; its scan after [method set_up_platform] finds the same.
func preview_platform(platform_id: String, setup: PlatformSetup) -> PreviewAnswer:
	return PreviewAnswer.new(await _request(&"previewPlatform", [platform_id, setup.to_wire()],
		_form_answer({"report": _demo_report()})))


## The app's settings. The desktop demo keeps saved choices in memory until the process exits.
func settings() -> SettingsAnswer:
	if _on_desktop():
		return SettingsAnswer.new(_demo_settings)
	return SettingsAnswer.new(await _request(&"settings"))


## Stores the button style the user chose, [param style] as [SettingsAnswer] names it.
func save_button_style(style: StringName) -> Result:
	return await _save_setting(&"saveButtonStyle", "button_style", style)



## Stores the edge smoothing the user chose, [param smoothing] as [SettingsAnswer] names it.
func save_edge_smoothing(smoothing: StringName) -> Result:
	return await _save_setting(&"saveEdgeSmoothing", "edge_smoothing", smoothing)



## Stores whether the selected game sways and bobs ([param floating]); the consoles never do.
func save_games_float(floating: bool) -> Result:
	return await _save_setting(&"saveGamesFloat", "games_float", floating)


## Stores how loud the sounds play, [param steps] from 0 (silenced) to [constant SoundEffects.LEVELS].
func save_sound_level(steps: int) -> Result:
	return await _save_setting(&"saveSoundLevel", "sound_level", steps)



## Stores the region labels' images prefer, [param region] one of
## [member SettingsAnswer.preferred_regions] (empty for none); the labels it changes are looked for
## again, as [signal art_changed] tells.
func save_preferred_region(region: String) -> Result:
	return await _save_setting(&"savePreferredRegion", "preferred_region", region)



func _save_setting(request: StringName, key: String, value: Variant) -> Result:
	if _on_desktop():
		_demo_settings[key] = value
		return Result.new({"ok": true})
	return Result.new(await _request(request, [value]))


## Scans the folder of [param platform_id] and replaces its games.
func scan_platform(platform_id: String) -> ScanAnswer:
	return ScanAnswer.new(await _request(&"scanPlatform", [platform_id],
		_form_answer({"library": _desktop_form().get("library", "{}"), "report": _demo_report()})))


## Removes [param platform_id] from the library: its choices, games and art, and the access to its
## folder unless another platform uses it. The game files stay.
func remove_platform(platform_id: String) -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"removePlatform", [platform_id]))


## Remembers [param game] as the selected game of its platform, and that platform as the one shown.
func select_game(game: Game) -> Result:
	return Result.new(await _request(&"selectGame", [game.id]))


## Debug builds only: replaces the library with a made-up one of [param games] games, spread over
## the platforms or all on [param platform_id], stored apart from the user's, for measuring at
## scale. Without the plugin, the desktop demo's, whatever [param games].
func use_demo_library(games: int, platform_id := "") -> LibraryAnswer:
	if _on_desktop() and not _snapshot.is_empty():
		return LibraryAnswer.new(desktop_library())
	if _on_desktop():
		var demo := _desktop_current.duplicate(true) if not _desktop_current.is_empty() else _desktop_demo("library")
		demo["console_variants"] = _desktop_variants()
		_desktop_current = demo
		return LibraryAnswer.new({"ok": true, "library": JSON.stringify(demo)})
	return LibraryAnswer.new(await _request(&"useDemoLibrary", [games, platform_id]))


## Debug builds only: scans every console again, reading all of their game files anew, and looks
## every automatic label up again (never one the user chose: their own picture or a region's
## image); answers once every label was looked for, so not while offline or while a game is played.
## Without the plugin, the desktop demo's library, none of whose games has a label.
func rescrape() -> RescrapeAnswer:
	if _on_desktop():
		var demo := _desktop_demo("library")
		var games: Array = demo.get("games", [])
		return RescrapeAnswer.new({"ok": true, "library": JSON.stringify(demo), "games": games.size(), "labels": 0})
	return RescrapeAnswer.new(await _request(&"rescrape"))


## The images the art sources have for [param game]'s label, every one of both sources, each with
## its region and source, in the order they are tried; those not downloaded yet then arrive
## through [signal label_variant_downloaded]. Without the plugin, none.
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
## Without the plugin, the desktop's library takes that order until the app quits.
func order_consoles(platform_ids: PackedStringArray) -> Result:
	if _on_desktop() and not _desktop_current.is_empty():
		var found: Dictionary = _desktop_current["shelves"]
		var shelves: Array = found["shelves"]
		var selected: Variant = shelves[found["selected"]] if not shelves.is_empty() else null
		shelves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return platform_ids.find(str(a["platform"])) < platform_ids.find(str(b["platform"])))
		found["selected"] = maxi(shelves.find(selected), 0)
	return Result.new(await _request(&"orderConsoles", [platform_ids], {"ok": true}))


## Puts [param platform_id]'s console at [param gap] among the others as the consoles screen
## shows them, the others keeping their order: [param gap] counts from 0 to their number. The
## answer carries the order of all the consoles; a gap out of range or a console not in the library
## keeps the order (codes `gap_out_of_range`, `not_in_library`). Without the plugin, the order the
## desktop demo's form story holds for that gap.
func place_console(platform_id: String, gap: int) -> Placed:
	var orders: Dictionary = _desktop_form().get("placing", {})
	var order: Array = orders.get(str(gap), [])
	var story := {"order": PackedStringArray(order)} if orders.has(str(gap)) else {"ok": false, "code": "gap_out_of_range"}
	return Placed.new(await _request(&"placeConsole", [platform_id, gap], _form_answer(story)))


## Opens the system's picker on images, for a picture of the user's own to put on a label; the app
## keeps a copy of the one picked, to be framed. Cancelled when the user leaves the picker.
func pick_label_picture() -> LabelPicture:
	return LabelPicture.new(await _request(&"pickLabelPicture"))


## Shows the picture picked last on [param game]'s label from now on, as [param framing] frames it.
func keep_own_label(game: Game, framing: LabelFraming) -> ArtAnswer:
	return ArtAnswer.new(await _request(&"keepOwnLabel", [game.id, framing.zoom, framing.centre.x, framing.centre.y,
		framing.proportion]))


## Whether disc [param disc] of [param game] can launch (its emulator is installed, its file still
## there), with the failure [method launch_game] would give; starts and stops nothing. Without the
## plugin, or rehearsing (see [method launch_game]), every game can: the insertion plays.
func check_launch(game: Game, disc: int) -> Result:
	if _on_desktop() or _rehearsing():
		return Result.new({"ok": true})
	return Result.new(await _request(&"checkLaunch", [{"game_id": game.id, "disc": disc}]))


## Launches disc [param disc] (an index into [member Game.discs]) of [param game], hiding the
## emulator under a black curtain until its game shows when [method curtain_allowed]. Debug builds
## started with `--launch=rehearse` start nothing and fail with `rehearsed`: the insertion plays
## whether an emulator is installed or not, then the carousel shows again.
func launch_game(game: Game, disc: int) -> Result:
	if _rehearsing():
		return Result.new({"ok": false, "code": &"rehearsed"})
	return Result.new(await _request(&"launchGame", [{"game_id": game.id, "disc": disc}]))


# Plumbing

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


## The desktop demo's form story, in the plugin's wire shape (see `DesktopDemoTest.kt`):
## the installed players of its type, the folder picked, how many games
## it holds, the library once its console is added, and the console order for each gap of
## [method place_console]. Empty where the demo has none, which is how the generated demo is.
func _desktop_form() -> Dictionary:
	if not _on_desktop() or not FileAccess.file_exists(DESKTOP_DEMO):
		return {}
	if not _story_read:
		var demo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESKTOP_DEMO))
		_story = _story_of(demo)
		_story_read = true
	return _story


## The form story of [param demo], its lists of texts as the plugin sends them (PackedStringArrays,
## where JSON has Arrays).
static func _story_of(demo: Dictionary) -> Dictionary:
	var story: Dictionary = demo.get("form", {})
	for player: Dictionary in story.get("players", []):
		var extensions: Array = player.get("extensions", [])
		player["extensions"] = PackedStringArray(extensions)
	var folder: Dictionary = story.get("folder", {})
	if folder.has("place"):
		var place: Dictionary = folder["place"]
		var folders: Array = place.get("folders", [])
		place["folders"] = PackedStringArray(folders)
	return story


## The games the form story's folder holds, as a scan or a preview reports them.
func _demo_report() -> Dictionary:
	var games: int = _desktop_form().get("games", 0)
	return {"games": games, "files": games}


## [param story] as the answer of an operation without the plugin, when the desktop demo holds a
## form story; none, and the operation fails as unavailable, when it does not.
func _form_answer(story: Dictionary) -> Dictionary:
	if _desktop_form().is_empty():
		return {}
	var answer := {"ok": true}
	answer.merge(story, true)
	return answer


## Part [param key] of the desktop demo; none where it is not shipped (exports leave it out).
static func _desktop_demo(key: String) -> Dictionary:
	if not FileAccess.file_exists(DESKTOP_DEMO):
		return {}
	var demo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DESKTOP_DEMO))
	return demo.get(key, {})


## Whether a desktop snapshot of a device's data is loaded (see [method load_snapshot]).
func has_snapshot() -> bool:
	return not _snapshot.is_empty()


## Debug desktop data copied from a plugin snapshot, with pictures rooted in that copy.
func load_snapshot(folder: String) -> bool:
	if not OS.is_debug_build() or not _on_desktop() or folder.is_empty():
		return false
	var path := folder.path_join("snapshot.json")
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		return false
	var snapshot: Dictionary = parsed
	if snapshot.get("library") is not Dictionary or snapshot.get("settings") is not Dictionary \
			or snapshot.get("variants", {}) is not Dictionary:
		return false
	var answer: Dictionary = snapshot["library"]
	var content: Variant = JSON.parse_string(str(answer.get("library", "")))
	if content is not Dictionary:
		return false
	_snapshot = _map_snapshot(snapshot, folder)
	var mapped_answer: Dictionary = _snapshot["library"]
	var library_text: String = mapped_answer["library"]
	_desktop_current = JSON.parse_string(library_text)
	_desktop_current["console_variants"] = _snapshot.get("variants", {})
	var snapshot_settings: Dictionary = _snapshot["settings"]
	_demo_settings = snapshot_settings.duplicate(true)
	var locale: String = _snapshot.get("locale", "")
	if locale:
		TranslationServer.set_locale(locale)
	return true


## The library as the desktop shows it: the snapshot's answer with the library as it now stands, or the
## current desktop library, or the demo's.
func desktop_library() -> Dictionary:
	if _snapshot.is_empty():
		return {"ok": true, "library": JSON.stringify(_desktop_current if _desktop_current else _desktop_demo("library"))}
	var original: Dictionary = _snapshot["library"]
	var answer := original.duplicate(true)
	answer["library"] = JSON.stringify(_desktop_current)
	return answer


static func _map_snapshot(value: Variant, folder: String, field := "") -> Variant:
	if value is Dictionary:
		var mapped := {}
		for key: String in value:
			mapped[key] = _map_snapshot(value[key], folder, key)
		return mapped
	if value is Array:
		var mapped: Array = []
		for entry: Variant in value:
			mapped.append(_map_snapshot(entry, folder))
		return mapped
	if value is String:
		var text: String = value
		if field in ["library", "art"] and (text.begins_with("{") or text.begins_with("[")):
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary or parsed is Array:
				return JSON.stringify(_map_snapshot(parsed, folder))
		var marker := text.find("/files/art/")
		if field in ["path", "label_path"] and marker >= 0:
			var relative := text.substr(marker + 1)
			if relative.simplify_path() == relative and "\\" not in relative:
				return folder.path_join(relative)
	return value


## The texts listed under [param key] of [param item]; none when it is absent.
static func _strings(item: Dictionary, key: String) -> PackedStringArray:
	var texts: Array = item.get(key, [])
	return PackedStringArray(texts)


## Asks the plugin itself, even where a fake stands for its operations alone ([method is_available]).
func _query(method: StringName, args: Array, fallback: Variant) -> Variant:
	var value: Variant = _plugin.callv(method, args) if not _on_desktop() else fallback
	# The catalog's arguments are the whole data files, a shelf's view thousands of positions: not
	# worth formatting (the plugin traces the view's size).
	if Diagnostics.enabled and method not in [&"loadCatalog", &"browse"]:
		Diagnostics.trace("plugin", "%s%s = %s" % [method, args, value])
	return value


## Calls an operation (its first argument is the request id) and waits for its answer.
## Without the plugin the answer is [param without_plugin] when it has one, else a failure.
func _request(method: StringName, args: Array = [], without_plugin := {}) -> Dictionary:
	if _on_desktop():
		return without_plugin if without_plugin else {"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"}
	_last_request_id += 1
	var id := _last_request_id
	var started := Time.get_ticks_msec()
	if Diagnostics.enabled:
		Diagnostics.trace("plugin", "#%d %s%s" % [id, method, args])
	_plugin.callv(method, [id] + args)
	var payload: Dictionary = await _answered
	while payload.get("request_id") != id:
		payload = await _answered
	if Diagnostics.enabled:
		var elapsed := Time.get_ticks_msec() - started
		# The library is traced once read (LibraryAnswer): here it would cost as much as the games.
		var shown := payload.duplicate()
		shown.erase("library")
		Diagnostics.trace("plugin", "#%d answered in %d ms: %s" % [id, elapsed, shown])
	return payload


# Values

## An answer asked for now, with one of these operations, and taken later, once other work is done:
## the plugin answers meanwhile.
class Asked:
	signal arrived
	var value: Variant
	var has_arrived := false

	## Asks with [param asking].
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


class Result:
	var ok: bool
	## Stable error code (`not_installed`, `permission_denied`…); empty when [member ok].
	var code: StringName
	## English detail, for logs.
	var detail: String

	func _init(payload: Dictionary) -> void:
		ok = payload.get("ok", false)
		code = payload.get("code", &"")
		detail = payload.get("detail", "")


## A folder or file reached through the system's document providers.
class Document:
	var uri: String
	var name: String
	## Whether the document has a filesystem [member path] (some emulators need one).
	var has_path: bool
	var path: String

	func _init(item: Dictionary) -> void:
		uri = item["uri"]
		name = item["name"]
		has_path = item.has("path")
		path = item.get("path", "")


## A folder granted through the system picker.
class Folder extends Document:
	## Whether the folder is on the device's storage, where [member volume] and [member folders]
	## say where, as the user reads it.
	var has_place: bool
	## `internal` or `card`.
	var volume: StringName
	## The folders from the volume down to this one; none for the volume itself.
	var folders: PackedStringArray

	func _init(item: Dictionary) -> void:
		super(item)
		has_place = item.has("place")
		var place: Dictionary = item.get("place", {})
		volume = place.get("volume", &"")
		folders = place.get("folders", PackedStringArray())


## A folder listing entry.
class Entry extends Document:
	var is_directory: bool
	var document_id: String

	func _init(item: Dictionary) -> void:
		super(item)
		is_directory = item["is_directory"]
		document_id = item["document_id"]


## A player able to open a given file, with its platform's name.
class Candidate extends Player:
	var platform_name: String

	func _init(item: Dictionary) -> void:
		super(item)
		platform_name = item["platform_name"]


class App:
	var package_name: String
	var label: String

	func _init(item: Dictionary) -> void:
		package_name = item["package"]
		label = item["label"]


class Battery:
	var has_level: bool
	var level_percent: int
	## Whether the device is plugged into a charger, charging or full.
	var plugged: bool

	func _init(payload: Dictionary) -> void:
		has_level = payload.has("level_percent")
		level_percent = payload.get("level_percent", 0)
		plugged = payload.get("plugged", false)


class Platform:
	var id: String
	var name: String
	## `dvd`, `cartridge` or `minidisc`.
	var media: String

	func _init(item: Dictionary) -> void:
		id = item["id"]
		name = item["name"]
		media = item["media"]


class Player:
	var id: String
	var name: String
	## The name without the platform the definitions put first, as the user knows the emulator.
	var emulator_name: String
	## The file extensions the player opens, when its definition says them plainly; empty otherwise.
	var extensions: PackedStringArray

	func _init(item: Dictionary) -> void:
		id = item["player_id"]
		name = item["player_name"]
		emulator_name = item.get("emulator_name", name)
		extensions = item.get("extensions", PackedStringArray())


class CatalogSummary:
	var platforms: Array[Platform] = []
	## The platforms a person may add, those with a console model, in the order of the Type chooser;
	## none from a catalog that did not name them (the desktop demo as generated).
	var offered: Array[OfferedConsole] = []
	## One line per rejected definition: `source: detail`.
	var rejected := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		for item: Dictionary in payload.get("platforms", []):
			platforms.append(Platform.new(item))
		for item: Dictionary in payload.get("offered", []):
			offered.append(OfferedConsole.new(item))
		for rejection: Dictionary in payload.get("rejected", []):
			rejected.append("%s: %s" % [rejection["source"], rejection["detail"]])


## A platform of the Type chooser: its maker, shown small above its model (empty when the name has no
## maker in it), and its model name.
class OfferedConsole:
	var id: String
	var maker: String
	var model: String

	func _init(item: Dictionary) -> void:
		id = item["id"]
		maker = item.get("maker", "")
		model = item["model"]


class Placed extends Result:
	## The platform ids of all the consoles after placing, first to last; empty when not [member ok].
	var order := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			order = payload.get("order", PackedStringArray())


class Pick extends Result:
	var folder: Folder

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["folder"]
			folder = Folder.new(item)


class FolderList extends Result:
	var folders: Array[Folder] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("folders", []):
			folders.append(Folder.new(item))


class Listing extends Result:
	var entries: Array[Entry] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("entries", []):
			entries.append(Entry.new(item))


class AppList extends Result:
	var apps: Array[App] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("apps", []):
			apps.append(App.new(item))


## The choices made for one platform.
class PlatformSetup:
	var has_folder: bool
	var folder_uri: String
	## Without a player, the first installed one is used.
	var has_player: bool
	var player_id: String
	## `grouped` (`Game (Disc 1)` and `(Disc 2)` make one game) or `separate`.
	var disc_grouping: String
	## `top_level` or `subfolders`.
	var folder_depth: String
	var variant_id: String

	func _init(item: Dictionary = {}) -> void:
		has_folder = item.has("folder_uri")
		folder_uri = item.get("folder_uri", "")
		has_player = item.has("player_id")
		player_id = item.get("player_id", "")
		disc_grouping = item.get("disc_grouping", "grouped")
		folder_depth = item.get("folder_depth", "top_level")
		variant_id = item.get("variant", "")

	func to_wire() -> Dictionary:
		var item := {"disc_grouping": disc_grouping, "folder_depth": folder_depth}
		if not variant_id.is_empty():
			item["variant"] = variant_id
		if has_folder:
			item["folder_uri"] = folder_uri
		if has_player:
			item["player_id"] = player_id
		return item


class Disc:
	## Whether the file names a disc number (`Disc 2`); single-disc games have none.
	var has_number: bool
	var number: int
	var name: String

	func _init(item: Dictionary) -> void:
		has_number = item.has("number")
		number = item.get("number", 0)
		name = item["name"]


class Game:
	var id: String
	var platform_id: String
	var title: String
	var regions := PackedStringArray()
	## The medium its platform gives a game of its regions (`sfc_cart`); empty when the platform is
	## unknown.
	var medium: String
	var languages := PackedStringArray()
	var serials := PackedStringArray()
	var has_version: bool
	var version: String
	## Whether the reference list knows the game: as the exact disc [member redump_name], or by
	## the [member serials] of its release.
	var identified: bool
	var has_redump_name: bool
	var redump_name: String
	var discs: Array[Disc] = []
	## Index into [member discs] of the disc launched last.
	var last_disc: int
	## Whether the user chose the image its label shows, by [member label_region] and
	## [member label_source].
	var has_label_region: bool
	var label_region: String
	## The source of the chosen image, as the plugin names sources (`launchbox`, `screenscraper`).
	var label_source: String
	## Whether its label shows a picture of the user's own.
	var label_own: bool
	## The title it had before the user renamed it, [member title] being the name they gave it.
	var has_original_title: bool
	var original_title: String

	## The title it has of its own, whatever name the user gave it.
	func own_title() -> String:
		return original_title if has_original_title else title

	func _init(item: Dictionary) -> void:
		id = item["id"]
		platform_id = item["platform_id"]
		title = item["title"]
		regions = AndroidServices._strings(item, "regions")
		medium = item.get("medium", "")
		languages = AndroidServices._strings(item, "languages")
		serials = AndroidServices._strings(item, "serials")
		has_version = item.has("version")
		version = item.get("version", "")
		identified = item["identified"]
		has_redump_name = item.has("redump_name")
		redump_name = item.get("redump_name", "")
		for disc: Dictionary in item["discs"]:
			discs.append(Disc.new(disc))
		last_disc = item["last_disc"]
		has_label_region = item.has("label_region")
		label_region = item.get("label_region", "")
		label_source = item.get("label_source", "")
		label_own = item.get("label_own", false)
		has_original_title = item.has("original_title")
		original_title = item.get("original_title", "")


## A sub-folder a scan did not look into.
class SkippedFolder:
	## Relative to the scanned folder, such as `Saves/memcards`.
	var path: String
	## `hidden`, `emulator_data`, `too_deep` or `unreadable`.
	var reason: String

	func _init(item: Dictionary) -> void:
		path = item["path"]
		reason = item["reason"]


## How many hidden or unsupported files a scan set aside, with the first of their names.
class IgnoredCount:
	## `hidden` or `unsupported`.
	var reason: String
	var count: int
	var examples := PackedStringArray()

	func _init(reason_name: String, item: Dictionary) -> void:
		reason = reason_name
		count = item["count"]
		examples = AndroidServices._strings(item, "examples")


## The games of one platform, in the order the carousel shows them.
class Shelf:
	var platform_id: String
	var games: Array[Game] = []
	## Index into [member games] of the game to show first.
	var selected: int

	func _init(item: Dictionary, all_games: Array[Game]) -> void:
		platform_id = item["platform"]
		for index: int in item["games"]:
			games.append(all_games[index])
		selected = item["selected"]


## What the carousel shows of a shelf, sent as JSON (see `View.toWireJson` in `Wire.kt`).
class Browse:
	## How many games the shelf has, as the plugin knows it: a view of another library is not
	## for the shelf shown.
	var count: int
	## Positions in the shelf of the games shown, in their order.
	var games := PackedInt32Array()
	## The index's groups of [member games] (none while searching).
	var groups: Array[Group] = []
	## Each key of the ribbon that leads to a game (a lowercase letter, a digit, a space), and the
	## index into [member games] it brings the carousel to.
	var keys: Dictionary[String, int] = {}

	func _init(item: Dictionary) -> void:
		count = item.get("count", 0)
		var positions: Array = item.get("games", [])
		games = PackedInt32Array(positions)
		for group: Dictionary in item.get("groups", []):
			groups.append(Group.new(group))
		var found: Dictionary = item.get("keys", {})
		for key: String in found:
			# JSON numbers are read as floats.
			var at: int = found[key]
			keys[key] = at


## The games of a view from [member start] on that share a [member label]: a letter, `#`, a region.
class Group:
	var label: String
	var start: int

	func _init(item: Dictionary) -> void:
		label = item["label"]
		start = item["start"]


## The library, sent as JSON (see `toWireJson` in `Wire.kt`).
class Library:
	var games: Array[Game] = []
	## One per platform that has games, in catalog order; none when the library has no games.
	var shelves: Array[Shelf] = []
	## Index into [member shelves] of the shelf to show first.
	var selected_shelf: int
	var _setups: Dictionary[String, PlatformSetup] = {}
	var _not_games: Dictionary[String, Array] = {}
	var _ignored_counts: Dictionary[String, Dictionary] = {}
	var _skipped: Dictionary[String, Array] = {}
	var console_variants: Dictionary[String, String] = {}

	func _init(item: Dictionary) -> void:
		var variants: Dictionary = item.get("console_variants", {})
		console_variants.assign(variants)
		var setups: Dictionary = item.get("setups", {})
		for platform_id: String in setups:
			var setup: Dictionary = setups[platform_id]
			_setups[platform_id] = PlatformSetup.new(setup)
			_setups[platform_id].variant_id = console_variants.get(platform_id, "")
		for game: Dictionary in item.get("games", []):
			games.append(Game.new(game))
		var not_games: Dictionary = item.get("not_games", {})
		_not_games.assign(not_games)
		var skipped: Dictionary = item.get("skipped_folders", {})
		_skipped.assign(skipped)
		var counts: Dictionary = item.get("ignored_counts", {})
		_ignored_counts.assign(counts)
		var found: Dictionary = item.get("shelves", {"shelves": [], "selected": 0})
		for shelf: Dictionary in found["shelves"]:
			shelves.append(Shelf.new(shelf, games))
		selected_shelf = found["selected"]

	func setup_of(platform_id: String) -> PlatformSetup:
		return _setups.get(platform_id, PlatformSetup.new())

	## The platforms set up, games or not.
	func set_up_platforms() -> PackedStringArray:
		return PackedStringArray(_setups.keys())

	func games_of(platform_id: String) -> Array[Game]:
		return games.filter(func(game: Game) -> bool: return game.platform_id == platform_id)

	## Files a player opens that were not taken for games (a BIOS, too small).
	func not_games_of(platform_id: String) -> PackedStringArray:
		return AndroidServices._strings(_not_games, platform_id)

	func ignored_counts_of(platform_id: String) -> Array[IgnoredCount]:
		var counts: Array[IgnoredCount] = []
		var by_reason: Dictionary = _ignored_counts.get(platform_id, {})
		for reason: String in by_reason:
			var count: Dictionary = by_reason[reason]
			counts.append(IgnoredCount.new(reason, count))
		return counts

	func skipped_folders_of(platform_id: String) -> Array[SkippedFolder]:
		var folders: Array[SkippedFolder] = []
		for item: Dictionary in _skipped.get(platform_id, []):
			folders.append(SkippedFolder.new(item))
		return folders


class LibraryAnswer extends Result:
	var library: Library
	## The art stored for its games, and the ids of those no source had an image of when last
	## looked for (sent by [method AndroidServices.library] only).
	var art: Array[Art] = []
	var absent: PackedStringArray
	## Why the stored library could not be read, when it could not: it then started empty.
	var has_load_problem: bool
	var load_problem: String

	func _init(payload: Dictionary) -> void:
		super(payload)
		var text: String = payload.get("library", "{}")
		var started := Time.get_ticks_usec()
		var item: Dictionary = JSON.parse_string(text)
		library = Library.new(item)
		if Diagnostics.enabled:
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			Diagnostics.trace("library", "%d games read from %d characters in %.1f ms" % [
				library.games.size(), text.length(), elapsed])
		has_load_problem = payload.has("load_problem")
		load_problem = payload.get("load_problem", "")
		var art_text: String = payload.get("art", "[]")
		var stored: Array = JSON.parse_string(art_text)
		for found: Dictionary in stored:
			art.append(Art.new(found))
		absent = payload.get("absent", PackedStringArray())


class ScanReport:
	var files: int
	var games: int
	var identified: int
	var ignored: int
	var skipped_folders: int
	var milliseconds: int

	func _init(item: Dictionary) -> void:
		files = item.get("files", 0)
		games = item.get("games", 0)
		identified = item.get("identified", 0)
		ignored = item.get("ignored", 0)
		skipped_folders = item.get("skipped_folders", 0)
		milliseconds = item.get("milliseconds", 0)


class PreviewAnswer extends Result:
	var report: ScanReport

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("report", {})
		report = ScanReport.new(item)


class SettingsAnswer extends Result:
	## Whether the first launch is still to do: no button style chosen and no platform.
	var first_launch: bool
	var has_button_style: bool
	## `xbox`, `nintendo` or `playstation`: how the buttons are drawn.
	var button_style: StringName
	## `4x`, `2x` or `off`: how smooth the 3D's edges are drawn.
	var edge_smoothing: StringName
	## Whether the selected game sways and bobs; the consoles never do.
	var games_float: bool
	## How loud the sounds play, from 0 (silenced) to [constant SoundEffects.LEVELS].
	var sound_level: int
	## The region labels' images prefer, one of [member preferred_regions]; empty for none.
	var preferred_region: String
	## The regions labels' images can prefer, as the plugin names them, the only ones it saves.
	var preferred_regions: PackedStringArray

	func _init(payload: Dictionary) -> void:
		super(payload)
		first_launch = payload.get("first_launch", false)
		has_button_style = payload.has("button_style")
		button_style = payload.get("button_style", &"")
		edge_smoothing = payload.get("edge_smoothing", &"4x")
		games_float = payload.get("games_float", false)
		sound_level = payload.get("sound_level", SoundEffects.LEVELS)
		preferred_region = payload.get("preferred_region", "")
		preferred_regions = payload.get("preferred_regions", PackedStringArray())


class ScanAnswer extends LibraryAnswer:
	var report: ScanReport

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("report", {})
		report = ScanReport.new(item)


class RescrapeAnswer extends LibraryAnswer:
	## How many games the library holds.
	var games: int
	## How many of the labels looked for were found.
	var labels: int
	## Why each console that could not be scanned was not.
	var failures: PackedStringArray

	func _init(payload: Dictionary) -> void:
		super(payload)
		games = payload.get("games", 0)
		labels = payload.get("labels", 0)
		failures = payload.get("failures", PackedStringArray())


## A game's disc scan, as the plugin stored it.
class Art:
	var game_id: String
	## An absolute path to a JPEG.
	var path: String

	func _init(item: Dictionary) -> void:
		game_id = item["game_id"]
		path = item["path"]


## How looking for the games' art goes.
class ArtProgress:
	## Games of this run done, and looked for in it, done or not.
	var done: int
	var total: int
	## Why it waits: `offline`, `refused` (a server busy or failing) or `storage`; empty when it
	## does not.
	var stall: StringName

	func _init(item: Dictionary) -> void:
		done = item.get("done", 0)
		total = item.get("total", 0)
		stall = item.get("stall", &"")


class ArtChange:
	var progress: ArtProgress
	var has_found: bool
	var found: Art
	## The ids of games no source has an image of, just looked for.
	var absent: PackedStringArray

	func _init(payload: Dictionary) -> void:
		progress = ArtProgress.new(payload)
		has_found = payload.has("found")
		if has_found:
			var item: Dictionary = payload["found"]
			found = Art.new(item)
		absent = payload.get("absent", PackedStringArray())


## How far the download of a game's label has come, as `art_progress` tells it.
class LabelDownload:
	var game_id: String
	## Whether it goes on; once over, found or not, it does not.
	var running: bool
	## How much of the image is read, from 0 to 1; -1 when its size is unknown.
	var fraction: float

	func _init(item: Dictionary) -> void:
		game_id = item["game_id"]
		running = item.has("fraction")
		fraction = item.get("fraction", -1.0)


## One image a game's label can show: [member source]'s for [member region] (as the sources name
## it, empty when they name none), at [member path] once downloaded.
class LabelVariant:
	## Set when it arrives through [signal AndroidServices.label_variant_downloaded].
	var game_id: String
	var region: String
	## The source, as the plugin names it for [method AndroidServices.choose_label], and as shown.
	var source: String
	var source_name: String
	var has_path: bool
	var path: String
	## Why it could not be downloaded: `offline`, `refused`, `not_found`, `unreadable` or `storage`;
	## empty when it was, or is still to be.
	var failure: StringName

	func _init(item: Dictionary) -> void:
		game_id = item.get("game_id", "")
		region = item["region"]
		source = item["source"]
		source_name = item["source_name"]
		has_path = item.has("path")
		path = item.get("path", "")
		failure = item.get("failure", &"")


class LabelVariants extends Result:
	var variants: Array[LabelVariant] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("variants", []):
			variants.append(LabelVariant.new(item))


## What a game is called once renamed: [member title], and its own title when the user gave it a name.
class Renamed extends Result:
	var title: String
	var has_original_title: bool
	var original_title: String

	func _init(payload: Dictionary) -> void:
		super(payload)
		title = payload.get("title", "")
		has_original_title = payload.has("original_title")
		original_title = payload.get("original_title", "")


## The name a console was given, when it was given one ([member has_name]).
## A picture of the user's own being framed: the app's copy at [member path], [member size] pixels.
class LabelPicture extends Result:
	var path: String
	var size: Vector2i

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["picture"]
			path = item["path"]
			var width: int = item["width"]
			var height: int = item["height"]
			size = Vector2i(width, height)


class ArtAnswer extends Result:
	var art: Art

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["art"]
			art = Art.new(item)
