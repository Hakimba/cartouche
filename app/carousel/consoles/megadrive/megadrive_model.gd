# SPDX-License-Identifier: GPL-3.0-or-later
class_name MegaDriveModel
extends ConsoleModel
## The Mega Drive, drawn from its glb (`megadrive.glb`, or a variant's) and read by its [MegaDriveShape]: a cartridge
## goes down through the dust flaps into the slot of its top. Nothing on it moves.


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())


func moving_parts() -> Array[MovingPart]:
	return []


func seat() -> Transform3D:
	return (shape as MegaDriveShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return three_quarter()
