# SPDX-License-Identifier: GPL-3.0-or-later
class_name AddConsole
extends Control
## The form adding a console, field by field with the controller: its type (any platform of the
## catalog not on the ring yet), its emulator (installed ones only; read again when the app comes back
## to the front), both chosen from a list and neither chosen in advance, the folder of its games
## (Android's folder picker), and its model, chosen in place among the console's ([ModelSwatches]) when it has more
## than one. Once an emulator and a folder are chosen, the compatible games are counted without saving anything and
## the focus goes to "Add", which stays greyed until there is something to add.
## B or "Cancel" gives up, except while the console is being added.
## It is the Studio's numbered list beside the console chosen, standing as the consoles screen will show it
## ([RingView]). One card rests on the focused line and moves with the focus.
##
## The same form edits a console of the ring ([method edit]): filled with its choices, titled "Edit", its type
## locked, its buttons read "Remove", set apart at the left in red, and "Save". B gives up: nothing is saved and the
## console shows the model it had again. A new model alone is saved without counting or scanning the games again.

signal closed(outcome: Outcome)
## The form starts to go, given up: the screens behind it may start to come in.
signal leaving
## Slow storage and scanning run behind the departing form.
signal saving(pending: bool)
## The console edited is shown as the model in [param folder] on the ring: for a look while choosing, or back.
signal model_shown(folder: String)

## How the form closed.
enum Outcome {
	## The console was added or saved, and scanned.
	DONE,
	GIVEN_UP,
	## "Remove" was pressed while editing: removing is asked first.
	REMOVE,
}

const _CQW := FormPaint.CQW
const _NOTE_PX := 1.45 * _CQW
const _NOTE_FOUND_PX := 1.9 * _CQW
const _DOT := 1.0 * _CQW
const _DOT_GAP := 1.0 * _CQW
## How far past a pill button its ring stands.
const _PILL_RING := 0.7 * _CQW
## The corners of that ring, whatever the pill's height.
const _PILL_RING_RADIUS := 3.5 * _CQW
const _CARD_S := 0.24
const _CARD_MOTIONS: Array[StringName] = [&"card_position", &"card_size"]
const _LINE_MOTIONS: Array[StringName] = [&"enter", &"lines", &"leave"]
## The form's own motion, in seconds and px: the "+" ball to form transition (its form half), and the form to
## chooser transition (its form half).
const _ENTER_S := 0.32
const _LEAVE_FADE_S := 0.3
const _COME_BACK_S := 0.23
## The console coming back after a chooser, in this time, as a picture rises.
const _MODEL_RISE_S := 0.3
## Remove's place, alone at the left of the pills' row; where the model line goes while its chooser fills the column
## under it, and how long the lines take to make way.
const _REMOVE_X := 28.16
const _HEADER_Y := 0.0
const _MAKE_WAY_S := 0.2

var android: AndroidServices = Android
## The platform the form adds; empty until one is chosen.
var platform_id := ""
## The library as the form last saved it (a console added or saved, or choices kept although
## their scan found nothing); null while nothing was saved.
var library: AndroidServices.Library
## The carousel's consoles and sun: the console chosen stands as theirs ([RingView]). Required before the form opens.
var ring: ConsoleRow
var sun: DirectionalLight3D
## The platform edited, as it was set up; empty while adding.
var _edited_id := ""
## The choices of the platform edited as stored, and whether the user changed any of them but its model.
var _stored: AndroidServices.PlatformSetup
var _touched := false
## The platforms the form cannot set up: those on the ring already.
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
## The gel's colour now, and whether the note is the one that games were found.
var _rim := StudioTokens.NEUTRAL
var _found := false
var _title_line: StudioText
var _note_line: StudioText
## Platform id to the folder of its console under res://carousel/consoles.
var _folders: Dictionary[String, String] = {}
## The models of the console chosen, and the one the console had as the form opened.
var _variants: Array[ConsoleManifest] = []
var _had_model := ""
## Remove's place in add mode, Cancel's.
var _cancel_x := 0.0
var _card: FormPaint.Card
var _dot: FormPaint.Layer
var _leaving := false
## Whether the form has gone for the ring placing its console, and is not back.
var _away := false
## Where each moving part rests, and each motion running.
var _rests: Dictionary[Control, Vector2] = {}
var _motions: Dictionary[StringName, Tween] = {}
var _fields: Array[Control] = []

