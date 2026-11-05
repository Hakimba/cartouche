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
var _settings := {"ok": true, "first_launch": false, "games_float": false, "sound_level": 10,
	"language": "", "languages": Locale.NAMES.keys()}
var _backdrop := {"backdrop": "light", "pixel_veil": true}
## The library as the choices made since the app started left it; empty until one is made.
var _current := {}
var _story := {}
var _story_read := false
## Debug builds: how many games the next re-read of each console brings, by platform id (`--new-games=gba:2`).
var _arriving: Dictionary[String, int] = {}
## The games not seen yet, as the plugin sends them.
var _arrivals := {"unseen": PackedStringArray(), "announced": {}}


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


## Debug builds: starts on the backdrop named [param chosen] (a `backdrop` wire name, `--backdrop=dark`), the veil
## still when [param veil] is `off` (`--pixel-veil=off`); the stored ones when empty. A name that is no backdrop's is
## traced and left aside.
func start_with_backdrop(chosen: String, veil: String) -> void:
	if StringName(chosen) in Backdrop.NAMES:
		_backdrop["backdrop"] = chosen
	elif chosen:
		Diagnostics.trace("backdrop", "--backdrop=%s refused, not one of %s" % [chosen,
			", ".join(PackedStringArray(Backdrop.NAMES.keys()))])
	if veil:
		_backdrop["pixel_veil"] = veil != "off"


## Debug builds: the consoles of [param asked] (`gba:2,ps2:3`) are set up with a folder, and their next re-read
## brings that many made-up games, copies of their first one; asked at start (`--new-games`) or later.
func start_with_arrivals(asked: String) -> void:
	if not OS.is_debug_build() or asked.is_empty():
		return
	for part in asked.split(",", false):
		var pieces := part.split(":")
		if pieces.size() == 2 and pieces[1].is_valid_int():
			_arriving[pieces[0]] = pieces[1].to_int()
	if _current.is_empty():
		_current = demo("library")
	var setups: Dictionary = _current.get_or_add("setups", {})
	for platform_id in _arriving:
		setups[platform_id] = {"folder_uri": "content://demo/tree/" + platform_id, "disc_grouping": "grouped",
			"folder_depth": "top_level"}


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
	return _keep_variant(id, platform_id, variant) if variant else answer


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


func backdrop() -> Dictionary:
	return _backdrop


func saveBackdrop(_id: int, chosen: StringName) -> Dictionary:
	_backdrop["backdrop"] = chosen
	return {"ok": true}


func savePixelVeil(_id: int, on: bool) -> Dictionary:
	_backdrop["pixel_veil"] = on
	return {"ok": true}


func saveSoundLevel(_id: int, steps: int) -> Dictionary:
	return _save("sound_level", steps)


func saveLanguage(_id: int, language: String) -> Dictionary:
	return _save("language", language)


func savePreferredRegion(_id: int, region: String) -> Dictionary:
	return _save("preferred_region", region)


func scanPlatform(_id: int, _platform_id: String) -> Dictionary:
	return _form_answer({"library": form().get("library", "{}"), "report": _report()})


## The games [method start_with_arrivals] asked for, the first time the console is read again.
func refreshPlatform(_id: int, platform_id: String) -> Dictionary:
	var count: int = _arriving.get(platform_id, 0)
	_arriving.erase(platform_id)
	var answer := {"ok": true, "arrivals": _arrivals}
	var found: Dictionary = _current.get("shelves", {"shelves": []})
	var shelves: Array = found["shelves"]
	var at := shelves.find_custom(func(shelf: Dictionary) -> bool: return shelf["platform"] == platform_id)
	if count == 0 or at < 0:
		return answer
	var games: Array = _current["games"]
	var shelf: Dictionary = shelves[at]
	var indices: Array = shelf["games"]
	var first: Dictionary = games[indices[0]]
	var unseen: PackedStringArray = _arrivals["unseen"]
	var announced: Dictionary = _arrivals["announced"]
	var platform_new: PackedStringArray = announced.get(platform_id, PackedStringArray())
	for i in count:
		var game := first.duplicate(true)
		# Numbered across the library: games asked again later never take an id already given.
		game["id"] = "demo/new-%s-%d" % [platform_id, games.size()]
		game["title"] = "%s %s" % [first["title"], ["II", "III", "IV", "V", "VI"][i % 5]]
		indices.append(games.size())
		games.append(game)
		var id: String = game["id"]
		unseen.append(id)
		platform_new.append(id)
	_arrivals["unseen"] = unseen
	announced[platform_id] = platform_new
	answer["library"] = JSON.stringify(_current)
	return answer


func enterConsole(_id: int, platform_id: String) -> Dictionary:
	var announced: Dictionary = _arrivals["announced"]
	announced.erase(platform_id)
	return {"ok": true, "arrivals": _arrivals}


func leaveGame(_id: int, game_id: String) -> Dictionary:
	var unseen: PackedStringArray = _arrivals["unseen"]
	_arrivals["unseen"] = PackedStringArray(Array(unseen).filter(func(id: String) -> bool: return id != game_id))
	return {"ok": true, "arrivals": _arrivals}


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


## Keeps the model beside the user's other files (in the snapshot when one is loaded).
func _keep_variant(id: int, platform_id: String, variant: String) -> Dictionary:
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
