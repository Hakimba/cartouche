# SPDX-License-Identifier: GPL-3.0-or-later
class_name DesktopPlugin
extends RefCounted
## Stands for the Kotlin plugin where there is none (editor, desktop): [AndroidServices] calls it as it calls the
## plugin, with the plugin's method names, and it answers in the plugin's JSON text. It answers from the desktop demo
## ([constant DEMO]), a snapshot of a device's data (`--snapshot=DIR`, debug builds) and the choices made since the
## app started; an operation answers at once. A call it has no method for gets nothing: an empty value, or an
## operation failing as `unavailable`.

## The catalog, a demo library and the add form's story as the plugin sends them: see `DesktopDemoTest.kt`, which
## keeps it up to date.
const DEMO := "res://dev/demo/desktop.json"
const _VARIANTS := "user://console-variants.json"

var _snapshot := {}
## The settings as the plugin sends them, a fresh install's ([method settings_of] the demo's) until changed.
var _settings := {"ok": true}.merged(settings_of(demo("settings")))
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


## The demo's library: on its ring the consoles ready, and with `--coming-consoles` those not fully supported yet too.
static func demo_library() -> Dictionary:
	return demo("library_with_coming" if Diagnostics.flag("coming-consoles") else "library")


## The settings [param parsed] holds, their numbers ints and their lists of names PackedStringArrays where JSON has
## floats and Arrays: [method saveSetting] reads a value back as the type it holds.
static func settings_of(parsed: Dictionary) -> Dictionary:
	var sent := {}
	for key: String in parsed:
		var value: Variant = parsed[key]
		if value is float:
			var number: float = value
			value = int(number)
		elif value is Array:
			var names: Array = value
			value = PackedStringArray(names)
		sent[key] = value
	return sent


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
	var snapshot: Dictionary = parsed if parsed is Dictionary else {}
	var sent: Variant = snapshot.get("library")
	var answer: Dictionary = sent if sent is Dictionary else {}
	if answer.get("library") is not Dictionary or snapshot.get("settings") is not Dictionary \
			or snapshot.get("variants", {}) is not Dictionary:
		Diagnostics.trace("snapshot", "%s refused: not in the shape the bridge's `snapshot` writes, take it again" % path)
		return
	_snapshot = _map_snapshot(snapshot, folder)
	var mapped_answer: Dictionary = _snapshot["library"]
	_current = mapped_answer["library"]
	_current["console_variants"] = _snapshot.get("variants", {})
	var snapshot_settings: Dictionary = _snapshot["settings"]
	_settings.merge(settings_of(snapshot_settings), true)
	var locale: String = _snapshot.get("locale", "")
	if locale:
		TranslationServer.set_locale(locale)


## Debug builds: starts on the backdrop named [param chosen] (a `backdrop` wire name, `--backdrop=dark`), the veil
## still when [param veil] is `off` (`--pixel-veil=off`); the stored ones when empty. A name that is no backdrop's is
## traced and left aside.
func start_with_backdrop(chosen: String, veil: String) -> void:
	if StringName(chosen) in Backdrop.NAMES:
		_settings["backdrop"] = chosen
	elif chosen:
		Diagnostics.trace("backdrop", "--backdrop=%s refused, not one of %s" % [chosen,
			", ".join(PackedStringArray(Backdrop.NAMES.keys()))])
	if veil:
		_settings["pixel_veil"] = veil != "off"


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
		var setup: Dictionary = setups.get(platform_id, {"disc_grouping": "grouped", "folder_depth": "top_level"})
		setup["folder_uri"] = "content://demo/tree/" + platform_id
		setups[platform_id] = setup


## The demo's catalog; every console ready with `--coming-consoles`, as the app then tells the plugin.
func loadCatalog(..._data: Array) -> String:
	var catalog := demo("catalog")
	if Diagnostics.flag("coming-consoles"):
		for console: Dictionary in catalog.get("offered", []):
			console["coming"] = false
	return JSON.stringify(catalog)


## Those of the form story, for its type.
func installedPlayers(platform_id: String) -> String:
	var story := form()
	return JSON.stringify({"players": story.get("players", []) if story.get("type") == platform_id else []})


