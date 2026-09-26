# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## Browses a granted folder, lists the installed players able to open the selected file and
## launches it. Also reports whether returning from the emulator restarted the app.

## Written before a launch, read on the next refresh: at startup it means the app was restarted.
const _LAUNCH_MARKER := "user://device_check_launch.cfg"

var _folder: AndroidServices.Folder
## Sub-folders entered from the folder root, innermost last.
var _trail: Array[AndroidServices.Entry] = []
## Increases with every listing, so a slow answer never replaces a newer one.
var _listing_generation := 0
var _refreshed_once := false
var _launching := false

@onready var _folders: ItemList = %Folders
@onready var _path: Label = %Path
@onready var _entries: ItemList = %Entries
@onready var _players: ItemList = %Players
@onready var _launch: Button = %LaunchButton
@onready var _outcome: Label = %Outcome


func refresh() -> void:
	_report_last_launch()
	var listed := await Android.persisted_folders()
	_folders.clear()
	for folder in listed.folders:
		_folders.set_item_metadata(_folders.add_item(folder.name), folder)
	(_entries if _entries.item_count > 0 else _folders).grab_focus()


func go_back() -> bool:
	if _trail.is_empty():
		return false
	_trail.pop_back()
	_list_current()
	return true


func _on_folders_item_activated(index: int) -> void:
	_folder = _folders.get_item_metadata(index)
	_trail.clear()
	await _list_current()
	_entries.grab_focus()


func _on_entries_item_selected(index: int) -> void:
	var entry: AndroidServices.Entry = _entries.get_item_metadata(index)
	_players.clear()
	if not entry.is_directory:
		for candidate in Android.candidates(entry.name):
			var label := "%s — %s" % [candidate.platform_name, candidate.player_name]
			_players.set_item_metadata(_players.add_item(label), candidate)
	if _players.item_count > 0:
		_players.select(0)
	_launch.disabled = _launching or _players.item_count == 0
	_outcome.text = "" if entry.is_directory else "%d installed player(s)." % _players.item_count


func _on_entries_item_activated(index: int) -> void:
	var entry: AndroidServices.Entry = _entries.get_item_metadata(index)
	if entry.is_directory:
		_trail.append(entry)
		_list_current()
	else:
		_players.grab_focus()


func _on_launch_pressed() -> void:
	# Also reached by activating a player, which ignores the button state.
	if _launch.disabled or _launching:
		return
	var entry: AndroidServices.Entry = _entries.get_item_metadata(_entries.get_selected_items()[0])
	var candidate: AndroidServices.Candidate = _players.get_item_metadata(
			_players.get_selected_items()[0])
	var marker := ConfigFile.new()
	marker.set_value("launch", "game", entry.name)
	marker.set_value("launch", "time", Time.get_unix_time_from_system())
	if marker.save(_LAUNCH_MARKER) != OK:
		logged.emit("[color=salmon]Cannot write the launch marker: restarts go unnoticed.[/color]")
	_launching = true
	_launch.disabled = true
	var result := await Android.launch_game(candidate.player_id, entry)
	_launching = false
	# The player list may have changed meanwhile (back, another file).
	_launch.disabled = _players.get_selected_items().is_empty()
	_outcome.text = "Launched." if result.ok else "Failed (%s): %s" % [result.code, result.detail]
	var outcome := "ok" if result.ok else String(result.code)
	logged.emit("%s → %s: %s" % [plain(entry.name), plain(candidate.player_name), outcome])
	if not result.ok:
		DirAccess.remove_absolute(_LAUNCH_MARKER)


func _list_current() -> void:
	_listing_generation += 1
	var generation := _listing_generation
	var at_root := _trail.is_empty()
	var listing: AndroidServices.Listing = (await Android.list_folder(_folder) if at_root
			else await Android.list_sub_folder(_folder, _trail[-1]))
	if generation != _listing_generation:
		return
	_path.text = _folder.name if at_root else "%s / … / %s" % [_folder.name, _trail[-1].name]
	_entries.clear()
	_players.clear()
	_launch.disabled = true
	if not listing.ok:
		_outcome.text = "Cannot list the folder (%s)." % listing.code
		return
	listing.entries.sort_custom(_directories_first)
	for entry in listing.entries:
		var label := ("▸ " if entry.is_directory else "") + entry.name
		_entries.set_item_metadata(_entries.add_item(label), entry)


func _report_last_launch() -> void:
	var marker := ConfigFile.new()
	var restarted := not _refreshed_once
	_refreshed_once = true
	if marker.load(_LAUNCH_MARKER) != OK:
		return
	DirAccess.remove_absolute(_LAUNCH_MARKER)
	var game := plain(str(marker.get_value("launch", "game")))
	var launched_at: float = marker.get_value("launch", "time")
	var seconds := int(Time.get_unix_time_from_system() - launched_at)
	logged.emit("[color=salmon]The app restarted after launching %s.[/color]" % game if restarted
			else "[color=lightgreen]Back from %s after %d s, no restart.[/color]" % [game, seconds])


static func _directories_first(a: AndroidServices.Entry, b: AndroidServices.Entry) -> bool:
	if a.is_directory != b.is_directory:
		return a.is_directory
	return a.name.naturalnocasecmp_to(b.name) < 0
