# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every console folder must hold to be shown and launched, whichever console it is.

## How a segment meets a wall: not at all, grazing its rim, or through it.
enum Meeting { CLEAR, GRAZED, CROSSED }

## The kinds of value a shape's dimension may be, and a step of each.
const _DIMENSION_TYPES: Array[int] = [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_BOOL]
const _ONE: Dictionary[int, Variant] = {TYPE_FLOAT: 1.0, TYPE_INT: 1, TYPE_VECTOR2: Vector2.ONE,
	TYPE_VECTOR3: Vector3.ONE}
const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"
const MM := Fixtures.MM
const EPSILON := 0.0001
## The least area, in square millimetres, of a face that is one.
const MIN_AREA_MM2 := 1.0e-6
## The parts of each console a seated medium lies in, drawn solid: its way in is open through the
## others.
const HOUSINGS: Dictionary[String, Array] = {
	"nes": [&"Upper", &"Lower", &"Throat"], "wii": [&"Front", &"Body", &"Light"],
	"gbc": [&"body"], "snes": [&"body"], "gba_sp": [&"body"], "ps2_fat": [&"body", &"tray"],
}
## The open edges of each glb's body as shipped: the shells have openings (undersides, hidden faces), welded by
## position. The closed-mesh promise does not hold for them; these hold.
const OPEN_EDGES: Dictionary[String, int] = {"nes": 80, "gbc": 2475, "snes": 2210, "ps2_fat": 998, "gba_sp": 1359}
## The two bench models' rest poses: the SP's screen stands open and the PS2 tray's bezel stands proud.
## These exact boxes preserve their supplied geometry without changing the other consoles' rest envelopes.
const BENCH_RESTS: Dictionary[String, AABB] = {
	"gba_sp: lid": AABB(Vector3(-0.4199632, 0.07824055, -0.5978231), Vector3(0.8399357, 0.8035966, 0.2716731)),
	"ps2_fat: tray": AABB(Vector3(-0.0571249, 0.5008283, -0.8095596), Vector3(1.2912878, 0.1669884, 1.7316538)),
}
## At least this share of a glb mesh's triangles face the way the vertex normals say.
const WINDING_AGREES := 0.98
## The edges of more than two faces of a glb's meshes, by `console: mesh`: none, but ten on the Super Nintendo's
## body where its shell was cut.
const FOLDED_EDGES: Dictionary[String, int] = {"snes: body": 10}
## The side of the grid's squares a medium's way in is checked by, in millimetres.
const _CELL_MM := 4.0


func test_inv_14_every_console_folder_holds_a_manifest_the_app_can_show() -> void:
	var folders := Array(ResourceLoader.list_directory(ConsoleManifest.FOLDERS)).filter(
		func(entry: String) -> bool: return entry.ends_with("/"))
	var manifests := ConsoleManifest.found()
	assert_int(manifests.size()).is_equal(folders.size()).is_greater(0)
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	var defaults: Dictionary[String, int] = {}
	for manifest in manifests:
		assert_array(manifest.problems()).override_failure_message(
			"%s: %s" % [manifest.resource_path, manifest.problems()]).is_empty()
		assert_bool(manifest.platform in profiles).override_failure_message(
			"%s: no profile for %s" % [manifest.resource_path, manifest.platform]).is_true()
		defaults[manifest.platform] = defaults.get(manifest.platform, 0) + (1 if manifest.is_default else 0)
		var scene: PackedScene = load(manifest.scene)
		var model: Node = auto_free(scene.instantiate())
		assert_bool(model is ConsoleModel).override_failure_message("%s is no console" % manifest.scene).is_true()
		if model is not ConsoleModel:
			continue
		var console: ConsoleModel = model
		for part in console.moving_parts():
			var value: Variant = console.get(part.property)
			assert_bool(value is float and value == part.rest).override_failure_message(
				"%s: %s is %s, not at rest" % [manifest.platform, part.property, value]).is_true()
		assert_float(console.approach().length()).is_equal_approx(1.0, EPSILON)
		if manifest.launch:
			var steps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest.launch))
			assert_array(LaunchAnimation.problems(steps, console)).is_empty()
			assert_str(steps.get("model_hash", "")).override_failure_message(
				"%s: steps tuned on another model" % manifest.platform).is_equal(console.fingerprint())
	for platform: String in defaults:
		assert_int(defaults[platform]).override_failure_message("%s: default versions" % platform).is_equal(1)