@onready var _backdrop: Cyclorama = $Backdrop
@onready var _title: Label = %Title
@onready var _list: Control = $List
@onready var _type: StepField = %Type
@onready var _emulator: StepField = %Emulator
@onready var _folder_field: StepField = %Folder
@onready var _model: ModelField = %Model
@onready var _models: ModelSwatches = %Models
@onready var _console: RingView = %Console
@onready var _note: Label = %Note
@onready var _subfolders: FormToggle = %Subfolders
@onready var _discs: FormToggle = %Discs
@onready var _cancel: FormPill = %Cancel
@onready var _add: FormPill = %Add
@onready var _choice: StudioChooser = %Choice
@onready var _choose_hint: ButtonHint = %Choose
@onready var _back_hint: ButtonHint = %Back


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)
	for text: Label in [_title, _note]:
		text.add_theme_color_override(&"font_color", Color.TRANSPARENT)
	_title.draw.connect(_draw_title)
	_note.draw.connect(_draw_note)
	_card = FormPaint.Card.new()
	_list.add_child(_card)
	_list.move_child(_card, 0)
	_dot = FormPaint.Layer.new(_note, _dot_material())
	var defaults := Appearance.defaults(ConsoleManifest.found())
	for platform in defaults:
		_folders[platform] = ConsoleManifest.folder_of(defaults[platform])
	_fields = [_type, _emulator, _folder_field, _model, _subfolders, _discs, _cancel, _add]
	for field: Control in _fields:
		field.focus_entered.connect(_aim.bind(field, true))
	for line: Control in [_title, _list, _console, _model]:
		_rests[line] = line.position
	_cancel_x = _cancel.position.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_visible_in_tree() and not _adding and not _leaving and not _choice.visible:
		_read_players(_players[_player].id if _player >= 0 else "")
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_paint(Backdrop.palette.gel(_rim))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _choice.visible or _leaving:
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _models.is_open():
		Sounds.play(SoundEffects.Cue.BACK)
		_models.cancel()
	else:
		_give_up()


## Shows the form as new, nothing chosen, the focus on the type; the platforms already on the ring,
## [param taken], cannot be chosen.
func open(taken := PackedStringArray()) -> void:
	_fill("", AndroidServices.PlatformSetup.new({"folder_depth": "subfolders"}), null, taken)
	_type.grab_focus()
	_aim(_type, false)
	_enter()


## Shows the form filled with [param choices], those of [param edited_id], whose folder is
## [param folder], its type locked; the focus on the emulator.
func edit(edited_id: String, choices: AndroidServices.PlatformSetup, folder: AndroidServices.Folder) -> void:
	_fill(edited_id, choices, folder, PackedStringArray())
	_emulator.grab_focus()
	_aim(_emulator, false)
	_enter()


func is_editing() -> bool:
	return not _edited_id.is_empty()


## Back from the confirmation of a removal: the focus on "Remove", and a note when it [param failed].
func back_from_removal(failed: bool) -> void:
	if failed:
		_set_note(tr("The console could not be removed."), false)
	_cancel.grab_focus()


## The choices made, as the plugin takes them.
func setup() -> AndroidServices.PlatformSetup:
	var choices := AndroidServices.PlatformSetup.new()
	choices.has_folder = _has_folder
	choices.folder_uri = _folder.uri if _has_folder else ""
	choices.has_player = _player >= 0
	choices.player_id = _players[_player].id if choices.has_player else ""
	choices.folder_depth = "subfolders" if _subfolders.button_pressed else "top_level"
	choices.variant_id = _folders.get(platform_id, "")
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
	_stored = choices
	_touched = false
	_taken = taken
	library = null
	platform_id = edited_id
	var editing := is_editing()
	_title.text = tr("Edit") if editing else tr("Add a console")
	_title_line = FormPaint.line(_title.text, StudioTokens.Face.JAKARTA_800, FormPaint.TITLE_PX, -0.04)
	_type.disabled = editing
	_type.focus_mode = FOCUS_NONE if editing else FOCUS_ALL
	_emulator.focus_neighbor_top = _emulator.get_path_to(_emulator if editing else _type)
	_cancel.text = tr("Remove") if editing else tr("Cancel")
	_cancel.destructive = editing
	_cancel.position.x = _REMOVE_X if editing else _cancel_x
	_add.text = tr("Save") if editing else tr("Add")
	_folder = folder
	_has_folder = choices.has_folder
	_games = -1
	_subfolders.set_pressed_no_signal(choices.folder_depth == "subfolders")
	_discs.set_pressed_no_signal(choices.disc_grouping == "grouped")
	_subfolders.snap()
	_discs.snap()
	_leaving = false
	_form_back()
	_console.ring = ring
	_console.sun = sun
	_models.ring = ring
	_models.sun = sun
	_use_variants(choices.variant_id)
	_had_model = _folders.get(platform_id, "")
	_show_console(true)
	_show_type()
	_show_folder()
	_show_gel(false)
	_read_players(choices.player_id)


