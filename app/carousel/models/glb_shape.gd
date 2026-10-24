# SPDX-License-Identifier: GPL-3.0-or-later
@tool
@abstract
class_name GlbShape
extends ModelShape
## The dimensions of a model drawn from a glb: what the launch reads of it (where a medium seats and the
## parts' travel), in millimetres. The glb holds its meshes, so the shape builds none and has no rules.


func parts() -> Array[StringName]:
	return []


func _arrays(_part: StringName, _detail: int) -> Array:
	return []


func _rules() -> Dictionary[StringName, bool]:
	return {}
