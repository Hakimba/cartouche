# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsMenu
extends Control
## The settings on the plain backdrop: the choices, the games floating switch and the sounds' level, which left
## and right turn down and up. The card shows [constant _SHOWN] lines; the focus scrolls the others in, and an
## arrow above or below says lines are hidden that way.

## [param choice] names a row, or `close` (B).
signal chosen(choice: StringName)
signal transition_frame(subject: float, rail: float, chrome: float)
## Left or right on the sounds' line set them to [param steps].
signal sound_level_changed(steps: int)

enum State { OPENING, OPEN, CLOSING, CLOSED }

const _PITCH := 89.6 # Row height plus the 7.68 px gap.
const _SHOWN := 6
## Where the arrows saying lines are hidden above and below stand, in the card; a finger on one scrolls a line.
const _MORE_UP_Y := 127.64
const _MORE_DOWN_Y := 689.24
const _ROW_SIZE := Vector2(624.64, 81.92)
const _CARD_TOP := 128.0
const _HEADING_INSET := Vector2(43.52, 37.4)
## The first row's top in the card, in px: a pixel above where centring puts its text and frame.
const _ITEMS_TOP := 143.64
const _KNOB_TRAVEL := 38.4
const _KNOB_MIDDLE := Color("#f4efe7")
const _KNOB_EDGE := Color("#e2d9cc")
const _TRACK_OFF := Color("#ddd4c7")
const SAVE_ESCAPE_MS := 2000
## The sounds' level drawn as this many steps, right on the line, each this size and this far from the next.
const _STEP_SIZE := Vector2(10.24, 23.04)
const _STEP_GAP := 6.4

static var DURATION_S: float:
	get: return maxf(StudioTokens.TR_SETTINGS_OPEN_S, StudioTokens.TR_SETTINGS_CARD_AT_S + StudioTokens.TR_SETTINGS_CARD_S)

var games_float := false:
	set(value):
		if games_float == value:
			return
		games_float = value
		if is_node_ready():
			_snap_switch()
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
			_snap_switch()
var saving := false:
	set(value):
		saving = value
		_save_started_ms = Time.get_ticks_msec()
var state := State.OPEN
var _save_started_ms := 0
var _time := DURATION_S
var _direction := 1.0
var _closing := false
var _cursor_y := 0.0
var _knob_x := 0.0
var _switch_color := _TRACK_OFF
var _cursor_tween: Tween
var _switch_tween: Tween
var _rows: Array[FieldButton] = []
## The row on the card's first line.
var _first := 0
var _card: SatinPanel.Backing
var _cursor: SatinPanel.Backing
var _track: ColorRect
var _knob: ColorRect
var _ink: Control