func test_steps_moving_a_part_the_console_lacks_are_refused() -> void:
	var random := Fixtures.cases(70)
	var refused := 0
	for i in 200:
		var console: Fixtures.Console = auto_free(Fixtures.Console.new())
		console.moving = Fixtures.moving_parts(random)
		# The parts the steps drawn move, now and then.
		for part: StringName in [&"lid_degrees", &"flap_cm"]:
			if random.randf() < 0.7:
				console.moving.append(MovingPart.new(part, MovingPart.Role.OPENING, 0.0, 1.0))
		var data := Fixtures.launch_steps(random)
		var named: Array[StringName] = []
		for step: Dictionary in data["steps"]:
			var parts: Dictionary = step.get("parts", {})
			for part: String in parts:
				if StringName(part) not in named:
					named.append(StringName(part))
		var lacking := named.filter(func(part: StringName) -> bool:
			return console.moving.all(func(moving: MovingPart) -> bool: return moving.property != part))
		var problems := LaunchAnimation.problems(data, console)
		problems.sort()
		lacking.sort()
		assert_array(problems).is_equal(lacking)
		refused += 1 if not lacking.is_empty() else 0
	assert_int(refused).is_between(40, 160)


func test_a_console_s_fingerprint_changes_with_any_dimension_or_moving_part() -> void:
	var random := Fixtures.cases(73)
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var shipped: ConsoleModel = auto_free(scene.instantiate())
		var console: Fixtures.Console = auto_free(Fixtures.Console.new())
		console.shape = shipped.shape.duplicate()
		console.moving = Fixtures.moving_parts(random)
		var seen := {console.fingerprint(): true}
		# Each change of a dimension says so: what the shape found of its rules is found again.
		var said := [0]
		console.shape.changed.connect(func() -> void: said[0] += 1)
		for dimension: StringName in console.shape.dimensions():
			var value: Variant = console.shape.get(dimension)
			assert_bool(typeof(value) in _DIMENSION_TYPES).override_failure_message(
				"%s.%s: a dimension is a number, a count, a Vector2, a Vector3 or a bool" % [manifest.platform,
				dimension]).is_true()
			console.shape.set(dimension, (not value) if value is bool else value + _ONE[typeof(value)])
			seen[console.fingerprint()] = true
			console.shape.set(dimension, value)
		for part in console.moving:
			var changes := {&"property": &"other", &"role": (part.role + 1) % MovingPart.Role.size(),
				&"rest": part.rest + 1.0, &"open": part.open + 1.0}
			for property: StringName in changes:
				var value: Variant = part.get(property)
				part.set(property, changes[property])
				seen[console.fingerprint()] = true
				part.set(property, value)
		assert_int(seen.size()).is_equal(1 + console.shape.dimensions().size() + 4 * console.moving.size())
		assert_int(said[0]).override_failure_message("%s: a dimension changes silently" % manifest.platform) \
			.is_equal(2 * console.shape.dimensions().size())
		assert_bool(console.fingerprint() in seen).is_true()


func test_the_contract_depends_on_the_shape_and_the_moving_parts_alone() -> void:
	var appearance := Appearance.read(APPEARANCE)
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var fresh: ConsoleModel = auto_free(scene.instantiate())
		var in_tree: ConsoleModel = auto_free(scene.instantiate())
		fresh.name = ConsoleManifest.folder_of(manifest)
		in_tree.name = fresh.name
		add_child(in_tree)
		var medium := _default_medium_box(appearance, manifest.platform)
		_assert_same_animation(LaunchAnimation.placeholder(fresh, medium), LaunchAnimation.placeholder(in_tree, medium))
		for moved in 2:
			for console: ConsoleModel in [fresh, in_tree]:
				for part in console.moving_parts():
					console.set(part.property, part.open if moved else part.rest)
			assert_str(var_to_str(_contract(fresh))).override_failure_message(
				"%s: its contract reads its nodes" % manifest.platform).is_equal(var_to_str(_contract(in_tree)))