## The installed players, [param preferred_id] chosen if it is one of them, else none; then the
## count again with it.
func _read_players(preferred_id := "") -> void:
	_games = -1
	# A count still on its way belongs to the players as they were.
	_counts += 1
	_players.clear()
	if platform_id:
		_players = android.installed_players(platform_id)
	_player = _players.find_custom(func(player: AndroidServices.Player) -> bool: return player.id == preferred_id)
	_show_player()
	_show_count()
	_count(false)


func _show_type() -> void:
	_type.show_value(platform_name() if platform_id else tr("Choose…"), not platform_id.is_empty())


func _show_folder() -> void:
	_folder_field.show_value(folder_place(_folder) if _has_folder else tr("Choose…"), _has_folder)


func _show_player() -> void:
	_emulator.show_value(_players[_player].emulator_name if _player >= 0
		else tr("None installed") if platform_id and _players.is_empty() else tr("Choose…"), _player >= 0)


## Once an emulator is chosen, the files it accepts until a folder is chosen, then how many games
## that holds; "Add" only when there are some.
func _show_count() -> void:
	if platform_id and _players.is_empty():
		_set_note(tr("Install an emulator for this console, then come back."), false)
	elif _player < 0:
		_set_note("", false)
	elif _games < 0:
		var extensions := _players[_player].extensions
		_set_note(tr("Accepted files: {extensions}").format({"extensions": " ".join(Array(extensions).map(
			func(extension: String) -> String: return "." + extension))}) if not extensions.is_empty() else "", false)
	else:
		_set_note(tr_n("{count} compatible game found", "{count} compatible games found", _games).format(
			{"count": _games}) if _games > 0 else tr("No compatible game in this folder"), _games > 0)
	_add.disabled = _games <= 0 and not _model_only()
	# Greyed, "Add" cannot keep the focus: it goes back to the folder, never nowhere.
	if _add.disabled and _add.has_focus():
		_folder_field.grab_focus()
	_add.focus_mode = Control.FOCUS_NONE if _add.disabled else Control.FOCUS_ALL
	_discs.focus_neighbor_bottom = _discs.get_path_to(_cancel if _add.disabled else _add)


func _set_note(shown: String, found: bool) -> void:
	_note.text = shown
	_found = found
	_note_line = FormPaint.line(shown, StudioTokens.Face.JAKARTA_800 if found else StudioTokens.Face.PLEX_600,
		_NOTE_FOUND_PX if found else _NOTE_PX, -0.01 if found else 0.03)
	_note.queue_redraw()


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
	if _leaving:
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	var offered: Array[AndroidServices.OfferedConsole] = []
	offered.assign(android.catalog.offered.filter(func(console: AndroidServices.OfferedConsole) -> bool:
		return console.id not in _taken))
	if offered.is_empty():
		return
	var current := offered.find_custom(func(console: AndroidServices.OfferedConsole) -> bool: return console.id == platform_id)
	_choice.console_folders = _folders
	_step_aside()
	var index := await _choice.choose_console(offered, current)
	var changed := index >= 0 and offered[index].id != platform_id
	var from := _choice.cursor_rect()
	_type.grab_focus()
	if changed:
		platform_id = offered[index].id
		_use_variants(_folders[platform_id])
		Diagnostics.trace("console form", "platform %s" % platform_id)
		_show_type()
		_show_console(true)
		_show_gel(true)
		_read_players()
	_come_back(from)


