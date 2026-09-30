# SPDX-License-Identifier: GPL-3.0-or-later
class_name StickTurn
extends RefCounted
## How the right stick turns the selected one of a row of models: pushed, it turns it any way, up to
## its back; let go, it stays exactly as it was left; once another is selected, the one turned turns
## back to the front as it leaves, and the one arriving turns from its front.

## Radians a second, the stick pushed all the way.
const SPEED := 2.6

## How the stick has turned the model it last turned; back to none once another is selected.
var turned := Basis.IDENTITY
## Index of the model last turned, -1 for none.
var index := -1

var _shown := Basis.IDENTITY


## Follows [param stick] (each axis from -1 to 1) for [param delta] seconds, [param selected] being
## the index of the selected model; what shows catches up with the turn.
func follow(stick: Vector2, selected: int, delta: float) -> void:
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
	return _shown if at == index else Basis.IDENTITY


## Another is selected: the one turned turns back to the front.
func release() -> void:
	turned = Basis.IDENTITY
