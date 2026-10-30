# SPDX-License-Identifier: GPL-3.0-or-later
class_name FocusScale
extends RefCounted
## The focused control grows a little, from its centre, and shrinks back once the focus leaves.

const GROWN := 1.03
const DURATION_S := 0.12

var _tween: Tween


## Makes [param control] grow while it has the focus.
func watch(control: Control) -> void:
	control.focus_entered.connect(_scale.bind(control, GROWN))
	control.focus_exited.connect(_scale.bind(control, 1.0))
	control.pivot_offset_ratio = Vector2(0.5, 0.5)


func _scale(control: Control, to: float) -> void:
	_tween = Motion.restart(control, _tween)
	_tween.tween_property(control, ^"scale", Vector2.ONE * to, DURATION_S)