func test_every_medium_a_console_s_platform_declares_comes_down_its_way_in_clear_of_its_parts() -> void:
	var appearance := Appearance.read(APPEARANCE)
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		add_child(model)
		var media := Fixtures.platform(manifest.platform).media
		var housings: Array = HOUSINGS.get(ConsoleManifest.folder_of(manifest), [])
		for medium in Fixtures.media(manifest.platform):
			var shown: Node3D = auto_free(appearance.model_of(medium, media).instantiate())
			var box := appearance.medium_box(medium, media)
			_assert_moving_parts_fit(model, box)
			_assert_medium_clear(model, shown, box, housings)


func test_every_glb_holds_beside_it_its_licence_and_source_and_its_credit_line_is_in_the_readme() -> void:
	var readme := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../README.md"))
	var glbs := _glbs("res://carousel")
	for glb in glbs:
		var licence := FileAccess.get_file_as_string(glb.get_base_dir().path_join("LICENSE.txt"))
		var lines := Array(licence.split("\n")).map(func(line: String) -> String: return line.strip_edges())
		var credit := lines.filter(func(line: String) -> bool: return line.begins_with("This work is based on"))
		var source := lines.filter(func(line: String) -> bool: return line.begins_with("* source:"))
		assert_array(credit).override_failure_message("%s: no credit line in its LICENSE.txt" % glb).has_size(1)
		assert_array(source).override_failure_message("%s: no source in its LICENSE.txt" % glb).has_size(1)
		if credit.size() != 1 or source.size() != 1:
			continue
		var line: String = source[0]
		var url := line.trim_prefix("* source:").strip_edges()
		for kept: String in [licence, credit[0], readme]:
			assert_bool(kept.contains(url) and kept.contains("CC-BY-4.0")).override_failure_message(
				"%s: its source or its licence (CC-BY-4.0) is missing from %s" % [glb, kept.left(60)]).is_true()
		assert_bool(credit[0] in readme).override_failure_message("%s: its credit line is not in the README" % glb) \
			.is_true()
	assert_int(glbs.size()).is_greater(2)


func test_a_glb_console_s_meshes_never_fold_nor_degenerate_and_their_winding_agrees_with_their_normals() -> void:
	var checked := 0
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		if not _is_glb(model):
			continue
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var arrays := geometry.mesh.surface_get_arrays(0)
			var meshes: Array[Array] = [arrays]
			var label := "%s: %s" % [ConsoleManifest.folder_of(manifest), geometry.name]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var agreeing := 0
			for point in points:
				assert_bool(is_finite(point.x) and is_finite(point.y) and is_finite(point.z)).override_failure_message(
					"%s: a point is not a number" % label).is_true()
			for t in range(0, corners.size(), 3):
				var facing := Fixtures.face_normal(points[corners[t]], points[corners[t + 1]], points[corners[t + 2]])
				assert_float(facing.length() / (MM * MM)).override_failure_message("%s: a degenerate face" % label) \
					.is_greater(MIN_AREA_MM2)
				var told := normals[corners[t]] + normals[corners[t + 1]] + normals[corners[t + 2]]
				agreeing += 1 if facing.dot(told) > 0.0 else 0
			var folded := Fixtures.folded_edges(meshes)
			assert_int(folded).override_failure_message("%s: %d edges of more than two faces" % [label, folded]) \
				.is_equal(FOLDED_EDGES.get(label, 0))
			assert_float(agreeing / (corners.size() / 3.0)).override_failure_message(
				"%s: its winding disagrees with its normals" % label).is_greater_equal(WINDING_AGREES)
			if geometry.name == &"body":
				assert_int(Fixtures.open_edges(meshes).size()).override_failure_message(label).is_equal(
					OPEN_EDGES[ConsoleManifest.folder_of(manifest)])
				var volume := 0.0
				for piece in Fixtures.volumes(meshes):
					volume += piece
				assert_float(volume).override_failure_message("%s: its volume is not positive" % label).is_greater(0.0)
			checked += 1
	assert_int(checked).is_greater(10)


