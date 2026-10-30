# SPDX-License-Identifier: GPL-3.0-or-later
class_name PsxModel
extends ConsoleModel
## The first PlayStation, built from its [PsxShape]: the lid turns about its hinge, the power and
## open buttons go down when pressed, the power light comes on, and the drive's [Spindle] sits in
## the well, where a seated disc's centre is the spindle's origin.

## The lid fully open, in degrees; how far a button goes in pressed, in millimetres, as far as it
## stands out (see [method ConsoleModel.press_travel]).
const _OPEN_DEGREES := 86.0
const _PRESSED_MM := 1.5
## How bright the power light is once on, as its material's emission energy.
const _LIT := 3.0

var lid_degrees := 0.0:
	set(value):
		if value != lid_degrees and is_node_ready():
			_lid.rotation.x = -deg_to_rad(value)
		lid_degrees = value
var open_mm := 0.0:
	set(value):
		if value != open_mm and is_node_ready():
			_press(_open, &"open", value)
		open_mm = value
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_press(_power, &"power", value)
		power_mm = value

@onready var _spindle: Spindle = %Spindle
@onready var _lid: Node3D = %Lid
@onready var _power: Node3D = %PowerButton
@onready var _open: Node3D = %OpenButton


func _ready() -> void:
	_lid.position = (shape as PsxShape).hinge()
	_spindle.transform = (shape as PsxShape).seat()
	_lid.rotation.x = -deg_to_rad(lid_degrees)
	_press(_open, &"open", open_mm)
	_press(_power, &"power", power_mm)


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"lid_degrees", MovingPart.Role.OPENING, 0.0, _OPEN_DEGREES),
		MovingPart.new(&"open_mm", MovingPart.Role.PRESS, 0.0, _pressed()),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, _pressed()),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as PsxShape).seat()


func hold(angle: float) -> void:
	_spindle.turn(angle)


func _pressed() -> float:
	return press_travel(PsxGeometry.BUTTON_PROUD, _PRESSED_MM)


func _press(button: Node3D, part: StringName, mm: float) -> void:
	button.position = PsxGeometry.button_top((shape as PsxShape), part) + Vector3.DOWN * mm * MeshBuilder.UNITS_PER_MM
