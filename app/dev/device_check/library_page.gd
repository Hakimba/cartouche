# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## One platform's library: its folder, emulator and scan options, the games a scan found and the
## files it set aside. Games launch with the platform's emulator, from the disc chosen here.

const _AUTOMATIC := "Emulator: first installed (%s)"
const _NO_FOLDER := "No folder (add one in the Storage tab)"

var _library := AndroidServices.Library.new({})
## Set while the controls are being filled, which is not a choice to store.
var _filling := false
## Choices waiting to be stored, by platform: they are stored one at a time, in order.
var _pending_setups: Dictionary[String, AndroidServices.PlatformSetup] = {}
var _storing := false
var _launching := false
var _scanning := false
var _problem_reported := false

@onready var _platform: OptionButton = %Platform
@onready var _folder: OptionButton = %Folder
@onready var _player: OptionButton = %Player
@onready var _group_discs: CheckBox = %GroupDiscs
@onready var _subfolders: CheckBox = %Subfolders
@onready var _scan: Button = %Scan
@onready var _status: Label = %Status
@onready var _games: ItemList = %Games
@onready var _details: Label = %Details
@onready var _disc: OptionButton = %Disc
@onready var _launch: Button = %LaunchButton
@onready var _ignored: ItemList = %Ignored


func refresh() -> void:
	if _platform.item_count == 0:
		_fill_platforms()
	var focused: Control = _games if _games.item_count > 0 else _platform
	focused.grab_focus.call_deferred()
	var answer := await Android.library()
	if not answer.ok:
		logged.emit("Cannot read the library (%s): %s" % [answer.code, plain(answer.detail)])
		return
	if answer.has_load_problem and not _problem_reported:
		_problem_reported = true
		logged.emit("[color=salmon]The library was reset: %s[/color]" % plain(answer.load_problem))
	_library = answer.library
	await _show_platform()


func _on_platform_selected(_index: int) -> void:
	await _show_platform()


func _on_setup_changed() -> void:
	if _filling:
		return
	# Read now: the platform may change before this choice is stored.
	_pending_setups[_platform_id()] = _chosen_setup()
	if _storing:
		return
	_storing = true
	while not _pending_setups.is_empty():
		var platform_id: String = _pending_setups.keys()[0]
		var setup: AndroidServices.PlatformSetup = _pending_setups[platform_id]
		_pending_setups.erase(platform_id)
		var answer := await Android.set_up_platform(platform_id, setup)
		if answer.ok:
			_library = answer.library
		else:
			logged.emit("Cannot store the choice (%s): %s" % [answer.code, plain(answer.detail)])
	_storing = false
	# The controls may have been filled from the library before the last choice was stored.
	await _show_platform()


func _on_scan_pressed() -> void:
	var platform_id := _platform_id()
	_scanning = true
	_scan.disabled = true
	_status.text = "Scanning…"
	# A choice still being stored (such as Subfolders) must apply to this scan.
	while _storing:
		await get_tree().process_frame
	var answer := await Android.scan_platform(platform_id)
	_scanning = false
	_scan.disabled = _launching
	if not answer.ok:
		_status.text = "Scan failed (%s): %s" % [answer.code, answer.detail]
		return
	_library = answer.library
	if _platform_id() != platform_id:
		return
	var report := answer.report
	_status.text = "%d games, %d identified · %d files ignored · %d files in %d ms" % [
		report.games, report.identified, report.ignored, report.files, report.milliseconds]
	logged.emit("Scan: " + _status.text)
	_show_games()


func _on_game_selected(index: int) -> void:
	var game: AndroidServices.Game = _games.get_item_metadata(index)
	var lines := PackedStringArray([game.title])
	var serials := ", ".join(game.serials) if not game.serials.is_empty() else "unknown"
	lines.append("Serial: " + serials)
	var reference := "not identified"
	if game.identified:
		reference = game.redump_name if game.has_redump_name else "one version of this release"
	lines.append("Reference: " + reference)
	if not game.languages.is_empty():
		lines.append("Languages: " + ", ".join(game.languages))
	if game.has_version:
		lines.append("Version: " + game.version)
	_details.text = "\n".join(lines)
	_disc.clear()
	for disc in game.discs:
		var label := "Disc %d" % disc.number if disc.has_number else "Disc"
		_disc.add_item(label + " — " + disc.name)
	_disc.select(clampi(game.last_disc, 0, game.discs.size() - 1))
	_disc.visible = game.discs.size() > 1
	_launch.disabled = _launching


