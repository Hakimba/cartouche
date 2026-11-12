# SPDX-License-Identifier: GPL-3.0-or-later
class_name AddConsole
extends Page
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
## The same form edits a console of the ring (opened for an [Edit]): filled with its choices, titled "Edit", its type
## locked, its buttons read "Remove", set apart at the left in red, and "Save". B gives up: nothing is saved and the
## console shows the model it had again. A new model alone is saved without counting or scanning the games again.
##
## It answers how it closed ([enum Outcome]). What it holds chosen is a [FormChoices]; how it moves, a [FormMotion].

## The form starts to go, given up: the screens behind it may start to come in.
signal leaving
## The console edited is shown as the model in [param folder] on the ring: for a look while choosing, or back.
signal model_shown(folder: String)
## The type [param platform_id] is chosen: its shelf's model may load while the rest of the form is filled.
signal platform_chosen(platform_id: String)

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
## Remove's place, alone at the left of the pills' row.
const _REMOVE_X := 28.16

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
## The choices of the platform edited as stored.
var _stored: AndroidServices.PlatformSetup
## The platforms the form cannot set up: those on the ring already.
var _taken := PackedStringArray()
var _choices := FormChoices.new()
## Counts asked for: only the last one's answer is shown.
var _counts := 0
## How many times the form was filled, and whether a folder pick of this filling is unanswered: one picker at a time,
## its folder only for the form it was asked for.
var _fillings := 0
var _picking := false
## Cartouche came back to the screen while a chooser was open: the players are read again once it closes.
var _resume_held := false
## The gel's colour now, and whether the note is the one that games were found.
var _rim := StudioTokens.NEUTRAL
var _found := false
var _title_line: StudioText
var _note_line: StudioText
## Platform id to the folder of its console under res://carousel/consoles: the one shown, and each platform's default.
var _folders: Dictionary[String, String] = {}
var _default_folders: Dictionary[String, String] = {}
## The models of the console chosen, and the one the console had as the form opened.
var _variants: Array[ConsoleManifest] = []
var _had_model := ""
## Remove's place in add mode, Cancel's.
var _cancel_x := 0.0
var _card: FormPaint.Card
var _dot: SatinPanel.Backing
var _motion: FormMotion
## The gel's fade running.
var _motions: Dictionary[StringName, Tween] = {}
var _fields: Array[Control] = []

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
	_dot = SatinPanel.Backing.of(_note, _dot_material())
	var defaults := Appearance.defaults(ConsoleManifest.found())
	for platform in defaults:
		_default_folders[platform] = ConsoleManifest.folder_of(defaults[platform])
	_fields = [_type, _emulator, _folder_field, _model, _subfolders, _discs, _cancel, _add]
	_motion = FormMotion.new(self, _title, _list, _console, _model, _models, _card, _choice,
		[_type, _emulator, _folder_field, _note, _subfolders, _discs, _cancel, _add], _fields)
	for field: Control in _fields:
		field.focus_entered.connect(_motion.aim.bind(field, true))
	_cancel_x = _cancel.position.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_visible_in_tree() and phase != Phase.BUSY \
			and phase != Phase.LEAVING:
		_resume_held = _choice.visible
		if not _resume_held:
			# Add greyed while they are counted again hands its focus to the folder: it takes it back once they are.
			_read_players(_choices.player_id(), _add.has_focus())
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_paint(Backdrop.palette.gel(_rim))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _choice.visible or phase == Phase.LEAVING:
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _models.is_open():
		Sounds.play(SoundEffects.Cue.BACK)
		_models.cancel()
	else:
		_give_up()


func is_editing() -> bool:
	return not _edited_id.is_empty()


## The choices made, as the plugin takes them.
func setup() -> AndroidServices.PlatformSetup:
	var variant: String = _folders.get(platform_id, "")
	return _choices.setup(_subfolders.button_pressed, _discs.button_pressed, variant)


## Where [param folder] is, as the user reads it: "SD card › ROMs › ps2".
static func folder_place(folder: AndroidServices.Folder) -> String:
	if not folder.has_volume:
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


