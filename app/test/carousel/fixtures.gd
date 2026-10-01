# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Readable values for the carousel's tests, and the seeded random cases their properties run on:
## the same cases on every run.

## Cases each property checks.
const CASES := 2000
const FRAME_S := 1.0 / 60.0
const DVD := preload("res://carousel/models/dvd.tscn")
const CAROUSEL := preload("res://carousel/carousel.tscn")


## A generator of cases, seeded by the test so that a failure always comes back.
static func cases(test_seed: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = test_seed
	return random


## Left or right, as [param random] draws it.
static func direction(random: RandomNumberGenerator) -> int:
	return -1 if random.randf() < 0.5 else 1


## [param count] games of one shelf, titled `Game 0`, `Game 1`…
static func games(count: int) -> Array[AndroidServices.Game]:
	var shelf: Array[AndroidServices.Game] = []
	for i in count:
		shelf.append(AndroidServices.Game.new({
			"id": "test/%d" % i, "platform_id": "test", "title": "Game %d" % i, "identified": false,
			"discs": [{"name": "Game %d.iso" % i}], "last_disc": 0,
		}))
	return shelf


## A disc [param random] draws, from a small, thick one to a large, thin one, that
## [method DiscShape.problems] accepts: each dimension drawn within the room the previous ones leave,
## the gaps between them down to a few hundredths of a millimetre.
static func disc(random: RandomNumberGenerator) -> DiscShape:
	var shape := DiscShape.new()
	shape.radius = random.randf_range(8.0, 70.0)
	shape.thickness = random.randf_range(0.5, minf(3.0, shape.radius * 0.15))
	shape.hole = random.randf_range(1.0, shape.radius * 0.2)
	shape.ring_width = random.randf_range(0.3, maxf(0.31, shape.radius * 0.05))
	shape.ring_height = _or_zero(random, random.randf_range(0.0, 0.3))
	shape.ring = shape.hole + shape.ring_width / 2.0 + _gap(random, shape.radius * 0.05)
	var hub := shape.ring + shape.ring_width / 2.0
	var edge := shape.radius - shape.thickness / 2.0
	var room := edge - hub
	shape.label_inner = hub + _gap(random, room * 0.1)
	shape.label_outer = random.randf_range(shape.label_inner + room * 0.3, edge - 0.02)
	shape.mirror_inner = hub + _gap(random, room * 0.1)
	shape.mirror_outer = random.randf_range(shape.mirror_inner + room * 0.3, edge - 0.02)
	shape.data_inner = shape.mirror_inner + _gap(random, room * 0.05)
	shape.data_outer = random.randf_range(shape.data_inner + room * 0.1, shape.mirror_outer - 0.02)
	return shape


## A cartridge [param random] draws that [method CartridgeShape.problems] accepts: each part from
## roomy to just inside its rules' limits, the label anywhere on the body's front, into its
## corners, the plate anywhere on the upper part's, below the ridge.
static func cartridge(random: RandomNumberGenerator) -> CartridgeShape:
	var shape := CartridgeShape.new()
	shape.width = random.randf_range(40.0, 80.0)
	shape.height = random.randf_range(25.0, 60.0)
	shape.depth = random.randf_range(4.0, 10.0)
	shape.bevel = random.randf_range(0.3, 1.0)
	shape.bottom_corner = random.randf_range(shape.bevel + 0.2, 3.0)
	shape.top_corner = random.randf_range(shape.bevel + 0.2, 5.0)
	shape.notch = _or_zero(random, random.randf_range(0.05, 1.2))
	shape.ledge = _or_zero(random, random.randf_range(0.0, 2.0))
	shape.recess_slope = _or_zero(random, random.randf_range(0.0, 1.5))
	# From just above its corners (with room for the ridge and the plate) to just below the body's
	# (with room for a label).
	var lowest := maxf(shape.top_corner + shape.hidden_corner(), 4.0 * shape.bevel + 0.3)
	var highest := minf(shape.height - shape.bottom_corner - shape.hidden_corner(),
		shape.height - 2.0 * (shape.bevel + shape.recess_slope) - 2.0)
	shape.upper_height = _near_limits(random, lowest + 0.01, highest - 0.01)
	var deepest := minf(minf(3.0, (shape.upper_height - 2.0 * shape.bevel) * 0.99), shape.depth + shape.ledge - 0.01)
	shape.ridge_height = _near_limits(random, 2.0 * shape.bevel + 0.01, deepest)
	shape.ridge_raise = random.randf_range(0.01, 1.0)
	shape.recess = random.randf_range(0.1, minf(1.0, shape.depth - 2.0 * shape.bevel - 0.1))
	var room := shape.body().grow(-shape.bevel - shape.recess_slope - 0.1)
	shape.label_size = room.size * Vector2(random.randf_range(0.05, 0.9), random.randf_range(0.1, 0.8))
	shape.label_corner = random.randf_range(0.05, minf(shape.label_size.x, shape.label_size.y) / 2.0 - 0.05)
	shape.label_centre = _somewhere(random, room, shape.label_size)
	# Over the straight part of the body's edges, up to its very end.
	var straight := shape.body().end.x - maxf(shape.bottom_corner, shape.hidden_corner()) - 0.01
	shape.label_centre.x = clampf(shape.label_centre.x, -straight, straight)
	_back_off(shape, &"label_on_body", func() -> void:
		shape.label_centre = shape.label_centre.move_toward(room.get_center(), 0.05)
		shape.label_size *= 0.995
		shape.label_corner *= 0.995)
	var band := Rect2(-shape.width / 2.0 + shape.bevel, shape.step() + shape.bevel,
		shape.width - 2.0 * shape.bevel, shape.upper_height - shape.ridge_height - shape.bevel)
	shape.plate_size = band.size * Vector2(random.randf_range(0.02, 0.9), random.randf_range(0.3, 0.8))
	shape.plate_centre = _somewhere(random, band, shape.plate_size)
	_back_off(shape, &"plate_on_upper_part", func() -> void:
		shape.plate_centre = shape.plate_centre.move_toward(band.get_center(), 0.05)
		shape.plate_size *= 0.995)
	shape.plate_raise = random.randf_range(0.01, 0.5)
	return shape


## A top-loading console [param random] draws that [method ConsoleShape.problems] accepts: from a
## thin one for small discs to a thick one, its lid anywhere on the top, near its rounded corners,
## the ribs beside it or none.
static func console(random: RandomNumberGenerator) -> ConsoleShape:
	var shape := ConsoleShape.new()
	shape.bevel = random.randf_range(0.3, 2.0)
	shape.seam = random.randf_range(2.0 * shape.bevel + 0.2, 15.0)
	shape.lid_thickness = random.randf_range(0.5, 5.0)
	var above := maxf(shape.lid_thickness + 3.2, 2.0 * shape.bevel + 0.2)
	shape.height = shape.seam + above + random.randf_range(0.0, 20.0)
	shape.seat_height = _near_limits(random, shape.seam + 2.01, shape.height - shape.lid_thickness - 1.01)
	shape.disc_radius = random.randf_range(20.0, 60.0)
	shape.lid_gap = random.randf_range(0.1, 2.0)
	var side := 2.0 * shape.disc_radius + 2.2
	shape.lid_size = Vector2(side + random.randf_range(0.0, 30.0), side + random.randf_range(0.0, 30.0))
	shape.lid_corner = _near_limits(random, 0.2, minf(shape.lid_size.x, shape.lid_size.y) / 2.0 - 0.2)
	shape.rib_count = random.randi_range(0, 16)
	shape.rib_width = random.randf_range(0.2, 2.0)
	shape.rib_pitch = shape.rib_width + random.randf_range(0.1, 5.0)
	shape.rib_raise = random.randf_range(0.05, 1.0)
	var margin := shape.bevel + 1.0 + shape.lid_gap
	var ribs_room := shape.rib_count * shape.rib_pitch + 1.0
	shape.width = shape.lid_size.x + ribs_room + 2.0 * margin + random.randf_range(0.5, 40.0)
	shape.depth = shape.lid_size.y + 2.0 * margin + random.randf_range(0.5, 40.0)
	shape.corner = _near_limits(random, shape.bevel + 0.2, minf(shape.width, shape.depth) / 2.0 - 0.2)
	var room := shape.body().grow(-margin)
	room.size.x -= ribs_room
	shape.lid_centre = _somewhere(random, room, shape.lid_size)
	shape.rib_start = shape.opening().end.x + 0.6 + shape.rib_width / 2.0
	shape.rib_length = random.randf_range(1.0, shape.depth - 2.0 * margin)
	# Rounder corners than the lid's place leaves room for are rounded less.
	_back_off(shape, &"lid_inside_the_top", func() -> void: shape.corner = maxf(shape.bevel + 0.2, shape.corner * 0.97))
	_back_off(shape, &"ribs_on_the_top_beside_the_lid", func() -> void: shape.rib_length *= 0.97)
	return shape


## The steps of a launch animation [param random] draws: two to nine, from very short to long, each
## curve, held or not, the disc in the row or out of it and on the spindle, the black whole or not.
## Written as by hand: some values left out or whole, durations and holds sometimes negative, an ease
## now and then unknown, the step the game is chosen at sometimes out of the steps or not given.
static func launch_steps(random: RandomNumberGenerator) -> Dictionary:
	var steps: Array[Dictionary] = []
	var count := random.randi_range(2, 9)
	var eases: Array[String] = ["linear", "in", "out", "inOut", "outBack", "outBack", "bounce"]
	for i in count:
		var step := {
			"dur": _or_zero(random, random.randf_range(-0.2, 1.0)), "hold": _or_zero(random, random.randf_range(-0.2, 0.5)),
			"ease": eases[random.randi_range(0, eases.size() - 1)],
			"console": {"px": _anywhere(random, 20.0), "py": _anywhere(random, 20.0), "pz": _anywhere(random, 20.0),
				"rx": _anywhere(random, 180.0), "ry": _anywhere(random, 180.0), "rz": _anywhere(random, 180.0),
				"scale": random.randf_range(0.1, 2.0), "pose": random.randf(), "sway": random.randf_range(0.0, 10.0),
				"bob": random.randf()},
			"lid": {"angle": random.randf_range(0.0, 130.0)},
			"disc": {"visible": random.randf(), "inRow": float(random.randi_range(0, 1)),
				"lift": _or_zero(random, _anywhere(random, 10.0)), "dx": _anywhere(random, 5.0),
				"dy": _anywhere(random, 5.0), "rx": _anywhere(random, 40.0), "ry": _anywhere(random, 40.0),
				"spin": random.randf_range(0.0, 20.0)},
			"row": {"show": random.randf(), "x": _anywhere(random, 20.0), "y": _anywhere(random, 20.0),
				"z": _anywhere(random, 20.0), "scale": random.randf_range(0.1, 2.0), "pose": random.randf()},
			"consoles": {"show": random.randf()},
			"look": {"blur": random.randf_range(0.0, 20.0), "opacity": random.randf(), "sat": random.randf_range(0.0, 2.0)},
			"ui": {"bar": random.randf(), "tabs": random.randf(), "pill": random.randf()},
			"fx": {"black": [0.0, 1.0, random.randf()][random.randi_range(0, 2)]},
		}
		for key: String in step.keys():
			var roll := random.randf()
			if roll < 0.05:
				step.erase(key)
			elif step[key] is Dictionary:
				var group: Dictionary = step[key]
				for name: String in group.keys():
					roll = random.randf()
					if roll < 0.1:
						group.erase(name)
					elif roll < 0.15:
						var value: float = group[name]
						group[name] = roundi(value)
		steps.append(step)
	var data := {"steps": steps}
	var chosen := random.randi_range(1, count - 1)
	var choices: Array[Variant] = [chosen, chosen, chosen, chosen, 0, count, count + 3, -2, chosen + 0.3]
	var drawn := random.randi_range(0, choices.size())
	if drawn < choices.size():
		data["choice"] = choices[drawn]
	return data


static func _anywhere(random: RandomNumberGenerator, reach: float) -> float:
	return random.randf_range(-reach, reach)


## An insertion [param random] draws: each step from none to long, the drive upright or leaning
## back, with or without a spindle.
static func insertion(random: RandomNumberGenerator) -> Insertion:
	var drawn := Insertion.new()
	for step: StringName in [&"face_s", &"grab_s", &"seat_s", &"bounce_s", &"spin_up_s", &"black_after_s", &"black_s"]:
		drawn.set(step, _or_zero(random, random.randf_range(0.01, 1.0)))
	for distance: StringName in [&"grab_distance", &"seat_depth", &"bounce"]:
		drawn.set(distance, _or_zero(random, random.randf_range(0.001, 1.0)))
	drawn.tilt_degrees = _or_zero(random, random.randf_range(-40.0, 40.0))
	drawn.turns_per_s = _or_zero(random, random.randf_range(0.1, 40.0))
	drawn.spindle = random.randf() < 0.7
	return drawn


## How a game [param random] draws may stand when it is launched: turned any way, stretched as a
## fast row stretches it, anywhere near the centre.
static func stand(random: RandomNumberGenerator) -> Transform3D:
	var turned := Basis.from_euler(Vector3(random.randf_range(-PI, PI), random.randf_range(-PI, PI), random.randf_range(-PI, PI)))
	var stretch := random.randf_range(0.0, 0.1)
	var scale := Vector3(1.0 + stretch, 1.0 - stretch * 0.6, 1.0) * random.randf_range(0.6, 1.0)
	var origin := Vector3(random.randf_range(-0.5, 0.5), random.randf_range(-0.2, 0.2), random.randf_range(-0.5, 0.2))
	return Transform3D(turned.scaled_local(scale), origin)


## Disc scans kept in memory by title, ready at once; none unless given.
## The carousel of the demo library, shown on its consoles screen in [param suite], moved on by the
## test itself (see [method step_frame]).
static func shown_carousel(suite: GdUnitTestSuite) -> Carousel:
	var carousel: Carousel = suite.auto_free(CAROUSEL.instantiate())
	var row: ShelfRow = carousel.get_node("%Row")
	row.label_images = suite.auto_free(FakeArt.new())
	var screens: ScreenFlow = carousel.get_node("%Screens")
	screens.welcome_waits = false
	suite.add_child(carousel)
	for i in 100:
		if carousel._shown:
			break
		await suite.await_idle_frame()
	suite.assert_bool(carousel._shown).is_true()
	# The carousel's arrival at its end.
	carousel._arrival.custom_step(10.0)
	row.set_process(false)
	carousel.set_process(false)
	carousel._consoles.set_process(false)
	return carousel


## One frame of [param delta] seconds for [param carousel]: its console's animation and its launch,
## the carousel, then its rows, in the order of their process priorities.
static func step_frame(carousel: Carousel, delta := FRAME_S) -> void:
	if carousel._sequence.is_processing():
		carousel._sequence._process(delta)
	if carousel._game_launch.is_processing():
		carousel._game_launch._process(delta)
	carousel._process(delta)
	carousel._row._process(delta)
	carousel._consoles._process(delta)


## [param count] frames of [method step_frame].
static func step_frames(carousel: Carousel, count: int) -> void:
	for i in count:
		step_frame(carousel)


## Frames until [param carousel] is on [param screen], ten seconds at most.
static func step_until(carousel: Carousel, screen: Carousel.Screen) -> void:
	for i in 600:
		if carousel._screen == screen:
			return
		step_frame(carousel)


## [param action] pressed then let go.
static func press(carousel: Carousel, action: StringName) -> void:
	carousel._unhandled_input(button(action, true))
	carousel._unhandled_input(button(action, false))


static func button(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


class FakeArt extends GameArt:
	var _images: Dictionary[String, Texture2D]

	func _init(images: Dictionary[String, Texture2D] = {}) -> void:
		_images = images

	## [param game]'s scan arrives, as the plugin finds it.
	func arrive(game: AndroidServices.Game, image: Texture2D) -> void:
		_images[game.title] = image
		loaded.emit(game.id)

	func has_art(game: AndroidServices.Game) -> bool:
		return game.title in _images

	func has_texture(game: AndroidServices.Game) -> bool:
		return has_art(game)

	func texture(game: AndroidServices.Game) -> Texture2D:
		return _images[game.title]

	func request(_game: AndroidServices.Game) -> void:
		pass


## The Android services answering launches as the test says, counting them: a game can start
## unless [member check_code] (or [member start_code]) holds the code of a failure. With
## [member late], each answer waits for [signal replied]; with [member silent], it never comes.
class FakeAndroid extends AndroidServices:
	signal replied

	var check_code := &""
	var start_code := &""
	var late := false
	var silent: Array[StringName] = []
	## Called as the game starts, before the answer.
	var on_start := func() -> void: pass
	var checks := 0
	var starts := 0

	func check_launch(_game: AndroidServices.Game, _disc: int) -> AndroidServices.Result:
		checks += 1
		return await _answer(&"check", check_code)

	func launch_game(_game: AndroidServices.Game, _disc: int) -> AndroidServices.Result:
		starts += 1
		on_start.call()
		return await _answer(&"start", start_code)

	func _answer(request: StringName, code: StringName) -> AndroidServices.Result:
		while late or request in silent:
			await replied
			if request not in silent:
				break
		return AndroidServices.Result.new({"ok": true} if code.is_empty() else {"ok": false, "code": code, "detail": "fake"})


## The centre of a box of [param size] that [param random] puts anywhere within [param room], a
## quarter of the times in one of its corners.
static func _somewhere(random: RandomNumberGenerator, room: Rect2, size: Vector2) -> Vector2:
	var slack := Rect2(room.position + size / 2.0, room.size - size)
	if random.randf() < 0.25:
		return Vector2(slack.end.x if random.randf() < 0.5 else slack.position.x,
			slack.end.y if random.randf() < 0.5 else slack.position.y)
	return Vector2(random.randf_range(slack.position.x, slack.end.x), random.randf_range(slack.position.y, slack.end.y))


## Moves [param shape]'s part with [param step] until it follows [param rule]: just inside it.
static func _back_off(shape: ModelShape, rule: StringName, step: Callable) -> void:
	for i in 2000:
		if rule not in shape.problems():
			return
		step.call()


## A value between [param low] and [param high], a third of the times close to one of them.
static func _near_limits(random: RandomNumberGenerator, low: float, high: float) -> float:
	var margin := (high - low) * 0.02
	match random.randi_range(0, 5):
		0:
			return random.randf_range(low, low + margin)
		1:
			return random.randf_range(high - margin, high)
	return random.randf_range(low, high)


## [param value] most of the times, else zero.
static func _or_zero(random: RandomNumberGenerator, value: float) -> float:
	return 0.0 if random.randf() < 0.2 else value


## A gap of up to [param largest] mm, down to a few hundredths.
static func _gap(random: RandomNumberGenerator, largest: float) -> float:
	return random.randf_range(0.02, maxf(0.03, largest))


## The triangles of mesh [param arrays], as their three corners.
static func triangles(arrays: Array) -> Array[PackedVector3Array]:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found: Array[PackedVector3Array] = []
	for i in range(0, indices.size(), 3):
		found.append(PackedVector3Array([vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]))
	return found


## The triangles of [param meshes], as their three corners.
static func all_triangles(meshes: Array[Array]) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	for arrays in meshes:
		found.append_array(triangles(arrays))
	return found


static func points(arrays: Array) -> PackedVector3Array:
	return arrays[Mesh.ARRAY_VERTEX]


## The edges of [param meshes]' faces, as their two ends, that no face goes back along: none on a
## closed surface whose faces are all turned the same way. Points are joined to the micrometre.
static func open_edges(meshes: Array[Array]) -> Array[PackedVector3Array]:
	var counts: Dictionary[String, int] = {}
	var ends: Dictionary[String, PackedVector3Array] = {}
	for triangle in all_triangles(meshes):
		for k in 3:
			var from := _micrometres(triangle[k])
			var to := _micrometres(triangle[(k + 1) % 3])
			if from == to:
				continue
			counts[from + ">" + to] = counts.get(from + ">" + to, 0) + 1
			counts[to + ">" + from] = counts.get(to + ">" + from, 0) - 1
			ends[from + ">" + to] = PackedVector3Array([triangle[k], triangle[(k + 1) % 3]])
	var found: Array[PackedVector3Array] = []
	for edge in counts:
		if counts[edge] > 0:
			found.append(ends[edge])
	return found


## The volume each separate piece of [param meshes] encloses (pieces share no point): positive
## when its faces are turned outwards.
static func volumes(meshes: Array[Array]) -> PackedFloat32Array:
	var found_triangles := all_triangles(meshes)
	# Each point's piece, pieces merged as faces join them.
	var piece: Dictionary[String, String] = {}
	var root := func(at: String) -> String:
		while piece[at] != at:
			at = piece[at]
		return at
	for triangle in found_triangles:
		var keys: Array[String] = []
		for corner in triangle:
			var key := _micrometres(corner)
			if key not in piece:
				piece[key] = key
			keys.append(key)
		for key: String in keys.slice(1):
			piece[root.call(key)] = root.call(keys[0])
	var sums: Dictionary[String, float] = {}
	for triangle in found_triangles:
		var at: String = root.call(_micrometres(triangle[0]))
		# Godot's front faces are clockwise seen from the side they face.
		sums[at] = sums.get(at, 0.0) - triangle[0].dot(triangle[1].cross(triangle[2])) / 6.0
	return PackedFloat32Array(sums.values())


static func _micrometres(point: Vector3) -> String:
	var at := Vector3i((point / MeshBuilder.UNITS_PER_MM * 1000.0).round())
	return "%d %d %d" % [at.x, at.y, at.z]
