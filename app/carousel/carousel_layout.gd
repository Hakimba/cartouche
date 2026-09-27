# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselLayout
extends RefCounted
## The carousel's screen mechanics as pure functions: which games stand where, how the row moves,
## and how fast a held direction repeats. The scenes only apply them, and tests call them headless.
##
## Positions are game indexes. A shelf of more than [constant WHOLE_SHELF] games is an endless
## row: position p shows game `posmod(p, count)`, so moving right from the last game reaches the
## first. A shorter one fits on screen and is shown whole, in order: moving right from its last
## game slides back to the first, as no game can stand at both ends at once. The scroll is the
## position shown, fractional while the row moves.

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
## Distance from the centre, in world units, of the first place, then between the next ones.
const CENTRE_GAP := 1.5
const SIDE_GAP := 0.9
const SIDE_SCALE := 0.6
## How transparent the neighbours of the selected game are; farther places fade out.
const SIDE_FADE := 0.35


## The offset from the centre of each game shown at [param scroll], by game index, at most
## [constant REACH] + 1 places away.
static func offsets(count: int, scroll: float) -> Dictionary[int, float]:
	var shown: Dictionary[int, float] = {}
	var first := floori(scroll)
	for step in range(-REACH - 1, REACH + 2):
		var position := first + step
		var offset := position - scroll
		if absf(offset) <= REACH + 1 and (count > WHOLE_SHELF or (position >= 0 and position < count)):
			shown[posmod(position, count)] = offset
	return shown


## The position one step towards [param direction] (-1 or 1) from [param position].
static func stepped(position: int, direction: int, count: int) -> int:
	return position + direction if count > WHOLE_SHELF else posmod(position + direction, count)


## How a game [param offset] places from the centre stands; the selected game is then posed (see
## [ShelfRow.Pose]).
static func place(offset: float) -> Transform3D:
	var distance := absf(offset)
	var near := minf(distance, 1.0)
	var x := signf(offset) * (near * CENTRE_GAP + maxf(distance - 1.0, 0.0) * SIDE_GAP)
	var scale := lerpf(1.0, SIDE_SCALE, near)
	var turned := Basis.from_euler(Vector3(0.0, -0.45 * signf(offset) * near, 0.0))
	return Transform3D(turned.scaled(Vector3.ONE * scale), Vector3(x, 0.0, -0.9 * near))


## How transparent a game [param offset] places from the centre is: opaque at the centre, faded
## beside it, gone past the last place shown.
static func fade(offset: float) -> float:
	var distance := absf(offset)
	if distance <= 1.0:
		return SIDE_FADE * distance
	return lerpf(SIDE_FADE, 1.0, clampf(distance - REACH, 0.0, 1.0))


## The scroll one frame of [param delta] seconds later, moving towards [param target] without
## passing it.
static func scrolled(scroll: float, target: float, delta: float) -> float:
	var speed := maxf(1.0, absf(target - scroll)) / STEP_S
	return move_toward(scroll, target, speed * delta)


## The wait before the next step of a direction held for [param steps] steps already.
static func repeat_delay(steps: int) -> float:
	return maxf(FASTEST_REPEAT_S, FIRST_REPEAT_S * pow(REPEAT_SPEED_UP, steps))
