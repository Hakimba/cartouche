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

var _plugin: Object
var _last_request_id := 0


func _ready() -> void:
	if Engine.has_singleton(_SINGLETON):
		_plugin = Engine.get_singleton(_SINGLETON)
		_plugin.connect(&"answered", _answered.emit)


func is_available() -> bool:
	return _plugin != null


# Getters

## Loads the bundled platform definitions into the plugin. Call once at startup.
func load_catalog() -> CatalogSummary:
	var sources := {}
	for file_name: String in DirAccess.get_files_at(_PLATFORM_DEFINITIONS):
		if file_name.ends_with(".json"):
			var path := _PLATFORM_DEFINITIONS.path_join(file_name)
			sources[file_name] = FileAccess.get_file_as_string(path)
	var summary: Dictionary = _query(&"loadCatalog", [sources], {})
	return CatalogSummary.new(summary)


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


func launch_game(player_id: String, file: Entry) -> Result:
	var game := {"name": file.name, "uri": file.uri}
	if file.has_path:
		game["path"] = file.path
	return Result.new(await _request(&"launchGame", [player_id, game]))


# Plumbing

func _query(method: StringName, args: Array, fallback: Variant) -> Variant:
	var value: Variant = _plugin.callv(method, args) if is_available() else fallback
	Diagnostics.trace("plugin", "%s%s = %s" % [method, args, value])
	return value


## Calls an operation (its first argument is the request id) and waits for its answer.
func _request(method: StringName, args: Array = []) -> Dictionary:
	if not is_available():
		return {"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"}
	_last_request_id += 1
	var id := _last_request_id
	var started := Time.get_ticks_msec()
	Diagnostics.trace("plugin", "#%d %s%s" % [id, method, args])
	_plugin.callv(method, [id] + args)
	var payload: Dictionary = await _answered
	while payload.get("request_id") != id:
		payload = await _answered
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


class Candidate:
	var platform_name: String
	var player_id: String
	var player_name: String

	func _init(item: Dictionary) -> void:
		platform_name = item["platform_name"]
		player_id = item["player_id"]
		player_name = item["player_name"]


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


class CatalogSummary:
	var platform_names := PackedStringArray()
	## One line per rejected definition: `source: detail`.
	var rejected := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		var names: Array = payload.get("platforms", [])
		platform_names = PackedStringArray(names)
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
