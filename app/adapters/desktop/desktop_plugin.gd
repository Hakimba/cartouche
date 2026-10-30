# SPDX-License-Identifier: GPL-3.0-or-later
class_name DesktopPlugin
extends RefCounted
## Stands for the Kotlin plugin where there is none (editor, desktop): [AndroidServices] calls it as it calls the
## plugin, with the plugin's method names and wire shapes. It answers from the desktop demo ([constant DEMO]), a
## snapshot of a device's data (`--snapshot=DIR`, debug builds) and the choices made since the app started; an
## operation answers at once, as a Dictionary. A call it has no method for gets nothing: an empty value, or an
## operation failing as `unavailable`.

## The catalog, a demo library and the add form's story as the plugin sends them: see `DesktopDemoTest.kt`, which
## keeps it up to date.
const DEMO := "res://dev/demo/desktop.json"
const _VARIANTS := "user://console-variants.json"

var _snapshot := {}
var _settings := {"ok": true, "first_launch": false, "games_float": false, "sound_level": 10}
## The library as the choices made since the app started left it; empty until one is made.
var _current := {}
var _story := {}
var _story_read := false


## Part [param key] of the desktop demo, or none without the file. Exports ship it: on a device, the debug bridge's
## route preview reads it.
static func demo(key: String) -> Dictionary:
	if not FileAccess.file_exists(DEMO):
		return {}
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO))
	return parsed.get(key, {})


## The form story of [param parsed], its lists of texts as the plugin sends them (PackedStringArrays, where JSON
## has Arrays).
static func story_of(parsed: Dictionary) -> Dictionary:
	var story: Dictionary = parsed.get("form", {})
	for player: Dictionary in story.get("players", []):
		var extensions: Array = player.get("extensions", [])
		player["extensions"] = PackedStringArray(extensions)
	var folder: Dictionary = story.get("folder", {})
	if folder.has("place"):
		var place: Dictionary = folder["place"]
		var folders: Array = place.get("folders", [])
		place["folders"] = PackedStringArray(folders)
	return story


## Whether a snapshot of a device's data is loaded.
func has_snapshot() -> bool:
	return not _snapshot.is_empty()


## Debug builds: the desktop data copied from a plugin snapshot in [param folder], if any, with pictures rooted
## in that copy, and the snapshot's locale.
func load_snapshot(folder: String) -> void:
	if not OS.is_debug_build() or folder.is_empty():
		return
	var path := folder.path_join("snapshot.json")
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		return
	var snapshot: Dictionary = parsed
	if snapshot.get("library") is not Dictionary or snapshot.get("settings") is not Dictionary \
			or snapshot.get("variants", {}) is not Dictionary:
		return
	var answer: Dictionary = snapshot["library"]
	if JSON.parse_string(str(answer.get("library", ""))) is not Dictionary:
		return
	_snapshot = _map_snapshot(snapshot, folder)
	var mapped_answer: Dictionary = _snapshot["library"]
	var library_text: String = mapped_answer["library"]
	_current = JSON.parse_string(library_text)
	_current["console_variants"] = _snapshot.get("variants", {})
	var snapshot_settings: Dictionary = _snapshot["settings"]
	_settings = snapshot_settings.duplicate(true)
	var locale: String = _snapshot.get("locale", "")
	if locale:
		TranslationServer.set_locale(locale)


func loadCatalog(..._data: Array) -> Dictionary:
	return demo("catalog")


## Those of the form story, for its type.
func installedPlayers(platform_id: String) -> Array:
	var story := form()
	return story.get("players", []) if story.get("type") == platform_id else []


## A snapshot's shelf, unfiltered.
func browse(platform_id: String, order: String, typed: String) -> String:
	var shelves: Dictionary = _snapshot.get("browse", {})
	var recorded: Dictionary = shelves.get(platform_id, {}) if typed.is_empty() else {}
	return recorded.get(order, "{}")


## A full one, charging.
func battery() -> Dictionary:
	return demo("battery")


func deviceName() -> String:
	return OS.get_name()


func pickFolder(_id: int) -> Dictionary:
	return _form_answer({"folder": form().get("folder", {})})


## The snapshot's answer with the library as it now stands, or the library as it now stands, or the demo's.
func library(_id: int) -> Dictionary:
	if _snapshot.is_empty():
		return {"ok": true, "library": JSON.stringify(_current if _current else demo("library"))}
	var original: Dictionary = _snapshot["library"]
	var answer := original.duplicate(true)
	answer["library"] = JSON.stringify(_current)
	return answer


func setUpPlatform(id: int, platform_id: String, setup: Dictionary) -> Dictionary:
	var answer := _form_answer({"library": form().get("library", "{}")})
	if not answer.get("ok", false):
		return answer
	var story: String = form().get("library", "{}")
	_current = JSON.parse_string(story)
	var variant: String = setup.get("variant", "")
	return setVariant(id, platform_id, variant) if variant else answer


