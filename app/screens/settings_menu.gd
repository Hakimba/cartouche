# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsMenu
extends Page
## The settings on the plain backdrop: the choices, the switches (the backdrop's pixel veil, the games
## floating, the games in a line) and the sounds' level, which left and right turn down and up, as a finger on it left or right of its lit
## end does. The card shows [constant _SHOWN] lines; the focus scrolls the others in, and an arrow above or below says
## lines are hidden that way. It answers the key of the row pressed, or `close` (B), and is asked again after a switch.

## Each move of the card's clock: how present the screen under it, its rail and its chrome are, from 1 (whole) to 0,
## and whether its 3D is cut.
signal transition_frame(subject: float, rail: float, chrome: float, cut: bool)
## Left or right on the sounds' line, or a finger on its level, set them to [param steps].
signal sound_level_changed(steps: int)

enum State { OPENING, OPEN, CLOSING, CLOSED }
## How a row changes: [code]CHOICE[/code] opens its own page, its value right of its name ([code]CHOICE_BELOW[/code]:
## under it, for long values); [code]SWITCH[/code] slides on its row; [code]LEVEL[/code], the sounds' bar, is turned
## with left and right, or a tap on it.
enum Kind { CHOICE, CHOICE_BELOW, SWITCH, LEVEL }

const _PITCH := 89.6 # Row height plus the 7.68 px gap.
const _SHOWN := 6
## Where the arrows saying lines are hidden above and below stand, in the card; a finger on one scrolls a line.
const _MORE_UP_Y := 127.64
const _MORE_DOWN_Y := 689.24
const _ROW_SIZE := Vector2(624.64, 81.92)
const _HEADING_INSET := Vector2(43.52, 37.4)
## The first row's top in the card, in px: a pixel above where centring puts its text and frame.
const _ITEMS_TOP := 143.64
## The sounds' level drawn as this many steps, right on the line, each this size and this far from the next.
const _STEP_SIZE := Vector2(10.24, 23.04)
const _STEP_GAP := 6.4
## How far beside the level's first and last steps a finger still falls on it, in px.
const _LEVEL_REACH := 24.0
## The card's rows, top to bottom, by the choice a press on one emits (a switch's is its setting's key; its node is
## named after it in PascalCase): its name and how it changes ([enum Kind]), with a switch's note under its name. A row
## marked [code]arc[/code] shows only on screens whose games stand on an arc ([member ScreenLayout.Format.shelf_level]
## off): on the others it would change nothing.
const ROWS: Dictionary[StringName, Dictionary] = {
	&"button_style": {&"label": "Button style", &"kind": Kind.CHOICE},
	&"graphics": {&"label": "Graphics", &"kind": Kind.CHOICE},
	&"backdrop": {&"label": "Background", &"kind": Kind.CHOICE},
	&"pixel_veil": {&"label": "Animated background", &"kind": Kind.SWITCH, &"note": "A veil of pixels drifts behind the screens"},
	&"games_float": {&"label": "Games float", &"kind": Kind.SWITCH, &"note": "The selected game gently rises and falls"},
	&"games_in_line": {&"label": "Games in a line", &"kind": Kind.SWITCH,
		&"note": "The games stand in a straight line instead of an arc", &"arc": true},
	&"region": {&"label": "Preferred region of images", &"kind": Kind.CHOICE_BELOW},
	&"sounds": {&"label": "Sounds", &"kind": Kind.LEVEL},
	&"language": {&"label": "Language", &"kind": Kind.CHOICE_BELOW},
}
const _ROW := preload("res://screens/settings_row.tscn")

static var DURATION_S: float:
	get: return maxf(StudioTokens.TR_SETTINGS_OPEN_S, StudioTokens.TR_SETTINGS_CARD_AT_S + StudioTokens.TR_SETTINGS_CARD_S)

var sound_level := SoundEffects.LEVELS:
	set(value):
		sound_level = value
		if is_node_ready():
			_ink.queue_redraw()
var gel := StudioTokens.GEL[&"ps2_slim"]:
	set(value):
		gel = value
		if is_node_ready():
			_cursor.tint = value
			for switch: Switch in _switches.values():
				switch.snap(switch.on, value)
