# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Readable values for the carousel's tests, and the seeded random cases their properties run on:
## the same cases on every run.

## Cases each property checks.
## Millimetres in the models' units, and how near two values of a model are the same.
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
const CASES := 2000
const FRAME_S := 1.0 / 60.0
const DVD := preload("res://carousel/media/ps2_dvd/ps2_dvd.tscn")
## The games of [method games], which have no medium, on [constant DVD].
const DVDS: Dictionary[String, PackedScene] = {"": DVD}
const CAROUSEL := preload("res://carousel/carousel.tscn")
## Loaded, never preloaded: a script holding a console's scene keeps it cached, and the loading tests tell
## which consoles were loaded by the cache.
const PS2_SLIM := "res://carousel/consoles/ps2_slim/ps2_slim.tscn"
const PROFILES := "res://data/platforms/profiles.json"
## The detail every shipped part is built at in the tests.
const SHAPE_DETAIL := 32
## The media made for a later stage, which shows a console's regional cartridges: no platform's games
## come in them yet, though the fronts of their scans may be declared already.
const LATER_MEDIA: Array[String] = ["famicom_cart", "sfc_cart", "snes_us_cart"]
const Request := Scripted.Request
const Answer := Scripted.Answer

## Every medium's scene, loaded on the main thread and kept, so that Appearance's background loads find it cached and
## make no mesh on a worker: the headless engine's mesh owner is not thread-safe (Godot 4.7.2,
## servers/rendering/dummy/storage/mesh_storage.h:50) and a mesh made there can break one made on the main thread.
static var held_media: Array = medium_scenes().map(func(scene: String) -> Resource: return load(scene))


## The JSON file at [param path], read.
static func json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The fronts of [param platform_id]'s cartridges whose scans its labels are cut from, by medium; none
## for a platform of discs or of no scans.
static func fronts(platform_id: String) -> Dictionary:
	var profile: Dictionary = json(PROFILES)[platform_id]
	var art: Dictionary = profile.get("art", {})
	return art.get("fronts", {})


## The scene of every medium folder.
static func medium_scenes() -> Array[String]:
	var found: Array[String] = []
	for manifest: MediumManifest in MediumManifest.found().values():
		found.append(manifest.scene)
	return found


## Whether [param model] is drawn from a glb: its meshes are its own, placed as the glb places them.
static func is_glb(model: Node) -> bool:
	return model.find_children("*", "Node3D", true, false).any(func(node: Node) -> bool:
		return node.scene_file_path.get_extension() == "glb")


## [param carousel]'s consoles row stepped to the console at [param index], a second on.
static func select_console(carousel: Carousel, index: int) -> void:
	while carousel._consoles.selected_index() != index:
		press(carousel, &"carousel_right" if carousel._consoles.selected_index() < index else &"carousel_left")
	step_frames(carousel, 60)


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
			"id": "test/%d" % i, "platform_id": "test", "title": "Game %d" % i, "last_disc": 0,
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
			"parts": {"lid_degrees": random.randf_range(0.0, 130.0), "flap_cm": _anywhere(random, 5.0)},
			"disc": {"visible": random.randf(), "inRow": float(random.randi_range(0, 1)),
				"lift": _or_zero(random, _anywhere(random, 10.0)), "dx": _anywhere(random, 5.0),
				"dy": _anywhere(random, 5.0), "rx": _anywhere(random, 40.0), "ry": _anywhere(random, 40.0),
				"spin": random.randf_range(0.0, 20.0)},
			"row": {"show": random.randf(), "x": _anywhere(random, 20.0), "y": _anywhere(random, 20.0),
				"z": _anywhere(random, 20.0), "scale": random.randf_range(0.1, 2.0), "pose": random.randf()},
			"consoles": {"show": random.randf()},
			"look": {"blur": random.randf_range(0.0, 20.0), "opacity": random.randf(), "sat": random.randf_range(0.0, 2.0)},
			"ui": {"bar": random.randf(), "tabs": random.randf(), "pill": random.randf()},
			"fx": {"black": [0.0, 1.0, random.randf()][random.randi_range(0, 2)],
				"fade": [0.0, 1.0, random.randf()][random.randi_range(0, 2)]},
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


## The carousel freed with [param suite]'s test, on [param android] (the desktop's demo library when none), the
## welcome as short as can be; not added yet.
static func new_carousel(suite: GdUnitTestSuite, android: AndroidServices = null) -> Carousel:
	var carousel: Carousel = suite.auto_free(CAROUSEL.instantiate())
	if android != null:
		carousel.android = android
	(carousel.get_node("%Screens") as ScreenFlow).welcome_waits = false
	return carousel


## [param carousel], shown, past its arrival and never resting.
static func arrived(carousel: Carousel) -> void:
	carousel._arrival.custom_step(10.0)
	carousel._resting.set_process(false)


