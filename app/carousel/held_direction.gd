# SPDX-License-Identifier: GPL-3.0-or-later
class_name HeldDirection
extends RefCounted
## Which way the carousel is held, read from input events. A stick sends a stream of events while
## it is held: only a press or a release is a change. Every event is read, even while the carousel
## ignores moves, so that a release is never missed.

const _ACTIONS: Dictionary[StringName, int] = {&"carousel_left": -1, &"carousel_right": 1}

## The direction of the last change, -1 or 1, and whether it is now held.
var direction := 0
var held := false
var _held: Dictionary[StringName, bool] = {}


## Records [param event]; returns whether it pressed or released a direction.
func update(event: InputEvent) -> bool:
	# A stick's motion matches both directions of its axis, pressing one at most.
	for action: StringName in _ACTIONS:
		var pressed := event.is_action_pressed(action)
		if event.is_action(action) and pressed != _held.get(action, false):
			_held[action] = pressed
			direction = _ACTIONS[action]
			held = pressed
			return true
	return false