## The save of the settings under way, owned by the screens' flow.
var held: ScreenFlow.HeldSave
var state := State.OPEN
## The card's clock: the opening's, or the closing's while [member _closing].
var _clock := Motion.Timeline.new(_sample)
var _closing := false
var _cursor_y := 0.0
var _cursor_tween: Tween
## The rows the card shows, top to bottom, and their keys.
var _rows: Array[FieldButton] = []
var _keys: Array[StringName] = []
## The rows by their key in [constant ROWS].
var _rows_of: Dictionary[StringName, FieldButton] = {}
## The row on the card's first line.
var _first := 0
var _card: SatinPanel.Backing
var _cursor: SatinPanel.Backing
var _switches: Dictionary[StringName, Switch] = {}
var _ink: Control
## Left or right on the sounds' level: a stick held sends a stream of events, only its push is a step.
var _level_way := HeldDirection.new({&"ui_left": -1, &"ui_right": 1})

@onready var _panel: Control = $Panel
@onready var _rests := Rests.new([_panel])
@onready var _items: Control = $Panel/Items


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)
	_panel.pivot_offset = _panel.size / 2.0
	for key: StringName in ROWS:
		var row: FieldButton = _ROW.instantiate()
		row.name = key.to_pascal_case()
		row.label = ROWS[key][&"label"]
		_items.add_child(row)
		_rows_of[key] = row
		row.size = _ROW_SIZE
		row.focus_entered.connect(_focus_row.bind(row))
		FormPaint.plain(row)
		if kind_of(key) == Kind.LEVEL:
			row.focus_neighbor_left = row.get_path_to(row)
			row.focus_neighbor_right = row.get_path_to(row)
			continue
		row.pressed.connect(_on_row_pressed.bind(key))
		if kind_of(key) == Kind.SWITCH:
			_switches[key] = Switch.new(row)
	_card = SatinPanel.Backing.new(_panel, StudioTokens.Look.SATIN)
	_card.place(Rect2(Vector2.ZERO, _panel.size), 28.16)
	_cursor = SatinPanel.Backing.new(_items, StudioTokens.Look.FOCUS)
	_cursor.tint = gel
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_ink)
	_ink.draw.connect(_draw_card)
	_show_rows()
	get_viewport().size_changed.connect(_follow_screen)
	_clock.seconds = DURATION_S
	_clock.arrived.connect(_settled)
	visibility_changed.connect(func() -> void:
		if not visible:
			set_process(false))
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		for switch: Switch in _switches.values():
			switch.repaint(gel)


