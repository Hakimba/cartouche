# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
## The steps' curves, as the steps' tuning tool draws them.
const CURVES: Array[String] = ["linear", "in", "out", "inOut", "outBack"]
## What a step leaves out, as ONBOARDING documents the steps.
const DEFAULTS: Dictionary[String, Dictionary] = {
	"console": {"px": 0.0, "py": 0.0, "pz": 0.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "scale": 1.0, "pose": 1.0,
		"sway": 7.0, "bob": 0.5},
	"consoles": {"show": 1.0},
	"lid": {"angle": 0.0},
	"disc": {"visible": 1.0, "inRow": 1.0, "lift": 0.0, "dx": 0.0, "dy": 0.0, "rx": 0.0, "ry": 0.0, "spin": 0.0},
	"row": {"show": 1.0, "x": 0.0, "y": 0.0, "z": 0.0, "scale": 1.0, "pose": 1.0},
	"look": {"blur": 0.0, "opacity": 1.0, "sat": 1.0},
	"ui": {"bar": 1.0, "tabs": 1.0, "pill": 1.0},
	"fx": {"black": 0.0},
}
## Where carousel.tscn stands the games' row, in centimetres: the steps move it from there.
const ROW_HEIGHT_CM := 1.8
const EPSILON := 0.0001
## An animation reads a time this close to a key as the key's own, and goes on from it: a hold is
## sampled no closer to its end.
const KEY_SNAP_S := 0.0001
## How far 12 straight keys stray from the rebound's curve, as a share of the way: an eighth of the
## square of their spacing times the curve's largest bend (12.8).
const REBOUND_KEYS_ERROR := 0.012


func test_INV_E5_03_each_step_is_reached_exactly_and_held_until_the_next_leaves() -> void:
	var random := Fixtures.cases(51)
	for i in 300:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data)
		var steps: Array = data["steps"]
		var times := _times(steps)
		for s in steps.size():
			var step: Dictionary = steps[s]
			for track in LaunchAnimation.TRACKS:
				var index := animation.find_track(NodePath(track), Animation.TYPE_VALUE)
				var held := maxf(times[s].x, times[s].y - KEY_SNAP_S)
				for at: float in [times[s].x, lerpf(times[s].x, held, random.randf())]:
					_assert_near(animation.value_track_interpolate(index, at), _expected(track, step), EPSILON, track)


func test_INV_E5_03_between_two_steps_each_value_follows_the_step_s_curve() -> void:
	var random := Fixtures.cases(52)
	var followed: Dictionary[String, int] = {}
	for i in 300:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data)
		var steps: Array = data["steps"]
		var times := _times(steps)
		for s in range(1, steps.size()):
			var from: Dictionary = steps[s - 1]
			var to: Dictionary = steps[s]
			var named := _ease(to)
			# Not at a key, which the animation would read as the key's own (see KEY_SNAP_S).
			var u := random.randf_range(0.01, 0.99)
			var at := lerpf(times[s - 1].y, times[s].x, u)
			for track in LaunchAnimation.TRACKS:
				var index := animation.find_track(NodePath(track), Animation.TYPE_VALUE)
				var a: Variant = _expected(track, from)
				var b: Variant = _expected(track, to)
				var tolerance := 0.001 + (REBOUND_KEYS_ERROR * _gap(a, b) if named == "outBack" else 0.0)
				_assert_near(animation.value_track_interpolate(index, at), lerp(a, b, _curve(named, u)),
					tolerance, "%s along %s" % [track, named])
			followed[named] = followed.get(named, 0) + 1
	for named in CURVES:
		assert_int(followed.get(named, 0)).override_failure_message("%s rarely followed" % named).is_greater(50)


func test_INV_E5_03_the_rebound_overshoots_its_end_by_a_tenth_then_comes_back_to_it() -> void:
	assert_float(LaunchAnimation.back_out(0.0)).is_equal_approx(0.0, EPSILON)
	assert_float(LaunchAnimation.back_out(1.0)).is_equal_approx(1.0, EPSILON)
	var peak := 0.0
	for k in 1001:
		var u := k / 1000.0
		assert_float(LaunchAnimation.back_out(u)).is_equal_approx(_curve("outBack", u), EPSILON)
		peak = maxf(peak, LaunchAnimation.back_out(u))
	assert_float(peak).is_between(1.09, 1.11)