## A snapshot's shelf, unfiltered.
func browse(platform_id: String, order: String, typed: String) -> String:
	var shelves: Dictionary = _snapshot.get("browse", {})
	var recorded: Dictionary = shelves.get(platform_id, {}) if typed.is_empty() else {}
	return recorded.get(order, "{}")


## A full one, charging.
func battery() -> String:
	return JSON.stringify(demo("battery"))


func pickFolder(_id: int) -> String:
	return _form_answer({"folder": form().get("folder", {})})


## The snapshot's answer with the library as it now stands, or the library as it now stands, or the demo's.
func library(_id: int) -> String:
	if _snapshot.is_empty():
		return JSON.stringify({"ok": true, "library": _current if _current else demo_library()})
	var original: Dictionary = _snapshot["library"]
	var answer := original.duplicate(true)
	answer["library"] = _current
	return JSON.stringify(answer)


func setUpPlatform(id: int, platform_id: String, setup: Dictionary) -> String:
	var variant: String = setup.get("variant_id", "")
	# A model chosen in Edit is kept on the library as it stands: no form story needed.
	if form().is_empty():
		return _keep_variant(id, platform_id, variant) if variant else _form_answer({})
	var story: Dictionary = form().get("library", {})
	_current = story.duplicate(true)
	return _keep_variant(id, platform_id, variant) if variant else _form_answer({"library": story})


func previewPlatform(_id: int, _platform_id: String, _setup: Dictionary) -> String:
	return _form_answer({"report": _report()})


## Kept in memory until the app quits.
func settings(_id: int) -> String:
	return JSON.stringify(_settings)


## Takes any key, its value read back from its text as the type it is sent as: the plugin checks both against the
## settings it declares.
func saveSetting(_id: int, key: String, value: String) -> String:
	match typeof(_settings.get(key)):
		TYPE_BOOL:
			_settings[key] = value == "true"
		TYPE_INT:
			_settings[key] = value.to_int()
		_:
			_settings[key] = value
	return JSON.stringify({"ok": true})


func backdrop() -> String:
	return JSON.stringify({"backdrop": _settings["backdrop"], "pixel_veil": _settings["pixel_veil"]})


func scanPlatform(_id: int, _platform_id: String) -> String:
	return _form_answer({"library": form().get("library", {}), "report": _report()})


## The games [method start_with_arrivals] asked for, the first time the console is read again.
func refreshPlatform(_id: int, platform_id: String) -> String:
	var count: int = _arriving.get(platform_id, 0)
	_arriving.erase(platform_id)
	var answer := {"ok": true, "arrivals": _arrivals}
	var shelves: Array = _current.get("shelves", [])
	var at := shelves.find_custom(func(shelf: Dictionary) -> bool: return shelf["platform_id"] == platform_id)
	if count == 0 or at < 0:
		return JSON.stringify(answer)
	var games: Array = _current["games"]
	var shelf: Dictionary = shelves[at]
	var indices: Array = shelf["game_indexes"]
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
	answer["library"] = _current
	return JSON.stringify(answer)


func enterConsole(_id: int, platform_id: String) -> String:
	var announced: Dictionary = _arrivals["announced"]
	announced.erase(platform_id)
	return JSON.stringify({"ok": true, "arrivals": _arrivals})


func leaveGame(_id: int, game_id: String) -> String:
	var unseen: PackedStringArray = _arrivals["unseen"]
	_arrivals["unseen"] = PackedStringArray(Array(unseen).filter(func(id: String) -> bool: return id != game_id))
	return JSON.stringify({"ok": true, "arrivals": _arrivals})


## The library as it now stands, whatever the number of games asked for; at first the demo's, every game on
## [param platform_id] when one is given, as on the device.
func useDemoLibrary(id: int, _games: int, platform_id: String) -> String:
	if not _snapshot.is_empty():
		return library(id)
	var made := _current.duplicate(true) if not _current.is_empty() else _on_one_shelf(demo_library(), platform_id)
	_with_variants(made, _variants())
	_current = made
	return JSON.stringify({"ok": true, "library": made})


