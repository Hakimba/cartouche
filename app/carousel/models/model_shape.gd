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

# The rules broken, found once for each change of the dimensions: every part's mesh asks for them.
var _broken: Array[StringName] = []
var _checked := false


## The names of [param rules] not followed.
static func broken(rules: Dictionary[StringName, bool]) -> Array[StringName]:
	var found: Array[StringName] = []
	found.assign(rules.keys().filter(func(rule: StringName) -> bool: return not rules[rule]))
	return found


# A method, not a lambda holding the shape: the shape would hold itself and never be freed.
func _init() -> void:
	changed.connect(_forget_problems)


## The names of the parts, such as `label`.
@abstract func parts() -> Array[StringName]


## The rules these dimensions break, by name; none when the model can be built.
func problems() -> Array[StringName]:
	if not _checked:
		_broken = broken(_rules())
		_checked = true
	return _broken.duplicate()


## The parts drawn as a single face, open by nature (a floor seen from above); the others each
## enclose a volume.
func surfaces() -> Array[StringName]:
	return []


## Each of these dimensions by name, as the shape exports them.
func dimensions() -> Dictionary[StringName, Variant]:
	var found: Dictionary[StringName, Variant] = {}
	for property in get_property_list():
		var usage: int = property["usage"]
		var name: StringName = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			found[name] = get(name)
	return found


## The mesh arrays of [param part], curves in [param detail] steps; none when there are
## [method problems] or [param part] is not one of [method parts].
func mesh_arrays(part: StringName, detail: int) -> Array:
	if not problems().is_empty() or part not in parts():
		return []
	return _arrays(part, detail)


## Where the title is drawn on the label, as a fraction of its image.
func title_area() -> Rect2:
	return TITLE_AREA


func platform_area() -> Rect2:
	return PLATFORM_AREA


## The radius of the ring a blank label shows while its image downloads, centred on it, as a
## fraction of its image's smaller side.
func progress_ring_radius() -> float:
	return 0.2


func _forget_problems() -> void:
	_checked = false


## The mesh arrays of [param part], one of [method parts], of dimensions without [method problems].
@abstract func _arrays(part: StringName, detail: int) -> Array


## Each rule of these dimensions, by name, and whether they follow it.
@abstract func _rules() -> Dictionary[StringName, bool]