func _on_emulator_pressed() -> void:
	if _leaving:
		return
	if _players.is_empty():
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	_step_aside()
	_choice.console_folders = _folders
	var index := await _choice.choose_player(platform_id, _players, _player)
	var from := _choice.cursor_rect()
	_emulator.grab_focus()
	_come_back(from)
	if index < 0 or index == _player:
		return
	_player = index
	_touched = true
	_games = -1
	Diagnostics.trace("console form", "emulator %s" % _players[_player].id)
	_show_player()
	_show_count()
	_count(false)


func _on_folder_pressed() -> void:
	if _leaving:
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	var pick := await android.pick_folder()
	if not pick.ok:
		Diagnostics.trace("console form", "no folder picked (%s)" % pick.code)
		return
	_folder = pick.folder
	_has_folder = true
	_touched = true
	_show_folder()
	await _count(true)


func _on_option_toggled(on: bool) -> void:
	Sounds.play(SoundEffects.Cue.TOGGLE if on else SoundEffects.Cue.UNTOGGLE)
	_touched = true
	var choices := setup()
	Diagnostics.trace("console form", "%s, %s" % [choices.folder_depth, choices.disc_grouping])
	_games = -1
	_show_count()
	_count(false)


## "Cancel", or "Remove" while editing.
func _on_cancel_pressed() -> void:
	if _leaving:
		return
	if _edited_id and not _adding:
		Sounds.play(SoundEffects.Cue.REMOVE)
		closed.emit(Outcome.REMOVE)
	else:
		_give_up()


func _give_up() -> void:
	if _adding or _leaving:
		return
	Diagnostics.trace("console form", "given up")
	Sounds.play(SoundEffects.Cue.BACK)
	_leaving = true
	# Unless the save stored the new model before its scan failed.
	if is_editing() and library == null and _folders[platform_id] != _had_model:
		_folders[platform_id] = _had_model
		model_shown.emit(_had_model)
	leaving.emit()
	await _leave().finished
	closed.emit(Outcome.GIVEN_UP)


func _on_add_pressed() -> void:
	if _leaving:
		return
	if _adding:
		return
	_adding = true
	_add.disabled = true
	Sounds.play(SoundEffects.Cue.SELECT)
	var started := Time.get_ticks_msec()
	saving.emit(true)
	if not is_editing():
		leave()
	var model_only := _model_only()
	var choices := setup()
	if model_only:
		choices = AndroidServices.PlatformSetup.new(_stored.to_wire())
		choices.variant_id = _folders[platform_id]
	var stored := await android.set_up_platform(platform_id, choices)
	if not stored.ok:
		_not_added(stored)
		return
	library = stored.library
	if not model_only:
		var scanned := await android.scan_platform(platform_id)
		if not scanned.ok:
			_not_added(scanned)
			return
		library = scanned.library
		Diagnostics.trace("console form", "%s saved: %d games in %d ms" % [platform_id, scanned.report.games,
			scanned.report.milliseconds])
		# The folder changed since it was counted: nothing to show, the form stays.
		if scanned.report.games == 0:
			saving.emit(false)
			resume()
			_adding = false
			_games = 0
			_show_count()
			return
	if is_editing():
		_leaving = true
		leaving.emit()
		await _leave().finished
	_adding = false
	saving.emit(false)
	Diagnostics.trace("console form", "added in %d ms after immediate departure" % (Time.get_ticks_msec() - started))
	closed.emit(Outcome.DONE)


func _not_added(failed: AndroidServices.Result) -> void:
	Diagnostics.trace("console form", "console not added (%s): %s" % [failed.code, failed.detail])
	saving.emit(false)
	resume()
	_adding = false
	_set_note(tr("The console could not be saved.") if is_editing() else tr("The console could not be added."), false)
	_add.disabled = false


## Whether, editing, only the model changed: it is saved as it is, the games neither counted nor scanned again.
func _model_only() -> bool:
	return is_editing() and not _touched and _folders[platform_id] != _had_model


## The models of the platform chosen, the one in [param current] shown if it is one of them, else its base model.
func _use_variants(current: String) -> void:
	_variants.clear()
	if platform_id:
		_variants = Appearance.defaults(ConsoleManifest.found())[platform_id].models()
		var kept := _variants.find_custom(func(model: ConsoleManifest) -> bool:
			return ConsoleManifest.folder_of(model) == current)
		_folders[platform_id] = ConsoleManifest.folder_of(_variants[maxi(kept, 0)])
	_show_model()


