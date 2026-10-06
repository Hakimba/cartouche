# SPDX-License-Identifier: GPL-3.0-or-later
class_name LaunchAnimation
extends RefCounted
## Makes a console's [Animation] from its steps (`data/launch/<console>.json`, see ONBOARDING): each
## step a whole state of the scene, reached from the previous one in `dur` seconds (a hundredth at
## least) along its `ease` (`linear`, `in`, `out`, `inOut`, the default, or the rebound `outBack`),
## then held `hold` seconds (none at least). A value left out takes its default (see [method _value]).
## Distances are in centimetres there, angles in degrees, the blur in pixels of the carousel's screen;
## the animation's tracks are in world units and
## radians, on the carousel's nodes (paths from the carousel, the player's root). The camera stays
## the carousel's.
##
## Its moments, in seconds ([method moment]): `consoles` once the first step's hold is over, `games`
## where the step the game is chosen at is reached, `launch` once that step's hold is over, `seated`
## where the disc, out of the row, first reaches the spindle, `black` where the black first covers
## the whole screen. They are metadata rather than markers, as several may fall at once. An animation
## that ends at the chosen step has no launch.

## Easing of the key a step leaves from, as [method @GlobalScope.ease] takes it: the steps' cubic
## curves exactly (`in` is u³, `out` 1 − (1 − u)³, `inOut` both halves of them).
const EASES: Dictionary[String, float] = {"linear": 1.0, "in": 3.0, "out": 1.0 / 3.0, "inOut": -3.0}
## A curve [method @GlobalScope.ease] cannot follow is laid down as this many straight keys.
const BAKED_KEYS := 12
const TRACKS: Array[String] = [
	"Consoles:console_position", "Consoles:console_rotation", "Consoles:console_scale",
	"Consoles:pose_amount", "Consoles:sway_degrees", "Consoles:bob_height", "Consoles:others_opacity",
	"Consoles:lid_degrees",
	"Row:position", "Row:scale", "Row:neighbours", "Row:pose_amount", "Row:selected_presence",
	"Sequence:disc_away", "Sequence:disc_lift", "Sequence:disc_offset", "Sequence:disc_tilt",
	"Sequence:disc_turns_per_s", "Sequence:blur", "Sequence:layer_opacity", "Sequence:saturation",
	"Sequence:black",
	"TopBar:modulate:a", "Pill:modulate:a",
	"ArtProgress:modulate:a",
]
## The shortest a step takes: an animation merges keys closer than a few hundred-thousandths of a
## second, and a rebound lays [constant BAKED_KEYS] of them in one step.
const SHORTEST_STEP_S := 0.01
const _MOMENTS := &"moments"
const _CM_PER_UNIT := 10.0
## Where the games' row rests, in centimetres (as carousel.tscn stands it): the steps move it from
## there.
const _ROW_HEIGHT_CM := 1.8
const _OVERSHOOT := 1.70158
const _REBOUND := "outBack"


## The animation of [param data] (`choice`, the index of the step the game is chosen at, and
## `steps`); an empty one when it has fewer than two steps (see [method read]).
static func build(data: Dictionary) -> Animation:
	var animation := Animation.new()
	var steps: Array[Dictionary] = []
	var listed: Variant = data.get("steps")
	for step: Variant in (listed if listed is Array else []):
		if step is Dictionary:
			steps.append(step)
	if steps.size() < 2:
		return animation
	var choice := clampi(roundi(_number(data, "choice", 1.0)), 1, steps.size() - 1)
	var times := _times(steps)
	for track in TRACKS:
		var index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(index, NodePath(track))
		for i in steps.size():
			if i > 0:
				_bake(animation, index, track, steps[i - 1], steps[i], times[i - 1].y, times[i].x)
			var leaving: float = EASES.get(_ease(steps[i + 1]), 1.0) if i + 1 < steps.size() else 1.0
			var held := times[i].y > times[i].x
			var value: Variant = _value(track, steps[i])
			animation.track_insert_key(index, times[i].x, value, 1.0 if held else leaving)
			if held:
				animation.track_insert_key(index, times[i].y, value, leaving)
	animation.length = times[-1].y
	var moments: Dictionary[StringName, float] = {
		&"consoles": times[0].y, &"games": times[choice].x, &"launch": times[choice].y,
	}
	for i in range(steps.size() - 1, choice, -1):
		var disc := _group(steps[i], "disc")
		if _number(disc, "inRow", 1.0) < 0.5 and absf(_number(disc, "lift", 0.0)) < 0.001:
			moments[&"seated"] = times[i].x
		if _number(_group(steps[i], "fx"), "black", 0.0) >= 1.0:
			moments[&"black"] = times[i].x
	animation.set_meta(_MOMENTS, moments)
	return animation


## When [param animation] comes to its moment [param named] (see the class description), or
## [param otherwise] when it has none such.
static func moment(animation: Animation, named: StringName, otherwise := 0.0) -> float:
	var moments: Dictionary = animation.get_meta(_MOMENTS, {})
	return moments.get(named, otherwise)


## The animation of the steps file at [param path] (see [method build]); an error, and an empty
## animation, when it cannot be read or has fewer than two steps.
static func read(path: String) -> Animation:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var parsed: Dictionary = data if data is Dictionary else {}
	var animation := build(parsed)
	if animation.get_track_count() == 0:
		push_error("%s: not the steps of a launch animation" % path)
	return animation