@onready var _panel: Control = $Panel
@onready var _items: Control = $Panel/Items
@onready var _platforms: FieldButton = %Platforms
@onready var _button_style: FieldButton = %ButtonStyle
@onready var _graphics: FieldButton = %Graphics
@onready var _floating: FieldButton = %GamesFloat
@onready var _region: FieldButton = %Region
@onready var _sounds: FieldButton = %Sounds
@onready var _language: FieldButton = %Language


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)
	_panel.pivot_offset = _panel.size / 2.0
	_rows.assign([_platforms, _button_style, _graphics, _floating, _region, _sounds, _language])
	_sounds.focus_neighbor_left = _sounds.get_path_to(_sounds)
	_sounds.focus_neighbor_right = _sounds.get_path_to(_sounds)
	_card = SatinPanel.Backing.new(_panel, StudioTokens.Look.SATIN)
	_card.place(Rect2(Vector2.ZERO, _panel.size), 28.16)
	_cursor = SatinPanel.Backing.new(_items, StudioTokens.Look.FOCUS)
	_cursor.tint = gel
	for i in _rows.size():
		var row := _rows[i]
		row.size = _ROW_SIZE
		row.focus_entered.connect(_focus_row.bind(i))
		for style: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
			row.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		row.focus_neighbor_top = row.get_path_to(_rows[maxi(0, i - 1)])
		row.focus_neighbor_bottom = row.get_path_to(_rows[mini(_rows.size() - 1, i + 1)])
		row.focus_next = row.focus_neighbor_bottom
		row.focus_previous = row.focus_neighbor_top
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_ink)
	_ink.draw.connect(_draw_card)
	_place_rows()
	_track = _switch_piece(Vector2(81.92, 43.52), 21.76, false)
	_knob = _switch_piece(Vector2.ONE * 34.56, 17.28, true)
	_track.position = Vector2(507.68, 7.2)
	_floating.add_child(_track)
	_track.add_child(_knob)
	_knob.position = Vector2.ONE * 4.48
	_snap_switch()
	visibility_changed.connect(func() -> void:
		if not visible:
			set_process(false))
	set_process(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if saving:
		if event.is_action_pressed(&"screen_back") and Time.get_ticks_msec() - _save_started_ms >= SAVE_ESCAPE_MS:
			_reverse(false)
		get_viewport().set_input_as_handled()
		return
	if state == State.OPEN:
		if event is InputEventMouseButton and event.is_pressed() and _tapped_arrow(event as InputEventMouseButton):
			return
		if _sounds.has_focus() and (event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_right", true)):
			get_viewport().set_input_as_handled()
			var steps := clampi(sound_level + (1 if event.is_action_pressed(&"ui_right", true) else -1), 0, SoundEffects.LEVELS)
			if steps != sound_level:
				sound_level = steps
				sound_level_changed.emit(steps)
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


func enter() -> void:
	state = State.OPENING
	_time = 0.0
	_direction = 1.0
	_closing = false
	set_process(false)


func _reverse(opening: bool) -> void:
	Sounds.play(SoundEffects.Cue.SETTINGS if opening else SoundEffects.Cue.BACK)
	if state == State.OPEN:
		_closing = true
		_time = 0.0
	_direction = (1.0 if opening == (not _closing) else -1.0)
	state = State.OPENING if opening else State.CLOSING
	set_process(true)


func _process(delta: float) -> void:
	_time = clampf(_time + minf(delta, 0.1) * _direction, 0.0, _duration())
	_sample()
	if _time > 0.0 and _time < _duration():
		return
	var opened := (_time == _duration()) != _closing
	state = State.OPEN if opened else State.CLOSED
	set_process(false)
	if not opened:
		chosen.emit(&"close")


func _duration() -> float:
	return StudioTokens.TR_SETTINGS_CLOSE_S if _closing else DURATION_S


func _sample() -> void:
	var card := _portion(0.0, StudioTokens.TR_SETTINGS_CARD_OUT_S, StudioTokens.TR_SETTINGS_CARD_OUT_S_CURVE) if _closing \
		else 1.0 - _portion(StudioTokens.TR_SETTINGS_CARD_AT_S, StudioTokens.TR_SETTINGS_CARD_S, StudioTokens.TR_SETTINGS_CARD_S_CURVE)
	_panel.modulate.a = 1.0 - card
	_panel.position.y = _CARD_TOP + card * (25.6 if _closing else StudioTokens.TR_SETTINGS_RISE_PX)
	_panel.scale = Vector2.ONE * lerpf(1.0, 0.98 if _closing else 0.97, card)
	($Dim as ColorRect).modulate.a = 1.0 - _portion(0.06, 0.2, Motion.Easing.EASE_IN) if _closing \
		else _portion(StudioTokens.TR_SETTINGS_VEIL_AT_S, StudioTokens.TR_SETTINGS_VEIL_S, Motion.Easing.EASE_OUT)
	($Hints as Control).modulate.a = 1.0 - _portion(0.0, 0.12, Motion.Easing.LINEAR) if _closing \
		else _portion(0.21, StudioTokens.TR_SETTINGS_HINTS_S, Motion.Easing.LINEAR)
	var back_s := maxf(0.001, StudioTokens.TR_SETTINGS_CLOSE_S - StudioTokens.TR_SETTINGS_BACK_AT_S)
	var back := _portion(StudioTokens.TR_SETTINGS_BACK_AT_S, back_s, Motion.Easing.ARRIVE)
	var subject := back if _closing else 1.0 - _portion(0, StudioTokens.TR_SETTINGS_LEAVE_S, StudioTokens.TR_SETTINGS_LEAVE_S_CURVE)
	var rail := back if _closing else 1.0 - _portion(0, StudioTokens.TR_SETTINGS_SINK_S, StudioTokens.TR_SETTINGS_SINK_S_CURVE)
	var chrome := _portion(0.21, StudioTokens.TR_SETTINGS_HINTS_S, Motion.Easing.LINEAR) if _closing \
		else 1.0 - _portion(0, StudioTokens.TR_SETTINGS_HINTS_S, Motion.Easing.LINEAR)
	transition_frame.emit(subject, rail, chrome)


func _portion(start: float, duration: float, curve: Motion.Easing) -> float:
	return Motion.eased(curve, clampf((_time - start) / duration, 0.0, 1.0))


func _focus_row(index: int) -> void:
	_first = clampi(_first, index - _SHOWN + 1, index)
	# A line that cannot take the focus shows with the one under it: nothing hides behind an arrow out of reach.
	while _first == index and _first > 0 and _rows[_first - 1].focus_mode == FOCUS_NONE:
		_first -= 1
	_place_rows()
	_cursor_tween = Motion.restart(self, _cursor_tween)
	var start := _cursor_y
	_cursor_tween.tween_method(func(t: float) -> void:
		_place_cursor(lerpf(start, (index - _first) * _PITCH, Motion.eased(Motion.Easing.SNAP, t))), 0.0, 1.0, 0.24)
	_ink.queue_redraw()


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
	StudioText.new(tr("Settings"), StudioTokens.Face.JAKARTA_800, 53.76, -0.04).draw(_ink, _HEADING_INSET, StudioTokens.INK)
	var last := mini(_first + _SHOWN, _rows.size()) - 1
	for i in range(_first, last + 1):
		var row := _rows[i]
		var name_line := _row_name(row)
		var y := _ITEMS_TOP + (i - _first) * _PITCH
		var has_note := row == _floating or row == _region or row == _language
		name_line.draw(_ink, Vector2(61.44, y + (2.08 if has_note else 18.4)), StudioTokens.INK)
		if has_note:
			var note := row.shown_value() if row != _floating else tr("The selected game gently rises and falls")
			# The switch stands right of the floating note.
			_fitted(note, StudioTokens.Face.JAKARTA_500, 21.76, 460.0 if row == _floating else 512.0).draw(_ink,
				Vector2(61.44, y + 47.2), StudioTokens.MUTE)
		elif row == _sounds:
			_draw_sound_level(y)
		else:
			var value := _fitted(row.shown_value(), StudioTokens.Face.JAKARTA_700, 26.88, 240.0)
			value.draw(_ink, Vector2(608.0 - value.width, y + 20.8), StudioTokens.MUTE)
			var at := Vector2(629.61, y + 40.96)
			_ink.draw_polyline(PackedVector2Array([at + Vector2(-6.88, -6.88), at, at + Vector2(-6.88, 6.88)]), StudioTokens.MUTE, 3.584, true)
		if i < last:
			_ink.draw_line(Vector2(61.44, y + (_ROW_SIZE.y + _PITCH) / 2.0), Vector2(_items.position.x + _ROW_SIZE.x - 17.92,
				y + (_ROW_SIZE.y + _PITCH) / 2.0), StudioTokens.LINE, 1.0)
	for way: int in [-1, 1]:
		if _more(way):
			var at := Vector2(_panel.size.x / 2.0, (_MORE_UP_Y if way < 0 else _MORE_DOWN_Y) + way * 4.0)
			_ink.draw_polyline(PackedVector2Array([at + Vector2(-11.52, -way * 7.68), at, at + Vector2(11.52, -way * 7.68)]),
				StudioTokens.MUTE, 3.584, true)


## The sounds' level on the line at [param y]: its steps, the ones it reaches in the gel.
func _draw_sound_level(y: float) -> void:
	for i in SoundEffects.LEVELS:
		var at := Vector2(629.61 - (SoundEffects.LEVELS - i) * (_STEP_SIZE.x + _STEP_GAP), y + (_ROW_SIZE.y - _STEP_SIZE.y) / 2.0)
		_ink.draw_rect(Rect2(at, _STEP_SIZE), gel if i < sound_level else StudioTokens.LINE)


func _row_name(row: FieldButton) -> StudioText:
	var face := StudioTokens.Face.JAKARTA_800 if row.has_focus() else StudioTokens.Face.JAKARTA_700
	if row == _region or row == _language:
		return _fitted(tr(row.label), face, 30.08, 560.0)
	var line := StudioText.new(tr(row.label), face, 30.08)
	line.fit(450.0 if row == _floating else 380.0)
	return line


## [param text] at [param px], set smaller when it is wider than [param room]: never cut, it says what a line holds.
static func _fitted(text: String, face: StudioTokens.Face, px: float, room: float) -> StudioText:
	var line := StudioText.new(text, face, px)
	return line if line.width <= room else StudioText.new(text, face, px * room / line.width)


func _switch_piece(box: Vector2, radius: float, knob: bool) -> ColorRect:
	var piece := ColorRect.new()
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.size = box + Vector2.ONE * 24.0
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://studio/satin_panel.gdshader")
	var parameters := SatinPanel.Backing.recipe(StudioMaterial.new(StudioTokens.Look.SATIN))
	parameters[&"box_position"] = Vector2.ONE * 12.0
	parameters[&"box_size"] = box
	parameters[&"radius"] = radius
	parameters[&"stop_count"] = 3 if knob else 2
	parameters[&"stops"] = [0.0, 0.6, 1.0] if knob else [0.0, 1.0]
	parameters[&"colors"] = [Vector4(1, 1, 1, 1), _rgba(_KNOB_MIDDLE), _rgba(_KNOB_EDGE)] if knob else [Vector4(0.8667, 0.8314, 0.7804, 1),
		Vector4(0.8667, 0.8314, 0.7804, 1)]
	parameters[&"centre"] = Vector2(0.36, 0.3) if knob else Vector2(-1, -1)
	parameters[&"shadow_count"] = 1
	parameters[&"inset_count"] = 0 if knob else 1
	parameters[&"shadow_shapes"] = [Vector4(0, 1.92, 3.84, 0)] if knob else [Vector4(0, 2.56, 5.12, 0)]
	parameters[&"shadow_colors"] = [Vector4(0.27451, 0.203922, 0.133333, 0.3 if knob else 0.25)]
	for key in parameters:
		paint.set_shader_parameter(key, parameters[key])
	piece.material = paint
	return piece


## Stored values are placed at once; only a user change or rollback animates.
func animate_float(value: bool) -> void:
	if games_float == value:
		return
	var start := _knob_x
	var color := _switch_color
	games_float = value
	_place_knob(start)
	_color_track(color)
	_move_switch()


func _snap_switch() -> void:
	if _switch_tween:
		_switch_tween.kill()
	_place_knob(_KNOB_TRAVEL if games_float else 0.0)
	_color_track(gel if games_float else _TRACK_OFF)


static func _rgba(color: Color) -> Vector4:
	return Vector4(color.r, color.g, color.b, color.a)


func _move_switch() -> void:
	_switch_tween = Motion.restart(self, _switch_tween).set_parallel()
	var start := _knob_x
	var end := _KNOB_TRAVEL if games_float else 0.0
	var color_start := _switch_color
	var color_end := gel if games_float else _TRACK_OFF
	_switch_tween.tween_method(func(t: float) -> void:
		_place_knob(lerpf(start, end, Motion.eased(Motion.Easing.SNAP, t)))
		_color_track(color_start.lerp(color_end, Motion.eased(Motion.Easing.EASE, t))), 0.0, 1.0, 0.2)


func _place_knob(x: float) -> void:
	_knob_x = x
	_knob.position.x = 4.48 + x


func _color_track(color: Color) -> void:
	_switch_color = color
	(_track.material as ShaderMaterial).set_shader_parameter(&"colors", [_rgba(color), _rgba(color)])


## Shows how many [param platforms] are set up, the button style, the edges' smoothing, the preferred
## [param region] (empty for none) and the [param language] (empty for the device's), the focus on the line of
## [param focus] (a choice). With no platform, its line cannot be opened.
func open(platforms: int, focus: StringName, region: String, language: String) -> void:
	_snap_switch()
	if state == State.CLOSED:
		state = State.OPEN
		_closing = false
		_time = DURATION_S
		_sample()
	_platforms.show_value(str(platforms))
	_platforms.disabled = platforms == 0
	_platforms.focus_mode = FOCUS_NONE if _platforms.disabled else FOCUS_ALL
	_button_style.focus_neighbor_top = _button_style.get_path_to(_button_style if _platforms.disabled else _platforms)
	_button_style.show_value(Controls.style_name())
	_graphics.show_value(tr(EdgeSmoothingScreen.NAMES[EdgeSmoothingScreen.of(get_viewport())]))
	_region.show_value(region_name(region))
	_language.show_value(Locale.name_of(language))
	_first = 0
	_place_rows()
	if focus == &"graphics":
		_graphics.grab_focus()
	elif focus == &"games_float":
		_floating.grab_focus()
	elif focus == &"region":
		_region.grab_focus()
	elif focus == &"sounds":
		_sounds.grab_focus()
	elif focus == &"language":
		_language.grab_focus()
	else:
		(_button_style if focus == &"button_style" or _platforms.disabled else _platforms).grab_focus()
	# The line already focused takes no focus_entered: its place on the card is set here.
	_focus_row(maxi(_rows.find(get_viewport().gui_get_focus_owner() as FieldButton), 0))
	if state == State.OPENING:
		_sample()
		set_process(true)


## How the settings name [param region] (empty: none).
static func region_name(region: String) -> String:
	return TranslationServer.translate(region if region else "None")


func _on_platforms_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(&"platforms")


func _on_button_style_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(&"button_style")


func _on_graphics_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(&"graphics")


func _on_region_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(&"region")


func _on_language_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(&"language")


func _on_games_float_pressed() -> void:
	# A mouse or synthesized pressed signal bypasses _input.
	if not saving and state == State.OPEN:
		chosen.emit(&"games_float")
