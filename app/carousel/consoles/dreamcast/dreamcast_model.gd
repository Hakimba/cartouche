# SPDX-License-Identifier: GPL-3.0-or-later
class_name DreamcastModel
extends ConsoleModel
## The Dreamcast, drawn from its glb (`dreamcast.glb`) and read by its [DreamcastShape]: a disc comes down onto the
## drive under its lid, label up. Nothing on it moves.


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())


func moving_parts() -> Array[MovingPart]:
	return []


func seat() -> Transform3D:
	return (shape as DreamcastShape).seat()


func presented() -> Basis:
	return three_quarter()
