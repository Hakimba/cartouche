# SPDX-License-Identifier: GPL-3.0-or-later
class_name Finger
extends RefCounted
## The first finger on the screen, read as the person means it: put down, then a tap (lifted
## soon, having barely moved), a long press (held still), or a drag (moved past the slop). A touch
## the system takes back (its back gesture, a second finger's pinch) ends as nothing. Times come
## from the caller, so that the reading is the same whatever the frame rate. The thresholds are the
## design's.

enum Gesture { NONE, DOWN, TAP, DRAG }

## How far a finger moves before it drags, in pixels of the 1280-wide screen; how long a tap lasts
## (less than), and a long press at least, in milliseconds.
const SLOP := 24.0
const TAP_MS := 250
const LONG_MS := 550

## Where the finger came down and where it is now.
var start := Vector2.ZERO
var at := Vector2.ZERO
var is_down := false
var is_dragging := false
## How far it last moved, in pixels.
var moved := Vector2.ZERO

var _down_ms := 0
var _long_pressed := false


## What [param event], at [param now_ms], means.
func read(event: InputEvent, now_ms: int) -> Gesture:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if touch and touch.index == 0 and touch.pressed:
		start = touch.position
		at = start
		is_down = true
		is_dragging = false
		_long_pressed = false
		_down_ms = now_ms
		return Gesture.DOWN
	elif touch and touch.index == 0 and is_down:
		is_down = false
		at = touch.position
		# Lifted far from where it came down, with no move seen between: not a tap either.
		if not (touch.canceled or is_dragging or _long_pressed) and now_ms - _down_ms < TAP_MS \
				and at.distance_to(start) < SLOP:
			return Gesture.TAP
	elif drag and drag.index == 0 and is_down:
		# The first drag counts from where the finger came down: nothing within the slop is lost.
		moved = drag.position - (at if is_dragging else start)
		at = drag.position
		is_dragging = is_dragging or (not _long_pressed and at.distance_to(start) >= SLOP)
		if is_dragging:
			return Gesture.DRAG
	return Gesture.NONE


## Whether the finger, held still since it came down, has just become a long press, at
## [param now_ms]; once per press.
func held(now_ms: int) -> bool:
	if not is_down or is_dragging or _long_pressed or now_ms - _down_ms < LONG_MS:
		return false
	_long_pressed = true
	return true