func test_a_console_without_steps_of_its_own_plays_the_placeholder() -> void:
	var appearance := Appearance.read(APPEARANCE)
	var without: ConsoleManifest = appearance.console_of("ps2").duplicate()
	without.launch = ""
	appearance._consoles["ps2"] = without
	var animation := appearance.animation_of(Fixtures.platform("ps2"), "ps2_dvd")
	var console: ConsoleModel = auto_free(appearance.console("ps2"))
	_assert_same_animation(animation, LaunchAnimation.placeholder(console, appearance.medium_box("ps2_dvd", "dvd")))
	var lid := animation.find_track(^"Consoles/ps2:lid_degrees", Animation.TYPE_VALUE)
	assert_int(lid).is_greater_equal(0)
	assert_float(animation.value_track_interpolate(lid, LaunchAnimation.moment(animation, &"games"))).is_equal(88.0)


func test_only_the_consoles_of_the_library_are_loaded() -> void:
	var manifests := ConsoleManifest.found()
	for shown: Array in [["gba"], ["gba", "ps2"]]:
		var consoles: Dictionary[String, int] = {}
		for platform: String in shown:
			consoles[platform] = 3
		for manifest in manifests:
			assert_bool(ResourceLoader.has_cached(manifest.scene)).override_failure_message(
				"%s loaded before any library" % manifest.platform).is_false()
		var carousel := ScreenFixtures.carousel_for(self, ScreenFixtures.past_first_launch(self, consoles))
		add_child(carousel)
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
		# What the appearance loaded, the one way a console's scene is: a scene loaded and freed again
		# would no longer be cached.
		assert_array(carousel._appearance._scenes.keys()).contains_exactly_in_any_order(consoles.keys())
		carousel.queue_free()
		await await_idle_frame()


func test_only_the_library_s_media_are_loaded_the_shown_shelf_s_made_with_their_launch_animations() -> void:
	var carousel := ScreenFixtures.carousel_for(self, ScreenFixtures.past_first_launch(self, {"snes": 2, "psx": 2}))
	add_child(carousel)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	# The shown shelf's at start, the other's as its shelf shows.
	assert_array(carousel._appearance._models.keys()).contains_exactly(["snes_pal_cart"])
	_assert_shown_shelf_made(carousel, [["snes_pal_cart"]])
	# A game of the PlayStation's on a PS2 disc: both made as its shelf shows, the other shelf's kept.
	var library: AndroidServices.Library = carousel._screens.library
	library.shelves[1].games[1].medium = "ps2_dvd"
	carousel._show_library(library, "psx")
	_assert_shown_shelf_made(carousel, [["ps1_cd", "ps2_dvd"], ["snes_pal_cart"]])
	# Not the cartridge nor the disc their kinds fall back to.
	assert_array(carousel._appearance._models.keys()).contains_exactly_in_any_order(["snes_pal_cart", "ps1_cd",
		"ps2_dvd"])
	# Gone from the library, the other shelf's medium is freed.
	library.shelves.remove_at(0)
	carousel._show_library(library)
	_assert_shown_shelf_made(carousel, [["ps1_cd", "ps2_dvd"]])
	carousel.queue_free()
	await await_idle_frame()