## [param made] with all its games on [param platform_id] and its medium; as it is without a game of that console.
static func _on_one_shelf(made: Dictionary, platform_id: String) -> Dictionary:
	var games: Array = made.get("games", [])
	var at := games.find_custom(func(game: Dictionary) -> bool: return game["platform_id"] == platform_id)
	if at < 0:
		return made
	var medium: String = games[at]["medium"]
	for game: Dictionary in games:
		game["platform_id"] = platform_id
		game["medium"] = medium
	made["shelves"] = [{"platform_id": platform_id, "game_indexes": range(games.size()), "selected": 0}]
	made["selected_shelf"] = 0
	return made


## The demo's library, none of whose games has a label.
func rescrape(_id: int) -> String:
	var made := demo_library()
	var games: Array = made.get("games", [])
	return JSON.stringify({"ok": true, "library": made, "games": games.size(), "labels": 0})


## The library as it now stands takes that order until the app quits.
func orderConsoles(_id: int, platform_ids: PackedStringArray) -> String:
	if not _current.is_empty():
		var shelves: Array = _current["shelves"]
		var selected: Variant = shelves[_current["selected_shelf"]] if not shelves.is_empty() else null
		shelves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return platform_ids.find(str(a["platform_id"])) < platform_ids.find(str(b["platform_id"])))
		_current["selected_shelf"] = maxi(shelves.find(selected), 0)
	return JSON.stringify({"ok": true})


## The order the form story holds for [param gap].
func placeConsole(_id: int, _platform_id: String, gap: int) -> String:
	var orders: Dictionary = form().get("placing", {})
	var order: Array = orders.get(str(gap), [])
	return _form_answer({"order": order} if orders.has(str(gap)) else {"ok": false, "code": "gap_out_of_range"})


## Every game can: the insertion plays.
func checkLaunch(_id: int, _launch: Dictionary) -> String:
	return JSON.stringify({"ok": true})


## The desktop demo's form story, in the plugin's wire shape (see `DesktopDemoTest.kt`): the installed players of
## its type, the folder picked, how many games it holds, the library once its console is added, and the console
## order for each gap of [method placeConsole]. Empty where the demo has none, which is how the generated demo is.
func form() -> Dictionary:
	if not _story_read:
		_story = demo("form")
	_story_read = true
	return _story


## Keeps the model beside the user's other files (in the snapshot when one is loaded).
func _keep_variant(id: int, platform_id: String, variant: String) -> String:
	var kept := _variants()
	kept[platform_id] = variant
	if not _snapshot.is_empty():
		_snapshot["variants"] = kept
		_with_variants(_current, kept)
		return library(id)
	var library_data := _current.duplicate(true) if not _current.is_empty() else demo_library()
	var file := FileAccess.open(_VARIANTS, FileAccess.WRITE)
	if file == null:
		return JSON.stringify({"ok": false, "code": "permission_denied"})
	file.store_string(JSON.stringify(kept))
	_with_variants(library_data, kept)
	_current = library_data
	return JSON.stringify({"ok": true, "library": library_data})


## [param sent] showing the models of [param variants], on the ring and in its setups, as the plugin sends them.
static func _with_variants(sent: Dictionary, variants: Dictionary) -> void:
	sent["console_variants"] = variants
	var setups: Dictionary = sent.get("setups", {})
	for platform_id: String in variants:
		if setups.has(platform_id):
			var setup: Dictionary = setups[platform_id]
			setup["variant_id"] = variants[platform_id]


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
func _form_answer(story: Dictionary) -> String:
	if form().is_empty():
		return JSON.stringify({"ok": false, "code": &"unavailable", "detail": "Android plugin not loaded"})
	var answer := {"ok": true}
	answer.merge(story, true)
	return JSON.stringify(answer)


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
		var marker := text.find("/files/art/")
		if field in ["path", "label_path"] and marker >= 0:
			var relative := text.substr(marker + 1)
			if relative.simplify_path() == relative and "\\" not in relative:
				return folder.path_join(relative)
	return value
