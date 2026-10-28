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
## It is the Studio's numbered list beside a plinth: the console chosen turns on it, its logo and the emulator's name
## on its plate. One card rests on the focused line and moves with the focus.
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
## The form starts to go, given up: the screens behind it may start to come in.
signal leaving
## Slow storage and scanning run behind the departing form.
signal saving(pending: bool)

const _CQW := FormPaint.CQW
const _TITLE_PX := 4.6 * _CQW
const _COUNT_PX := 1.7 * _CQW
## The browser's count sits this far up and left of its box.
const _COUNT_SHIFT := Vector2(-1.0, -1.0)
const _NOTE_PX := 1.45 * _CQW
const _NOTE_FOUND_PX := 1.9 * _CQW
const _DOT := 1.0 * _CQW
const _DOT_GAP := 1.0 * _CQW
const _KICK_PX := 1.4 * _CQW
## The logo box on the plate: its top, the room an empty one keeps, and the gap under it.
const _PLATE_PAD := 1.4 * _CQW
const _LOGO_MIN := 4.6 * _CQW
const _PLATE_GAP := 0.3 * _CQW
## Where the overview's plate puts "No console" against the middle of the logo's box (px, from the picture).
const _NO_TYPE_DROP := 6.0
const _PLATE_S := 0.22
const _PLATE_RISE := 0.6 * _CQW
## How far past a pill button its ring stands.
const _PILL_RING := 0.7 * _CQW
## The corners of that ring, as the design's table gives them whatever the pill's height.
const _PILL_RING_RADIUS := 3.5 * _CQW
const _CARD_S := 0.24
const _CARD_MOTIONS: Array[StringName] = [&"card_position", &"card_size"]
const _LINE_MOTIONS: Array[StringName] = [&"enter", &"lines", &"leave"]
static var _CARD_FLIGHT_S: float:
	get: return StudioTokens.TR_CHOOSER_CARD_S
## The form's own motion, in seconds and px: the "+" ball to form transition (its form half), and the form to
## chooser transition (its form half).
static var _ENTER_AT_S: float:
	get: return StudioTokens.TR_FORM_AT_S
static var _ENTER_FADE_S: float:
	get: return StudioTokens.TR_FORM_FADE_S
const _ENTER_S := 0.32
static var _ENTER_LIFT: float:
	get: return StudioTokens.TR_FORM_LIFT_PX
static var _ENTER_SLIDE: float:
	get: return StudioTokens.TR_FORM_SLIDE_PX
static var _ENTER_RISE: float:
	get: return StudioTokens.TR_FORM_CHOOSER_TITLE_PX
const _LEAVE_FADE_S := 0.3
static var _LEAVE_S: float:
	get: return StudioTokens.TR_FORM_LEAVE_S
static var _ASIDE_S: float:
	get: return StudioTokens.TR_CHOOSER_OUT_S
static var _ASIDE_SHIFT: float:
	get: return StudioTokens.TR_CHOOSER_SHIFT_PX
static var _ASIDE_MODEL_S: float:
	get: return StudioTokens.TR_CHOOSER_MODEL_S
const _COME_BACK_S := 0.23
## The model rising again after a chooser: from this far down (px), in this time, as the plinth's own rise.
const _MODEL_RISE := 1.6 * _CQW
const _MODEL_RISE_S := 0.3

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

## The gel's colour now, and whether the note is the one that games were found.
var _rim := StudioTokens.NEUTRAL
var _found := false
var _title_line: StudioText
var _note_line: StudioText
## Platform id to the folder of its console under res://carousel/consoles.
var _folders: Dictionary[String, String] = {}
var _variants: Array[ConsoleManifest] = []
var _variant := 0
var _plinth: Plinth
var _logo: LogoView
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
@onready var _count_node: Control = $Count
@onready var _plate: Control = $Plate
@onready var _list: Control = $List
@onready var _type: StepField = %Type
@onready var _emulator: StepField = %Emulator
@onready var _folder_field: StepField = %Folder
@onready var _note: Label = %Note
@onready var _subfolders: FormToggle = %Subfolders
@onready var _discs: FormToggle = %Discs
@onready var _cancel: FormPill = %Cancel
@onready var _add: FormPill = %Add
@onready var _choice: StudioChooser = %Choice