func test_a_manifest_with_problems_or_a_platform_s_second_default_is_left_out() -> void:
	var shipped: ConsoleManifest = ConsoleManifest.found()[0]
	var broken: ConsoleManifest = shipped.duplicate()
	broken.scene = ""
	var second: ConsoleManifest = shipped.duplicate()
	second.version = &"other"
	var other_version: ConsoleManifest = shipped.duplicate()
	other_version.is_default = false
	for listed: Array[ConsoleManifest] in [[broken, shipped, second] as Array[ConsoleManifest],
			[other_version, shipped, broken] as Array[ConsoleManifest]]:
		var shown := Appearance.defaults(listed)
		assert_array(shown.keys()).is_equal([shipped.platform])
		assert_object(shown[shipped.platform]).is_same(shipped)


## Every glb under [param dir], at any depth.
static func _glbs(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "glb":
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_glbs(dir.path_join(sub)))
	return found


## Whether [param model] is drawn from a glb: its meshes are its own, placed as the glb places them.
static func _is_glb(model: Node) -> bool:
	return model.find_children("*", "Node3D", true, false).any(func(node: Node) -> bool:
		return node.scene_file_path.get_extension() == "glb")


## What the launch reads of [param console]: its parts, its seat, its way in and how it is presented.
static func _contract(console: ConsoleModel) -> Array:
	var parts := console.moving_parts().map(func(part: MovingPart) -> Array:
		return [part.property, part.role, part.rest, part.open])
	return [parts, console.seat(), console.approach(), console.presented()]


## [param animation] has the tracks, keys and moments of [param expected].
func _assert_same_animation(animation: Animation, expected: Animation) -> void:
	assert_int(animation.get_track_count()).is_equal(expected.get_track_count())
	for track in expected.get_track_count():
		var path := expected.track_get_path(track)
		var found := animation.find_track(path, Animation.TYPE_VALUE)
		assert_int(found).override_failure_message("no track %s" % path).is_greater_equal(0)
		assert_int(animation.track_get_key_count(found)).is_equal(expected.track_get_key_count(track))
		for key in expected.track_get_key_count(track):
			assert_float(animation.track_get_key_time(found, key)).is_equal(expected.track_get_key_time(track, key))
			assert_str(var_to_str(animation.track_get_key_value(found, key))).override_failure_message(
				"%s: key %d" % [path, key]).is_equal(var_to_str(expected.track_get_key_value(track, key)))
	for moment: StringName in [&"consoles", &"games", &"launch", &"seated", &"black"]:
		assert_float(LaunchAnimation.moment(animation, moment, -1.0)).is_equal(LaunchAnimation.moment(expected, moment, -1.0))


## Each place of [param carousel]'s row has its model of the media of [param media] alone (each
## shelf's, the shown one's first), whose launch animations are all made already.
func _assert_shown_shelf_made(carousel: Carousel, media: Array) -> void:
	var appearance := carousel._appearance
	var models: Array[PackedScene] = []
	for shelf: Array in media:
		for medium: String in shelf:
			models.append(appearance.model_of(medium, appearance._media[medium].media))
	for place: ShelfRow.Place in carousel._row._places:
		assert_array(place._models.keys()).contains_exactly_in_any_order(models)
	var made := appearance._animations.keys()
	for medium: String in media[0]:
		appearance.animation_of(carousel._platforms[carousel._shelves[carousel._shelf].platform_id], medium)
	assert_array(appearance._animations.keys()).is_equal(made)


## The box of the default medium of [param platform]'s games, at its real size on the seat.
static func _default_medium_box(appearance: Appearance, platform: String) -> AABB:
	return appearance.medium_box(Fixtures.media(platform)[0], Fixtures.platform(platform).media)