## The model line: the console's model, choosable when it has more than one; the focus goes round it otherwise.
func _show_model() -> void:
	var at := _model_index()
	_model.show_model(_variants[at].model_name if at >= 0 else "", _variants.size() > 1)
	var choosable := _model.focus_mode != FOCUS_NONE
	var below: Control = _model if choosable else _subfolders
	var above: Control = _model if choosable else _folder_field
	_folder_field.focus_neighbor_bottom = _folder_field.get_path_to(below)
	_subfolders.focus_neighbor_top = _subfolders.get_path_to(above)


## Where the model shown is among [member _variants]; -1 for none.
func _model_index() -> int:
	var folder: String = _folders.get(platform_id, "")
	return _variants.find_custom(func(model: ConsoleManifest) -> bool: return ConsoleManifest.folder_of(model) == folder)


## The console chosen at the left, as the consoles screen will show it; [param framed], filling the left.
func _show_console(framed: bool) -> void:
	_console.visible = not platform_id.is_empty()
	if platform_id:
		_console.show_console(platform_id, _folders[platform_id], framed)


func _on_model_pressed() -> void:
	if _leaving or _models.is_open():
		return
	Sounds.play(SoundEffects.Cue.OPEN)
	_model.open = true
	_model.models = _variants.size()
	_model.focused = _model_index()
	_models.rim = _rim
	_models.open(platform_id, _variants, _model_index())
	_make_way(true)


## The lines make way while the models' chooser is open, and come back: they fade, the model line going up to head
## the column (the focus card fading with it); the hints say what A and B do there.
func _make_way(away: bool) -> void:
	var way: Tween = _motions.get(&"way")
	var motion := Motion.restart(self, way).set_parallel()
	_motions[&"way"] = motion
	var easing := Motion.curve(Motion.Easing.EASE)
	for line: Control in [_type, _emulator, _folder_field, _note, _subfolders, _discs, _cancel, _add]:
		motion.tween_property(line, ^"modulate:a", 0.0 if away else 1.0, _MAKE_WAY_S).set_custom_interpolator(easing)
	motion.tween_property(_model, ^"position:y", _HEADER_Y if away else _rests[_model].y, _MAKE_WAY_S) \
		.set_custom_interpolator(easing)
	if away:
		motion.tween_property(_card, ^"modulate:a", 0.0, _MAKE_WAY_S * 0.6)
		_models.modulate.a = 0.0
		motion.tween_property(_models, ^"modulate:a", 1.0, _MAKE_WAY_S).set_delay(_MAKE_WAY_S * 0.5)
	else:
		# Back on the line once it is back in its place.
		motion.tween_callback(_aim.bind(_model, false)).set_delay(_MAKE_WAY_S)
		motion.tween_property(_card, ^"modulate:a", 1.0, _MAKE_WAY_S * 0.6).set_delay(_MAKE_WAY_S)
	_choose_hint.text = "Keep" if away else "Choose"
	_back_hint.text = "Back" if away else "Cancel"


func _on_model_looked(index: int) -> void:
	var folder := ConsoleManifest.folder_of(_variants[index])
	if folder == _folders[platform_id]:
		return
	_folders[platform_id] = folder
	_model.show_model(_variants[index].model_name, true)
	_model.focused = index
	_console.show_console(platform_id, folder, false)
	if is_editing():
		model_shown.emit(folder)


func _on_models_closed(index: int) -> void:
	_on_model_looked(index)
	_show_count()
	_model.open = false
	_make_way(false)
	_model.grab_focus()
	Diagnostics.trace("console form", "model %s" % _folders[platform_id])


func _gel() -> Color:
	return Backdrop.palette.gel(ConsoleManifest.gel_of(_folders[platform_id] if _folders.has(platform_id) else ""))


## The gel of the console chosen on everything the form paints with it.
func _show_gel(animated: bool) -> void:
	var gel := _gel()
	if not animated:
		_paint(gel)
		return
	var from := Backdrop.palette.gel(_rim)
	Motion.animate(self, _motions, &"rim", StudioTokens.GEL_FADE_S, Motion.Easing.EASE, func(p: float) -> void: _paint(from.lerp(gel, p)))