func _ready() -> void:
	for text: Label in [_title, _note]:
		text.add_theme_color_override(&"font_color", Color.TRANSPARENT)
	_title.draw.connect(_draw_title)
	_note.draw.connect(_draw_note)
	_count_node.draw.connect(_draw_count)
	_plate.draw.connect(_draw_plate)
	_logo = LogoView.new()
	_plate.add_child(_logo)
	_card = FormPaint.Card.new()
	_list.add_child(_card)
	_list.move_child(_card, 0)
	_dot = FormPaint.Layer.new(_note, _dot_material())
	var defaults := Appearance.defaults(ConsoleManifest.found())
	for platform in defaults:
		_folders[platform] = ConsoleManifest.folder_of(defaults[platform])
	_fields = [_type, _emulator, _folder_field, _subfolders, _discs, _cancel, _add]
	for field: Control in _fields:
		field.focus_entered.connect(_aim.bind(field, true))
	for line: Control in [_title, _count_node, _list, _plate]:
		_rests[line] = line.position


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_visible_in_tree() and not _adding and not _leaving and not _choice.visible:
		_read_players(_players[_player].id if _player >= 0 else "")


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _choice.visible or _leaving:
		return
	if event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_give_up()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _choice.visible or _leaving:
		return
	if not _adding and not event.is_echo() and _variants.size() > 1 			and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")) 			and get_viewport().gui_get_focus_owner() in [_type, _emulator, _folder_field]:
		get_viewport().set_input_as_handled()
		_variant = posmod(_variant + (1 if event.is_action_pressed(&"ui_right") else -1), _variants.size())
		_folders[platform_id] = ConsoleManifest.folder_of(_variants[_variant])
		_plinth.show_console(_folders[platform_id])


## Shows the form as new, nothing chosen, the focus on the type; the platforms already set up,
## [param taken], cannot be chosen.
func open(taken := PackedStringArray()) -> void:
	_fill("", AndroidServices.PlatformSetup.new({"folder_depth": "subfolders"}), null, taken)
	_type.grab_focus()
	_aim(_type, false)
	_enter()


## Shows the form filled with [param choices], those of [param edited_id], whose folder is
## [param folder]; its type cannot become one of the other platforms set up, [param taken]. The
## focus on the emulator.
func edit(edited_id: String, choices: AndroidServices.PlatformSetup, folder: AndroidServices.Folder,
		taken: PackedStringArray) -> void:
	_fill(edited_id, choices, folder, taken)
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


## How many of the three fields (type, emulator, folder) are chosen.
func steps() -> int:
	return int(not platform_id.is_empty()) + int(_player >= 0) + int(_has_folder)


## What the plate says under the logo: the emulator chosen, "No console" while there is no console chosen, nothing between.
func plate_name() -> String:
	if platform_id.is_empty():
		return tr("No console")
	return _players[_player].emulator_name if _player >= 0 else ""


## The plinth the console chosen turns on.
func plinth() -> Plinth:
	return _plinth


## The card resting on the focused control.
func card() -> FormPaint.Card:
	return _card


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
	_title_line = FormPaint.line(_title.text, StudioTokens.Face.JAKARTA_800, _TITLE_PX, -0.04)
	_cancel.text = tr("Remove") if edited_id else tr("Cancel")
	_cancel.keyed = edited_id.is_empty()
	_add.text = tr("Save") if edited_id else tr("Add")
	_folder = folder
	_has_folder = choices.has_folder
	_games = -1
	_subfolders.set_pressed_no_signal(choices.folder_depth == "subfolders")
	_discs.set_pressed_no_signal(choices.disc_grouping == "grouped")
	_subfolders.snap()
	_discs.snap()
	_leaving = false
	_form_back()
	_use_variants(choices.variant_id)
	_present_plinth()
	_show_type()
	_show_folder()
	_show_gel(false)
	_read_players(choices.player_id)
	_show_plate(false)


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
	_showsteps()


func _show_folder() -> void:
	_folder_field.show_value(folder_place(_folder) if _has_folder else tr("Choose…"), _has_folder)
	_showsteps()


func _show_player() -> void:
	_emulator.show_value(_players[_player].emulator_name if _player >= 0
		else tr("None installed") if platform_id and _players.is_empty() else tr("Choose…"), _player >= 0)
	_showsteps()
	_plate.queue_redraw()


## How many of the three fields are chosen, for the count and the trace.
func _showsteps() -> void:
	_count_node.queue_redraw()
	Diagnostics.trace("console form", "step=%d" % steps())


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
	_add.disabled = _games <= 0
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
	_come_back(from, not changed)
	if not changed:
		return
	platform_id = offered[index].id
	_use_variants(_folders[platform_id])
	Diagnostics.trace("console form", "platform %s" % platform_id)
	_show_type()
	_plinth.show_console(_folders[platform_id])
	_show_gel(true)
	_show_plate(true)
	_read_players()