func test_INV_E5_03_before_its_start_and_after_its_end_the_animation_holds_its_first_and_last_step() -> void:
	var random := Fixtures.cases(53)
	for i in 200:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data)
		var steps: Array = data["steps"]
		var first: Dictionary = steps[0]
		var last: Dictionary = steps[-1]
		for track in LaunchAnimation.TRACKS:
			var index := animation.find_track(NodePath(track), Animation.TYPE_VALUE)
			_assert_near(animation.value_track_interpolate(index, -1.0), _expected(track, first), EPSILON, track)
			_assert_near(animation.value_track_interpolate(index, animation.length + 1.0), _expected(track, last),
				EPSILON, track)


func test_INV_E5_03_the_animation_s_moments_fall_where_its_steps_have_them() -> void:
	var random := Fixtures.cases(54)
	var found: Dictionary[StringName, int] = {}
	for i in 300:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data)
		var steps: Array = data["steps"]
		var times := _times(steps)
		var choice := _choice(data)
		assert_float(LaunchAnimation.moment(animation, &"consoles")).is_equal_approx(times[0].y, EPSILON)
		assert_float(LaunchAnimation.moment(animation, &"games")).is_equal_approx(times[choice].x, EPSILON)
		assert_float(LaunchAnimation.moment(animation, &"launch")).is_equal_approx(times[choice].y, EPSILON)
		for moment: StringName in [&"seated", &"black"]:
			var first := -1
			for s in range(choice + 1, steps.size()):
				var step: Dictionary = steps[s]
				if first < 0 and _reaches(moment, step):
					first = s
			var expected := times[first].x if first >= 0 else -1.0
			assert_float(LaunchAnimation.moment(animation, moment, -1.0)).is_equal_approx(expected, EPSILON)
			found[moment] = found.get(moment, 0) + (1 if first >= 0 else 0)
	assert_int(found[&"seated"]).is_greater(30)
	assert_int(found[&"black"]).is_greater(30)


func test_fewer_than_two_steps_make_no_animation() -> void:
	for data: Dictionary in [{}, {"steps": []}, {"steps": [{}]}, {"steps": "none"}]:
		var animation := LaunchAnimation.build(data)
		assert_int(animation.get_track_count()).is_equal(0)


func test_INV_E5_08_every_console_takes_a_game_to_the_whole_screen_black_in_2_4_s_at_most() -> void:
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(APPEARANCE))
	var consoles: Dictionary = appearance["consoles"]
	assert_int(consoles.size()).is_greater(0)
	for platform_id: String in consoles:
		var console: Dictionary = consoles[platform_id]
		var steps: String = console["steps"]
		var animation := LaunchAnimation.read(steps)
		var launch := LaunchAnimation.moment(animation, &"launch")
		var black := LaunchAnimation.moment(animation, &"black", INF)
		assert_float(animation.length).is_greater(launch)
		assert_float(black).is_less_equal(animation.length)
		assert_float(black - launch).is_less_equal(2.4)


