# SPDX-License-Identifier: GPL-3.0-or-later
class_name SwitchModel
extends ConsoleModel
## The Nintendo Switch, its Joy-Con attached, drawn from its glb (`switch.glb`, or a variant's) and read by its
## [SwitchShape]: a game card goes down into the slot at the right of its top edge. Nothing on it moves.


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())


func moving_parts() -> Array[MovingPart]:
	return []


func seat() -> Transform3D:
	return (shape as SwitchShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return standing()