func _paint(gel: Color) -> void:
	_rim = gel
	_backdrop.gel = gel
	_card.rim = gel
	for field: Control in _fields:
		field.set(&"rim", gel)
	_dot.shown.colors.assign([gel, gel])
	_dot.tint = gel


func _dot_material() -> StudioMaterial:
	var colors: Array[Color] = [_rim, _rim]
	return FormPaint.material(colors, _DOT / 2.0, [[Vector4(0.0, 0.0, 0.8 * _CQW, 0.0), Color.WHITE, false, true]])


## Where the card goes for the control that has the focus: its box, grown to a ring round a pill.
func _aim(control: Control, animated: bool) -> void:
	var pill := control is FormPill
	var rect := Rect2(control.position, control.size).grow(_PILL_RING if pill else 0.0)
	var radius := _PILL_RING_RADIUS if pill else StudioTokens.FOCUS_RADIUS
	_card.bare = pill
	# Round Remove, the ring is red.
	_card.rim = FormPill.red() if pill and (control as FormPill).destructive else _rim
	if not animated:
		for key in _CARD_MOTIONS:
			if key in _motions:
				_motions[key].kill()
		_card.position = rect.position
		_card.size = rect.size
		_card.radius = radius
		return
	_glide_card(rect, radius, _CARD_S, Motion.Easing.FOCUS, Motion.Easing.EASE)


## The card from where it is to [param rect] over [param seconds]: its place by [param moving], its size and
## radius by [param growing].
func _glide_card(rect: Rect2, radius: float, seconds: float, moving: Motion.Easing, growing: Motion.Easing) -> void:
	var from := Rect2(_card.position, _card.size)
	var from_radius := _card.radius
	Motion.animate(self, _motions, &"card_position", seconds, moving,
		func(p: float) -> void: _card.position = from.position.lerp(rect.position, p))
	Motion.animate(self, _motions, &"card_size", seconds, growing, func(p: float) -> void:
		_card.size = from.size.lerp(rect.size, p)
		_card.radius = lerpf(from_radius, radius, p))


## Every part of the form where it rests, whole.
func _settle_lines() -> void:
	_stop_lines()
	modulate.a = 1.0
	for line: Control in _rests:
		line.position = _rests[line]
		line.modulate.a = 1.0


## The motions of the lines stopped where they are: the next one starts from there, nothing jumps.
func _stop_lines() -> void:
	for key in _LINE_MOTIONS:
		if key in _motions:
			_motions[key].kill()


## The form half of the "+" ball to form transition: the screen fades in, the console comes up, the list in from
## the right, the title up from a little lower.
func _enter() -> void:
	_settle_lines()
	modulate.a = 0.0
	var motion := create_tween().set_parallel()
	_motions[&"enter"] = motion
	motion.tween_property(self, ^"modulate:a", 1.0, StudioTokens.TR_FORM_FADE_S).set_delay(StudioTokens.TR_FORM_AT_S) \
		.set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	_console.position.y += StudioTokens.TR_FORM_LIFT_PX
	motion.tween_property(_console, ^"position:y", _rests[_console].y,
		_ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S).set_custom_interpolator(arrive)
	_list.position.x += StudioTokens.TR_FORM_SLIDE_PX
	motion.tween_property(_list, ^"position:x", _rests[_list].x, _ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S).set_custom_interpolator(arrive)
	_title.position.y += StudioTokens.TR_FORM_CHOOSER_TITLE_PX
	motion.tween_property(_title, ^"position:y", _rests[_title].y, _ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S) \
		.set_custom_interpolator(arrive)


## The form goes, taking no press and no focus, the console just added flying to its place on the ring; hidden once
## gone. Returns the motion; [method resume] brings it back as it was filled.
func leave() -> Tween:
	_away = true
	get_viewport().gui_release_focus()
	var motion := _leave()
	# Bound to the screens, which keep going while the form takes nothing.
	motion.bind_node(get_parent())
	process_mode = Node.PROCESS_MODE_DISABLED
	motion.chain().tween_callback(hide)
	return motion


## The form is back as it was filled, as it comes in (the console, the list and the title), "Add" enabled and
## focused: the console was added and is not placed.
func resume() -> void:
	# Once: a second one would start the form's coming in again from nothing.
	if not _away:
		return
	_form_back()
	show()
	_enter()
	_add.disabled = false
	_add.focus_mode = Control.FOCUS_ALL
	_add.grab_focus()


