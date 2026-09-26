# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidServices
extends Node
## Typed access to Cartouche's Kotlin plugin (`kotlin/android`), registered as the `Android`
## autoload. This is the only file that talks to the plugin: everything else gets the typed values
## below. The wire format is described in `Wire.kt`; a missing value is an absent key, surfaced
## here as a `has_*` flag.
##
## Getters answer at once. Operations are coroutines (`await Android.list_folder(folder)`); without
## the plugin (editor, desktop) they fail with `code == &"unavailable"` and getters return empty
## values.

## Every operation's answer; callers await the one carrying their request id.
signal _answered(payload: Dictionary)

const _SINGLETON := &"CartoucheAndroid"
const _PLATFORM_DEFINITIONS := "res://data/platforms/daijishou"
const _PLATFORM_PROFILES := "res://data/platforms/profiles.json"
## One reference list per platform, named after its id (`ps2.tsv`).
const _TITLE_LISTS := "res://data/redump"

## The catalog loaded by [method load_catalog].
var catalog := CatalogSummary.new({})

var _plugin: Object
var _last_request_id := 0


func _ready() -> void:
	if Engine.has_singleton(_SINGLETON):
		_plugin = Engine.get_singleton(_SINGLETON)
		_plugin.connect(&"answered", _answered.emit)


func is_available() -> bool:
	return _plugin != null


# Getters

## Loads the bundled platform definitions, profiles and reference lists into the plugin. Call
## once at startup.
func load_catalog() -> CatalogSummary:
	var profiles := FileAccess.get_file_as_string(_PLATFORM_PROFILES)
	var definitions := _files_in(_PLATFORM_DEFINITIONS, ".json")
	var titles := _files_in(_TITLE_LISTS, ".tsv", true)
	var summary: Dictionary = _query(&"loadCatalog", [definitions, profiles, titles], {})
	catalog = CatalogSummary.new(summary)
	return catalog


## Installed players of [param platform_id], in definition order.
func installed_players(platform_id: String) -> Array[Player]:
	var found: Array[Player] = []
	for item: Dictionary in _query(&"installedPlayers", [platform_id], []):
		found.append(Player.new(item))
	return found


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


func battery() -> Battery:
	var state: Dictionary = _query(&"battery", [], {})
	return Battery.new(state)


## Such as "Acme Handheld 2, Android 13"; the OS name without the plugin.
func device_name() -> String:
	return _query(&"deviceName", [], OS.get_name())


# Operations

func request_all_files_access() -> Result:
	return Result.new(await _request(&"requestAllFilesAccess"))


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


## The library, read from its file on first use.
func library() -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"library"))


## Stores the choices made for [param platform_id].
func set_up_platform(platform_id: String, setup: PlatformSetup) -> LibraryAnswer:
	return LibraryAnswer.new(await _request(&"setUpPlatform", [platform_id, setup.to_wire()]))


## Scans the folder of [param platform_id] and replaces its games.
func scan_platform(platform_id: String) -> ScanAnswer:
	return ScanAnswer.new(await _request(&"scanPlatform", [platform_id]))


## Launches disc [param disc] (an index into [member Game.discs]) of [param game].
func launch_game(game: Game, disc: int) -> Result:
	return Result.new(await _request(&"launchGame", [{"game_id": game.id, "disc": disc}]))


# Plumbing

## `{file name or base name: text}` for the files of [param folder] ending with [param extension].
static func _files_in(folder: String, extension: String, by_base_name := false) -> Dictionary:
	var texts := {}
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(extension):
			var key := file_name.get_basename() if by_base_name else file_name
			texts[key] = FileAccess.get_file_as_string(folder.path_join(file_name))
	return texts


func _query(method: StringName, args: Array, fallback: Variant) -> Variant:
	var value: Variant = _plugin.callv(method, args) if is_available() else fallback
	# The catalog's arguments are the whole data files: not worth formatting.
	if Diagnostics.enabled and method != &"loadCatalog":
		Diagnostics.trace("plugin", "%s%s = %s" % [method, args, value])
	return value


