# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbaSpModel
extends ConsoleModel
## The Game Boy Advance SP, open at rest: the lid folds forwards and the switch slides towards its ON marking.

var lid_degrees := 0.0:
	set(value):
		if value == lid_degrees:
			return
		lid_degrees = value
		if is_node_ready():
			_lid.rotation.x = deg_to_rad(value)
var power_mm := 0.0:
	set(value):
		if value == power_mm:
			return
		power_mm = value
		if is_node_ready():
			_power.position.y = _power_rest + value * MeshBuilder.UNITS_PER_MM

@onready var _lid: Node3D = $Model/gba_sp/lid
@onready var _power: Node3D = $Model/gba_sp/power
@onready var _power_rest := _power.position.y


func _ready() -> void:
	_lid.rotation.x = deg_to_rad(lid_degrees)
	_power.position.y = _power_rest + power_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"lid_degrees", MovingPart.Role.POSE, 0.0, 105.0),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as GbaSpShape).power_travel),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, 2.5),
	]


func seat() -> Transform3D:
	return (shape as GbaSpShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func _lights() -> Array[MeshInstance3D]:
	return [$Model/gba_sp/led]
