# SPDX-License-Identifier: GPL-3.0-or-later
class_name StickTurn
extends RefCounted
## How the right stick turns the selected one of a row of models: pushed, it turns it any way, up to
## its back; let go, it stays exactly as it was left; once another is selected, the one turned turns
## back to the front as it leaves, and the one arriving turns from its front. A finger turns the
## selected one too, but it comes back to the front once let go ([constant BACK_S]).

## Radians a second, the stick pushed all the way; radians a pixel dragged; how long a model turned
## by a finger takes to come back to the front once let go, in seconds.
const SPEED := 2.6
const PER_PIXEL := 0.006
const BACK_S := 0.35

## How the stick has turned the model it last turned; back to none once another is selected.
var turned := Basis.IDENTITY
## Index of the model last turned, -1 for none.
var index := -1

var _shown := Basis.IDENTITY
## How a finger turns the model it touched last, in radians about Y then X, which one, and whether
## it still touches it; the one selected now.
var _touched := Vector2.ZERO
var _touched_at := -1
var _touching := false
var _selected := -1


## Follows [param stick] (each axis from -1 to 1) for [param delta] seconds, [param selected] being
## the index of the selected model; what shows catches up with the turn.
func follow(stick: Vector2, selected: int, delta: float) -> void:
	_selected = selected
	if not _touching:
		_touched = Vector2.ZERO if _touched.length() < 0.0001 else _touched * exp(-3.0 * delta / BACK_S)
	if not stick.is_zero_approx():
		if index != selected:
			_shown = Basis.IDENTITY
			index = selected
		var push := stick * SPEED * delta
		turned = (Basis.from_euler(Vector3(push.y, push.x, 0.0)) * turned).orthonormalized()
	_shown = _shown.slerp(turned, 1.0 - exp(-10.0 * delta))
	# Then exactly there: a model let go stays still.
	if _shown.get_rotation_quaternion().angle_to(turned.get_rotation_quaternion()) < 0.001:
		_shown = turned


## How the model at [param at] shows turned.
func of(at: int) -> Basis:
	var touched := Basis.from_euler(Vector3(_touched.y, _touched.x, 0.0)) if at == _touched_at else Basis.IDENTITY
	return touched * (_shown if at == index else Basis.IDENTITY)


## A finger dragged [param pixels] over the selected model, which turns with it.
func touch(pixels: Vector2) -> void:
	if _touched_at != _selected:
		_touched = Vector2.ZERO
		_touched_at = _selected
	_touching = true
	_touched += pixels * PER_PIXEL


## The finger is lifted: the model comes back to the front.
func let_go() -> void:
	_touching = false


## Another is selected: the one turned turns back to the front.
func release() -> void:
	turned = Basis.IDENTITY
