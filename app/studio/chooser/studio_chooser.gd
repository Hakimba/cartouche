# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioChooser
extends Control
## The Console and emulator choosers of the add-console form: the chosen console's still picture on its plinth at the
## left, the list at the right, a satin card on the focused row. Up and down move (no wrap), A chooses, B
## gives up. The Console chooser shows each console's picture as the cursor moves; the emulator chooser keeps the
## form's console and shows the focused player's name, variant and files on the plate.

## Answered once per choice: the index chosen, or -1 when given up.
signal chosen(index: int)

## What the list shows of one choice.
class Entry:
	extends RefCounted

	var kicker := ""
	var name: String
	## The console's folder under res://carousel/consoles (the Type chooser's model).
	var folder := ""
	var files := PackedStringArray()
	var id := ""

	func _init(shown: String, kick := "") -> void:
		name = shown
		kicker = kick


## One row: kicker over name, the number at the right, the separator under it.
class Row:
	extends Button

	var on := false:
		set(value):
			on = value
			queue_redraw()
	var rim := StudioTokens.NEUTRAL:
		set(value):
			rim = value
			if on:
				queue_redraw()
	var _kick: StudioText
	var _name: StudioText
	var _name_on: StudioText
	var _number: StudioText
	var _number_on: StudioText

	func _init(entry: Entry, index: int) -> void:
		flat = true
		for state: StringName in [&"focus", &"normal", &"hover", &"pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_neighbor_left = NodePath(".")
		focus_neighbor_right = NodePath(".")
		auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		custom_minimum_size = _ROW
		size = _ROW
		text = entry.name
		# The row draws its own text: the button's stays for the tests and the screen readers.
		for colour: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color",
				&"font_hover_pressed_color", &"font_disabled_color"]:
			add_theme_color_override(colour, Color.TRANSPARENT)
		_kick = StudioText.new(entry.kicker.to_upper(), StudioTokens.Face.PLEX_600, _KICK_PX, 0.14)
		_name = StudioText.new(entry.name, StudioTokens.Face.JAKARTA_700, _NAME_PX, 0.0)
		_name_on = StudioText.new(entry.name, StudioTokens.Face.JAKARTA_800, _NAME_PX, 0.0)
		var number := "%02d" % (index + 1)
		_number = StudioText.new(number, StudioTokens.Face.PLEX_500, _NUMBER_PX, 0.0)
		_number_on = StudioText.new(number, StudioTokens.Face.PLEX_600, _NUMBER_PX, 0.0)

	## The kicker shown over the name.
	func kicker() -> String:
		return _kick.text

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()

	func _draw() -> void:
		var number := _number_on if on else _number
		var room := size.x - _PAD_LEFT - _PAD_RIGHT - _GAP - number.width
		var top := (size.y - _KICK_LINE - _NAME_LINE) / 2.0
		_kick.draw(self, Vector2(_PAD_LEFT, top + _KICK_ASCENT - _kick.baseline - _KICK_RAISE), StudioTokens.MUTE)
		var name_text := _name_on if on else _name
		name_text.fit(room)
		var ink := Color(StudioTokens.INK, 1.0 if on else 0.82)
		name_text.draw(self, Vector2(_PAD_LEFT, top + _KICK_LINE + _NAME_ASCENT - name_text.baseline), ink)
		var number_top := (size.y - _NUMBER_LINE) / 2.0 + _NUMBER_ASCENT - number.baseline
		number.draw(self, Vector2(size.x - _PAD_RIGHT - number.width, number_top), rim if on else StudioTokens.MUTE)
		draw_rect(Rect2(_PAD_LEFT, size.y + _SEPARATOR_GAP - 1.0, size.x - _PAD_LEFT - _SEPARATOR_RIGHT, 1.0), StudioTokens.LINE)


