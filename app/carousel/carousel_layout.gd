# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselLayout
extends RefCounted
## The screen mechanics of the consoles and games rows as pure functions: how the row moves, how the selected model
## floats and how fast a held direction repeats. The scenes only apply them, and tests call them headless.
##
## Positions are indexes. A row of more than [constant WHOLE_SHELF] items is an endless
## row: position p shows item `posmod(p, count)`, so moving right from the last item reaches the
## first. A shorter one fits on screen and is shown whole, in order: moving right from its last
## item slides back to the first, as no item can stand at both ends at once. The scroll is the
## position shown, fractional while the row moves.

## The screen size the layout is set out on, in pixels, shared by the consoles and games screens.
const FRAME := Vector2(1280.0, 960.0)

## Places shown on each side of the selected game; one more on each side slides in and out.
const REACH := 1
const WHOLE_SHELF := 2 * REACH + 2
## A held direction steps once, waits [constant FIRST_REPEAT_S], then repeats faster and faster,
## never faster than every [constant FASTEST_REPEAT_S]: just under three frames at 60 fps, so that
## the fastest repeat lands on a frame (20 steps a second) instead of waiting for a fourth.
const FIRST_REPEAT_S := 0.35
const REPEAT_SPEED_UP := 0.82
const FASTEST_REPEAT_S := 0.048
## The row covers one step in this time, and faster when it is behind.
const STEP_S := 0.16
## The selected model floats up and down at this pace, in radians a second, this high at most (in
## world units), and sways this much (in degrees) unless told otherwise.
const _FLOAT_SPEED := 1.6
const BOB_HEIGHT := 0.05
const SWAY_DEGREES := 7.0


## The position showing game [param index] nearest [param position]: on an endless row, the one
## the shorter way round.
static func nearest(position: int, index: int, count: int) -> int:
	if count <= WHOLE_SHELF:
		return index
	var ahead := posmod(index - position, count)
	return position + (ahead if ahead * 2 <= count else ahead - count)


## How far the selected model floats up at [param clock_s], [param height] at most, as much as it is
## [param posed] (from 0 to 1).
static func float_height(clock_s: float, height: float, posed: float) -> float:
	return sin(clock_s * _FLOAT_SPEED) * height * posed


## The scroll one frame of [param delta] seconds later, moving towards [param target] without
## passing it.
static func scrolled(scroll: float, target: float, delta: float) -> float:
	var speed := maxf(1.0, absf(target - scroll)) / STEP_S
	return move_toward(scroll, target, speed * delta)


## The wait before the next step of a direction held for [param steps] steps already.
static func repeat_delay(steps: int) -> float:
	return maxf(FASTEST_REPEAT_S, FIRST_REPEAT_S * pow(REPEAT_SPEED_UP, steps))


## The steps of a direction held, again and again, faster and faster ([method repeat_delay]): the owner steps once as
## it is pressed ([method start]), then whenever [method due] says so.
class Repeat:
	extends RefCounted

	## The steps repeated since the press.
	var steps := 0
	var _left_s := 0.0

	func start() -> void:
		steps = 0
		_left_s = CarouselLayout.repeat_delay(0)

	## Whether a step is due once [param delta] more seconds have passed.
	func due(delta: float) -> bool:
		_left_s -= delta
		if _left_s > 0.0:
			return false
		steps += 1
		_left_s = CarouselLayout.repeat_delay(steps)
		return true