## The curve that overshoots its end a little, then comes back to it (the steps' `outBack`).
static func back_out(u: float) -> float:
	return 1.0 + (_OVERSHOOT + 1.0) * pow(u - 1.0, 3.0) + _OVERSHOOT * pow(u - 1.0, 2.0)


## When each step is reached (x) and when its hold is over (y).
static func _times(steps: Array[Dictionary]) -> PackedVector2Array:
	var found := PackedVector2Array()
	var at := 0.0
	for i in steps.size():
		if i > 0:
			at += maxf(SHORTEST_STEP_S, _number(steps[i], "dur", 0.0))
		var reached := at
		at += maxf(0.0, _number(steps[i], "hold", 0.0))
		found.append(Vector2(reached, at))
	return found


## The ease [param step] is reached along: `inOut` unless it names one of [constant EASES] or the
## rebound.
static func _ease(step: Dictionary) -> String:
	var named: Variant = step.get("ease")
	return named if named is String and (named in EASES or named == _REBOUND) else "inOut"


## The keys between [param from] and [param to] along a curve [method @GlobalScope.ease] cannot
## follow, from [param start] to [param end] seconds; none for the others.
static func _bake(animation: Animation, index: int, track: String, from: Dictionary, to: Dictionary,
		start: float, end: float) -> void:
	if _ease(to) != _REBOUND or end <= start:
		return
	var a: Variant = _value(track, from)
	var b: Variant = _value(track, to)
	for k in range(1, BAKED_KEYS):
		var u := float(k) / BAKED_KEYS
		animation.track_insert_key(index, lerpf(start, end, u), lerp(a, b, back_out(u)), 1.0)


## The value of [param track] at [param step], converted from the steps' units.
static func _value(track: String, step: Dictionary) -> Variant:
	var console := _group(step, "console")
	var row := _group(step, "row")
	var disc := _group(step, "disc")
	var look := _group(step, "look")
	var shown := _group(step, "ui")
	match track:
		"Consoles:console_position":
			return _vector(console, "px", "py", "pz") / _CM_PER_UNIT
		"Consoles:console_rotation":
			return _vector(console, "rx", "ry", "rz") * PI / 180.0
		"Consoles:console_scale":
			return _number(console, "scale", 1.0)
		"Consoles:pose_amount":
			return _number(console, "pose", 1.0)
		"Consoles:sway_degrees":
			return _number(console, "sway", CarouselLayout.SWAY_DEGREES)
		"Consoles:bob_height":
			return _number(console, "bob", CarouselLayout.BOB_HEIGHT * _CM_PER_UNIT) / _CM_PER_UNIT
		"Consoles:others_opacity":
			return _number(_group(step, "consoles"), "show", 1.0)
		"Consoles:lid_degrees":
			return _number(_group(step, "lid"), "angle", 0.0)
		"Row:position":
			return (_vector(row, "x", "y", "z") + Vector3.UP * _ROW_HEIGHT_CM) / _CM_PER_UNIT
		"Row:scale":
			return Vector3.ONE * _number(row, "scale", 1.0)
		"Row:neighbours":
			return _number(row, "show", 1.0)
		"Row:pose_amount":
			return _number(row, "pose", 1.0)
		"Row:selected_presence":
			return _number(disc, "visible", 1.0)
		"Sequence:disc_away":
			return 1.0 - _number(disc, "inRow", 1.0)
		"Sequence:disc_lift":
			return _number(disc, "lift", 0.0) / _CM_PER_UNIT
		"Sequence:disc_offset":
			return Vector2(_number(disc, "dx", 0.0), _number(disc, "dy", 0.0)) / _CM_PER_UNIT
		"Sequence:disc_tilt":
			return Vector2(_number(disc, "rx", 0.0), _number(disc, "ry", 0.0)) * PI / 180.0
		"Sequence:disc_turns_per_s":
			return _number(disc, "spin", 0.0)
		"Sequence:blur":
			return _number(look, "blur", 0.0)
		"Sequence:layer_opacity":
			return _number(look, "opacity", 1.0)
		"Sequence:saturation":
			return _number(look, "sat", 1.0)
		"Sequence:black":
			return _number(_group(step, "fx"), "black", 0.0)
		"TopBar:modulate:a":
			return _number(shown, "bar", 1.0)
		"Pill:modulate:a":
			return _number(shown, "pill", 1.0)
		# The art bar shows under the pill, and with it, unless the step says otherwise: over the
		# consoles, where the pill does not show.
		"ArtProgress:modulate:a":
			return _number(shown, "art", _number(shown, "pill", 1.0))
	push_error("LaunchAnimation: no value for %s" % track)
	return 0.0


static func _group(step: Dictionary, name: String) -> Dictionary:
	var group: Variant = step.get(name)
	return group if group is Dictionary else {}


static func _number(values: Dictionary, key: String, default: float) -> float:
	var value: Variant = values.get(key)
	return value if value is float or value is int else default


static func _vector(values: Dictionary, x: String, y: String, z: String) -> Vector3:
	return Vector3(_number(values, x, 0.0), _number(values, y, 0.0), _number(values, z, 0.0))