## Keeps the model beside the user's other files (in the snapshot when one is loaded).
func setVariant(id: int, platform_id: String, variant: String) -> Dictionary:
	var kept := _variants()
	kept[platform_id] = variant
	if not _snapshot.is_empty():
		_snapshot["variants"] = kept
		_current["console_variants"] = kept
		return library(id)
	var library_data := _current.duplicate(true) if not _current.is_empty() else demo("library")
	var file := FileAccess.open(_VARIANTS, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "permission_denied"}
	file.store_string(JSON.stringify(kept))
	library_data["console_variants"] = kept
	_current = library_data
	return {"ok": true, "library": JSON.stringify(library_data)}


func previewPlatform(_id: int, _platform_id: String, _setup: Dictionary) -> Dictionary:
	return _form_answer({"report": _report()})


## Kept in memory until the app quits.
func settings(_id: int) -> Dictionary:
	return _settings


func saveButtonStyle(_id: int, style: StringName) -> Dictionary:
	return _save("button_style", style)


func saveEdgeSmoothing(_id: int, smoothing: StringName) -> Dictionary:
	return _save("edge_smoothing", smoothing)


func saveGamesFloat(_id: int, floating: bool) -> Dictionary:
	return _save("games_float", floating)


func saveSoundLevel(_id: int, steps: int) -> Dictionary:
	return _save("sound_level", steps)


func savePreferredRegion(_id: int, region: String) -> Dictionary:
	return _save("preferred_region", region)


func scanPlatform(_id: int, _platform_id: String) -> Dictionary:
	return _form_answer({"library": form().get("library", "{}"), "report": _report()})


## The library as it now stands, whatever the number of games asked for.
func useDemoLibrary(id: int, _games: int, _platform_id: String) -> Dictionary:
	if not _snapshot.is_empty():
		return library(id)
	var made := _current.duplicate(true) if not _current.is_empty() else demo("library")
	made["console_variants"] = _variants()
	_current = made
	return {"ok": true, "library": JSON.stringify(made)}


## The demo's library, none of whose games has a label.
func rescrape(_id: int) -> Dictionary:
	var made := demo("library")
	var games: Array = made.get("games", [])
	return {"ok": true, "library": JSON.stringify(made), "games": games.size(), "labels": 0}


## The library as it now stands takes that order until the app quits.
func orderConsoles(_id: int, platform_ids: PackedStringArray) -> Dictionary:
	if not _current.is_empty():
		var found: Dictionary = _current["shelves"]
		var shelves: Array = found["shelves"]
		var selected: Variant = shelves[found["selected"]] if not shelves.is_empty() else null
		shelves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return platform_ids.find(str(a["platform"])) < platform_ids.find(str(b["platform"])))
		found["selected"] = maxi(shelves.find(selected), 0)
	return {"ok": true}


## The order the form story holds for [param gap].
func placeConsole(_id: int, _platform_id: String, gap: int) -> Dictionary:
	var orders: Dictionary = form().get("placing", {})
	var order: Array = orders.get(str(gap), [])
	return _form_answer({"order": PackedStringArray(order)} if orders.has(str(gap)) else {"ok": false, "code": "gap_out_of_range"})


## Every game can: the insertion plays.
func checkLaunch(_id: int, _launch: Dictionary) -> Dictionary:
	return {"ok": true}


## The desktop demo's form story, in the plugin's wire shape (see `DesktopDemoTest.kt`): the installed players of
## its type, the folder picked, how many games it holds, the library once its console is added, and the console
## order for each gap of [method placeConsole]. Empty where the demo has none, which is how the generated demo is.
func form() -> Dictionary:
	if not _story_read and FileAccess.file_exists(DEMO):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO))
		_story = story_of(parsed)
	_story_read = true
	return _story


func _save(key: String, value: Variant) -> Dictionary:
	_settings[key] = value
	return {"ok": true}


func _variants() -> Dictionary:
	if not _snapshot.is_empty():
		return _snapshot.get("variants", {})
	if not FileAccess.file_exists(_VARIANTS):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_VARIANTS))
	return data if data is Dictionary else {}


## The games the form story's folder holds, as a scan or a preview reports them.
func _report() -> Dictionary:
	var games: int = form().get("games", 0)
	return {"games": games, "files": games}


## [param story] as an operation's answer when the demo holds a form story; none, and the operation fails as
## unavailable, when it does not.
func _form_answer(story: Dictionary) -> Dictionary:
	if form().is_empty():
		return {"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"}
	var answer := {"ok": true}
	answer.merge(story, true)
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