## The carousel of the demo library, shown on its consoles screen in [param suite], moved on by the
## test itself (see [method step_frame]), its games row drawing the same picks at every run.
static func shown_carousel(suite: GdUnitTestSuite) -> Carousel:
	var carousel := new_carousel(suite)
	var row: ShelfRow = carousel.get_node("%Row")
	row.label_images = suite.auto_free(FakeArt.new())
	row.random = cases(0)
	suite.add_child(carousel)
	for i in 100:
		if carousel.is_shown():
			break
		await suite.await_idle_frame()
	suite.assert_bool(carousel.is_shown()).is_true()
	arrived(carousel)
	row.set_process(false)
	carousel.set_process(false)
	carousel._consoles.set_process(false)
	return carousel


## One frame of [param delta] seconds for [param carousel]: its console's animation, its launch and
## its toss, the carousel, then its rows, in the order of their process priorities.
static func step_frame(carousel: Carousel, delta := FRAME_S) -> void:
	if carousel._sequence.is_processing():
		carousel._sequence._process(delta)
	if carousel._game_launch.is_processing():
		carousel._game_launch._process(delta)
	if carousel._toss.is_processing():
		carousel._toss._process(delta)
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


## The parts [param random] draws for a console: none to five, each of any role, at rest and moved
## anywhere, a door, a light, a hinge…
static func moving_parts(random: RandomNumberGenerator) -> Array[ConsolePart]:
	var found: Array[ConsolePart] = []
	for i in random.randi_range(0, 5):
		var role := random.randi_range(0, ConsolePart.Role.size() - 1) as ConsolePart.Role
		found.append(part(StringName("part_%d" % i), role, _anywhere(random, 100.0), _anywhere(random, 100.0)))
	return found


## A part moving [param property], of [param role], at [param rest] and fully moved at [param open].
static func part(property: StringName, role: ConsolePart.Role, rest: float, open: float) -> ConsolePart:
	var made := ConsolePart.new()
	made.property = property
	made.role = role
	made.rest = rest
	made.open = open
	return made


## Every console folder, as the app finds them.
static func console_folders() -> Array[String]:
	var folders: Array[String] = []
	folders.assign(ConsoleManifest.found().map(ConsoleManifest.folder_of))
	return folders


## A new console of [param scene], not in the tree.
static func new_console(scene: String) -> ConsoleModel:
	return (load(scene) as PackedScene).instantiate()


## [param shipped]'s dimensions drawn again by [param random] until its rules accept them, a thousand
## times at most (the last one drawn then, which [method accepted] refuses): [param share] of them each
## time, each number from [param spread].x to [param spread].y times itself, each count up to
## [param counts] more or fewer.
static func drawn_around(shipped: ModelShape, random: RandomNumberGenerator, spread: Vector2, counts := 0,
		share := 1.0) -> ModelShape:
	var shape: ModelShape
	for attempt in 1000:
		shape = shipped.duplicate()
		for dimension in shape.dimensions():
			var value: Variant = shape.get(dimension)
			if random.randf() >= share:
				continue
			if value is int:
				var count: int = value
				shape.set(dimension, maxi(0, count + random.randi_range(-counts, counts)))
			elif value is float:
				var number: float = value
				shape.set(dimension, number * random.randf_range(spread.x, spread.y))
			elif value is Vector2:
				var vector: Vector2 = value
				shape.set(dimension, vector * Vector2(random.randf_range(spread.x, spread.y),
					random.randf_range(spread.x, spread.y)))
			elif value is Vector3:
				var vector: Vector3 = value
				shape.set(dimension, vector * Vector3(random.randf_range(spread.x, spread.y),
					random.randf_range(spread.x, spread.y), random.randf_range(spread.x, spread.y)))
		if shape.problems().is_empty():
			break
	return shape


## Whether a triangle of [param corners] (three by three) meets [param box]: one of its edges goes
## through the box, or one of the box's edges through it.
static func meets(corners: PackedVector3Array, box: AABB) -> bool:
	for i in range(0, corners.size(), 3):
		for side in 3:
			if box.intersects_segment(corners[i + side], corners[i + (side + 1) % 3]):
				return true
		for corner in 8:
			for axis: int in [1, 2, 4]:
				if (corner & axis) == 0 and Geometry3D.segment_intersects_triangle(box.get_endpoint(corner),
						box.get_endpoint(corner | axis), corners[i], corners[i + 1], corners[i + 2]) != null:
					return true
	return false


## The shape of [param medium]'s model, its label's.
static func medium_shape(medium: String) -> ModelShape:
	var model: Node3D = (load(MediumManifest.found()[medium].scene) as PackedScene).instantiate()
	var shape := ((model.get_node(^"Label") as MeshInstance3D).mesh as ShapedMesh).shape
	model.free()
	return shape