## Each opening of [param model] (a flap is one) moves a part; at rest, every part an opening moves
## lies within the bounds of the rest of the console, and any other part that moves stands out of
## them by [constant ConsoleModel.PROUD_MM] at most. All its openings open at once: a part whose
## opening moves the seat carries the medium, and still holds the seat; no other part an opening
## moves meets a medium filling [param medium] (in the seat's frame) on its way in, from the seat to
## as far as the placeholder lifts it.
func _assert_moving_parts_fit(model: ConsoleModel, medium: AABB) -> void:
	var parts := model.moving_parts()
	var openings: Array[MovingPart] = []
	openings.assign(parts.filter(func(part: MovingPart) -> bool:
		return part.role in [MovingPart.Role.OPENING, MovingPart.Role.FLAP]))
	var resting := _boxes(model)
	var seat := model.seat()
	var moving: Dictionary[MeshInstance3D, bool] = {}
	# The meshes the openings move, and whether each carries the medium.
	var opened_by: Dictionary[MeshInstance3D, bool] = {}
	for part in parts:
		model.set(part.property, part.open)
		var opened := _boxes(model)
		var moved := _moved(resting, opened)
		if part in openings:
			assert_array(moved).override_failure_message("%s opens nothing" % part.property).is_not_empty()
			var carries := not moved.is_empty() and not model.seat().is_equal_approx(seat)
			if carries:
				var holder := opened[moved[0]]
				for geometry in moved:
					holder = holder.merge(opened[geometry])
				assert_bool(holder.grow(MM).has_point(model.seat().origin)).override_failure_message(
					"%s carries the seat away from it" % part.property).is_true()
			for geometry in moved:
				opened_by[geometry] = carries
		for geometry in moved:
			moving[geometry] = true
		model.set(part.property, part.rest)
	var body := AABB()
	for geometry in resting:
		if geometry not in moving:
			body = resting[geometry] if body.size == Vector3.ZERO else body.merge(resting[geometry])
	for geometry in moving:
		var bench_key := "%s: %s" % [model.scene_file_path.get_base_dir().get_file(), geometry.name]
		if BENCH_RESTS.has(bench_key):
			var expected: AABB = BENCH_RESTS[bench_key]
			assert_bool(resting[geometry].is_equal_approx(expected)).override_failure_message(bench_key).is_true()
		else:
			var proud := 0.5 if geometry in opened_by else ConsoleModel.PROUD_MM
			assert_bool(body.grow(proud * MM).encloses(resting[geometry])).override_failure_message(
				"%s sticks out at rest" % geometry.name).is_true()
	for part in openings:
		model.set(part.property, part.open)
	# In millimetres, as all that is crossed: in world units, a small triangle seems flat.
	var to_seat := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * model.seat().affine_inverse() \
		* model.global_transform.affine_inverse()
	var reach := LaunchAnimation.lift(model.approach(), medium) / MM
	var sized := AABB(medium.position / MM, medium.size / MM).grow(-0.5)
	var way := sized.merge(Transform3D(Basis(), model.approach() * reach) * sized)
	for geometry in opened_by:
		if not opened_by[geometry]:
			assert_bool(Fixtures.meets(_triangles(geometry, to_seat, way), way)).override_failure_message(
				"%s is in the way in once open" % geometry.name).is_false()
	for part in openings:
		model.set(part.property, part.rest)


