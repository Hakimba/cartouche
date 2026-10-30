# SPDX-License-Identifier: GPL-3.0-or-later
class_name LaunchAnimation
extends RefCounted
## Makes a console's [Animation] from its steps (its folder's `launch.json`, see docs/adding-a-console.md, "Launch steps"): each
## step a whole state of the scene, reached from the previous one in `dur` seconds (a hundredth at
## least) along its `ease` (`linear`, `in`, `out`, `inOut`, the default, or the rebound `outBack`),
## then held `hold` seconds (none at least). A value left out takes its default (see
## [method _value]). Distances are in centimetres there, angles in degrees, the blur in pixels of
## the carousel's screen; the animation's tracks are in world units and radians, on the carousel's
## nodes (paths from the carousel, the player's root). The camera stays the carousel's. The `parts`
## group gives the console's own moving parts ([method ConsoleModel.moving_parts]) by property, in
## the model's units, each one at rest when left out; a part the model does not have is refused.
##
## Its moments, in seconds ([method moment]): `consoles` once the first step's hold is over, `games`
## where the step the game is chosen at is reached, `launch` once that step's hold is over, `seated`
## where the disc, out of the row, first reaches the seat, `black` where the black first covers
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
	"Row:position", "Row:scale", "Row:neighbours", "Row:pose_amount", "Row:selected_presence",
	"Sequence:disc_away", "Sequence:disc_lift", "Sequence:disc_offset", "Sequence:disc_tilt",
	"Sequence:disc_turns_per_s", "Sequence:blur", "Sequence:layer_opacity", "Sequence:saturation",
	"Sequence:black", "Sequence:fade",
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
## The placeholder's steps (see [method placeholder]), each changing the previous one's state: the
## consoles screen, the console come forward, open, the games screen, the medium out of the row over
## the seat, down onto it, the console closed and on, the black.
const _PLACEHOLDER: Array[Dictionary] = [
	{"hold": 0.5, "console": {"py": 1.8, "scale": 0.55, "sway": 3.5, "bob": 0.25},
		"disc": {"visible": 0.0}, "row": {"show": 0.0}, "ui": {"pill": 0.0, "tabs": 0.0, "art": 1.0}},
	{"dur": 0.7, "console": {"px": 3.9, "py": 1.0, "scale": 1.0, "pose": 0.0}, "consoles": {"show": 0.0},
		"ui": {"art": 0.0}},
	{"dur": 0.5, "ease": "outBack"},
	{"dur": 0.5, "ease": "out", "disc": {"visible": 1.0}, "row": {"show": 1.0},
		"look": {"blur": 8.848, "opacity": 0.5, "sat": 0.7}, "ui": {"pill": 1.0, "tabs": 1.0, "art": 1.0}},
	{"dur": 0.5, "disc": {"inRow": 0.0}, "row": {"show": 0.0}, "look": {"blur": 0.0, "opacity": 1.0, "sat": 1.0},
		"ui": {"bar": 0.0, "pill": 0.0, "tabs": 0.0, "art": 0.0}},
	{"dur": 0.28, "ease": "in", "hold": 0.08, "disc": {"lift": 0.0}},
	{"dur": 0.35, "ease": "in", "hold": 0.1},
	{"dur": 0.35, "ease": "in", "hold": 0.3, "fx": {"black": 1.0}},
]
## The placeholder's step the game is chosen at; the openings open from one step until another, where
## the console is on; the medium comes down onto the seat at one between.
const _PLACEHOLDER_CHOICE := 3
const _OPENS := 2
const _SEATS := 5
const _CLOSES := 6
## How much further than its own length along the way in the placeholder's medium starts from the
## seat, in world units.
const _CLEARANCE := 0.7


## The animation of [param data] (`choice`, the index of the step the game is chosen at, and
## `steps`), moving the parts of [param console] when it has one; an empty one when it has fewer
## than two steps (see [method read]).
static func build(data: Dictionary, console: ConsoleModel = null) -> Animation:
	var animation := Animation.new()
	var steps := _steps(data)
	if steps.size() < 2:
		return animation
	var choice := clampi(roundi(_number(data, "choice", 1.0)), 1, steps.size() - 1)
	var times := _times(steps)
	var tracks: Dictionary[NodePath, Callable] = {}
	for track in TRACKS:
		tracks[NodePath(track)] = func(step: Dictionary) -> Variant: return _value(track, step)
	for part in _moving_parts(console):
		tracks[NodePath("Consoles/%s:%s" % [console.name, part.property])] = func(step: Dictionary) -> Variant:
			return _number(_group(step, "parts"), part.property, part.rest)
	for track in tracks:
		var value_at := tracks[track]
		var index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(index, track)
		for i in steps.size():
			if i > 0:
				_bake(animation, index, value_at, steps[i - 1], steps[i], times[i - 1].y, times[i].x)
			var leaving: float = EASES.get(_ease(steps[i + 1]), 1.0) if i + 1 < steps.size() else 1.0
			var held := times[i].y > times[i].x
			var value: Variant = value_at.call(steps[i])
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
		var fx := _group(steps[i], "fx")
		if _number(fx, "black", 0.0) >= 1.0 or _number(fx, "fade", 0.0) >= 1.0:
			moments[&"black"] = times[i].x
	animation.set_meta(_MOMENTS, moments)
	return animation


