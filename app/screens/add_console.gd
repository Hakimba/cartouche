# SPDX-License-Identifier: GPL-3.0-or-later
class_name AddConsole
extends Control
## The form adding a console, field by field with the controller: its type (any platform of the
## catalog not set up yet), its emulator (installed ones only; read again when the app comes back
## to the front), both chosen from a list and neither chosen in advance, the folder of its games
## (Android's folder picker). Once an emulator and a folder are chosen, the compatible games are
## counted without saving anything and the focus goes to "Add", which stays greyed until there is
## something to add.
## B or "Cancel" gives up, except while the console is being added.
##
## The same form edits a console set up ([method edit]): filled with its choices, titled as an
## edit, its buttons read "Remove" and "Save". Saving another type (one not set up yet) adds that
## console and removes the one edited.

## How the form closed.
enum Outcome {
	## The console was added or saved, and scanned.
	DONE,
	GIVEN_UP,
	## "Remove" was pressed while editing: removing is asked first.
	REMOVE,
}

signal closed(outcome: Outcome)

var android: AndroidServices = Android
## The platform the form adds; empty until one is chosen.
var platform_id := ""
## The library as the form last saved it (a console added or saved, or choices kept although
## their scan found nothing); null while nothing was saved.
var library: AndroidServices.Library

## The platform edited, as it was set up; empty while adding.
var _edited_id := ""
## The platforms the form cannot set up: those set up already, but for the one edited.
var _taken := PackedStringArray()

var _players: Array[AndroidServices.Player] = []
## Index of the chosen player in [member _players]; -1 until one is chosen.
var _player := -1
var _folder: AndroidServices.Folder
var _has_folder := false
## Games found in the folder with the current choices; -1 until counted.
var _games := -1
## Counts asked for: only the last one's answer is shown.
var _counts := 0
## Set while the console is being set up and scanned: nothing else may act meanwhile.
var _adding := false

@onready var _title: Label = %Title
@onready var _type: FieldButton = %Type
@onready var _emulator: FieldButton = %Emulator
@onready var _folder_field: FieldButton = %Folder
@onready var _note: Label = %Note
@onready var _subfolders: CheckButton = %Subfolders
@onready var _discs: CheckButton = %Discs
@onready var _cancel: Button = %Cancel
@onready var _add: Button = %Add
@onready var _choice: ChoiceList = %Choice


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_visible_in_tree() and not _adding and not _choice.visible:
		_read_players(_players[_player].id if _player >= 0 else "")


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _choice.visible:
		return
	if event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_give_up()
	elif event.is_action_pressed(&"form_submit") and not _add.disabled:
		get_viewport().set_input_as_handled()
		_on_add_pressed()


## Shows the form as new, nothing chosen, the focus on the type; the platforms already set up,
## [param taken], cannot be chosen.
func open(taken := PackedStringArray()) -> void:
	_fill("", AndroidServices.PlatformSetup.new({"folder_depth": "subfolders"}), null, taken)
	_type.grab_focus()


## Shows the form filled with [param choices], those of [param edited_id], whose folder is
## [param folder]; its type cannot become one of the other platforms set up, [param taken]. The
## focus on the emulator.
func edit(edited_id: String, choices: AndroidServices.PlatformSetup, folder: AndroidServices.Folder,
		taken: PackedStringArray) -> void:
	_fill(edited_id, choices, folder, taken)
	_emulator.grab_focus()


func is_editing() -> bool:
	return not _edited_id.is_empty()


## Back from the confirmation of a removal: the focus on "Remove", and a note when it [param failed].
func back_from_removal(failed: bool) -> void:
	if failed:
		_note.text = tr("The console could not be removed.")
		_note.theme_type_variation = &"PanelNote"
	_cancel.grab_focus()