## The form goes, taking no press and no focus, the console just added flying to its place on the ring; hidden once
## gone. Returns the motion; [method resume] brings it back as it was filled.
func leave() -> Tween:
	get_viewport().gui_release_focus()
	var motion := _motion.leave()
	# Bound to the screens, which keep going while the form takes nothing.
	motion.bind_node(get_parent())
	process_mode = Node.PROCESS_MODE_DISABLED
	motion.chain().tween_callback(hide)
	return motion


## The form is back as it was filled, as it comes in (the console, the list and the title), "Add" enabled and
## focused: the console was added and is not placed.
func resume() -> void:
	# Once, and only a form that went ([method leave]): a second one would start its coming in again from nothing.
	if process_mode != Node.PROCESS_MODE_DISABLED:
		return
	_form_back()
	show()
	_motion.enter()
	_add.disabled = false
	_add.focus_mode = Control.FOCUS_ALL
	_add.grab_focus()


## The ring sends the form back as the console flies back to it ([method resume]): its presses are held until the
## console is back ([method came_back]).
func come_back() -> void:
	phase = Phase.ENTERING
	resume()


## The placing is over: a form sent back takes its presses.
func came_back() -> void:
	if phase == Phase.ENTERING:
		phase = Phase.LIVE


## For a list of platform ids (a [PackedStringArray]), shows the form as new, nothing chosen, the focus on the
## type: those platforms, already on the ring, cannot be chosen. For an [Edit], shows it filled with that console's
## choices, its type locked, the focus on the emulator. For a [Kept], the form is back as it was left from the
## confirmation of a removal: the focus on "Remove", and a note when the removal failed.
func _open(request: Variant) -> void:
	if request is Kept:
		var kept: Kept = request
		_back_from_removal(kept.failed)
		return
	if request is Edit:
		var edit: Edit = request
		_fill(edit.edited_id, edit.choices, edit.folder, PackedStringArray())
		_emulator.grab_focus()
		_motion.aim(_emulator, false)
	else:
		var taken: PackedStringArray = request
		_fill("", AndroidServices.PlatformSetup.new({"folder_depth": "subfolders"}), null, taken)
		_type.grab_focus()
		_motion.aim(_type, false)
	_motion.enter()


func _back_from_removal(failed: bool) -> void:
	if failed:
		_set_note(tr("The console could not be removed."), false)
	_cancel.grab_focus()


func _fill(edited_id: String, choices: AndroidServices.PlatformSetup, folder: AndroidServices.Folder,
		taken: PackedStringArray) -> void:
	# An answer still on its way belongs to the form as it was.
	_counts += 1
	_fillings += 1
	_picking = false
	_edited_id = edited_id
	_stored = choices
	_choices.touched = false
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
	_choices.folder = folder
	_choices.has_folder = choices.has_folder_uri
	_choices.games = -1
	_subfolders.set_pressed_no_signal(choices.folder_depth == "subfolders")
	_discs.set_pressed_no_signal(choices.disc_grouping == "grouped")
	_subfolders.snap()
	_discs.snap()
	_form_back()
	# A model looked at on a form given up is not this one's.
	_folders = _default_folders.duplicate()
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
## count again with it, the platform's tables prepared for it meanwhile, the focus to "Add" once counted when
## [param then_add] and there are games.
func _read_players(preferred_id := "", then_add := false) -> void:
	_resume_held = false
	_choices.games = -1
	# A count still on its way belongs to the players as they were.
	_counts += 1
	_choices.players.clear()
	if platform_id:
		android.prepare_tables(platform_id)
		_choices.players = android.installed_players(platform_id)
	_choices.player = _choices.players.find_custom(func(player: AndroidServices.Player) -> bool: return player.id == preferred_id)
	_show_player()
	_show_count()
	_count(then_add)


func _show_type() -> void:
	_type.show_value(platform_name() if platform_id else tr("Choose…"), not platform_id.is_empty())


func _show_folder() -> void:
	_folder_field.show_value(folder_place(_choices.folder) if _choices.has_folder else tr("Choose…"), _choices.has_folder)


func _show_player() -> void:
	_emulator.show_value(_choices.players[_choices.player].emulator_name if _choices.player >= 0
		else tr("None installed") if platform_id and _choices.players.is_empty() else tr("Choose…"), _choices.player >= 0)


