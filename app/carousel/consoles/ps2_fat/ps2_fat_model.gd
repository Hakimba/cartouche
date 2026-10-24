# SPDX-License-Identifier: GPL-3.0-or-later
class_name Ps2FatModel
extends ConsoleModel
## The bench's fat PS2: its tray moves towards the front, carrying the disc; both buttons press in.

var tray_mm := 0.0:
	set(value):
		if value == tray_mm:
			return
		tray_mm = value
		if is_node_ready():
			_tray.position.z = value * MeshBuilder.UNITS_PER_MM
var power_mm := 0.0:
	set(value):
		if value == power_mm:
			return
		power_mm = value
		if is_node_ready():
			_power.position.z = -value * MeshBuilder.UNITS_PER_MM
var eject_mm := 0.0:
	set(value):
		if value == eject_mm:
			return
		eject_mm = value
		if is_node_ready():
			_eject.position.z = -value * MeshBuilder.UNITS_PER_MM

@onready var _tray: Node3D = $Model/ps2_fat/tray
@onready var _power: Node3D = $Model/ps2_fat/power
@onready var _eject: Node3D = $Model/ps2_fat/eject


func _ready() -> void:
	_tray.position.z = tray_mm * MeshBuilder.UNITS_PER_MM
	_power.position.z = -power_mm * MeshBuilder.UNITS_PER_MM
	_eject.position.z = -eject_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"tray_mm", MovingPart.Role.OPENING, 0.0, (shape as Ps2FatShape).tray_travel),
		MovingPart.new(&"eject_mm", MovingPart.Role.PRESS, 0.0, 1.5),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER_PRESS, 0.0, 1.5),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, 2.0),
	]


func seat() -> Transform3D:
	return (shape as Ps2FatShape).seat(tray_mm)


func _lights() -> Array[MeshInstance3D]:
	return [$Model/ps2_fat/power/led]