## Calls an operation (its first argument is the request id) and waits for its answer.
func _request(method: StringName, args: Array = []) -> Dictionary:
	if not is_available():
		return {"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"}
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
		Diagnostics.trace("plugin", "#%d answered in %d ms: %s" % [id, elapsed, payload])
	return payload


# Values

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
	pass


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
	var charging: bool

	func _init(payload: Dictionary) -> void:
		has_level = payload.has("level_percent")
		level_percent = payload.get("level_percent", 0)
		charging = payload.get("charging", false)


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

	func _init(item: Dictionary) -> void:
		id = item["player_id"]
		name = item["player_name"]


class CatalogSummary:
	var platforms: Array[Platform] = []
	## One line per rejected definition: `source: detail`.
	var rejected := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		for item: Dictionary in payload.get("platforms", []):
			platforms.append(Platform.new(item))
		for rejection: Dictionary in payload.get("rejected", []):
			rejected.append("%s: %s" % [rejection["source"], rejection["detail"]])


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

	func _init(item: Dictionary = {}) -> void:
		has_folder = item.has("folder_uri")
		folder_uri = item.get("folder_uri", "")
		has_player = item.has("player_id")
		player_id = item.get("player_id", "")
		disc_grouping = item.get("disc_grouping", "grouped")
		folder_depth = item.get("folder_depth", "top_level")

	func to_wire() -> Dictionary:
		var item := {"disc_grouping": disc_grouping, "folder_depth": folder_depth}
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

	func _init(item: Dictionary) -> void:
		id = item["id"]
		platform_id = item["platform_id"]
		title = item["title"]
		var texts: Array = item["regions"]
		regions = PackedStringArray(texts)
		texts = item["languages"]
		languages = PackedStringArray(texts)
		texts = item["serials"]
		serials = PackedStringArray(texts)
		has_version = item.has("version")
		version = item.get("version", "")
		identified = item["identified"]
		has_redump_name = item.has("redump_name")
		redump_name = item.get("redump_name", "")
		for disc: Dictionary in item["discs"]:
			discs.append(Disc.new(disc))
		last_disc = item["last_disc"]


class IgnoredFile:
	var name: String
	## `hidden`, `unsupported` or `not_a_game`.
	var reason: String

	func _init(item: Dictionary) -> void:
		name = item["name"]
		reason = item["reason"]


class Library:
	var games: Array[Game] = []
	var _setups: Dictionary[String, PlatformSetup] = {}
	var _ignored: Dictionary[String, Array] = {}

	func _init(item: Dictionary) -> void:
		var setups: Dictionary = item.get("setups", {})
		for platform_id: String in setups:
			var setup: Dictionary = setups[platform_id]
			_setups[platform_id] = PlatformSetup.new(setup)
		for game: Dictionary in item.get("games", []):
			games.append(Game.new(game))
		var ignored: Dictionary = item.get("ignored", {})
		_ignored.assign(ignored)

	func setup_of(platform_id: String) -> PlatformSetup:
		return _setups.get(platform_id, PlatformSetup.new())

	func games_of(platform_id: String) -> Array[Game]:
		return games.filter(func(game: Game) -> bool: return game.platform_id == platform_id)

	func ignored_of(platform_id: String) -> Array[IgnoredFile]:
		var files: Array[IgnoredFile] = []
		for item: Dictionary in _ignored.get(platform_id, []):
			files.append(IgnoredFile.new(item))
		return files


class LibraryAnswer extends Result:
	var library: Library
	## Why the stored library could not be read, when it could not: it then started empty.
	var has_load_problem: bool
	var load_problem: String

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("library", {})
		library = Library.new(item)
		has_load_problem = payload.has("load_problem")
		load_problem = payload.get("load_problem", "")


class ScanReport:
	var files: int
	var games: int
	var identified: int
	var ignored: int
	var milliseconds: int

	func _init(item: Dictionary) -> void:
		files = item.get("files", 0)
		games = item.get("games", 0)
		identified = item.get("identified", 0)
		ignored = item.get("ignored", 0)
		milliseconds = item.get("milliseconds", 0)


class ScanAnswer extends LibraryAnswer:
	var report: ScanReport

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("report", {})
		report = ScanReport.new(item)