func _on_emulator_pressed() -> void:
	if _leaving:
		return
	if _players.is_empty():
		return
	_step_aside()
	_choice.console_folders = _folders
	var index := await _choice.choose_player(platform_id, _players, _player)
	var from := _choice.cursor_rect()
	_emulator.grab_focus()
	_come_back(from, true)
	if index < 0 or index == _player:
		return
	_player = index
	_games = -1
	Diagnostics.trace("console form", "emulator %s" % _players[_player].id)
	_show_player()
	_show_plate(true)
	_show_count()
	_count(false)


func _on_folder_pressed() -> void:
	if _leaving:
		return
	var pick := await android.pick_folder()
	if not pick.ok:
		Diagnostics.trace("console form", "no folder picked (%s)" % pick.code)
		return
	_folder = pick.folder
	_has_folder = true
	_show_folder()
	await _count(true)


func _on_option_toggled(_on: bool) -> void:
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
		closed.emit(Outcome.REMOVE)
	else:
		_give_up()


func _give_up() -> void:
	if _adding or _leaving:
		return
	Diagnostics.trace("console form", "given up")
	_leaving = true
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
	var started := Time.get_ticks_msec()
	if not is_editing():
		saving.emit(true)
		leave()
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
		saving.emit(false)
		resume()
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
	saving.emit(false)
	Diagnostics.trace("console form", "added in %d ms after immediate departure" % (Time.get_ticks_msec() - started))
	closed.emit(Outcome.DONE)


func _not_added(failed: AndroidServices.Result) -> void:
	Diagnostics.trace("console form", "console not added (%s): %s" % [failed.code, failed.detail])
	saving.emit(false)
	resume()
	_adding = false
	_set_note(tr("The console could not be added."), false)
	_add.disabled = false


## A new plinth, the console of the platform chosen standing on it (none while nothing is chosen), so its picture
## is presented again; the plate's own logo is the form's, set apart.
func _use_variants(current: String) -> void:
	_variants.clear()
	_variant = 0
	if platform_id.is_empty():
		return
	var base := Appearance.defaults(ConsoleManifest.found())[platform_id]
	_variants = base.models()
	for i in _variants.size():
		if ConsoleManifest.folder_of(_variants[i]) == current:
			_variant = i
	_folders[platform_id] = ConsoleManifest.folder_of(_variants[_variant])


func _present_plinth() -> void:
	if not _plinth:
		_plinth = Plinth.create()
		_plinth.name = "Plinth"
		_plinth.position = StudioTokens.PLINTH.position
		_plinth.size = StudioTokens.PLINTH.size
		add_child(_plinth)
		move_child(_plinth, _backdrop.get_index() + 1)
	(_plinth.get_node("Plate") as Control).hide()
	if _folders.has(platform_id):
		_plinth.show_console(_folders[platform_id])
		_plinth.restart()
	else:
		_plinth.clear()


func _gel() -> Color:
	return StudioTokens.GEL.get(StringName(_folders[platform_id] if _folders.has(platform_id) else ""), StudioTokens.NEUTRAL)


## The gel of the console chosen on everything the form paints with it.
func _show_gel(animated: bool) -> void:
	var gel := _gel()
	if not animated:
		_paint(gel)
		return
	var from := _rim
	_animate(&"rim", StudioTokens.GEL_FADE_S, Motion.Easing.EASE, func(p: float) -> void: _paint(from.lerp(gel, p)))


func _paint(gel: Color) -> void:
	_rim = gel
	_card.rim = gel
	for field: Control in _fields:
		field.set(&"rim", gel)
	_dot.shown.colors.assign([gel, gel])
	_dot.tint = gel
	_count_node.queue_redraw()


func _dot_material() -> StudioMaterial:
	var colors: Array[Color] = [_rim, _rim]
	return FormPaint.material(colors, _DOT / 2.0, [[Vector4(0.0, 0.0, 0.8 * _CQW, 0.0), Color.WHITE, false, true]])


