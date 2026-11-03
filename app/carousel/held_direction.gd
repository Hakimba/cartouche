# SPDX-License-Identifier: GPL-3.0-or-later
class_name HeldDirection
extends RefCounted
## Which way the carousel is held, left or right, or whether up is, read from input events. A stick
## sends a stream of events while it is held: only a press or a release is a change. Every event is
## read, even while the carousel ignores moves, so that a release is never missed.

const _LEFT_RIGHT: Dictionary[StringName, int] = {&"carousel_left": -1, &"carousel_right": 1}

## The direction of the last change, -1 or 1, and whether it is now held.
var direction := 0
var held := false
var _actions: Dictionary[StringName, int]
var _held: Dictionary[StringName, bool] = {}


## Reads [param actions], each with its direction.
func _init(actions := _LEFT_RIGHT) -> void:
	_actions = actions


## Records [param event]; returns whether it pressed or released a direction.
func update(event: InputEvent) -> bool:
	# A stick's motion matches both directions of its axis, pressing one at most.
	for action: StringName in _actions:
		var pressed := event.is_action_pressed(action)
		if event.is_action(action) and pressed != _held.get(action, false):
			_held[action] = pressed
			direction = _actions[action]
			held = pressed
			return true
	return false


## Forgets what is held, as if let go: a release the app never received.
func let_go() -> void:
	_held.clear()
	held = false
