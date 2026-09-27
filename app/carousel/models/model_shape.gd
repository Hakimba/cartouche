# SPDX-License-Identifier: GPL-3.0-or-later
@tool
@abstract
class_name ModelShape
extends Resource
## The dimensions a model is built from, in millimetres; each [ShapedMesh] of the model is one of
## its [method parts].

## Where the title and the platform are drawn on a label, as fractions of its image, unless a
## shape says otherwise.
const TITLE_AREA := Rect2(0.06, 0.08, 0.88, 0.6)
const PLATFORM_AREA := Rect2(0.1, 0.72, 0.8, 0.18)


## The names of the parts, such as `label`.
@abstract func parts() -> Array[StringName]


## The rules these dimensions break, by name; none when the model can be built.
func problems() -> Array[StringName]:
	var rules := _rules()
	var broken: Array[StringName] = []
	broken.assign(rules.keys().filter(func(rule: StringName) -> bool: return not rules[rule]))
	return broken


## The mesh arrays of [param part], curves in [param detail] steps; none when there are
## [method problems] or [param part] is not one of [method parts].
@abstract func mesh_arrays(part: StringName, detail: int) -> Array


## Where the title is drawn on the label, as a fraction of its image.
func title_area() -> Rect2:
	return TITLE_AREA


func platform_area() -> Rect2:
	return PLATFORM_AREA


## Each rule of these dimensions, by name, and whether they follow it.
@abstract func _rules() -> Dictionary[StringName, bool]
