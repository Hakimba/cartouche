# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Readable values for the carousel's tests, and the seeded random cases their properties run on:
## the same cases on every run.

## Cases each property checks.
const CASES := 2000
const FRAME_S := 1.0 / 60.0
const DVD := preload("res://carousel/models/dvd.tscn")


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


## Label images kept in memory, by title; none unless given.
class FakeLabels extends DevLabels:
	var _images: Dictionary[String, Texture2D]

	func _init(images: Dictionary[String, Texture2D] = {}) -> void:
		_images = images

	func has_label(game: AndroidServices.Game) -> bool:
		return game.title in _images

	func label(game: AndroidServices.Game) -> Texture2D:
		return _images[game.title]


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
static func _back_off(shape: CartridgeShape, rule: StringName, step: Callable) -> void:
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