## Once an emulator is chosen, the files it accepts until a folder is chosen, then how many games
## that holds; "Add" only when there are some.
func _show_count() -> void:
	var games := _choices.games
	match _choices.note(platform_id):
		FormChoices.Note.INSTALL:
			_set_note(tr("Install an emulator for this console, then come back."), false)
		FormChoices.Note.NOTHING:
			_set_note("", false)
		FormChoices.Note.ACCEPTED:
			var extensions := _choices.players[_choices.player].extensions
			_set_note(tr("Accepted files: {extensions}").format({"extensions": " ".join(Array(extensions).map(
				func(extension: String) -> String: return "." + extension))}) if not extensions.is_empty() else "", false)
		FormChoices.Note.COUNTED:
			_set_note(tr_n("{count} compatible game found", "{count} compatible games found", games).format(
				{"count": games}) if games > 0 else tr("No compatible game in this folder"), games > 0)
	_add.disabled = games <= 0 and not _model_only()
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
	if not _choices.can_count():
		return
	_counts += 1
	var asked := _counts
	var answer := await android.preview_platform(platform_id, setup())
	if asked != _counts:
		return
	_choices.games = answer.report.games if answer.ok else 0
	Diagnostics.trace("console form", "%d games counted in %d ms (%s)" % [_choices.games, answer.report.milliseconds,
		answer.code if not answer.ok else "ok"])
	_show_count()
	# Only from the folder just picked: a press elsewhere or a list opened meanwhile keeps its focus.
	if then_add and _choices.games > 0 and _folder_field.has_focus() and not _choice.visible and not _models.is_open():
		_add.grab_focus()


func _on_type_pressed() -> void:
	if phase == Phase.LEAVING:
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	var offered: Array[AndroidServices.OfferedConsole] = []
	offered.assign(android.catalog.offered.filter(func(console: AndroidServices.OfferedConsole) -> bool:
		return console.id not in _taken))
	if offered.is_empty():
		return
	var current := offered.find_custom(func(console: AndroidServices.OfferedConsole) -> bool: return console.id == platform_id)
	_choice.console_folders = _folders
	_motion.step_aside()
	var index := await _choice.choose_console(offered, current)
	var changed := index >= 0 and offered[index].id != platform_id
	var from := _choice.cursor_rect()
	_type.grab_focus()
	if changed:
		platform_id = offered[index].id
		_use_variants(_folders[platform_id])
		Diagnostics.trace("console form", "platform %s" % platform_id)
		platform_chosen.emit(platform_id)
		_show_type()
		_show_console(true)
		_show_gel(true)
		_read_players()
	_read_again_if_resumed()
	_motion.come_back(from)


func _on_emulator_pressed() -> void:
	if phase == Phase.LEAVING:
		return
	if _choices.players.is_empty():
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	_motion.step_aside()
	_choice.console_folders = _folders
	var index := await _choice.choose_player(platform_id, _choices.players, _choices.player)
	var from := _choice.cursor_rect()
	_emulator.grab_focus()
	_motion.come_back(from)
	if index >= 0 and index != _choices.player:
		_choices.player = index
		_choices.touched = true
		_choices.games = -1
		Diagnostics.trace("console form", "emulator %s" % _choices.player_id())
		_show_player()
		_show_count()
		_count(false)
	_read_again_if_resumed()


func _read_again_if_resumed() -> void:
	if _resume_held:
		_read_players(_choices.player_id())


func _on_folder_pressed() -> void:
	if phase == Phase.LEAVING or _picking:
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	_picking = true
	var asked := _fillings
	var pick := await android.pick_folder()
	if asked != _fillings:
		return
	_picking = false
	if not pick.ok:
		Diagnostics.trace("console form", "no folder picked (%s)" % pick.code)
		return
	_choices.folder = pick.folder
	_choices.has_folder = true
	_choices.touched = true
	_show_folder()
	await _count(true)


func _on_option_toggled(on: bool) -> void:
	Sounds.play(SoundEffects.Cue.TOGGLE if on else SoundEffects.Cue.UNTOGGLE)
	_choices.touched = true
	var choices := setup()
	Diagnostics.trace("console form", "%s, %s" % [choices.folder_depth, choices.disc_grouping])
	_choices.games = -1
	_show_count()
	_count(false)