func _on_launch_pressed() -> void:
	# Also reached by activating a game, which ignores the button state.
	if _launching or _games.get_selected_items().is_empty():
		return
	var game: AndroidServices.Game = _games.get_item_metadata(_games.get_selected_items()[0])
	_launching = true
	_launch.disabled = true
	_scan.disabled = true  # A rescan during the launch would change the game being launched.
	var result := await Android.launch_game(game, _disc.selected)
	_launching = false
	_launch.disabled = false
	_scan.disabled = _scanning
	var outcome := "ok" if result.ok else "%s: %s" % [result.code, result.detail]
	logged.emit("%s → %s" % [plain(game.title), plain(outcome)])
	var answer := await Android.library()
	if answer.ok:
		# The launched disc is now the game's last one: show it.
		_library = answer.library
		_show_games()


## Lists the platforms and starts on the first one with an emulator installed.
func _fill_platforms() -> void:
	var start := -1
	for platform in Android.catalog.platforms:
		_platform.add_item("%s (%s)" % [platform.name, platform.media])
		_platform.set_item_metadata(_platform.item_count - 1, platform.id)
		if start < 0 and not Android.installed_players(platform.id).is_empty():
			start = _platform.item_count - 1
	if _platform.item_count > 0:
		_platform.select(maxi(start, 0))


func _chosen_setup() -> AndroidServices.PlatformSetup:
	var setup := AndroidServices.PlatformSetup.new()
	setup.has_folder = _folder.selected > 0
	if setup.has_folder:
		setup.folder_uri = _folder.get_item_metadata(_folder.selected)
	setup.has_player = _player.selected > 0
	if setup.has_player:
		setup.player_id = _player.get_item_metadata(_player.selected)
	setup.disc_grouping = "grouped" if _group_discs.button_pressed else "separate"
	setup.folder_depth = "subfolders" if _subfolders.button_pressed else "top_level"
	return setup


func _platform_id() -> String:
	return _platform.get_item_metadata(_platform.selected) if _platform.item_count > 0 else ""


## Fills the setup controls with the stored choices, then lists the platform's games.
func _show_platform() -> void:
	var platform_id := _platform_id()
	var folders := await Android.persisted_folders()
	if _platform_id() != platform_id:
		return  # Another platform was chosen meanwhile; its own call fills the controls.
	# Read after the wait: a choice stored meanwhile must show.
	var setup := _library.setup_of(platform_id)
	_filling = true
	_folder.clear()
	_folder.add_item(_NO_FOLDER)
	for folder in folders.folders:
		_folder.add_item(folder.name)
		_folder.set_item_metadata(_folder.item_count - 1, folder.uri)
		if setup.has_folder and folder.uri == setup.folder_uri:
			_folder.select(_folder.item_count - 1)
	if setup.has_folder and _folder.selected == 0:
		# The folder's access was removed: keep showing the stored choice.
		_folder.add_item("Access lost: " + setup.folder_uri)
		_folder.set_item_metadata(_folder.item_count - 1, setup.folder_uri)
		_folder.select(_folder.item_count - 1)
	var players := Android.installed_players(platform_id)
	_player.clear()
	_player.add_item(_AUTOMATIC % (players[0].name if not players.is_empty() else "none installed"))
	for player in players:
		_player.add_item(player.name)
		_player.set_item_metadata(_player.item_count - 1, player.id)
		if setup.has_player and player.id == setup.player_id:
			_player.select(_player.item_count - 1)
	_group_discs.button_pressed = setup.disc_grouping == "grouped"
	_subfolders.button_pressed = setup.folder_depth == "subfolders"
	_filling = false
	_show_games()


## Lists the platform's games, keeping the selected one selected.
func _show_games() -> void:
	var platform_id := _platform_id()
	var selected := ""
	for index in _games.get_selected_items():
		var game: AndroidServices.Game = _games.get_item_metadata(index)
		selected = game.id
	_games.clear()
	for game in _library.games_of(platform_id):
		var parts := PackedStringArray([game.title])
		if not game.regions.is_empty():
			parts.append(", ".join(game.regions))
		if game.discs.size() > 1:
			parts.append("%d discs" % game.discs.size())
		if not game.identified:
			parts.append("not identified")
		_games.set_item_metadata(_games.add_item("  ·  ".join(parts)), game)
	_ignored.clear()
	for file in _library.ignored_of(platform_id):
		_ignored.add_item("%s  —  %s" % [file.name, file.reason.replace("_", " ")])
	_details.text = "%d games" % _games.item_count
	_disc.visible = false
	_launch.disabled = true
	for index in _games.item_count:
		var game: AndroidServices.Game = _games.get_item_metadata(index)
		if game.id == selected:
			_games.select(index)
			_on_game_selected(index)
