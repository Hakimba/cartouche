# SPDX-License-Identifier: GPL-3.0-or-later
class_name GcModel
extends ConsoleModel
## The GameCube, built from its [GcShape]: the lid turns about its hinge, the power and open buttons
## are pushed in, the power light comes on behind its window, and the drive's [Spindle] sits in the
## well, where a seated disc's centre is the spindle's origin.

## How far a button goes in once pushed, in millimetres, and the power light's glow once on.
const _PUSHED_MM := 1.0
const _LIT := 1.6

var lid_degrees := 0.0:
	set(value):
		if value != lid_degrees and is_node_ready():
			_lid.rotation.x = -deg_to_rad(value)
		lid_degrees = value
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.y = -value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var open_mm := 0.0:
	set(value):
		if value != open_mm and is_node_ready():
			_open.position.y = -value * MeshBuilder.UNITS_PER_MM
		open_mm = value

@onready var _spindle: Spindle = %Spindle
@onready var _lid: Node3D = %Lid
@onready var _power: Node3D = %Power
@onready var _open: Node3D = %Open


func _ready() -> void:
	_lid.position = (shape as GcShape).hinge()
	_spindle.transform = (shape as GcShape).seat()
	_lid.rotation.x = -deg_to_rad(lid_degrees)
	_power.position.y = -power_mm * MeshBuilder.UNITS_PER_MM
	_open.position.y = -open_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"lid_degrees", MovingPart.Role.OPENING, 0.0, GcShape.OPEN_DEGREES),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, _PUSHED_MM),
		MovingPart.new(&"open_mm", MovingPart.Role.PRESS, 0.0, _PUSHED_MM),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as GcShape).seat()


func hold(angle: float) -> void:
	_spindle.turn(angle)
