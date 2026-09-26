# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## Shows every controller input the app receives. While visible it captures all input except
## touches; holding Start leaves it. Raw joypad indices are the point of this page: everywhere
## else, input goes through InputMap actions.

signal leave_requested

const _HOLD_TO_LEAVE_S := 2.0
const _BUTTONS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A (south)", JOY_BUTTON_B: "B (east)",
	JOY_BUTTON_X: "X (west)", JOY_BUTTON_Y: "Y (north)",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select / Back",
}
const _AXES: Dictionary[int, String] = {
	JOY_AXIS_LEFT_X: "Left stick ↔", JOY_AXIS_LEFT_Y: "Left stick ↕",
	JOY_AXIS_RIGHT_X: "Right stick ↔", JOY_AXIS_RIGHT_Y: "Right stick ↕",
	JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2",
}

var _cells: Dictionary[String, Label] = {}
var _seen: Dictionary[String, bool] = {}
var _start_presses := 0

@onready var _grid: GridContainer = %Grid
@onready var _axes: Label = %Axes
@onready var _events: RichTextLabel = %Events


func _ready() -> void:
	for button: int in _BUTTONS:
		_add_cell("b%d" % button, _BUTTONS[button])
	for axis: int in _AXES:
		_add_cell("a%d" % axis, _AXES[axis])


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event is InputEventScreenTouch or event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton:
		_on_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_on_motion(event as InputEventJoypadMotion)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Some handheld buttons arrive as keyboard keys rather than joypad buttons.
		var key := (event as InputEventKey).as_text_physical_keycode()
		_events.append_text("[color=yellow]key %s[/color]\n" % key)


func _on_button(event: InputEventJoypadButton) -> void:
	_light("b%d" % event.button_index, event.pressed)
	if not event.pressed:
		return
	var device := Input.get_joy_name(event.device)
	var label: String = _BUTTONS.get(event.button_index, "?")
	_events.append_text("button %d (%s) on %s\n" % [event.button_index, label, plain(device)])
	if event.button_index == JOY_BUTTON_START:
		_start_presses += 1
		var press := _start_presses
		await get_tree().create_timer(_HOLD_TO_LEAVE_S).timeout
		if press == _start_presses and Input.is_joy_button_pressed(event.device, JOY_BUTTON_START):
			leave_requested.emit()


func _on_motion(event: InputEventJoypadMotion) -> void:
	_light("a%d" % event.axis, absf(event.axis_value) > 0.5)
	var values := PackedStringArray()
	for axis: int in _AXES:
		values.append("%s %+.2f" % [_AXES[axis], Input.get_joy_axis(event.device, axis)])
	_axes.text = "   ".join(values)


func _add_cell(key: String, text: String) -> void:
	var cell := Label.new()
	cell.text = text
	cell.theme_type_variation = &"PadCell"
	_grid.add_child(cell)
	_cells[key] = cell


func _light(key: String, active: bool) -> void:
	if key not in _cells:
		return
	if active and key not in _seen:
		_seen[key] = true
		if _seen.size() == _cells.size():
			logged.emit("[color=lightgreen]Controller: every expected input was received.[/color]")
	_cells[key].theme_type_variation = (&"PadCellActive" if active
			else &"PadCellSeen" if key in _seen else &"PadCell")
