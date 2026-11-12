# SPDX-License-Identifier: GPL-3.0-or-later
class_name HeldDirection
extends RefCounted
## Which of a few directions is held, read from input events: the carousel's left and right, the directions the
## screens' focus follows (up holding the "+" of the consoles screen), the model swatches' and the settings' sound level.
## A stick sends a stream of events while it is held: only a press or a release is a change. A stick held is let go only
## once back under [constant _LET_GO] of its dead zone: its strength wavering about the dead zone is not a press again.
## Every event is read, even while its reader ignores moves, so that a release is never missed.

const _LEFT_RIGHT: Dictionary[StringName, int] = {&"carousel_left": -1, &"carousel_right": 1}
const _LET_GO := 0.5

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
		if not event.is_action(action):
			continue
		var pressed := event.is_action_pressed(action) or holds(action)
		if pressed != _held.get(action, false):
			_held[action] = pressed
			direction = _actions[action]
			held = pressed
			return true
	return false


## Whether [param action] is held: by any of its sources (a stick resting in its dead zone under a held D-pad does not
## let go of it), a stick once pressed until it is back under [constant _LET_GO] of its dead zone.
func holds(action: StringName) -> bool:
	return Input.is_action_pressed(action) or (_held.get(action, false)
		and Input.get_action_raw_strength(action) >= InputMap.action_get_deadzone(action) * _LET_GO)


## Whether [param event] presses one of the directions read, held already or not.
func presses(event: InputEvent) -> bool:
	for action: StringName in _actions:
		if event.is_action_pressed(action):
			return true
	return false


## Forgets what is held, as if let go: a release the app never received.
func let_go() -> void:
	_held.clear()
	held = false


## Takes what is held from the engine's input state: a release another screen took is seen, and a direction still held
## is not pressed again.
func read_again() -> void:
	for action: StringName in _actions:
		_held[action] = Input.is_action_pressed(action)
		if _actions[action] == direction:
			held = _held[action]
