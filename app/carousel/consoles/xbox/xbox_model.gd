# SPDX-License-Identifier: GPL-3.0-or-later
class_name XboxModel
extends ConsoleModel
## The Xbox, built from its [XboxShape]: the tray slides out of the strip's left half with its disc,
## the eject button presses in, the power button is pressed and let go, the ring around the power button lights up.

## How far the buttons press in, in millimetres, unless they stand out less (see
## [method ConsoleModel.press_travel]); how bright the power ring is once lit.
const _PRESS_MM := 1.5
const _LIT := 2.5

## How far the tray is out, in millimetres.
var tray_mm := 0.0:
	set(value):
		# Given each frame by the launch animation: the tray is moved only when it slides.
		if value != tray_mm and is_node_ready():
			_tray.position.z = value * MeshBuilder.UNITS_PER_MM
		tray_mm = value
## How far the power and eject buttons are pressed in, in millimetres.
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.z = -value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var eject_mm := 0.0:
	set(value):
		if value != eject_mm and is_node_ready():
			_eject.position.z = -value * MeshBuilder.UNITS_PER_MM
		eject_mm = value

@onready var _tray: Node3D = %Tray
@onready var _power: Node3D = %Power
@onready var _eject: Node3D = %Eject


func _ready() -> void:
	var mm := MeshBuilder.UNITS_PER_MM
	_tray.position.z = tray_mm * mm
	_power.position.z = -power_mm * mm
	_eject.position.z = -eject_mm * mm


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"tray_mm", MovingPart.Role.OPENING, 0.0, (shape as XboxShape).tray_travel()),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER_PRESS, 0.0, _pressed()),
		MovingPart.new(&"eject_mm", MovingPart.Role.PRESS, 0.0, _pressed()),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as XboxShape).seat(tray_mm)


func _pressed() -> float:
	return press_travel(XboxShape.BUTTON_RAISE, _PRESS_MM)