## The choices made, as the plugin takes them.
func setup() -> AndroidServices.PlatformSetup:
	var choices := AndroidServices.PlatformSetup.new()
	choices.has_folder = _has_folder
	choices.folder_uri = _folder.uri if _has_folder else ""
	choices.has_player = _player >= 0
	choices.player_id = _players[_player].id if choices.has_player else ""
	choices.folder_depth = "subfolders" if _subfolders.button_pressed else "top_level"
	choices.disc_grouping = "grouped" if _discs.button_pressed else "separate"
	return choices


## Where [param folder] is, as the user reads it: "SD card › ROMs › ps2".
static func folder_place(folder: AndroidServices.Folder) -> String:
	if not folder.has_place:
		return folder.name
	var parts := PackedStringArray([TranslationServer.translate("SD card") if folder.volume == &"card"
		else TranslationServer.translate("Internal storage")])
	parts.append_array(folder.folders)
	return " › ".join(parts)


## The name of the platform the form adds.
func platform_name() -> String:
	for platform in android.catalog.platforms:
		if platform.id == platform_id:
			return platform.name
	return platform_id


func _fill(edited_id: String, choices: AndroidServices.PlatformSetup, folder: AndroidServices.Folder,
		taken: PackedStringArray) -> void:
	android.prepare_titles()
	# An answer still on its way belongs to the form as it was.
	_counts += 1
	_edited_id = edited_id
	_taken = taken
	library = null
	platform_id = edited_id
	_title.text = tr("Edit the platform") if edited_id else tr("Add a console")
	_cancel.text = tr("Remove") if edited_id else tr("Cancel")
	_add.text = tr("Save") if edited_id else tr("Add")
	_type.show_value(platform_name() if platform_id else tr("Choose…"))
	_folder = folder
	_has_folder = choices.has_folder
	_folder_field.show_value(folder_place(folder) if _has_folder else tr("Choose…"))
	_games = -1
	_subfolders.set_pressed_no_signal(choices.folder_depth == "subfolders")
	_discs.set_pressed_no_signal(choices.disc_grouping == "grouped")
	_read_players(choices.player_id)


