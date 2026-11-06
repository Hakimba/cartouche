# SPDX-License-Identifier: GPL-3.0-or-later
class_name PspModel
extends ConsoleModel
## The PSP-1000, drawn from its glb (`psp.glb`) and read by its [PspShape]: a UMD comes down behind it into the drive in
## its back, label to the back. Nothing on it moves.


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())


func moving_parts() -> Array[MovingPart]:
	return []


func seat() -> Transform3D:
	return (shape as PspShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return standing()