## When each step is reached (x) and when its hold is over (y): a hundredth of a second at least
## from the previous one, held for no time at least.
static func _times(steps: Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	var at := 0.0
	for s in steps.size():
		var step: Dictionary = steps[s]
		if s > 0:
			at += maxf(_number(step, "dur", 0.0), LaunchAnimation.SHORTEST_STEP_S)
		var hold := maxf(_number(step, "hold", 0.0), 0.0)
		found.append(Vector2(at, at + hold))
		at += hold
	return found


## The step the game is chosen at: the second unless given, rounded, never the first nor past the
## last.
static func _choice(data: Dictionary) -> int:
	var steps: Array = data["steps"]
	return clampi(roundi(_number(data, "choice", 1.0)), 1, steps.size() - 1)


static func _ease(step: Dictionary) -> String:
	var named: Variant = step.get("ease", "inOut")
	return named if named in CURVES else "inOut"


## [param track]'s value at [param step], in the carousel's units: world units of 10 cm, radians.
static func _expected(track: String, step: Dictionary) -> Variant:
	match track:
		"Consoles:console_position":
			return _vector(step, "console", "px", "py", "pz") / 10.0
		"Consoles:console_rotation":
			return _vector(step, "console", "rx", "ry", "rz") * PI / 180.0
		"Consoles:console_scale":
			return _read(step, "console", "scale")
		"Consoles:pose_amount":
			return _read(step, "console", "pose")
		"Consoles:sway_degrees":
			return _read(step, "console", "sway")
		"Consoles:bob_height":
			return _read(step, "console", "bob") / 10.0
		"Consoles:others_opacity":
			return _read(step, "consoles", "show")
		"Consoles:lid_degrees":
			return _read(step, "lid", "angle")
		"Row:position":
			return (_vector(step, "row", "x", "y", "z") + Vector3.UP * ROW_HEIGHT_CM) / 10.0
		"Row:scale":
			return Vector3.ONE * _read(step, "row", "scale")
		"Row:neighbours":
			return _read(step, "row", "show")
		"Row:pose_amount":
			return _read(step, "row", "pose")
		"Row:selected_presence":
			return _read(step, "disc", "visible")
		"Sequence:disc_away":
			return 1.0 - _read(step, "disc", "inRow")
		"Sequence:disc_lift":
			return _read(step, "disc", "lift") / 10.0
		"Sequence:disc_offset":
			return Vector2(_read(step, "disc", "dx"), _read(step, "disc", "dy")) / 10.0
		"Sequence:disc_tilt":
			return Vector2(_read(step, "disc", "rx"), _read(step, "disc", "ry")) * PI / 180.0
		"Sequence:disc_turns_per_s":
			return _read(step, "disc", "spin")
		"Sequence:blur":
			return _read(step, "look", "blur")
		"Sequence:layer_opacity":
			return _read(step, "look", "opacity")
		"Sequence:saturation":
			return _read(step, "look", "sat")
		"Sequence:black":
			return _read(step, "fx", "black")
		"TopBar:modulate:a":
			return _read(step, "ui", "bar")
		"TopBar/Items/Platform:modulate:a":
			return _read(step, "ui", "tabs")
		"Pill:modulate:a", "ArtProgress:modulate:a":
			return _read(step, "ui", "pill")
	push_error("no expected value for %s" % track)
	return NAN


## Where the disc, out of the row, is down on the spindle; where the black is whole.
static func _reaches(moment: StringName, step: Dictionary) -> bool:
	if moment == &"seated":
		return _read(step, "disc", "inRow") == 0.0 and _read(step, "disc", "lift") == 0.0
	return _read(step, "fx", "black") == 1.0


static func _read(step: Dictionary, group: String, key: String) -> float:
	var defaults: Dictionary = DEFAULTS[group]
	var values: Dictionary = step.get(group, {})
	var default: float = defaults[key]
	return _number(values, key, default)


static func _number(values: Dictionary, key: String, default: float) -> float:
	var value: float = values.get(key, default)
	return value


static func _vector(step: Dictionary, group: String, x: String, y: String, z: String) -> Vector3:
	return Vector3(_read(step, group, x), _read(step, group, y), _read(step, group, z))


static func _gap(a: Variant, b: Variant) -> float:
	if a is Vector3:
		var from_3: Vector3 = a
		var to_3: Vector3 = b
		return from_3.distance_to(to_3)
	if a is Vector2:
		var from_2: Vector2 = a
		var to_2: Vector2 = b
		return from_2.distance_to(to_2)
	var from_1: float = a
	var to_1: float = b
	return absf(from_1 - to_1)


func _assert_near(got: Variant, expected: Variant, tolerance: float, what: String) -> void:
	assert_float(_gap(got, expected)).override_failure_message(
		"%s: %s instead of %s" % [what, got, expected]).is_less_equal(tolerance)


## How far along the curve [param named] is at [param u].
static func _curve(named: String, u: float) -> float:
	match named:
		"in":
			return u * u * u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"inOut":
			return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
		"outBack":
			return 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)
	return u
