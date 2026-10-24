# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleProperties
extends PropertiesScreen
## The console staged under its light, with its logo and the existing ordering action.

signal order_asked

enum Step { CLOSED, PROPERTIES }

static var _in_row := Staging.new(0.0, 0.0, 1.0, 0.0, 440.0)
static var _on_properties := Staging.new(1.0, 0.12, 1.0, 0.5, 440.0)
static var _opening := Move.new(Leave.FADE, 0.15, 0.52, Arrive.RISE, 0.24, 0.32)
static var _closing := Move.new(Leave.FADE, 0.15, 0.48, Arrive.FADE, 0.2, 0.3)

var consoles: ConsoleRow
var orderable := true
var _step := Step.CLOSED

@onready var _change_place: Button = %ChangePlace
@onready var _logo: LogoView = %Logo


func _init() -> void:
	_staging = _in_row


func _ready() -> void:
	super()
	_change_place.pressed.connect(_to_order)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var centre := camera.unproject_position(consoles.selected().model.global_position)
	light.look(centre, _staging.radius, _staging.darkness)


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.CLOSED or event.is_echo() or _busy:
		return
	if orderable and event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		_to_order()
	elif event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_close()


func is_open() -> bool:
	return _step != Step.CLOSED or _busy


func open() -> void:
	_logo.show_logo(LogoView.Slot.RING_MIDDLE, consoles.selected().folder)
	_logo.size = _logo.texture.get_size()
	_logo.position = Vector2(640.0 - _logo.size.x / 2.0, 730.0)
	_change_place.visible = orderable
	_step = Step.PROPERTIES
	show()
	set_process(true)
	await _move(behind, [_properties], _on_properties, _opening)
	(_change_place if orderable else _properties).grab_focus()


func _close() -> void:
	_step = Step.CLOSED
	_put_back([_properties], behind, _in_row, _closing)


func _to_order() -> void:
	if _busy:
		return
	_step = Step.CLOSED
	order_asked.emit()
	_put_back([_properties], [], _in_row, _closing)


func _place() -> void:
	consoles.stage = _staging.amount
	consoles.staged_lift = _staging.height
	consoles.staged_size = _staging.size
