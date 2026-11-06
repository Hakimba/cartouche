# SPDX-License-Identifier: GPL-3.0-or-later
class_name MasterSystemModel
extends ConsoleModel
## The Master System, drawn from its glb (`mastersystem.glb`) and read by its [MasterSystemShape]: a cartridge goes down
## through the flap into the slot of its top. Nothing on it moves.


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())


func moving_parts() -> Array[MovingPart]:
	return []


func seat() -> Transform3D:
	return (shape as MasterSystemShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return three_quarter()