## The catalog's platforms by name, as the type list shows them, but for those [member _taken].
func _platforms() -> Array[AndroidServices.Platform]:
	var platforms := android.catalog.platforms.filter(func(platform: AndroidServices.Platform) -> bool:
		return platform.id not in _taken)
	platforms.sort_custom(func(a: AndroidServices.Platform, b: AndroidServices.Platform) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return platforms


## The installed players, [param preferred_id] chosen if it is one of them, else none; then the
## count again with it.
func _read_players(preferred_id := "") -> void:
	_games = -1
	_players.clear()
	if platform_id:
		_players = android.installed_players(platform_id)
	_player = _players.find_custom(func(player: AndroidServices.Player) -> bool: return player.id == preferred_id)
	_show_player()
	_show_count()
	_count(false)


func _show_player() -> void:
	_emulator.show_value(_players[_player].emulator_name if _player >= 0
		else tr("None installed") if platform_id and _players.is_empty() else tr("Choose…"))


## Once an emulator is chosen, the files it accepts until a folder is chosen, then how many games
## that holds; "Add" only when there are some.
func _show_count() -> void:
	if platform_id and _players.is_empty():
		_note.text = tr("Install an emulator for this console, then come back.")
		_note.theme_type_variation = &"PanelNote"
	elif _player < 0:
		_note.text = ""
	elif _games < 0:
		var extensions := _players[_player].extensions
		_note.text = tr("Accepted files: {extensions}").format({"extensions": " ".join(Array(extensions).map(
			func(extension: String) -> String: return "." + extension))}) if not extensions.is_empty() else ""
		_note.theme_type_variation = &"PanelNote"
	else:
		_note.text = tr_n("{count} compatible game found", "{count} compatible games found", _games).format(
			{"count": _games}) if _games > 0 else tr("No compatible game in this folder")
		_note.theme_type_variation = &"FieldValue"
	_add.disabled = _games <= 0
	# Greyed, "Add" cannot keep the focus: it goes back to the folder, never nowhere.
	if _add.disabled and _add.has_focus():
		_folder_field.grab_focus()
	_add.focus_mode = Control.FOCUS_NONE if _add.disabled else Control.FOCUS_ALL


## Counts the games of the chosen folder with the current choices; the focus goes to "Add" when
## [param then_add] and there are some.
func _count(then_add: bool) -> void:
	if not _has_folder or _player < 0:
		return
	_counts += 1
	var asked := _counts
	var answer := await android.preview_platform(platform_id, setup())
	if asked != _counts:
		return
	_games = answer.report.games if answer.ok else 0
	Diagnostics.trace("console form", "%d games counted in %d ms (%s)" % [_games, answer.report.milliseconds,
		answer.code if not answer.ok else "ok"])
	_show_count()
	if then_add and _games > 0:
		_add.grab_focus()


func _on_type_pressed() -> void:
	var platforms := _platforms()
	if platforms.is_empty():
		return
	var names := PackedStringArray(platforms.map(func(platform: AndroidServices.Platform) -> String: return platform.name))
	var current := platforms.find_custom(func(platform: AndroidServices.Platform) -> bool: return platform.id == platform_id)
	var index := await _choice.choose(tr("Type"), names, current)
	_type.grab_focus()
	if index < 0 or platforms[index].id == platform_id:
		return
	platform_id = platforms[index].id
	Diagnostics.trace("console form", "platform %s" % platform_id)
	_type.show_value(platform_name())
	_read_players()


func _on_emulator_pressed() -> void:
	if _players.is_empty():
		return
	var names := PackedStringArray(_players.map(func(player: AndroidServices.Player) -> String: return player.emulator_name))
	var index := await _choice.choose(tr("Emulator"), names, _player)
	_emulator.grab_focus()
	if index < 0 or index == _player:
		return
	_player = index
	_games = -1
	Diagnostics.trace("console form", "emulator %s" % _players[_player].id)
	_show_player()
	_show_count()
	_count(false)


func _on_folder_pressed() -> void:
	var pick := await android.pick_folder()
	if not pick.ok:
		Diagnostics.trace("console form", "no folder picked (%s)" % pick.code)
		return
	_folder = pick.folder
	_has_folder = true
	_folder_field.show_value(folder_place(_folder))
	await _count(true)


func _on_option_toggled(_on: bool) -> void:
	var choices := setup()
	Diagnostics.trace("console form", "%s, %s" % [choices.folder_depth, choices.disc_grouping])
	_count(false)


## "Cancel", or "Remove" while editing.
func _on_cancel_pressed() -> void:
	if _edited_id and not _adding:
		closed.emit(Outcome.REMOVE)
	else:
		_give_up()


func _give_up() -> void:
	if _adding:
		return
	Diagnostics.trace("console form", "given up")
	closed.emit(Outcome.GIVEN_UP)


func _on_add_pressed() -> void:
	if _adding:
		return
	_adding = true
	_add.disabled = true
	var stored := await android.set_up_platform(platform_id, setup())
	if not stored.ok:
		_not_added(stored)
		return
	library = stored.library
	var scanned := await android.scan_platform(platform_id)
	if not scanned.ok:
		_not_added(scanned)
		return
	library = scanned.library
	Diagnostics.trace("console form", "%s saved: %d games in %d ms" % [platform_id, scanned.report.games,
		scanned.report.milliseconds])
	# The folder changed since it was counted: nothing to show, the form stays.
	if scanned.report.games == 0:
		_adding = false
		_games = 0
		_show_count()
		return
	# Another type is another console: the one edited goes once the new one is there.
	if _edited_id and platform_id != _edited_id:
		var removed := await android.remove_platform(_edited_id)
		if removed.ok:
			library = removed.library
		else:
			Diagnostics.trace("console form", "%s not removed (%s): %s" % [_edited_id, removed.code, removed.detail])
	_adding = false
	closed.emit(Outcome.DONE)


func _not_added(failed: AndroidServices.Result) -> void:
	Diagnostics.trace("console form", "console not added (%s): %s" % [failed.code, failed.detail])
	_adding = false
	_note.text = tr("The console could not be added.")
	_add.disabled = false