## The logo of the console chosen and the emulator's name on the plate; with [param popping], fading in from a little
## lower.
func _show_plate(popping: bool) -> void:
	var shown := _folders.has(platform_id) and _logo.show_logo(LogoView.Slot.FORM_PLATE, _folders[platform_id])
	_logo.visible = shown
	if shown:
		var plate := StudioTokens.PLINTH.position + StudioTokens.PLINTH_PLATE.position
		_logo.size = _logo.texture.get_size()
		_logo.position = (Vector2(plate.x + StudioTokens.PLINTH_PLATE.size.x / 2.0 - _logo.size.x / 2.0, plate.y + _PLATE_PAD)).round()
	_plate.queue_redraw()
	if popping:
		_animate(&"plate", _PLATE_S, Motion.Easing.EASE_OUT, func(p: float) -> void:
			_plate.modulate.a = clampf(p, 0.0, 1.0)
			_plate.position.y = _rests[_plate].y + _PLATE_RISE * (1.0 - p))


## Where the card goes for the control that has the focus: its box, grown to a ring round a pill.
func _aim(control: Control, animated: bool) -> void:
	var pill := control is FormPill
	var rect := Rect2(control.position, control.size).grow(_PILL_RING if pill else 0.0)
	var radius := _PILL_RING_RADIUS if pill else StudioTokens.FOCUS_RADIUS
	_card.bare = pill
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
	_animate(&"card_position", seconds, moving, func(p: float) -> void: _card.position = from.position.lerp(rect.position, p))
	_animate(&"card_size", seconds, growing, func(p: float) -> void:
		_card.size = from.size.lerp(rect.size, p)
		_card.radius = lerpf(from_radius, radius, p))


## A move of [param key] over [param seconds] by [param easing]: restarts from where the last one was left.
func _animate(key: StringName, seconds: float, easing: Motion.Easing, apply: Callable) -> void:
	if key in _motions:
		_motions[key].kill()
	var tween := create_tween()
	_motions[key] = tween
	tween.tween_method(func(t: float) -> void: apply.call(Motion.eased(easing, t)), 0.0, 1.0, seconds)


## Every part of the form where it rests, whole.
func _settle_lines() -> void:
	_stop_lines()
	modulate.a = 1.0
	for line: Control in _rests:
		line.position = _rests[line]
		line.modulate.a = 1.0
	if _plinth:
		_plinth.position = StudioTokens.PLINTH.position


## The motions of the lines stopped where they are: the next one starts from there, nothing jumps.
func _stop_lines() -> void:
	for key in _LINE_MOTIONS:
		if key in _motions:
			_motions[key].kill()


## The form half of the "+" ball to form transition: the screen fades in, the plinth comes up, the list in from
## the right, the title and the count up from a little lower.
func _enter() -> void:
	_settle_lines()
	modulate.a = 0.0
	var motion := create_tween().set_parallel()
	_motions[&"enter"] = motion
	motion.tween_property(self, ^"modulate:a", 1.0, _ENTER_FADE_S).set_delay(_ENTER_AT_S) \
		.set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	_plinth.position.y += _ENTER_LIFT
	motion.tween_property(_plinth, ^"position:y", StudioTokens.PLINTH.position.y, _ENTER_S).set_delay(_ENTER_AT_S).set_custom_interpolator(arrive)
	_plate.position.y += _ENTER_LIFT
	motion.tween_property(_plate, ^"position:y", _rests[_plate].y, _ENTER_S).set_delay(_ENTER_AT_S).set_custom_interpolator(arrive)
	_list.position.x += _ENTER_SLIDE
	motion.tween_property(_list, ^"position:x", _rests[_list].x, _ENTER_S).set_delay(_ENTER_AT_S).set_custom_interpolator(arrive)
	for line: Control in [_title, _count_node]:
		line.position.y += _ENTER_RISE
		motion.tween_property(line, ^"position:y", _rests[line].y, _ENTER_S).set_delay(_ENTER_AT_S).set_custom_interpolator(arrive)


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


## The form is back as it was filled, as it comes in (the plinth, the list, the title and the count), "Add" enabled and
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
## and the plinth sinks. Returns the motion, finished when the form is gone.
func _leave() -> Tween:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"leave"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(self, ^"modulate:a", 0.0, _LEAVE_FADE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"position:x", _rests[_list].x + _ENTER_SLIDE, _LEAVE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_plinth, ^"position:y", StudioTokens.PLINTH.position.y + _ENTER_LIFT, _LEAVE_S).set_custom_interpolator(ease_in)
	return motion


