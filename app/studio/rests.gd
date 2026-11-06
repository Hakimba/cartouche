# SPDX-License-Identifier: GPL-3.0-or-later
class_name Rests
extends RefCounted
## Where a screen's moving controls stand at rest, kept as their offsets from their anchors rather than as positions: a
## screen whose window changes shape after it was set out still brings them back where its layout puts them.

var _offsets: Dictionary[Control, Vector2] = {}


## Keeps where each of [param controls] stands now as its rest.
func _init(controls: Array[Control]) -> void:
	for control in controls:
		_offsets[control] = Vector2(control.offset_left, control.offset_top)


## Where [param control] stands at rest, on its parent as it is now.
func of(control: Control) -> Vector2:
	return Vector2(control.anchor_left, control.anchor_top) * control.get_parent_area_size() + _offsets[control]


## Puts every control back at its rest, whole.
func restore() -> void:
	for control in _offsets:
		control.position = of(control)
		control.modulate.a = 1.0