const _CQW := FormPaint.CQW
const _ROW := Vector2(56.0 * _CQW, 6.4 * _CQW)
const _PITCH := 7.0 * _CQW
const _PAD_LEFT := 2.2 * _CQW
const _PAD_RIGHT := 1.8 * _CQW
const _SEPARATOR_RIGHT := 1.4 * _CQW
const _SEPARATOR_GAP := 0.3 * _CQW
const _GAP := 1.6 * _CQW
const _KICK_PX := 1.35 * _CQW
const _NAME_PX := 2.35 * _CQW
const _NUMBER_PX := 1.4 * _CQW
## The text block of a row is centred as two lines of the families' normal height.
const _KICK_LINE := FormPaint.PLEX_LINE * _KICK_PX
const _KICK_ASCENT := FormPaint.PLEX_ASCENT * _KICK_PX
## How much higher in its row the kicker is set than its line box alone puts it, in px.
const _KICK_RAISE := 3.0
## How far the plate's lines are set down, in px: all of them when the kicker is empty, and a little more for
## the kicker and the files when it is not.
const _PLATE_DROP := 3.0
const _FILES_DROP := 1.0
const _KICKED_DROP := 1.0
const _KICKED_FILES_DROP := 1.5
const _NAME_LINE := FormPaint.JAKARTA_LINE * _NAME_PX
const _NAME_ASCENT := FormPaint.JAKARTA_ASCENT * _NAME_PX
const _NUMBER_LINE := FormPaint.PLEX_LINE * _NUMBER_PX
const _NUMBER_ASCENT := FormPaint.PLEX_ASCENT * _NUMBER_PX
const _LIST := Rect2(41.0 * _CQW, 7.6 * _CQW, 56.0 * _CQW, 58.4 * _CQW)
const _LIST_PAD := 2.2 * _CQW
const _FADE := 2.0 * _CQW
const _PLATE_NAME_PX := 2.6 * _CQW
const _PLATE_KICK_PX := 1.4 * _CQW
const _PLATE_FILES_WIDTH := 26.0 * _CQW
const _FILES_LINE := 1.35 * _PLATE_KICK_PX
const _FILES_SHARE := 0.6
const _DRAG_START_PX := 12.0
const _CURSOR_S := 0.24
const _SCROLL_S := 0.3
const _PLATE_S := 0.22
const _TYPE_PLATE_RISE := 0.6 * _CQW
const _PLAYER_PLATE_RISE := 0.8 * _CQW

static var _variant := RegEx.create_from_string("^(.*?) \\((.*)\\)$")

## The form's current model choices, by platform; empty entries use the base model.
var console_folders: Dictionary[String, String] = {}

var _entries: Array[Entry] = []
var _index := 0
var _is_type := true
var _rim := StudioTokens.NEUTRAL
var _scroll := 0.0
var _cursor_y := 0.0
var _rows: Array[Row] = []
var _plinth: Plinth
var _files: Array[StudioText] = []
var _plate_name: StudioText
var _plate_kick: StudioText
var _title: StudioText
var _opening: Tween
var _return_tween: Tween
var _open_clock := 0.0:
	set(value):
		_open_clock = value
		_place_opening()
var _returning := false
var _choosing := false
## Where each line of the screen rests, and the one the plate's ink is drawn on.
var _rests: Dictionary[Control, Vector2] = {}
var _plate_ink: Control
var _plate_rest := 0.0
## The touch in progress: where it began, and whether it has become a drag.
var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
var _motions: Dictionary[StringName, Tween] = {}

@onready var _backdrop: Cyclorama = $Backdrop
@onready var _title_node: Control = $Title
@onready var _count_node: Control = $Count
@onready var _plate_node: Control = $PlateText
@onready var _window: TextureRect = $List
@onready var _inner: Control = $List/Inner
@onready var _cursor: SatinPanel = $List/Inner/Cursor