## When [param animation] comes to its moment [param named] (see the class description), or
## [param otherwise] when it has none such.
static func moment(animation: Animation, named: StringName, otherwise := 0.0) -> float:
	var moments: Dictionary = animation.get_meta(_MOMENTS, {})
	return moments.get(named, otherwise)


## The animation of the steps file at [param path] for [param console] (see [method build]); an
## error, and an empty animation, when it cannot be read, has fewer than two steps or moves parts the
## console does not have.
static func read(path: String, console: ConsoleModel = null) -> Animation:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var parsed: Dictionary = data if data is Dictionary else {}
	var unknown := problems(parsed, console)
	var animation := build(parsed, console) if unknown.is_empty() else Animation.new()
	if not unknown.is_empty():
		push_error("%s: the console has no part %s" % [path, unknown])
	elif animation.get_track_count() == 0:
		push_error("%s: not the steps of a launch animation" % path)
	return animation


## The parts [param data]'s steps move that [param console] does not have, by name (all of them
## without a console): steps written for another model.
static func problems(data: Dictionary, console: ConsoleModel = null) -> Array[StringName]:
	var declared := _moving_parts(console).map(func(part: MovingPart) -> StringName: return part.property)
	var unknown: Array[StringName] = []
	for step in _steps(data):
		for key: String in _group(step, "parts"):
			var part := StringName(key)
			if part not in declared and part not in unknown:
				unknown.append(part)
	return unknown


## The launch animation of [param console] when it has no steps of its own, made from the roles of
## its parts (see [method _moved]), for a medium filling [param medium] in its own space: it stands
## as the PS2 does, turned as [method ConsoleModel.presented] has it, comes forward, its buttons
## pressed, and opens; once the game is chosen, the medium comes over the seat, its flaps opening,
## and down its way in onto it from [method lift] away, the openings close and the console comes on,
## its power button pressed and let go, and the screen is black 1.66 s after the launch.
static func placeholder(console: ConsoleModel, medium: AABB) -> Animation:
	var facing := console.presented().get_euler(EULER_ORDER_XYZ) * 180.0 / PI
	var state := {"console": {"rx": facing.x, "ry": facing.y, "rz": facing.z},
		"disc": {"lift": lift(console.approach(), medium) * _CM_PER_UNIT}}
	var steps: Array[Dictionary] = []
	for i in _PLACEHOLDER.size():
		var step := {}
		var changes := _PLACEHOLDER[i]
		for key: String in changes:
			var change: Variant = changes[key]
			if change is Dictionary:
				var group: Dictionary = change
				state[key] = _group(state, key).merged(group, true)
			else:
				step[key] = change
		step.merge(state.duplicate(true))
		var parts := {}
		for part in console.moving_parts():
			parts[part.property] = part.open if _moved(part.role, i) else part.rest
		step["parts"] = parts
		steps.append(step)
	return build({"choice": _PLACEHOLDER_CHOICE, "steps": steps}, console)


## How far from the seat, along [param way_in] (in the seat's frame), a medium filling
## [param medium] there is clear of it: its length that way, and [constant _CLEARANCE] more.
static func lift(way_in: Vector3, medium: AABB) -> float:
	var along: Array[float] = []
	for corner in 8:
		along.append(medium.get_endpoint(corner).dot(way_in.normalized()))
	return along.max() - along.min() + _CLEARANCE


## The curve that overshoots its end a little, then comes back to it (the steps' `outBack`).
static func back_out(u: float) -> float:
	return 1.0 + (_OVERSHOOT + 1.0) * pow(u - 1.0, 3.0) + _OVERSHOOT * pow(u - 1.0, 2.0)


## Whether the placeholder has a part of [param role] moved at its step [param i]: an opening from
## the console come forward until the medium is in; a flap from the medium over the seat on, the
## medium holding it open, so that it never cuts a flap half open; a press as the console comes
## forward, let go as the openings open; a power press as the console comes on, let go at the next
## step; a pose never; power, lights and spins from the step the console closes.
static func _moved(role: MovingPart.Role, i: int) -> bool:
	match role:
		MovingPart.Role.OPENING:
			return _OPENS <= i and i < _CLOSES
		MovingPart.Role.FLAP:
			return i >= _SEATS - 1
		MovingPart.Role.PRESS:
			return i == _OPENS - 1
		MovingPart.Role.POWER_PRESS:
			return i == _CLOSES
		MovingPart.Role.POSE:
			return false
		MovingPart.Role.POWER, MovingPart.Role.LIGHT, MovingPart.Role.SPIN:
			return i >= _CLOSES
	push_error("LaunchAnimation: no placeholder for the role %d" % role)
	return false


static func _steps(data: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var listed: Variant = data.get("steps")
	for step: Variant in (listed if listed is Array else []):
		if step is Dictionary:
			steps.append(step)
	return steps


static func _moving_parts(console: ConsoleModel) -> Array[MovingPart]:
	return console.moving_parts() if console else ([] as Array[MovingPart])


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
static func _bake(animation: Animation, index: int, value_at: Callable, from: Dictionary, to: Dictionary,
		start: float, end: float) -> void:
	if _ease(to) != _REBOUND or end <= start:
		return
	var a: Variant = value_at.call(from)
	var b: Variant = value_at.call(to)
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
		"Sequence:fade":
			return _number(_group(step, "fx"), "fade", 0.0)
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