func _input(event: InputEvent) -> void:
	# Read hidden too, so that a release is never missed.
	var pushed := _level_way.update(event) and _level_way.held
	if not is_visible_in_tree():
		return
	if held.pending():
		if event.is_action_pressed(&"screen_back") and held.lasted():
			_reverse(false)
		get_viewport().set_input_as_handled()
		return
	if state == State.OPEN:
		var tap := event as InputEventMouseButton
		if tap and tap.pressed and (_tapped_arrow(tap) or _tapped_level(tap)):
			return
		if _rows_of[&"sounds"].has_focus() and (event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_right", true)):
			get_viewport().set_input_as_handled()
			# A key held repeats its step.
			if pushed or event.is_echo():
				_step_level(_level_way.direction)
		return
	if event.is_action_pressed(&"screen_back"):
		_reverse(false)
	elif event.is_action_pressed(&"open_settings"):
		_reverse(true)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_reverse(false)


## Whether the card takes no press now (INV-20): a save under way, or the card not open. Read from [member state],
## as [method _input] does: [member _closing] only names the clock's track, still the closing's on a card turned back
## open by Y while it closed.
func holds_presses() -> bool:
	return held.pending() or state != State.OPEN


func enter() -> void:
	state = State.OPENING
	_clock.stop()
	_clock.seconds = 0.0
	_closing = false


func _reverse(opening: bool) -> void:
	Sounds.play(SoundEffects.Cue.SETTINGS if opening else SoundEffects.Cue.BACK)
	if state == State.OPEN:
		_closing = true
		_clock.seconds = 0.0
	state = State.OPENING if opening else State.CLOSING
	_clock.play(_duration() if opening != _closing else 0.0)
	set_process(true)


# The clock moves first: what it places is drawn this frame.
func _process(delta: float) -> void:
	_clock.tick(minf(delta, 0.1))


func _settled() -> void:
	var opened := (_clock.seconds == _duration()) != _closing
	state = State.OPEN if opened else State.CLOSED
	set_process(false)
	if not opened:
		done.emit(&"close")


func _duration() -> float:
	return StudioTokens.TR_SETTINGS_CLOSE_S if _closing else DURATION_S


func _sample() -> void:
	var t := _clock.seconds
	var card := Motion.phase(t, 0.0, StudioTokens.TR_SETTINGS_CARD_OUT_S, StudioTokens.TR_SETTINGS_CARD_OUT_S_CURVE) if _closing \
		else 1.0 - Motion.phase(t, StudioTokens.TR_SETTINGS_CARD_AT_S, StudioTokens.TR_SETTINGS_CARD_S, StudioTokens.TR_SETTINGS_CARD_S_CURVE)
	_panel.modulate.a = 1.0 - card
	_panel.position.y = _rests.of(_panel).y + card * (25.6 if _closing else StudioTokens.TR_SETTINGS_RISE_PX)
	_panel.scale = Vector2.ONE * lerpf(1.0, 0.98 if _closing else 0.97, card)
	($Dim as ColorRect).modulate.a = 1.0 - Motion.phase(t, 0.06, 0.2, Motion.Easing.EASE_IN) if _closing \
		else Motion.phase(t, StudioTokens.TR_SETTINGS_VEIL_AT_S, StudioTokens.TR_SETTINGS_VEIL_S, Motion.Easing.EASE_OUT)
	($Hints as Control).modulate.a = 1.0 - Motion.phase(t, 0.0, 0.12) if _closing \
		else Motion.phase(t, 0.21, StudioTokens.TR_SETTINGS_HINTS_S)
	var back := Motion.phase(t, StudioTokens.TR_SETTINGS_BACK_AT_S, StudioTokens.TR_SETTINGS_CLOSE_S - StudioTokens.TR_SETTINGS_BACK_AT_S,
		Motion.Easing.ARRIVE)
	# Back from the card's leaving on: the 3D shows again only once the card is gone.
	var grow := Motion.phase(t, StudioTokens.TR_SETTINGS_CARD_OUT_S, StudioTokens.TR_SETTINGS_CLOSE_S - StudioTokens.TR_SETTINGS_CARD_OUT_S,
		Motion.Easing.ARRIVE)
	var subject := grow if _closing else 1.0 - Motion.phase(t, 0, StudioTokens.TR_SETTINGS_LEAVE_S, StudioTokens.TR_SETTINGS_LEAVE_S_CURVE)
	var rail := back if _closing else 1.0 - Motion.phase(t, 0, StudioTokens.TR_SETTINGS_SINK_S, StudioTokens.TR_SETTINGS_SINK_S_CURVE)
	var chrome := Motion.phase(t, 0.21, StudioTokens.TR_SETTINGS_HINTS_S) if _closing \
		else 1.0 - Motion.phase(t, 0, StudioTokens.TR_SETTINGS_HINTS_S)
	# Like the console swap: the 3D is cut as the card starts coming and back once it is gone, never seen through it.
	transition_frame.emit(subject, rail, chrome, state == State.OPENING or _panel.modulate.a > 0.0)


func _focus_row(row: FieldButton) -> void:
	var index := _rows.find(row)
	_first = clampi(_first, index - _SHOWN + 1, index)
	_place_rows()
	_cursor_tween = Motion.restart(self, _cursor_tween)
	var start := _cursor_y
	_cursor_tween.tween_method(func(t: float) -> void:
		_place_cursor(lerpf(start, (index - _first) * _PITCH, Motion.eased(Motion.Easing.SNAP, t))), 0.0, 1.0, 0.24)
	_ink.queue_redraw()


## The rows this screen's shape shows, each linked to the ones above and below it, on their lines.
func _show_rows() -> void:
	var on_arc := not ScreenLayout.at(get_viewport()).format.shelf_level
	_keys.assign(ROWS.keys().filter(func(key: StringName) -> bool: return on_arc or not ROWS[key].get(&"arc", false)))
	_rows.clear()
	for key: StringName in _rows_of:
		_rows_of[key].visible = key in _keys
		if key in _keys:
			_rows.append(_rows_of[key])
	for i in _rows.size():
		var row := _rows[i]
		row.focus_neighbor_top = row.get_path_to(_rows[maxi(0, i - 1)])
		row.focus_neighbor_bottom = row.get_path_to(_rows[mini(_rows.size() - 1, i + 1)])
		row.focus_next = row.focus_neighbor_bottom
		row.focus_previous = row.focus_neighbor_top
	_first = clampi(_first, 0, maxi(0, _rows.size() - _SHOWN))
	_place_rows()


## The rows shown again as the screen takes another shape; a focused row gone gives the focus to the nearest shown
## ([method nearest_shown]).
func _follow_screen() -> void:
	var focused := get_viewport().gui_get_focus_owner() as FieldButton
	var key: StringName = _rows_of.find_key(focused) if focused in _rows else &""
	_show_rows()
	_ink.queue_redraw()
	if key.is_empty():
		return
	var row := _rows_of[nearest_shown(key, _keys)]
	row.grab_focus()
	_focus_row(row)


## [param key] when [param shown] (keys of [constant ROWS], in their order) has it, else the nearest shown above it,
## else the first shown: the row the focus goes to when its own is left out of the card.
static func nearest_shown(key: StringName, shown: Array[StringName]) -> StringName:
	var order: Array[StringName] = []
	order.assign(ROWS.keys())
	for at in range(order.find(key), -1, -1):
		if order[at] in shown:
			return order[at]
	return shown[0]


## Each row on its line of the card; the rows scrolled out stay focusable, unseen and untouchable.
func _place_rows() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var line := i - _first
		var shown := line >= 0 and line < _SHOWN
		row.position = Vector2(0, line * _PITCH)
		row.modulate.a = 1.0 if shown else 0.0
		row.mouse_filter = MOUSE_FILTER_STOP if shown else MOUSE_FILTER_IGNORE


## Whether [param tap] fell on an arrow, the card then scrolled a line that way.
func _tapped_arrow(tap: InputEventMouseButton) -> bool:
	var at := _panel.get_global_transform().affine_inverse() * tap.position
	for way: int in [-1, 1]:
		var y := _MORE_UP_Y if way < 0 else _MORE_DOWN_Y
		if _more(way) and absf(at.y - y) < 24.0 and absf(at.x - _panel.size.x / 2.0) < 64.0:
			get_viewport().set_input_as_handled()
			_scroll(way)
			return true
	return false


## Whether [param tap] fell on the sounds' level shown, the level then a step down left of its lit end, up right of it.
func _tapped_level(tap: InputEventMouseButton) -> bool:
	var row := _rows_of[&"sounds"]
	var at := _panel.get_global_transform().affine_inverse() * tap.position
	var top := _ITEMS_TOP + (_rows.find(row) - _first) * _PITCH
	if row.mouse_filter == MOUSE_FILTER_IGNORE or at.y < top or at.y > top + _ROW_SIZE.y \
			or at.x < _step_x(0) - _LEVEL_REACH or at.x > _step_x(SoundEffects.LEVELS) + _LEVEL_REACH:
		return false
	get_viewport().set_input_as_handled()
	row.grab_focus()
	_step_level(-1 if at.x < _step_x(sound_level) - _STEP_GAP / 2.0 else 1)
	return true


## The screen point of the sounds' step a tap on turns the level [param way] (-1 down, 1 up).
func level_point(way: int) -> Vector2:
	var line := _rows.find(_rows_of[&"sounds"]) - _first
	var step := sound_level - 1 if way < 0 else sound_level
	return _panel.get_global_transform() * Vector2(_step_x(step) + _STEP_SIZE.x / 2.0, _ITEMS_TOP + line * _PITCH + _ROW_SIZE.y / 2.0)


## The sounds' level a step [param way] (-1 down, 1 up), told when it changes.
func _step_level(way: int) -> void:
	var steps := clampi(sound_level + way, 0, SoundEffects.LEVELS)
	if steps != sound_level:
		sound_level = steps
		sound_level_changed.emit(steps)


## The screen point of the arrow telling lines are hidden [param way] (-1 above, 1 below); [constant Vector2.INF] when none are.
func arrow_point(way: int) -> Vector2:
	if not _more(way):
		return Vector2.INF
	return _panel.get_global_transform() * Vector2(_panel.size.x / 2.0, _MORE_UP_Y if way < 0 else _MORE_DOWN_Y)


## Whether lines are hidden [param way] (-1 above, 1 below).
func _more(way: int) -> bool:
	return _first > 0 if way < 0 else _first + _SHOWN < _rows.size()


## Scrolls the card a line [param way], the focus kept on a line shown.
func _scroll(way: int) -> void:
	_first += way
	_place_rows()
	var focused := _rows.find(get_viewport().gui_get_focus_owner() as FieldButton)
	var shown := clampi(focused, _first, _first + _SHOWN - 1)
	if shown != focused:
		_rows[shown].grab_focus()
	else:
		if _cursor_tween:
			_cursor_tween.kill()
		_place_cursor((focused - _first) * _PITCH)
		_ink.queue_redraw()


func _place_cursor(y: float) -> void:
	_cursor_y = y
	_cursor.place(Rect2(Vector2(0, y), _ROW_SIZE), 17.92)


func _draw_card() -> void:
	StudioText.new(tr("Settings"), StudioTokens.Face.JAKARTA_800, 53.76, -0.04).draw(_ink, _HEADING_INSET, Backdrop.palette.ink)
	var last := mini(_first + _SHOWN, _rows.size()) - 1
	for i in range(_first, last + 1):
		var row := _rows[i]
		var key := _keys[i]
		var kind := kind_of(key)
		var name_line := _row_name(row, kind)
		var y := _ITEMS_TOP + (i - _first) * _PITCH
		var switched := kind == Kind.SWITCH
		var has_note := switched or kind == Kind.CHOICE_BELOW
		name_line.draw(_ink, Vector2(61.44, y + (2.08 if has_note else 18.4)), Backdrop.palette.ink)
		if has_note:
			var note: String = ROWS[key].get(&"note", "")
			note = tr(note) if switched else row.shown_value()
			# The switch stands right of the note.
			_fitted(note, StudioTokens.Face.JAKARTA_500, 21.76, 460.0 if switched else 512.0).draw(_ink,
				Vector2(61.44, y + 47.2), Backdrop.palette.mute)
		elif kind == Kind.LEVEL:
			_draw_sound_level(y)
		else:
			var value := _fitted(row.shown_value(), StudioTokens.Face.JAKARTA_700, 26.88, 240.0)
			value.draw(_ink, Vector2(608.0 - value.width, y + 20.8), Backdrop.palette.mute)
			FormPaint.chevron(_ink, Vector2(629.61, y + 40.96), Vector2(-6.88, 0.0), Vector2(0.0, 6.88), Backdrop.palette.mute,
				3.584, false)
		if i < last:
			_ink.draw_line(Vector2(61.44, y + (_ROW_SIZE.y + _PITCH) / 2.0), Vector2(_items.position.x + _ROW_SIZE.x - 17.92,
				y + (_ROW_SIZE.y + _PITCH) / 2.0), Backdrop.palette.line, 1.0)
	for way: int in [-1, 1]:
		if _more(way):
			FormPaint.chevron(_ink, Vector2(_panel.size.x / 2.0, (_MORE_UP_Y if way < 0 else _MORE_DOWN_Y) + way * 4.0),
				Vector2(0.0, -way * 7.68), Vector2(11.52, 0.0), Backdrop.palette.mute, 3.584, false)


## The sounds' level on the line at [param y]: its steps, the ones it reaches in the gel.
func _draw_sound_level(y: float) -> void:
	for i in SoundEffects.LEVELS:
		var at := Vector2(_step_x(i), y + (_ROW_SIZE.y - _STEP_SIZE.y) / 2.0)
		_ink.draw_rect(Rect2(at, _STEP_SIZE), gel if i < sound_level else Backdrop.palette.line)


## Where the sounds' step [param i] starts, in x of the card.
static func _step_x(i: int) -> float:
	return 629.61 - (SoundEffects.LEVELS - i) * (_STEP_SIZE.x + _STEP_GAP)


func _row_name(row: FieldButton, kind: Kind) -> StudioText:
	var face := StudioTokens.Face.JAKARTA_800 if row.has_focus() else StudioTokens.Face.JAKARTA_700
	if kind == Kind.CHOICE_BELOW:
		return _fitted(tr(row.label), face, 30.08, 560.0)
	var line := StudioText.new(tr(row.label), face, 30.08)
	line.fit(450.0 if kind == Kind.SWITCH else 380.0)
	return line


## [param text] at [param px], set smaller when it is wider than [param room]: never cut, it says what a line holds.
static func _fitted(text: String, face: StudioTokens.Face, px: float, room: float) -> StudioText:
	var line := StudioText.new(text, face, px)
	return line if line.width <= room else StudioText.new(text, face, px * room / line.width)


## How the row of [param key] (a key of [constant ROWS]) changes.
static func kind_of(key: StringName) -> Kind:
	return ROWS[key][&"kind"]


## The keys of the rows that are switches, top to bottom: each a setting's key.
static func switches() -> Array[StringName]:
	return ROWS.keys().filter(func(key: StringName) -> bool: return kind_of(key) == Kind.SWITCH)


## The row of [param key] (a key of [constant ROWS]).
func row_of(key: StringName) -> FieldButton:
	return _rows_of[key]


## Shows the switch of [param choice] [param on] at once: a stored value.
func snap_switch(choice: StringName, on: bool) -> void:
	_switches[choice].snap(on, gel)


## Slides the switch of [param choice] to [param on]: a user change or a rollback.
func slide_switch(choice: StringName, on: bool) -> void:
	_switches[choice].animate(on, gel)


## Shows the button style, the edges' smoothing, the backdrop, and what [param request] (a [Shown]) says: the
## preferred region (empty for none), the language (empty for the device's), and the row that takes the focus.
func _open(request: Variant) -> void:
	var shown: Shown = request
	for switch: Switch in _switches.values():
		switch.snap(switch.on, gel)
	if state == State.CLOSED:
		state = State.OPEN
		_closing = false
		_clock.stand(DURATION_S)
	show_choices(shown.region, shown.language)
	_first = 0
	_show_rows()
	_rows_of[nearest_shown(shown.row, _keys)].grab_focus()
	# The line already focused takes no focus_entered: its place on the card is set here.
	var holder := get_viewport().gui_get_focus_owner() as FieldButton
	_focus_row(holder if holder in _rows else _rows[0])
	if state == State.OPENING:
		_sample()
		_clock.play(DURATION_S)
		set_process(true)


## The choices' lines show what is in use: the button style, the edges' smoothing, the backdrop, and the preferred
## [param region] (empty for none) and [param language] (empty for the device's).
func show_choices(region: String, language: String) -> void:
	_rows_of[&"button_style"].show_value(Controls.style_name())
	_rows_of[&"graphics"].show_value(tr(EdgeSmoothingScreen.NAMES[EdgeSmoothingScreen.of(get_viewport())]))
	_rows_of[&"backdrop"].show_value(tr(Backdrop.NAMES[Backdrop.choice]))
	_rows_of[&"region"].show_value(region_name(region))
	_rows_of[&"language"].show_value(Locale.name_of(language))


## How the settings name [param region] (empty: none).
static func region_name(region: String) -> String:
	return TranslationServer.translate(region if region else "None")


func _on_row_pressed(choice: StringName) -> void:
	if kind_of(choice) != Kind.SWITCH:
		Sounds.play(SoundEffects.Cue.SELECT)
	# A switch's press from a mouse, or synthesized, bypasses _input: none while a save is pending or the card moves.
	elif holds_presses():
		return
	done.emit(choice)


## What the card is opened for: the row that takes the focus (a key of [constant ROWS]), the preferred region and
## the language to show.
class Shown:
	extends RefCounted

	var row: StringName
	var region: String
	var language: String

	func _init(focused: StringName, preferred: String, spoken: String) -> void:
		row = focused
		region = preferred
		language = spoken


## A switch right of a line's note: its knob slid right and its track in the gel when on.
class Switch:
	extends RefCounted

	const _TRAVEL := 38.4
	const _TRACK := Vector2(81.92, 43.52)
	const _KNOB := Vector2(34.56, 34.56)

	var on := false
	var _track := _piece()
	var _knob := _piece()
	var _knob_x := 0.0
	var _color := Color.TRANSPARENT
	var _tween: Tween

	func _init(row: Control) -> void:
		_track.position = Vector2(507.68, 7.2)
		row.add_child(_track)
		_track.add_child(_knob)
		_knob.position = Vector2.ONE * 4.48

	## Shows [param value] at once, in the backdrop shown, the track in [param gel] when on.
	func snap(value: bool, gel: Color) -> void:
		on = value
		if _tween:
			_tween.kill()
		_place(_TRAVEL if on else 0.0)
		repaint(gel)

	## Paints the switch again in the backdrop shown where it stands: a slide under way goes on to its end.
	func repaint(gel: Color) -> void:
		_paint(_track, _TRACK, 21.76, false)
		_paint(_knob, _KNOB, 17.28, true)
		if not (_tween and _tween.is_running()):
			_color_track(gel if on else Backdrop.palette.switch_track_off)

	## Slides to [param value], the track turning to [param gel] or off.
	func animate(value: bool, gel: Color) -> void:
		if on == value:
			return
		on = value
		_tween = Motion.restart(_track, _tween).set_parallel()
		var start := _knob_x
		var end := _TRAVEL if on else 0.0
		var color_start := _color
		# The end read at each step: another backdrop shown meanwhile is slid to.
		_tween.tween_method(func(t: float) -> void:
			_place(lerpf(start, end, Motion.eased(Motion.Easing.SNAP, t)))
			_color_track(color_start.lerp(gel if on else Backdrop.palette.switch_track_off,
				Motion.eased(Motion.Easing.EASE, t))), 0.0, 1.0, 0.2)

	func _place(x: float) -> void:
		_knob_x = x
		_knob.position.x = 4.48 + x

	func _color_track(color: Color) -> void:
		_color = color
		(_track.material as ShaderMaterial).set_shader_parameter(&"colors", [StudioMaterial.rgba(color), StudioMaterial.rgba(color)])

	static func _piece() -> ColorRect:
		var piece := ColorRect.new()
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.material = ShaderMaterial.new()
		(piece.material as ShaderMaterial).shader = preload("res://studio/satin_panel.gdshader")
		return piece

	## The knob or the track, [param box] rounded by [param radius], in the backdrop shown.
	static func _paint(piece: ColorRect, box: Vector2, radius: float, knob: bool) -> void:
		var palette := Backdrop.palette
		piece.size = box + Vector2.ONE * 24.0
		var parameters: Dictionary[StringName, Variant] = {
			&"box_position": Vector2.ONE * 12.0, &"box_size": box, &"radius": radius,
			&"stop_count": 3 if knob else 2, &"stops": [0.0, 0.6, 1.0] if knob else [0.0, 1.0],
			&"colors": ([palette.knob_top, palette.switch_knob_middle, palette.switch_knob_edge] if knob
				else [palette.switch_track_off, palette.switch_track_off]).map(StudioMaterial.rgba),
			&"centre": Vector2(0.36, 0.3) if knob else Vector2(-1, -1),
			&"shadow_count": 1, &"inset_count": 0 if knob else 1,
			&"shadow_shapes": [Vector4(0, 1.92, 3.84, 0)] if knob else [Vector4(0, 2.56, 5.12, 0)],
			&"shadow_colors": [StudioMaterial.rgba(palette.switch_shadow_knob if knob else palette.switch_shadow_track)],
		}
		for key in parameters:
			(piece.material as ShaderMaterial).set_shader_parameter(key, parameters[key])