## "Cancel", or "Remove" while editing.
func _on_cancel_pressed() -> void:
	if phase == Phase.LEAVING:
		return
	if _edited_id and phase != Phase.BUSY:
		Sounds.play(SoundEffects.Cue.REMOVE)
		done.emit(Outcome.REMOVE)
	else:
		_give_up()


func _give_up() -> void:
	if phase == Phase.BUSY or phase == Phase.LEAVING:
		return
	Diagnostics.trace("console form", "given up")
	Sounds.play(SoundEffects.Cue.BACK)
	phase = Phase.LEAVING
	# Unless the save stored the new model before its scan failed.
	if is_editing() and library == null and _folders[platform_id] != _had_model:
		_folders[platform_id] = _had_model
		model_shown.emit(_had_model)
	leaving.emit()
	if not await Motion.played(_motion.leave()):
		return
	done.emit(Outcome.GIVEN_UP)


## Sets the console up and scans it, the presses held ([constant Page.Phase.BUSY]) until it is added, or the form
## is back: slow storage and scanning run behind the departing form.
func _on_add_pressed() -> void:
	if phase == Phase.LEAVING or phase == Phase.BUSY:
		return
	phase = Phase.BUSY
	_add.disabled = true
	Sounds.play(SoundEffects.Cue.SELECT)
	var started := Time.get_ticks_msec()
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
			phase = Phase.LIVE
			resume()
			_choices.games = 0
			_show_count()
			return
	if is_editing():
		leaving.emit()
		if not await Motion.played(_motion.leave()):
			return
		phase = Phase.LEAVING
	else:
		phase = Phase.AWAY
	Diagnostics.trace("console form", "added in %d ms after immediate departure" % (Time.get_ticks_msec() - started))
	done.emit(Outcome.DONE)


func _not_added(failed: AndroidServices.Result) -> void:
	Diagnostics.trace("console form", "console not added (%s): %s" % [failed.code, failed.detail])
	phase = Phase.LIVE
	resume()
	_set_note(tr("The console could not be saved.") if is_editing() else tr("The console could not be added."), false)
	_add.disabled = false


## Whether, editing, only the model changed: it is saved as it is, the games neither counted nor scanned again.
func _model_only() -> bool:
	return is_editing() and not _choices.touched and _folders[platform_id] != _had_model


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
	if phase == Phase.LEAVING or _models.is_open():
		return
	Sounds.play(SoundEffects.Cue.OPEN)
	_model.open = true
	_model.models = _variants.size()
	_model.focused = _model_index()
	_models.rim = _rim
	_models.open(platform_id, _variants, _model_index())
	_make_way(true)


## The lines make way while the models' chooser is open, and come back ([method FormMotion.make_way]); the hints say
## what A and B do there.
func _make_way(away: bool) -> void:
	_motion.make_way(away)
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
	_motion.rim = gel
	_card.rim = gel
	for field: Control in _fields:
		field.set(&"rim", gel)
	_dot.shown.colors.assign([gel, gel])
	_dot.tint = gel


func _dot_material() -> StudioMaterial:
	var colors: Array[Color] = [_rim, _rim]
	return FormPaint.material(colors, _DOT / 2.0, [[Vector4(0.0, 0.0, 0.8 * _CQW, 0.0), Color.WHITE, false, true]])


## The form is no longer gone for its console's placing: it takes presses again, and the hiding its going chained
## cannot hide it once more. Opened again without this, a form left disabled would show nothing and take no press.
func _form_back() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_motion.stop_leaving()


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


## A console of the ring to edit: its platform, its choices as stored, and its folder as Android describes it.
class Edit:
	extends RefCounted

	var edited_id: String
	var choices: AndroidServices.PlatformSetup
	var folder: AndroidServices.Folder

	func _init(platform: String, stored: AndroidServices.PlatformSetup, kept: AndroidServices.Folder) -> void:
		edited_id = platform
		choices = stored
		folder = kept


## The console kept after the confirmation of its removal: the removal cancelled, or [member failed].
class Kept:
	extends RefCounted

	var failed: bool

	func _init(removal_failed: bool) -> void:
		failed = removal_failed
