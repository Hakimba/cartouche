# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameToss
extends Node
## The selected game tossed like a coin, to land as the row's pick ([method ShelfRow.select_pick]), the row standing
## still: it settles facing the front, flies up flipping twice about its horizontal axis, turns into the pick the first
## time it is seen edge-on, falls back, squashes a little and bounces back to its place among the pick's neighbours.
## Its neighbours and the title's [member pill] leave while it is up, the console's [member logo] while it rises.

enum Part { POSE, NEIGHBOURS, LIFT, FLIP, SQUASH, PILL, LOGO }

## Every part at rest, before and after a toss.
const _REST: Dictionary[Part, float] = {
	Part.POSE: 1.0, Part.NEIGHBOURS: 1.0, Part.LIFT: 0.0, Part.FLIP: 0.0, Part.SQUASH: 0.0, Part.PILL: 1.0, Part.LOGO: 1.0,
}

var row: ShelfRow
var pill: CanvasItem
var logo: CanvasItem
## The toss, one step after the other: the parts each step names reach their values (the lift in world units, the flip
## in radians, the squash as a part of the height), the others stay.
var _steps: Array[Step] = [
	Step.new(0.14, Tween.TRANS_CUBIC, Tween.EASE_OUT, {Part.POSE: 0.0, Part.SQUASH: 0.12, Part.NEIGHBOURS: 0.0, Part.PILL: 0.0}),
	Step.new(0.42, Tween.TRANS_CUBIC, Tween.EASE_OUT, {Part.LIFT: 0.45, Part.FLIP: TAU, Part.SQUASH: -0.06, Part.LOGO: 0.0}),
	Step.new(0.38, Tween.TRANS_CUBIC, Tween.EASE_IN, {Part.LIFT: 0.0, Part.FLIP: 2.0 * TAU, Part.SQUASH: 0.0, Part.LOGO: 1.0}),
	Step.new(0.08, Tween.TRANS_CUBIC, Tween.EASE_OUT, {Part.SQUASH: 0.14}),
	Step.new(0.4, Tween.TRANS_BACK, Tween.EASE_OUT, {Part.SQUASH: 0.0, Part.POSE: 1.0, Part.NEIGHBOURS: 1.0, Part.PILL: 1.0}),
]
var _length_s: float = _steps.reduce(func(seconds: float, step: Step) -> float: return seconds + step.seconds, 0.0)
var _clock_s := 0.0
var _swapped := false


func _ready() -> void:
	# Before the carousel and its rows, as the launch: they show the toss of this very frame.
	process_priority = -1
	set_process(false)


func _process(delta: float) -> void:
	_clock_s += delta
	if _clock_s >= _length_s:
		finish()
		return
	var parts := _at(_clock_s)
	# Shown first: the pick takes its place standing as this frame has it, its neighbours already gone.
	_show(parts)
	if not _swapped and parts[Part.FLIP] >= PI / 2.0:
		_swap()


## Whether a game is in the air: the carousel takes no press nor touch meanwhile.
func is_busy() -> bool:
	return is_processing()


## Tosses the selected game, unless one is in the air or the row has no pick.
func toss() -> void:
	if is_busy() or not row.has_pick():
		return
	Sounds.play(SoundEffects.Cue.TOSS)
	row.read_pick()
	Diagnostics.trace("toss", "%s tossed to land as %s" % [row.selected_game().title, row.pick().title])
	row.freeze()
	_clock_s = 0.0
	_swapped = false
	set_process(true)


## Lands the toss under way at once, as the pick: a screen changing, or the app leaving, leaves nothing in the air.
func finish() -> void:
	if not is_busy():
		return
	if not _swapped:
		_swap()
	set_process(false)
	_show(_REST)


func _swap() -> void:
	_swapped = true
	row.select_pick()


## Every part [param seconds] into the toss.
func _at(seconds: float) -> Dictionary[Part, float]:
	var parts: Dictionary[Part, float] = _REST.duplicate()
	var start := 0.0
	for step in _steps:
		var into := clampf(seconds - start, 0.0, step.seconds)
		for part in step.to:
			var from: float = parts[part]
			parts[part] = Tween.interpolate_value(from, step.to[part] - from, into, step.seconds, step.transition,
				step.easing)
		start += step.seconds
	return parts


func _show(parts: Dictionary[Part, float]) -> void:
	row.pose_amount = parts[Part.POSE]
	row.neighbours = parts[Part.NEIGHBOURS]
	row.selected_lift = parts[Part.LIFT]
	row.selected_flip = parts[Part.FLIP]
	row.selected_squash = parts[Part.SQUASH]
	pill.modulate.a = parts[Part.PILL]
	logo.modulate.a = parts[Part.LOGO]


class Step extends RefCounted:
	var seconds: float
	var transition: Tween.TransitionType
	var easing: Tween.EaseType
	var to: Dictionary[Part, float]

	func _init(length_s: float, curve: Tween.TransitionType, ease_type: Tween.EaseType,
			values: Dictionary[Part, float]) -> void:
		seconds = length_s
		transition = curve
		easing = ease_type
		to = values
