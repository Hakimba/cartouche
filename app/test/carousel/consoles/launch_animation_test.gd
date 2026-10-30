# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
## What a step leaves out, as docs/adding-a-console.md documents the steps.
const DEFAULTS: Dictionary[String, Dictionary] = {
	"console": {"px": 0.0, "py": 0.0, "pz": 0.0, "rx": 0.0, "ry": 0.0, "rz": 0.0, "scale": 1.0, "pose": 1.0,
		"sway": 7.0, "bob": 0.5},
	"consoles": {"show": 1.0},
	"parts": {"lid_degrees": 0.0, "flap_cm": 1.5},
	"disc": {"visible": 1.0, "inRow": 1.0, "lift": 0.0, "dx": 0.0, "dy": 0.0, "rx": 0.0, "ry": 0.0, "spin": 0.0},
	"row": {"show": 1.0, "x": 0.0, "y": 0.0, "z": 0.0, "scale": 1.0, "pose": 1.0},
	"look": {"blur": 0.0, "opacity": 1.0, "sat": 1.0},
	"ui": {"bar": 1.0, "tabs": 1.0, "pill": 1.0},
	"fx": {"black": 0.0, "fade": 0.0},
}
## Where carousel.tscn stands the games' row, in centimetres: the steps move it from there.
const ROW_HEIGHT_CM := 1.8
const EPSILON := 0.0001
## An animation reads a time this close to a key as the key's own, and goes on from it: a hold is
## sampled no closer to its end.
const KEY_SNAP_S := 0.0001
func test_each_step_is_reached_exactly_and_held_until_the_next_leaves() -> void:
	var random := Fixtures.cases(51)
	for i in 300:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data, _console())
		var steps: Array = data["steps"]
		var times := _times(steps)
		for s in steps.size():
			var step: Dictionary = steps[s]
			for track in _tracks():
				var index := animation.find_track(NodePath(track), Animation.TYPE_VALUE)
				var held := maxf(times[s].x, times[s].y - KEY_SNAP_S)
				for at: float in [times[s].x, lerpf(times[s].x, held, random.randf())]:
					_assert_near(animation.value_track_interpolate(index, at), _expected(track, step), EPSILON, track)


func test_before_its_start_and_after_its_end_the_animation_holds_its_first_and_last_step() -> void:
	var random := Fixtures.cases(53)
	for i in 200:
		var data := Fixtures.launch_steps(random)
		var animation := LaunchAnimation.build(data, _console())
		var steps: Array = data["steps"]
		var first: Dictionary = steps[0]
		var last: Dictionary = steps[-1]
		for track in _tracks():
			var index := animation.find_track(NodePath(track), Animation.TYPE_VALUE)
			_assert_near(animation.value_track_interpolate(index, -1.0), _expected(track, first), EPSILON, track)
			_assert_near(animation.value_track_interpolate(index, animation.length + 1.0), _expected(track, last),
				EPSILON, track)


func test_fewer_than_two_steps_make_no_animation() -> void:
	for data: Dictionary in [{}, {"steps": []}, {"steps": [{}]}, {"steps": "none"}]:
		var animation := LaunchAnimation.build(data)
		assert_int(animation.get_track_count()).is_equal(0)


func test_a_steps_file_moving_a_part_the_console_lacks_is_read_as_no_animation() -> void:
	var path := "user://launch-animation-test.json"
	for part: String in ["lid_degrees", "tray_cm"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"choice": 1, "steps": [{}, {"dur": 0.5, "parts": {part: 1.0}}]}))
		file.close()
		var tracks := LaunchAnimation.read(path, _console()).get_track_count()
		assert_int(tracks).is_equal(_tracks().size() if part == "lid_degrees" else 0)
	DirAccess.remove_absolute(path)


func test_every_console_takes_a_game_to_the_whole_screen_black_in_2_4_s_unless_its_own_steps_take_longer() -> void:
	var manifests := ConsoleManifest.found()
	assert_int(manifests.size()).is_greater(0)
	for found in manifests:
		# Each version of a platform's console in an appearance of its own, with its own steps, then
		# as if it had none.
		var placeholder: ConsoleManifest = found.duplicate()
		placeholder.launch = ""
		for manifest: ConsoleManifest in [found, placeholder]:
			var appearance := Appearance.read(APPEARANCE)
			appearance._consoles[manifest.platform] = manifest
			var animation := appearance.animation_of(Fixtures.platform(manifest.platform),
				Fixtures.media(manifest.platform)[0])
			var launch := LaunchAnimation.moment(animation, &"launch")
			var black := LaunchAnimation.moment(animation, &"black", INF)
			assert_float(animation.length).is_greater(launch)
			assert_float(black).is_less_equal(animation.length)
			assert_float(black).is_greater(launch)
			if manifest.launch.is_empty():
				assert_float(black - launch).is_less_equal(2.4)


## A console whose parts the steps of [method Fixtures.launch_steps] move, at rest as [constant
## DEFAULTS] has them.
func _console() -> Fixtures.Console:
	var console: Fixtures.Console = auto_free(Fixtures.Console.new())
	console.name = "Console"
	console.moving = [MovingPart.new(&"lid_degrees", MovingPart.Role.OPENING, 0.0, 88.0),
		MovingPart.new(&"flap_cm", MovingPart.Role.POWER, 1.5, -2.0)]
	return console


## The tracks of [method _console]'s animations: the carousel's, then its parts'.
static func _tracks() -> Array[String]:
	var tracks := LaunchAnimation.TRACKS.duplicate()
	tracks.append_array(["Consoles/Console:lid_degrees", "Consoles/Console:flap_cm"])
	return tracks


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
		"Consoles/Console:lid_degrees":
			return _read(step, "parts", "lid_degrees")
		"Consoles/Console:flap_cm":
			return _read(step, "parts", "flap_cm")
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
		"Sequence:fade":
			return _read(step, "fx", "fade")
		"TopBar:modulate:a":
			return _read(step, "ui", "bar")
		"Pill:modulate:a", "ArtProgress:modulate:a":
			return _read(step, "ui", "pill")
	push_error("no expected value for %s" % track)
	return NAN


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
