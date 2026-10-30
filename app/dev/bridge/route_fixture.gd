# SPDX-License-Identifier: GPL-3.0-or-later
extends AndroidServices
## In-memory responses for the transition preview's add-console route. No call reaches the plugin.

var _added := false
var _setup := {}


func _ready() -> void:
	catalog = CatalogSummary.new(DesktopPlugin.demo("catalog"))


func is_available() -> bool:
	return true


func settings() -> SettingsAnswer:
	return SettingsAnswer.new({"ok": true, "first_launch": false, "games_float": false})


func library() -> LibraryAnswer:
	return LibraryAnswer.new({"ok": true, "library": _library()})


func installed_players(platform_id: String) -> Array[Player]:
	if platform_id != "ps2":
		return []
	return [Player.new({"player_id": "ps2.armsx2", "player_name": "ps2 - ARMSX2", "emulator_name": "ARMSX2",
		"extensions": PackedStringArray(["iso", "chd", "bin"])})]


func pick_folder() -> Pick:
	return Pick.new({"ok": true, "folder": {"uri": "content://preview/ps2", "name": "ps2",
		"place": {"volume": "preview", "folders": PackedStringArray(["ps2"])}}})


func preview_platform(_platform_id: String, _choices: PlatformSetup) -> PreviewAnswer:
	return PreviewAnswer.new({"ok": true, "report": {"games": 2, "files": 2}})


func set_up_platform(_platform_id: String, choices: PlatformSetup) -> LibraryAnswer:
	_setup = choices.to_wire()
	return library()


func scan_platform(_platform_id: String) -> ScanAnswer:
	_added = true
	return ScanAnswer.new({"ok": true, "library": _library(), "report": {"games": 2}})


func place_console(_platform_id: String, _gap: int) -> Placed:
	return Placed.new({"ok": true, "order": PackedStringArray(["gc", "gba", "ps2"])})


func persisted_folders() -> FolderList:
	return FolderList.new({"ok": true, "folders": []})


func _library() -> String:
	var data := DesktopPlugin.demo("library").duplicate(true)
	var source: Array = data.get("games", [])
	var games: Array = source.filter(func(game: Dictionary) -> bool: return game["platform_id"] in ["gc", "gba", "ps2"] \
		and (_added or game["platform_id"] != "ps2"))
	data["games"] = games
	var shelves: Array[Dictionary] = []
	for platform: String in ["gc", "gba", "ps2"] if _added else ["gc", "gba"]:
		var indices: Array[int] = []
		for i in games.size():
			if games[i]["platform_id"] == platform:
				indices.append(i)
		shelves.append({"platform": platform, "games": indices, "selected": 0})
	data["shelves"] = {"shelves": shelves, "selected": 0}
	if not _setup.is_empty():
		data["setups"] = {"ps2": _setup}
	return JSON.stringify(data)