## The form half of the form to chooser transition: the lines leave to the left, the title and the count go up,
## the model fades out, and the card glides to the chooser's cursor.
func _step_aside() -> void:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"lines"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(_list, ^"position:x", _rests[_list].x - _ASIDE_SHIFT, _ASIDE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"modulate:a", 0.0, _ASIDE_S).set_custom_interpolator(ease_in)
	for line: Control in [_title, _count_node]:
		motion.tween_property(line, ^"position:y", _rests[line].y - _ENTER_RISE, _ASIDE_S).set_custom_interpolator(ease_in)
		motion.tween_property(line, ^"modulate:a", 0.0, _ASIDE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_plinth.get_node("Turntable"), ^"modulate:a", 0.0, _ASIDE_MODEL_S)
	var from := Rect2(_card.position, _card.size)
	var from_radius := _card.radius
	_animate(&"card_position", _CARD_FLIGHT_S, StudioTokens.TR_CHOOSER_CARD_S_CURVE, func(p: float) -> void:
		var to := _choice.cursor_rect()
		_card.position = from.position.lerp(to.position - _list.global_position, p)
		_card.size = from.size.lerp(to.size, p)
		_card.radius = lerpf(from_radius, StudioTokens.FOCUS_RADIUS, p))


## The way back of [method _step_aside], from wherever it was: the lines come back, the card glides from the
## chooser's cursor to the field, and the model rises again when the console is the same ([param rise]; another
## one rises by itself).
func _come_back(cursor: Rect2, rise: bool) -> void:
	_stop_lines()
	var motion := create_tween().set_parallel()
	_motions[&"lines"] = motion
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	motion.tween_property(_list, ^"position:x", _rests[_list].x, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_list, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	for line: Control in [_title, _count_node]:
		motion.tween_property(line, ^"position:y", _rests[line].y, _COME_BACK_S).set_custom_interpolator(arrive)
		motion.tween_property(line, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	if rise:
		var model := _plinth.get_node("Turntable") as Control
		var rest := StudioTokens.TURNTABLE.position.y - StudioTokens.PLINTH.position.y
		model.position.y = rest + _MODEL_RISE
		var rising := Motion.curve(Motion.Easing.RISE)
		motion.tween_property(model, ^"modulate:a", 1.0, _MODEL_RISE_S).set_custom_interpolator(rising)
		motion.tween_property(model, ^"position:y", rest, _MODEL_RISE_S).set_custom_interpolator(rising)
	_card.position = cursor.position - _rests[_list]
	_card.size = cursor.size
	_card.radius = StudioTokens.FOCUS_RADIUS
	var field := get_viewport().gui_get_focus_owner()
	if field in _fields:
		_glide_card(Rect2(field.position, field.size), StudioTokens.FOCUS_RADIUS, _CARD_FLIGHT_S, StudioTokens.TR_CHOOSER_CARD_S_CURVE, StudioTokens.TR_CHOOSER_CARD_S_CURVE)


func _draw_title() -> void:
	if _title_line == null:
		return
	_title_line.draw(_title, Vector2.ZERO, StudioTokens.INK)


## The count of fields chosen, in the gel's colour, over the total.
func _draw_count() -> void:
	var number := FormPaint.line("%02d" % steps(), StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08)
	var rest := FormPaint.line(" / 03", StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08)
	number.draw(_count_node, _COUNT_SHIFT, _rim)
	rest.draw(_count_node, _COUNT_SHIFT + Vector2(number.width, 0.0), StudioTokens.MUTE)


## The note, centred in its box as a flex row is, a dot in the gel before it when games were found.
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
		StudioTokens.INK if found else StudioTokens.MUTE)


## The plate: the emulator's name under the logo, or "No console" while none is chosen.
func _draw_plate() -> void:
	var plate := StudioTokens.PLINTH.position + StudioTokens.PLINTH_PLATE.position
	var centre := plate.x + StudioTokens.PLINTH_PLATE.size.x / 2.0
	var top := plate.y + _PLATE_PAD
	var kicker := FormPaint.line(plate_name().to_upper(), StudioTokens.Face.PLEX_600, _KICK_PX, 0.14)
	kicker.fit(StudioTokens.PLINTH_PLATE.size.x)
	var line := FormPaint.PLEX_LINE * _KICK_PX
	var box := _logo.size.y if _logo.visible else _LOGO_MIN
	var row := top + (box - line) / 2.0 + _NO_TYPE_DROP if platform_id.is_empty() else top + box + _PLATE_GAP
	kicker.draw(_plate, Vector2(centre - kicker.width / 2.0, row + FormPaint.PLEX_ASCENT * _KICK_PX - kicker.baseline), StudioTokens.MUTE)