## The platform [param id] as the catalog sends it, its media its profile's.
static func platform(id: String) -> AndroidServices.Platform:
	var medium: Dictionary = _profile(id)["medium"]
	return AndroidServices.Platform.new({"id": id, "name": id, "media": _profile(id)["media"], "medium": medium["default"]})


## The media [param id]'s profile declares, its default first.
static func media(id: String) -> Array[String]:
	var declared: Dictionary = _profile(id)["medium"]
	var found: Array[String] = [declared["default"]]
	for group: String in declared:
		if declared[group] not in found:
			found.append(declared[group])
	return found


## A console with no shape nor mesh, made of what the launch knows of one: its [member moving]
## parts, its seat and its way in.
class Console extends ConsoleModel:
	var moving: Array[ConsolePart] = []
	var seated := Transform3D.IDENTITY

	func moving_parts() -> Array[ConsolePart]:
		return moving

	func seat() -> Transform3D:
		return seated


## Disc scans kept in memory by title, ready at once; none unless given.
class FakeArt extends GameArt:
	var _images: Dictionary[String, Texture2D]

	func _init(images: Dictionary[String, Texture2D] = {}) -> void:
		super()
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


## What the fakes of the plugin share: every request they answer is scripted by the test, at once by default.
class Scripted extends AndroidServices:
	signal released

	## The requests a fake answers; the settings' saves are one each, named by [method save_of].
	enum Request {
		CURTAIN, CURRENT_LIBRARY, PICK_FOLDER, PREVIEW, SET_UP, SCAN, REMOVE, ORDER_CONSOLES, RENAME_GAME, REFRESH_PLATFORM,
		ENTER_CONSOLE, LEAVE_GAME, CHOOSE_LABEL, PICK_LABEL_PICTURE, KEEP_OWN_LABEL, CHECK_LAUNCH,
		START_LAUNCH, SAVE_BUTTON_STYLE, SAVE_EDGE_SMOOTHING, SAVE_BACKDROP, SAVE_PREFERRED_REGION, SAVE_LANGUAGE, SAVE_SOUND_LEVEL,
		SAVE_GAMES_FLOAT, SAVE_PIXEL_VEIL, SAVE_GAMES_IN_LINE, LABEL_VARIANTS,
	}
	## How a request is answered: as the fake usually does, [constant LATER_FRAMES] frames later, once [signal released]
	## (a request asked while HELD waits for the next release; [method release] answers those waiting and erases every HELD
	## script, so a request asked after it is answered as usual; a test that wants it held again scripts it again), as a
	## failure, or never while the script says so.
	enum Answer { AT_ONCE, LATER, HELD, FAILS, NEVER }

	const LATER_FRAMES := 20
	const _UNEXPECTED := &"unexpected"

	## The scripted answers; a request not in it is answered at once.
	var answers: Dictionary[Request, Answer] = {}
	## The codes of the failures, by request: a request in it fails with its code whenever it is answered.
	var failures: Dictionary[Request, StringName] = {}

	## Answers the requests held, no longer held: each as the script now says.
	func release() -> void:
		for request: Request in answers.keys():
			if answers[request] == Answer.HELD:
				answers.erase(request)
		released.emit()

	## The request of the setting [param key]'s save; a key the settings do not save stops the test.
	static func save_of(key: StringName) -> Request:
		return Request["SAVE_" + String(key).to_upper()]

	## [param request]'s answer, [param usual_frames] frames after it is asked as the plugin does, then as scripted.
	func _answer(request: Request, usual_frames := 0) -> Dictionary:
		if usual_frames > 0:
			await _frames(usual_frames)
		match answers.get(request, Answer.AT_ONCE):
			Answer.LATER:
				await _frames(LATER_FRAMES)
			Answer.HELD:
				await released
			Answer.NEVER:
				while answers.get(request, Answer.AT_ONCE) == Answer.NEVER:
					await released
		if answers.get(request, Answer.AT_ONCE) == Answer.FAILS or failures.has(request):
			return {"ok": false, "code": failures.get(request, _UNEXPECTED)}
		return {"ok": true}

	static func _frames(count: int) -> void:
		for frame in count:
			await (Engine.get_main_loop() as SceneTree).process_frame