## The form is no longer gone for its console's placing: it takes presses again, and the hiding its going chained
## cannot hide it once more. Opened again without this, a form left disabled would show nothing and take no press.
func _form_back() -> void:
	_away = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if &"leave" in _motions:
		_motions[&"leave"].kill()


## The form half of the form to "+" ball transition: the screen fades out as the list slides off to the right
## and the console sinks. Returns the motion, finished when the form is gone.
func _leave() -> Tween:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"leave"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(self, ^"modulate:a", 0.0, _LEAVE_FADE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"position:x", _rests[_list].x + StudioTokens.TR_FORM_SLIDE_PX,
		StudioTokens.TR_FORM_LEAVE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_console, ^"position:y", _rests[_console].y + StudioTokens.TR_FORM_LIFT_PX,
		StudioTokens.TR_FORM_LEAVE_S).set_custom_interpolator(ease_in)
	return motion


## The form half of the form to chooser transition: the lines leave to the left, the title goes up, the console fades
## out, and the card glides to the chooser's cursor.
func _step_aside() -> void:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"lines"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(_list, ^"position:x", _rests[_list].x - StudioTokens.TR_CHOOSER_SHIFT_PX,
		StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"modulate:a", 0.0, StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_title, ^"position:y", _rests[_title].y - StudioTokens.TR_FORM_CHOOSER_TITLE_PX,
		StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_title, ^"modulate:a", 0.0, StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_console, ^"modulate:a", 0.0, StudioTokens.TR_CHOOSER_MODEL_S)
	var from := Rect2(_card.position, _card.size)
	var from_radius := _card.radius
	Motion.animate(self, _motions, &"card_position", StudioTokens.TR_CHOOSER_CARD_S, StudioTokens.TR_CHOOSER_CARD_S_CURVE,
		func(p: float) -> void:
		var to := _choice.cursor_rect()
		_card.position = from.position.lerp(to.position - _list.global_position, p)
		_card.size = from.size.lerp(to.size, p)
		_card.radius = lerpf(from_radius, StudioTokens.FOCUS_RADIUS, p))


## The way back of [method _step_aside], from wherever it was: the lines and the console come back, and the card
## glides from the chooser's cursor to the field.
func _come_back(cursor: Rect2) -> void:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"lines"] = motion
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	motion.tween_property(_list, ^"position:x", _rests[_list].x, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_list, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_title, ^"position:y", _rests[_title].y, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_title, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_console, ^"modulate:a", 1.0, _MODEL_RISE_S).set_custom_interpolator(Motion.curve(Motion.Easing.RISE))
	_card.position = cursor.position - _rests[_list]
	_card.size = cursor.size
	_card.radius = StudioTokens.FOCUS_RADIUS
	var field := get_viewport().gui_get_focus_owner()
	if field in _fields:
		_glide_card(Rect2(field.position, field.size), StudioTokens.FOCUS_RADIUS, StudioTokens.TR_CHOOSER_CARD_S,
			StudioTokens.TR_CHOOSER_CARD_S_CURVE, StudioTokens.TR_CHOOSER_CARD_S_CURVE)


func _draw_title() -> void:
	if _title_line == null:
		return
	_title_line.draw(_title, Vector2.ZERO, Backdrop.palette.ink)


## The note, centred in its box, a dot in the gel before it when games were found.
func _draw_note() -> void:
	if _note_line == null:
		return
	var middle := _note.size.y / 2.0
	var found := _found and not _note.text.is_empty()
	var left := _DOT + _DOT_GAP if found else 0.0
	var px := _NOTE_FOUND_PX if found else _NOTE_PX
	var line := (FormPaint.JAKARTA_LINE if found else FormPaint.PLEX_LINE) * px
	var ascent := (FormPaint.JAKARTA_ASCENT if found else FormPaint.PLEX_ASCENT) * px
	if found:
		_dot.place(Rect2(Vector2(0.0, middle - _DOT / 2.0), Vector2.ONE * _DOT), _DOT / 2.0)
	else:
		_dot.clear()
	_note_line.fit(_note.size.x - left)
	_note_line.draw(_note, Vector2(left, middle - line / 2.0 + ascent - _note_line.baseline),
		Backdrop.palette.ink if found else Backdrop.palette.mute)