func _ready() -> void:
	_title_node.draw.connect(_draw_title)
	_count_node.draw.connect(_draw_count)
	_plate_ink = Control.new()
	_plate_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_ink.draw.connect(_draw_plate)
	_plate_node.add_child(_plate_ink)
	_window.position = _LIST.position
	_window.size = _LIST.size
	var fade := Gradient.new()
	var edge := _FADE / _LIST.size.y
	fade.offsets = PackedFloat32Array([0.0, edge, 1.0 - edge, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = int(_LIST.size.y)
	_window.texture = texture
	_cursor.look = StudioTokens.Look.FOCUS
	_cursor.size = _ROW
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: Control in [_title_node, _count_node, _window, _plate_node]:
		_rests[line] = line.position


func _input(event: InputEvent) -> void:
	if not visible or _rows.is_empty():
		return
	var mouse := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if mouse and mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.pressed and _window.get_global_rect().has_point(mouse.position):
			_pressing = true
			_dragging = false
			_press_at = mouse.position
			get_viewport().set_input_as_handled()
		elif _pressing and not mouse.pressed:
			_pressing = false
			get_viewport().set_input_as_handled()
			if _dragging:
				_dragging = false
				_settle_scroll()
			else:
				_tap(mouse.position)
	elif mouse and mouse.pressed and _window.get_global_rect().has_point(mouse.position) \
			and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
		_drag_by(_PITCH if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -_PITCH)
		_settle_scroll()
	elif motion and _pressing:
		if not _dragging and motion.position.distance_to(_press_at) > _DRAG_START_PX:
			_dragging = true
		if _dragging:
			get_viewport().set_input_as_handled()
			_drag_by(motion.relative.y)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_answer(-1, true)


## Shows the Type chooser over [param offered] (the consoles a person may add, in order), the cursor on
## [param current]; returns the index chosen, or -1.
func choose_console(offered: Array[AndroidServices.OfferedConsole], current: int) -> int:
	var folders := _folders()
	var entries: Array[Entry] = []
	for console in offered:
		var entry := Entry.new(console.model, console.maker)
		entry.id = console.id
		entry.folder = folders[console.id]
		entries.append(entry)
	return await _choose(true, tr("Console"), entries, current, "")


## Shows the emulator chooser over [param players], the cursor on [param current]; the console of
## [param platform_id] stands still on the plinth. Returns the index chosen, or -1.
func choose_player(platform_id: String, players: Array[AndroidServices.Player], current: int) -> int:
	var entries: Array[Entry] = []
	for player in players:
		var entry := Entry.new(player.emulator_name)
		entry.id = player.id
		entry.files = player.extensions
		var family := player.emulator_name.split(" - ", true, 1)
		var variant := _variant.search(player.emulator_name)
		if family.size() == 2:
			entry.kicker = family[0]
			entry.name = family[1]
		elif variant:
			entry.kicker = variant.get_string(2)
			entry.name = variant.get_string(1)
		entries.append(entry)
	return await _choose(false, tr("Emulator"), entries, current, _folders()[platform_id])


## The focused row's card, on the screen: where the form's focus card flies to.
func cursor_rect() -> Rect2:
	return Rect2(_cursor.global_position, _cursor.size)


## The index the cursor is on.
func focused() -> int:
	return _index


## Where the list rests for the cursor on row [param i] of [param n]: the row in the middle of the window,
## the first and the last held to the window's ends (px of scroll).
static func scroll_of(i: int, n: int) -> float:
	return maxf(0.0, minf(i * _PITCH - (_LIST.size.y - _PITCH) / 2.0, _last_scroll(n)))


## The farthest the list of [param n] rows scrolls, px.
static func _last_scroll(n: int) -> float:
	return n * _PITCH - (_PITCH - _ROW.y) + 2.0 * _LIST_PAD - _LIST.size.y


## The count shown: the cursor's number, then the total (padded in the emulator chooser only).
func counter() -> String:
	var total := _entries.size()
	return "%02d / %s" % [_index + 1, str(total) if _is_type else "%02d" % total]


func rows() -> Array[Row]:
	return _rows


## The id of each choice, in order: the platform or the player.
func ids() -> PackedStringArray:
	return PackedStringArray(_entries.map(func(entry: Entry) -> String: return entry.id))


## The folder of each platform's default console under res://carousel/consoles.
func _folders() -> Dictionary[String, String]:
	var folders: Dictionary[String, String] = {}
	var defaults := Appearance.defaults(ConsoleManifest.found())
	for platform in defaults:
		folders[platform] = ConsoleManifest.folder_of(defaults[platform])
	folders.merge(console_folders, true)
	return folders


func _choose(is_type: bool, title: String, entries: Array[Entry], current: int, still_folder: String) -> int:
	if _choosing:
		return -1
	_choosing = true
	_is_type = is_type
	_entries = entries
	_title = StudioText.new(title, StudioTokens.Face.JAKARTA_800, FormPaint.TITLE_PX, -0.04)
	for row in _rows:
		_inner.remove_child(row)
		row.queue_free()
	_rows.clear()
	for i in entries.size():
		var row := Row.new(entries[i], i)
		row.position = Vector2(0.0, i * _PITCH)
		row.focus_entered.connect(_focus.bind(i))
		row.pressed.connect(_answer.bind(i))
		_inner.add_child(row)
		_rows.append(row)
	# Up and down stop at the ends, and never reach the form's controls under the chooser.
	for i in _rows.size():
		_rows[i].focus_neighbor_top = _rows[i].get_path_to(_rows[maxi(i - 1, 0)])
		_rows[i].focus_neighbor_bottom = _rows[i].get_path_to(_rows[mini(i + 1, _rows.size() - 1)])
	_present_plinth(still_folder)
	_index = clampi(current, 0, entries.size() - 1)
	_settle()
	show()
	_open()
	_rows[_index].grab_focus.call_deferred()
	return await chosen


## The chooser keeps its plinth and model cache between openings.
func _present_plinth(still_folder: String) -> void:
	if not _plinth:
		_plinth = Plinth.create()
		_plinth.name = "Plinth"
		_plinth.position = StudioTokens.PLINTH.position
		_plinth.size = StudioTokens.PLINTH.size
		add_child(_plinth)
		move_child(_plinth, _backdrop.get_index() + 1)
	_plate_node.visible = not _is_type
	(_plinth.get_node("Plate") as Control).visible = _is_type
	if not _is_type:
		_plinth.show_console(still_folder)
	_plinth.restart()


## Everything where it rests for the cursor now, no motion.
func _settle() -> void:
	for motion: Tween in _motions.values():
		motion.kill()
	_motions.clear()
	_rim = _gel_of(_index)
	_cursor_y = _index * _PITCH
	_scroll = scroll_of(_index, _entries.size())
	_place()
	_show_focus(false)


func _gel_of(i: int) -> Color:
	var folder := _entries[i].folder if _is_type else _plinth.console()
	return ConsoleManifest.gel_of(folder)


func _place() -> void:
	_inner.position.y = _LIST_PAD - _scroll
	_cursor.position.y = _cursor_y
	_cursor.gel = _rim
	for i in _rows.size():
		_rows[i].on = i == _index
		_rows[i].rim = _rim
	_count_node.queue_redraw()
	_plate_ink.queue_redraw()


func _focus(i: int) -> void:
	if i == _index:
		return
	_index = i
	_show_focus(true)


## The cursor is on row [member _index]: what follows it, eased into place when [param moving].
func _show_focus(moving: bool) -> void:
	var entry := _entries[_index]
	Diagnostics.trace("console form", "%s focus=%s" % ["type" if _is_type else "emulator", entry.id])
	var gel := _gel_of(_index)
	for i in _rows.size():
		_rows[i].on = i == _index
	if _is_type:
		_plinth.show_console(entry.folder)
		# Just placed: the plate's rest, which its rise must come back to.
		_plate_rest = (_plinth.get_node("Plate") as Control).position.y
	_rebuild_plate()
	if not moving:
		_rim = gel
		_place()
		return
	var from_y := _cursor_y
	var to_y := _index * _PITCH
	Motion.animate(self, _motions, &"cursor", _CURSOR_S, Motion.Easing.SNAP, func(p: float) -> void:
		_cursor_y = lerpf(from_y, to_y, p)
		_cursor.position.y = _cursor_y)
	if not _dragging:
		_settle_scroll()
	var from_rim := _rim
	Motion.animate(self, _motions, &"rim", StudioTokens.GEL_FADE_S, Motion.Easing.EASE, func(p: float) -> void:
		_rim = from_rim.lerp(gel, p)
		_cursor.gel = _rim
		_count_node.queue_redraw()
		_plate_ink.queue_redraw()
		for row in _rows:
			row.rim = _rim)
	var plate: Control = _plate_ink if not _is_type else _plinth.get_node("Plate")
	var rise := _TYPE_PLATE_RISE if _is_type else _PLAYER_PLATE_RISE
	var rest := 0.0 if not _is_type else _plate_rest
	Motion.animate(self, _motions, &"plate", _PLATE_S, Motion.Easing.EASE_OUT, func(p: float) -> void:
		plate.modulate.a = clampf(p, 0.0, 1.0)
		plate.position.y = rest + rise * (1.0 - p))


## The chooser's half of the form to chooser transition: the screen fades in, its lines, title and count come
## from the right and from below, the model rises (the plinth's own).
func _open() -> void:
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null
	_returning = false
	if _opening and _opening.is_valid():
		_opening.kill()
	_open_clock = 0.0
	_opening = create_tween()
	var seconds := maxf(StudioTokens.TR_CHOOSER_AT_S + StudioTokens.TR_CHOOSER_LAYER_S,
		StudioTokens.TR_CHOOSER_LINES_AT_S + StudioTokens.TR_CHOOSER_IN_S)
	_opening.tween_property(self, ^"_open_clock", seconds, seconds)


func _place_opening() -> void:
	modulate.a = Motion.phase(_open_clock, StudioTokens.TR_CHOOSER_AT_S, StudioTokens.TR_CHOOSER_LAYER_S, Motion.Easing.EASE_OUT)
	var progress := Motion.phase(_open_clock, StudioTokens.TR_CHOOSER_LINES_AT_S, StudioTokens.TR_CHOOSER_IN_S, Motion.Easing.ARRIVE)
	for line in _lines():
		line.position = _rests[line] + Vector2(StudioTokens.TR_CHOOSER_SHIFT_PX, StudioTokens.TR_CHOOSER_TITLE_PX) * (1.0 - progress)
		line.modulate.a = progress


## The lines that come in with the screen: the plate's text only in the emulator chooser.
func _lines() -> Array[Control]:
	var lines: Array[Control] = [_title_node, _count_node, _window]
	if not _is_type:
		lines.append(_plate_node)
	return lines


## The list moved by [param pixels] under a finger or the wheel, held to its ends; the cursor goes to the row
## in the middle of the window.
func _drag_by(pixels: float) -> void:
	if _motions.has(&"scroll"):
		_motions[&"scroll"].kill()
	_scroll = clampf(_scroll - pixels, 0.0, maxf(0.0, _last_scroll(_rows.size())))
	_inner.position.y = _LIST_PAD - _scroll
	var middle := (_scroll + _LIST.size.y / 2.0 - _LIST_PAD) / _PITCH - 0.5
	_rows[clampi(roundi(middle), 0, _rows.size() - 1)].grab_focus()


## The list comes to rest where the cursor's row puts it, after a drag or a wheel turn.
func _settle_scroll() -> void:
	var from := _scroll
	var to := scroll_of(_index, _entries.size())
	Motion.animate(self, _motions, &"scroll", _SCROLL_S, Motion.Easing.GLIDE, func(p: float) -> void:
		_scroll = lerpf(from, to, p)
		_inner.position.y = _LIST_PAD - _scroll)


## A touch released at [param at] without dragging: the row under it is chosen.
func _tap(at: Vector2) -> void:
	var row := floori((at.y - _window.get_global_rect().position.y - _LIST_PAD + _scroll) / _PITCH)
	if row >= 0 and row < _rows.size():
		_answer(row)


func _answer(picked: int, turn_back := false) -> void:
	if not visible or _returning:
		return
	if turn_back and picked < 0 and _opening and _opening.is_running() and StudioTokens.TR_REVERSE:
		_returning = true
		var seconds := _open_clock
		_opening.kill()
		_opening = null
		var leaving := create_tween()
		_return_tween = leaving
		leaving.tween_property(self, ^"_open_clock", 0.0, maxf(seconds, 0.001))
		await leaving.finished
		if _return_tween != leaving:
			return
		_return_tween = null
		_returning = false
		if not visible or not _choosing:
			return
	if _opening and _opening.is_valid():
		_opening.kill()
	_opening = null
	for motion: Tween in _motions.values():
		motion.kill()
	_motions.clear()
	# Given up mid-entry, the lines go back to rest, so the next opening starts from where it should.
	modulate.a = 1.0
	for line: Control in _rests:
		line.position = _rests[line]
		line.modulate.a = 1.0
	_pressing = false
	_dragging = false
	_choosing = false
	hide()
	Sounds.play(SoundEffects.Cue.SELECT if picked >= 0 else SoundEffects.Cue.BACK)
	chosen.emit(picked)


func _rebuild_plate() -> void:
	if _is_type:
		return
	var entry := _entries[_index]
	_plate_name = StudioText.new(entry.name, StudioTokens.Face.JAKARTA_800, _PLATE_NAME_PX, -0.02)
	_plate_kick = StudioText.new(entry.kicker.to_upper(), StudioTokens.Face.PLEX_600, _PLATE_KICK_PX, 0.14)
	_files.clear()
	var line := ""
	for file in entry.files:
		var next := (line + " ." + file.to_upper()).strip_edges()
		var probe := StudioText.new(next, StudioTokens.Face.PLEX_600, _PLATE_KICK_PX, 0.06)
		if probe.width > _PLATE_FILES_WIDTH and not line.is_empty():
			_files.append(StudioText.new(line, StudioTokens.Face.PLEX_600, _PLATE_KICK_PX, 0.06))
			line = "." + file.to_upper()
		else:
			line = next
	if not line.is_empty():
		_files.append(StudioText.new(line, StudioTokens.Face.PLEX_600, _PLATE_KICK_PX, 0.06))
	_plate_ink.queue_redraw()


func _draw_title() -> void:
	_title.draw(_title_node, Vector2.ZERO, StudioTokens.INK)


func _draw_count() -> void:
	var parts := counter().split(" / ")
	FormPaint.draw_count(_count_node, parts[0], " / " + parts[1], _rim)


func _draw_plate() -> void:
	if _plate_name == null:
		return
	var plate := StudioTokens.PLINTH.position + StudioTokens.PLINTH_PLATE.position
	var centre := plate.x + StudioTokens.PLINTH_PLATE.size.x / 2.0
	var kicked := not _plate_kick.text.is_empty()
	var y := plate.y + 1.4 * _CQW + (0.0 if kicked else _PLATE_DROP)
	var name_box := _PLATE_NAME_PX * 1.1
	var name_shift := (_plate_name.height - name_box) / 2.0
	_plate_name.draw(_plate_ink, Vector2(centre - _plate_name.width / 2.0, y - name_shift), StudioTokens.INK)
	y += name_box + 0.3 * _CQW
	var kick_box := _PLATE_KICK_PX * FormPaint.PLEX_LINE if kicked else 1.6 * _CQW
	_plate_kick.draw(_plate_ink, Vector2(centre - _plate_kick.width / 2.0,
			y + FormPaint.PLEX_ASCENT * _PLATE_KICK_PX - _plate_kick.baseline + _KICKED_DROP),
		StudioTokens.MUTE)
	y += kick_box + 0.3 * _CQW
	y += _KICKED_FILES_DROP if kicked else _FILES_DROP
	var ink := StudioTokens.MUTE.lerp(_rim, _FILES_SHARE)
	for line in _files:
		var shift := (line.height - _FILES_LINE) / 2.0
		line.draw(_plate_ink, Vector2(centre - line.width / 2.0, y - shift), ink)
		y += _FILES_LINE