## The Android services answering launches as the test says, counting them: a game can start unless the answer of
## [constant Request.CHECK_LAUNCH] or [constant Request.START_LAUNCH] is scripted otherwise.
class FakeAndroid extends Scripted:
	## Called as the game starts, before the answer; as it is checked, with the game.
	var on_start := func() -> void: pass
	var on_check := func(_game: AndroidServices.Game) -> void: pass
	var checks := 0
	var starts := 0

	func check_launch(game: AndroidServices.Game, _disc: int) -> AndroidServices.Result:
		checks += 1
		on_check.call(game)
		return AndroidServices.Result.new(await _answer(Request.CHECK_LAUNCH))

	func launch_game(_game: AndroidServices.Game, _disc: int) -> AndroidServices.Result:
		starts += 1
		on_start.call()
		return AndroidServices.Result.new(await _answer(Request.START_LAUNCH))


## The profile `data/platforms/profiles.json` gives [param id].
static func _profile(id: String) -> Dictionary:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/platforms/profiles.json"))
	return profiles[id]


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


## How many triangles [param model]'s meshes are drawn with.
static func triangle_count(model: Node) -> int:
	var count := 0
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in geometry.mesh.get_surface_count() if geometry.mesh else 0:
			count += triangles(geometry.mesh.surface_get_arrays(surface)).size()
	return count


static func points(arrays: Array) -> PackedVector3Array:
	return arrays[Mesh.ARRAY_VERTEX]


## The edges of [param meshes]' faces, as their two ends, that no face goes back along: none on a
## closed surface whose faces are all turned the same way. Points are joined to the micrometre.
static func open_edges(meshes: Array[Array]) -> Array[PackedVector3Array]:
	var joined := _joined(meshes)
	var corners: PackedInt32Array = joined[0]
	var spots: PackedVector3Array = joined[1]
	# Each edge by its two ends' spots, the first in the high bits.
	var counts: Dictionary[int, int] = {}
	for t in range(0, corners.size(), 3):
		for k in 3:
			var from := corners[t + k]
			var to := corners[t + (k + 1) % 3]
			if from != to:
				counts[(from << 32) | to] = counts.get((from << 32) | to, 0) + 1
				counts[(to << 32) | from] = counts.get((to << 32) | from, 0) - 1
	var found: Array[PackedVector3Array] = []
	for edge in counts:
		if counts[edge] > 0:
			found.append(PackedVector3Array([spots[edge >> 32], spots[edge & 0xFFFFFFFF]]))
	return found


## How many edges of [param meshes] belong to more than two faces, points joined as for [method open_edges]:
## none on a surface that never folds back on itself.
static func folded_edges(meshes: Array[Array]) -> int:
	var joined := _joined(meshes)
	var corners: PackedInt32Array = joined[0]
	var counts: Dictionary[int, int] = {}
	for t in range(0, corners.size(), 3):
		for k in 3:
			var from := corners[t + k]
			var to := corners[t + (k + 1) % 3]
			var key := (mini(from, to) << 32) | maxi(from, to)
			counts[key] = counts.get(key, 0) + 1
	return counts.values().filter(func(faces: int) -> bool: return faces > 2).size()


## The way face [param a], [param b], [param c] looks, its length twice its area: Godot's front faces are
## clockwise seen from the side they face.
static func face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a)


## The volume each separate piece of [param meshes] encloses (pieces share no point): positive
## when its faces are turned outwards.
static func volumes(meshes: Array[Array]) -> PackedFloat32Array:
	var joined := _joined(meshes)
	var corners: PackedInt32Array = joined[0]
	var spots: PackedVector3Array = joined[1]
	# Each point's piece, pieces merged as faces join them.
	var piece: Array[int] = []
	piece.assign(range(spots.size()))
	for t in range(0, corners.size(), 3):
		for k: int in [1, 2]:
			piece[_root(piece, corners[t + k])] = _root(piece, corners[t])
	var sums: Dictionary[int, float] = {}
	for t in range(0, corners.size(), 3):
		var at := _root(piece, corners[t])
		var corner := spots[corners[t]]
		# Godot's front faces are clockwise seen from the side they face.
		sums[at] = sums.get(at, 0.0) - corner.dot(spots[corners[t + 1]].cross(spots[corners[t + 2]])) / 6.0
	return PackedFloat32Array(sums.values())


## The corners of [param meshes]' triangles, three by three, each as the point it stands at (spots
## within a micrometre are one), then those points.
static func _joined(meshes: Array[Array]) -> Array:
	var ids: Dictionary[Vector3i, int] = {}
	var spots := PackedVector3Array()
	var corners := PackedInt32Array()
	for arrays in meshes:
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var at := PackedInt32Array()
		for vertex in vertices:
			var key := Vector3i((vertex / MeshBuilder.UNITS_PER_MM * 1000.0).round())
			if key not in ids:
				ids[key] = spots.size()
				spots.append(vertex)
			at.append(ids[key])
		for index in indices:
			corners.append(at[index])
	return [corners, spots]


static func _root(piece: Array[int], at: int) -> int:
	while piece[at] != at:
		at = piece[at]
	return at