## Every vertex of [param medium]'s model (filling [param box] on the seat, at its real size), brought
## half a millimetre into it, comes from the seat of [param model], its openings open, along its way
## in, as far as the placeholder lifts it, through none of the parts that never move but those it
## lies in, drawn solid ([param housings], their names): the console's body leaves its way in open.
func _assert_medium_clear(model: ConsoleModel, medium: Node3D, box: AABB, housings: Array) -> void:
	# Each point once, its faces' normals summed: brought in along them, a corner goes in from each face.
	var points: Dictionary[Vector3i, Vector3] = {}
	var normals: Dictionary[Vector3i, Vector3] = {}
	for part: MeshInstance3D in medium.find_children("*", "MeshInstance3D", false, false):
		var placed := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * part.transform
		var arrays := part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var faces: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var key := Vector3i((placed * vertices[i] * 100.0).round())
			points[key] = placed * vertices[i]
			normals[key] = normals.get(key, Vector3.ZERO) + (placed.basis * faces[i]).normalized()
	var openings := model.moving_parts().filter(func(part: MovingPart) -> bool:
		return part.role in [MovingPart.Role.OPENING, MovingPart.Role.FLAP])
	var still := _still(model).filter(func(geometry: MeshInstance3D) -> bool:
		return geometry.name not in housings)
	for part: MovingPart in openings:
		model.set(part.property, part.open)
	var axis := model.approach()
	var reach := axis * LaunchAnimation.lift(axis, box) / MM
	var sized := AABB(box.position / MM, box.size / MM)
	var to_seat := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * model.seat().affine_inverse() \
		* model.global_transform.affine_inverse()
	var walls := PackedVector3Array()
	var names := PackedStringArray()
	for geometry: MeshInstance3D in still:
		var found := _triangles(geometry, to_seat, sized.merge(Transform3D(Basis(), reach) * sized).grow(1.0))
		walls.append_array(found)
		for _corner in found:
			names.append(geometry.name)
	for part: MovingPart in openings:
		model.set(part.property, part.rest)
	# Each wall listed under the squares of a grid across the way in that it lies over: a point is
	# checked against those over its square only.
	var across := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
	var square := func(point: Vector3) -> Vector2i:
		return Vector2i(floori(point.dot(across) / _CELL_MM), floori(point.dot(axis.cross(across)) / _CELL_MM))
	var over: Dictionary[Vector2i, PackedInt32Array] = {}
	for i in range(0, walls.size(), 3):
		var low: Vector2i = square.call(walls[i])
		var high := low
		for corner: Vector3 in [walls[i + 1], walls[i + 2]]:
			var at: Vector2i = square.call(corner)
			low = low.min(at)
			high = high.max(at)
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				if not over.has(Vector2i(x, y)):
					over[Vector2i(x, y)] = PackedInt32Array()
				over[Vector2i(x, y)].append(i)
	for key in points:
		var from := points[key] - normals[key].normalized() * 0.5
		var near: PackedInt32Array = over.get(square.call(from), PackedInt32Array())
		for i in near:
			if Geometry3D.segment_intersects_triangle(from, from + reach, walls[i], walls[i + 1], walls[i + 2]) != null:
				assert_bool(false).override_failure_message("%s: %s goes through its %s from %s" % [model.name,
					medium.name, names[i], from]).is_true()
				return


## The meshes of [param model] that none of its moving parts moves.
static func _still(model: ConsoleModel) -> Array[MeshInstance3D]:
	var resting := _boxes(model)
	var still: Array[MeshInstance3D] = []
	still.assign(resting.keys())
	for part in model.moving_parts():
		model.set(part.property, part.open)
		for geometry in _moved(resting, _boxes(model)):
			still.erase(geometry)
		model.set(part.property, part.rest)
	return still


## The meshes whose box moved from [param resting] to [param moved].
static func _moved(resting: Dictionary[MeshInstance3D, AABB],
		moved: Dictionary[MeshInstance3D, AABB]) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	found.assign(resting.keys().filter(func(geometry: MeshInstance3D) -> bool:
		return not moved[geometry].is_equal_approx(resting[geometry])))
	return found


## Where each mesh of [param model] stands, in the model's space.
static func _boxes(model: ConsoleModel) -> Dictionary[MeshInstance3D, AABB]:
	var found: Dictionary[MeshInstance3D, AABB] = {}
	var to_model := model.global_transform.affine_inverse()
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		found[geometry] = to_model * geometry.global_transform * geometry.get_aabb()
	return found


## The corners of [param geometry]'s triangles, three by three, placed by [param to] from the world;
## only those of triangles meeting [param within], when given.
static func _triangles(geometry: MeshInstance3D, to: Transform3D, within := AABB()) -> PackedVector3Array:
	var found := PackedVector3Array()
	var placed := to * geometry.global_transform
	for surface in geometry.mesh.get_surface_count():
		for corners in Fixtures.triangles(geometry.mesh.surface_get_arrays(surface)):
			var triangle := placed * corners
			var box := AABB(triangle[0], Vector3.ZERO).expand(triangle[1]).expand(triangle[2])
			if within.size == Vector3.ZERO or within.intersects(box):
				found.append_array(triangle)
	return found
