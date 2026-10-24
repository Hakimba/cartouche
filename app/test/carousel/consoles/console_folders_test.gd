# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every console folder must hold to be shown and launched, whichever console it is.

## The kinds of value a shape's dimension may be, and a step of each.
const _DIMENSION_TYPES: Array[int] = [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_BOOL]
const _ONE: Dictionary[int, Variant] = {TYPE_FLOAT: 1.0, TYPE_INT: 1, TYPE_VECTOR2: Vector2.ONE,
	TYPE_VECTOR3: Vector3.ONE}
const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"
const MM := Fixtures.MM
## Dimensions drawn per console, and of them, consoles built whole and moved: the first ones, and as
## many again of those drawn far from the shipped ones.
const SHAPES := 100
const MODELS := 12
const FAR_MODELS := 3
## A moving part's way from rest to fully moved, in this many straight steps; its points that go
## further than this many millimetres are followed along it.
const STEPS := 4
const SWING_MM := 5.0
## Points followed per mesh, at most.
const FOLLOWED := 64
## The least a moving part moves what it moves, fully moved: the Xbox's buttons, half a millimetre out
## of its front, go in 0.2 mm, still showing.
const SEEN_MM := 0.1
const SEEN_DEGREES := 1.0
## The shaders a console is drawn with: those [ModelFade] fades, and the clear plastic, which fades
## itself. Any other would be compiled on the spot the first time the console shows.
const CLEAR_PLASTIC := preload("res://carousel/models/clear_plastic.gdshader")
## A console's logo: printed with the label shader, sharp at more pixels a millimetre than a console is
## ever shown at (about five, the console come forward on a 1080p screen); a logo of the tests' own.
const LABEL := preload("res://carousel/models/label.gdshader")
const LOGO_PX_PER_MM := 8.0
const LOGO := preload("res://test/carousel/consoles/logo_test.svg")
## How far out of a logo's centre nothing of its console lies, and how near under it its face does,
## in millimetres.
const LOGO_CLEAR_MM := 20.0
const LOGO_ON_MM := 1.0
const EPSILON := 0.0001
## The least area, in square millimetres, of a face that is one.
const MIN_AREA_MM2 := 1.0e-6
## The parts of each console a seated medium lies in, drawn solid: its way in is open through the
## others.
const HOUSINGS: Dictionary[String, Array] = {
	"nes": [&"Upper", &"Lower", &"Throat"], "wii": [&"Front", &"Body", &"Light"],
	"gbc": [&"body"], "snes": [&"body"], "gba_sp": [&"body"], "ps2_fat": [&"body", &"tray"],
}
## How far from the rim of a wall a swept part may cross it and still only graze it, in millimetres: a flap
## hangs in its slot to a tenth of a millimetre by design, its edge level with the slot's rim.
const CONTACT_MM := 0.2
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
## How a segment meets a wall: not at all, grazing its rim, or through it.
enum Meeting { CLEAR, GRAZED, CROSSED }
## How many crossings of a wall each glb console's sweeps excuse as grazes, by platform, playing the placeholder
## and playing its own launch steps alike: the Super Nintendo's flaps, level with the slot's rim. A new one fails.
const GRAZES: Dictionary[String, int] = {"snes": 35}
## The side of the grid's squares a medium's way in is checked by, in millimetres.
const _CELL_MM := 4.0
## Each console's moving parts and what each does: a part dropped, added or given another role is
## a choice made here too.
const ROLES: Dictionary[String, Dictionary] = {
	"ps2_fat": {&"tray_mm": MovingPart.Role.OPENING, &"eject_mm": MovingPart.Role.PRESS,
		&"power_mm": MovingPart.Role.POWER_PRESS, &"light_energy": MovingPart.Role.LIGHT},
	"gba_sp": {&"lid_degrees": MovingPart.Role.POSE, &"power_mm": MovingPart.Role.POWER,
		&"light_energy": MovingPart.Role.LIGHT},
	"gb": {&"power_mm": MovingPart.Role.POWER, &"light_energy": MovingPart.Role.LIGHT},
	"gba": {&"power_mm": MovingPart.Role.POWER, &"light_energy": MovingPart.Role.LIGHT,
		&"shoulders_degrees": MovingPart.Role.POSE},
	"gbc": {&"power_mm": MovingPart.Role.POWER, &"light_energy": MovingPart.Role.LIGHT},
	"gc": {&"lid_degrees": MovingPart.Role.OPENING, &"power_mm": MovingPart.Role.POWER,
		&"open_mm": MovingPart.Role.PRESS, &"light_energy": MovingPart.Role.LIGHT},
	"n64": {&"flaps_degrees": MovingPart.Role.FLAP, &"power_mm": MovingPart.Role.POWER,
		&"reset_mm": MovingPart.Role.POSE, &"light_energy": MovingPart.Role.LIGHT},
	"nes": {&"door_degrees": MovingPart.Role.OPENING, &"tray_degrees": MovingPart.Role.OPENING,
		&"power_mm": MovingPart.Role.POWER, &"reset_mm": MovingPart.Role.POSE, &"light_energy": MovingPart.Role.LIGHT},
	"ps2_slim": {&"lid_degrees": MovingPart.Role.OPENING},
	"psx": {&"lid_degrees": MovingPart.Role.OPENING, &"open_mm": MovingPart.Role.PRESS,
		&"power_mm": MovingPart.Role.POWER, &"light_energy": MovingPart.Role.LIGHT},
	"snes": {&"flaps_degrees": MovingPart.Role.FLAP, &"eject_degrees": MovingPart.Role.POSE,
		&"power_mm": MovingPart.Role.POWER, &"reset_mm": MovingPart.Role.POSE},
	"wii": {&"light_energy": MovingPart.Role.LIGHT, &"power_mm": MovingPart.Role.POWER_PRESS,
		&"eject_mm": MovingPart.Role.POSE, &"door_degrees": MovingPart.Role.POSE},
	"xbox": {&"tray_mm": MovingPart.Role.OPENING, &"power_mm": MovingPart.Role.POWER_PRESS,
		&"eject_mm": MovingPart.Role.PRESS, &"light_energy": MovingPart.Role.LIGHT},
	"xbox360": {&"tray_mm": MovingPart.Role.OPENING, &"power_mm": MovingPart.Role.POWER_PRESS,
		&"eject_mm": MovingPart.Role.PRESS, &"light_energy": MovingPart.Role.LIGHT},
}
## Whether the placeholder has each role's parts moved at its start, once the game is chosen, once
## the medium is seated and at the black.
const PLACED: Dictionary[MovingPart.Role, Array] = {
	MovingPart.Role.OPENING: [false, true, true, false], MovingPart.Role.FLAP: [false, false, true, true],
	MovingPart.Role.PRESS: [false, false, false, false], MovingPart.Role.POSE: [false, false, false, false],
	MovingPart.Role.POWER: [false, false, false, true], MovingPart.Role.LIGHT: [false, false, false, true],
	MovingPart.Role.SPIN: [false, false, false, true], MovingPart.Role.POWER_PRESS: [false, false, false, false],
}


## The crossings of a wall the last sweeps excused as grazes.
var _grazes := 0

func test_INV_E10_01_every_console_folder_holds_a_manifest_the_app_can_show() -> void:
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


func test_every_console_moves_its_own_parts_each_in_its_role() -> void:
	var manifests := ConsoleManifest.found()
	assert_array(manifests.map(func(manifest: ConsoleManifest) -> String: return ConsoleManifest.folder_of(manifest))) \
		.contains_exactly_in_any_order(ROLES.keys())
	for manifest in manifests:
		var scene: PackedScene = load(manifest.scene)
		var console: ConsoleModel = auto_free(scene.instantiate())
		var roles := {}
		for part in console.moving_parts():
			roles[part.property] = part.role
		assert_dict(roles).override_failure_message("%s: %s" % [manifest.platform, roles]) \
			.is_equal(ROLES[ConsoleManifest.folder_of(manifest)])


func test_INV_E10_01_steps_moving_a_part_the_console_lacks_are_refused() -> void:
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


func test_INV_E10_01_a_console_s_fingerprint_changes_with_any_dimension_or_moving_part() -> void:
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


func test_INV_E10_02_a_console_built_from_any_dimensions_its_rules_accept_is_closed_and_its_moving_parts_fit() -> void:
	var appearance := Appearance.read(APPEARANCE)
	for manifest in ConsoleManifest.found():
		var folder := manifest.scene.get_base_dir()
		var shipped: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		var medium := _default_medium_box(appearance, manifest.platform)
		if _is_glb(shipped):
			# Its meshes are the glb's, not built from dimensions: the model as shipped is what holds.
			add_child(shipped)
			_assert_moving_parts_fit(shipped, medium)
			_grazes = 0
			_assert_nothing_passed_through(shipped, LaunchAnimation.placeholder(shipped, medium))
			_assert_grazes(manifest.platform)
			_assert_pressed_parts_show(shipped)
			_assert_logos(shipped, folder)
			continue
		var refused := 0
		var drawn := 0
		# Built whole and moved: the first shapes accepted, and those drawn far from the shipped one.
		var built := 0
		var built_far := 0
		# As many shapes again as it takes to build enough of those the rules accept.
		while drawn < SHAPES or ((built < MODELS or built_far < FAR_MODELS) and drawn < 10 * SHAPES):
			# Each shape of each folder drawn on its own: a folder or a part added changes no other's shapes.
			var random := Fixtures.cases(folder.get_file().hash() + drawn)
			drawn += 1
			var shape: ModelShape = shipped.shape.duplicate()
			var far := Fixtures.disturb(shape, random)
			if not shape.problems().is_empty():
				refused += 1
				for part in shape.parts():
					assert_array(shape.mesh_arrays(part, 32)).override_failure_message(
						"%s built though %s" % [part, shape.problems()]).is_empty()
				continue
			var whole := true
			for part in shape.parts():
				var meshes: Array[Array] = [shape.mesh_arrays(part, random.randi_range(16, 64))]
				var faces: Array[PackedVector3Array] = []
				if not meshes[0].is_empty():
					faces = Fixtures.triangles(meshes[0])
				whole = whole and not faces.is_empty()
				assert_array(faces).override_failure_message("%s: %s built nothing from %s" % [manifest.platform,
					part, shape.dimensions()]).is_not_empty()
				if faces.is_empty() or part in shape.surfaces():
					continue
				assert_array(Fixtures.open_edges(meshes)).override_failure_message(
					"%s: %s is open" % [manifest.platform, part]).is_empty()
				for volume in Fixtures.volumes(meshes):
					assert_float(volume).override_failure_message(
						"%s: %s turned inwards" % [manifest.platform, part]).is_greater(0.0)
			if whole and (built < MODELS or far and built_far < FAR_MODELS):
				built += 1
				built_far += 1 if far else 0
				var model := Fixtures.built(self, manifest.scene, shape)
				_assert_moving_parts_fit(model, medium)
				_assert_nothing_passed_through(model, LaunchAnimation.placeholder(model, medium))
				_assert_pressed_parts_show(model)
				_assert_logos(model, folder)
		assert_int(built).override_failure_message("%s: few accepted" % manifest.platform).is_greater_equal(MODELS)
		assert_int(refused).override_failure_message("%s: none refused" % manifest.platform).is_greater(0)
		assert_int(built_far).override_failure_message("%s: few drawn far accepted" % manifest.platform) \
			.is_greater_equal(FAR_MODELS)


func test_INV_E10_07_every_medium_a_console_s_platform_declares_comes_down_its_way_in_clear_of_its_parts() -> void:
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


func test_INV_E10_05_the_placeholder_brings_the_game_s_own_medium_from_its_own_length_away() -> void:
	var appearance := Appearance.read(APPEARANCE)
	# The NES as if it had no steps of its own. Cartridges slid in: a shorter one comes from nearer.
	var manifest: ConsoleManifest = appearance.console_of("nes").duplicate()
	manifest.launch = ""
	appearance._consoles["nes"] = manifest
	var console: ConsoleModel = auto_free(appearance.console("nes"))
	var lifts: Array[float] = []
	# Games of a medium with a folder, of one without and of none: the last two shown as their kind's.
	for medium: String in ["famicom_cart", "nes_cart", "master_cart", ""]:
		var animation := appearance.animation_of(Fixtures.platform("nes"), medium)
		var box := appearance.medium_box(medium, "cartridge")
		_assert_same_animation(animation, LaunchAnimation.placeholder(console, box))
		lifts.append(LaunchAnimation.lift(console.approach(), box))
	assert_float(lifts[0]).is_less(lifts[1])
	assert_float(lifts[2]).is_equal(lifts[3])
	assert_float(lifts[3]).is_equal(LaunchAnimation.lift(console.approach(), appearance.medium_box("gba_cart", "cartridge")))


func test_a_handheld_s_cartridge_comes_down_into_it_from_as_far_as_its_real_size_is_long() -> void:
	var appearance := Appearance.read(APPEARANCE)
	# How tall each cartridge really is, in millimetres (the Game Boy Advance's measured on photos
	# beside a Game Boy cartridge and a DS card, not the 35 often quoted).
	var heights: Dictionary[String, float] = {"gb": 65.5, "gbc": 65.5, "gba": 33.0}
	for platform in heights:
		var medium: String = Fixtures.media(platform)[0]
		var shown: Node3D = auto_free(appearance.model_of(medium, "cartridge").instantiate())
		# Larger in the row, to read as large as a disc.
		assert_float(shown.scale.y).is_greater(1.0)
		var box := appearance.medium_box(medium, "cartridge")
		assert_float(box.size.y / MM).is_equal_approx(heights[platform], 0.5)
		# The placeholder's, as if the console had no steps of its own.
		var manifest: ConsoleManifest = appearance.console_of(platform).duplicate()
		manifest.launch = ""
		appearance._consoles[platform] = manifest
		var console: ConsoleModel = auto_free(appearance.console(platform))
		_assert_same_animation(appearance.animation_of(Fixtures.platform(platform), medium), LaunchAnimation.placeholder(console, box))
		assert_float(LaunchAnimation.lift(console.approach(), box)).is_less(
			LaunchAnimation.lift(console.approach(), shown.transform * box))


func test_a_logo_is_a_sharp_image_upright_on_its_face_that_fades_with_its_console() -> void:
	var box := Rect2(-20.0, 5.0, 40.0, 10.0)
	var mesh := MeshBuilder.new()
	ShapeGeometry.decal(mesh, box, 3.0)
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.arrays())
	var logo := MeshInstance3D.new()
	logo.mesh = built
	var printed := ShaderMaterial.new()
	printed.shader = LABEL
	printed.set_shader_parameter(&"label_texture", LOGO)
	printed.set_shader_parameter(&"has_label", true)
	printed.set_shader_parameter(&"grain", 0.0)
	logo.set_surface_override_material(0, printed)
	var console: Node3D = auto_free(Node3D.new())
	console.add_child(logo)
	_assert_logo(logo, "the tests' logo")
	# The image's top left corner on the box's: upright, as drawn.
	var arrays := built.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in points.size():
		var at := Vector2(points[i].x, points[i].y) / MM
		var expected := Vector2((at.x - box.position.x) / box.size.x, (box.end.y - at.y) / box.size.y)
		assert_vector(uvs[i]).is_equal_approx(expected, Vector2.ONE * EPSILON)
		assert_float(points[i].z / MM).is_greater(3.0)
	var fade := ModelFade.new(console)
	fade.apply(0.5)
	var fading: ShaderMaterial = logo.get_active_material(0)
	assert_object(fading.shader).is_same(ModelFade.FADING[LABEL])
	assert_object(fading.get_shader_parameter(&"label_texture")).is_same(LOGO)


func test_INV_E10_02_every_console_s_logo_is_an_image_of_its_folder_drawn_as_its_tests_logo_is_facing_out() -> void:
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		add_child(model)
		_assert_logos(model, manifest.scene.get_base_dir())


func test_INV_E10_02_a_console_s_parts_are_placed_by_its_shape_no_node_but_a_moving_part_s_pivot_moved() -> void:
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var model: ConsoleModel = auto_free(scene.instantiate())
		# Its own nodes, not those of a scene it holds (the drive's spindle).
		var own := model.find_children("*", "Node3D", true, false).filter(func(node: Node) -> bool:
			return node.owner == model)
		# As the scene holds it: no node placed by hand, which its shape would not move.
		for node: Node3D in own:
			assert_bool(node.transform.is_equal_approx(Transform3D.IDENTITY)).override_failure_message(
				"%s: %s placed by hand" % [manifest.platform, model.get_path_to(node)]).is_true()
		# Ready, a part stands where its mesh was built, unless a moving part's pivot carries it.
		add_child(model)
		var resting := _boxes(model)
		var carried: Dictionary[MeshInstance3D, bool] = {}
		for part in model.moving_parts():
			model.set(part.property, part.open)
			for geometry in _moved(resting, _boxes(model)):
				carried[geometry] = true
			model.set(part.property, part.rest)
		for geometry: MeshInstance3D in own.filter(func(node: Node) -> bool: return node is MeshInstance3D):
			var placed := model.global_transform.affine_inverse() * geometry.global_transform
			assert_bool(placed.is_equal_approx(Transform3D.IDENTITY) or geometry in carried).override_failure_message(
				"%s: %s placed by its node" % [manifest.platform, model.get_path_to(geometry)]).is_true()


func test_INV_E10_02_every_moving_part_moves_a_part_of_its_console_and_a_pressed_one_goes_into_it() -> void:
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		add_child(model)
		var to_mm := _to_mm(model)
		var meshes: Array[MeshInstance3D] = []
		meshes.assign(model.find_children("*", "MeshInstance3D", true, false))
		var resting: Array[Transform3D] = []
		resting.assign(meshes.map(func(geometry: MeshInstance3D) -> Transform3D:
			return to_mm * geometry.global_transform))
		# Each part's meshes, by index, and how far each went.
		var moved_by: Dictionary[MovingPart, Dictionary] = {}
		for part in model.moving_parts():
			assert_float(part.open).override_failure_message("%s: %s never moves" % [manifest.platform,
				part.property]).is_not_equal(part.rest)
			if part.role == MovingPart.Role.LIGHT:
				continue
			model.set(part.property, part.open)
			var travels: Dictionary[int, Vector3] = {}
			for i in meshes.size():
				var now := to_mm * meshes[i].global_transform
				if _shifted(resting[i], now, meshes[i].get_aabb()):
					travels[i] = now.origin - resting[i].origin
			model.set(part.property, part.rest)
			assert_dict(travels).override_failure_message("%s: %s moves nothing" % [manifest.platform,
				part.property]).is_not_empty()
			moved_by[part] = travels
		var still := range(meshes.size()).filter(func(i: int) -> bool:
			return moved_by.values().all(func(travels: Dictionary) -> bool: return i not in travels))
		var reach := 0.0
		for box: AABB in _boxes(model).values():
			reach = maxf(reach, box.size.length() / MM)
		for part: MovingPart in moved_by:
			if part.role not in [MovingPart.Role.PRESS, MovingPart.Role.POWER_PRESS]:
				continue
			for i: int in moved_by[part]:
				var centre := resting[i] * meshes[i].get_aabb().get_center()
				var travel: Vector3 = moved_by[part][i]
				var inwards := centre + travel.normalized() * reach
				var walls := PackedVector3Array()
				for k: int in still:
					walls.append_array(_triangles(meshes[k], to_mm, AABB(centre, Vector3.ZERO).expand(inwards)))
				assert_bool(_crosses(centre, inwards, walls)).override_failure_message(
					"%s: %s pressed out of the console" % [manifest.platform, part.property]).is_true()


func test_a_console_s_parts_given_each_frame_are_moved_only_when_they_change() -> void:
	var probes: Dictionary[ConsoleModel, Array] = {}
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		add_child(model)
		probes[model] = []
		for geometry: Node in model.find_children("*", "MeshInstance3D", true, false):
			var probe := Fixtures.TransformProbe.new()
			geometry.add_child(probe)
			probes[model].append(probe)
	# Every part a third of the way, then given that again each frame, then a little further.
	for frame in 4:
		for model in probes:
			for probe: Fixtures.TransformProbe in probes[model]:
				probe.heard = 0
			for part in model.moving_parts():
				model.set(part.property, lerpf(part.rest, part.open, 0.6 if frame == 3 else 0.3))
		await await_idle_frame()
		for model in probes:
			if frame > 0:
				assert_int(_loudest(probes[model])).override_failure_message("%s, frame %d" % [model.name, frame]) \
					.is_equal(1 if frame == 3 else 0)


func test_every_console_is_drawn_within_its_triangle_budget() -> void:
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var model: ConsoleModel = auto_free(scene.instantiate())
		add_child(model)
		var triangles := 0
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in geometry.mesh.get_surface_count():
				var arrays := geometry.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += int((indices.size() if not indices.is_empty() else points.size()) / 3.0)
		assert_int(triangles).override_failure_message("%s: %d triangles" % [manifest.platform, triangles]) \
			.is_between(1, manifest.triangle_budget)


func test_a_crossing_is_a_graze_only_within_the_contact_of_a_rim_never_at_a_seam_but_a_sliver_is_excused_whole() -> void:
	# Two triangles making a quad, their seam its diagonal; its rim the four sides.
	var quad := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 10, 0), Vector3(0, 0, 0),
		Vector3(10, 10, 0), Vector3(0, 10, 0)])
	var rims := _rims(quad)
	assert_int(rims.size()).is_equal(8)
	var down := func(at: Vector3, depth: float) -> Meeting:
		return _crossing(at + Vector3(0, 0, 0.5), at - Vector3(0, 0, depth), quad, rims)
	# By a rim, within the contact, however deep; a millimetre in from it, or by the seam, a crossing.
	assert_int(down.call(Vector3(0.1, 4.0, 0.0), 1.0)).is_equal(Meeting.GRAZED)
	assert_int(down.call(Vector3(1.0, 4.0, 0.0), 0.1)).is_equal(Meeting.CROSSED)
	assert_int(down.call(Vector3(4.05, 4.0, 0.0), 1.0)).is_equal(Meeting.CROSSED)
	assert_int(down.call(Vector3(5.0, 4.0, 0.0), 0.1)).is_equal(Meeting.CROSSED)
	assert_int(_crossing(Vector3(0.1, 4.0, 0.5), Vector3(0.1, 4.0, -1.0), quad)).is_equal(Meeting.CROSSED)
	assert_int(_crossing(Vector3(1.0, 4.0, 0.5), Vector3(1.0, 4.0, 0.3), quad, rims)).is_equal(Meeting.CLEAR)
	# A wall narrower than twice the contact is all rim: a crossing anywhere in it is a graze, which is why the
	# sweeps count theirs.
	var sliver := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0.3, 0), Vector3(0, 0, 0),
		Vector3(10, 0.3, 0), Vector3(0, 0.3, 0)])
	assert_int(_crossing(Vector3(5, 0.15, 0.5), Vector3(5, 0.15, -2.0), sliver, _rims(sliver))).is_equal(Meeting.GRAZED)


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


func test_a_glb_console_s_fingerprint_covers_the_bytes_of_its_glb() -> void:
	var checked := 0
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		if not _is_glb(model):
			continue
		var glb := manifest.scene.get_base_dir().path_join("%s.glb" % manifest.scene.get_base_dir().get_file())
		var parts := model.moving_parts().map(func(part: MovingPart) -> Array:
			return [part.property, part.role, part.rest, part.open])
		assert_str(model.fingerprint()).is_equal(
			var_to_str([model.shape.dimensions(), parts, [FileAccess.get_sha256(glb)]]).sha256_text())
		checked += 1
	assert_int(checked).is_equal(5)


func test_a_glb_console_s_own_launch_steps_open_its_openings_fully_by_the_seat_and_sweep_clear_on_their_values() -> void:
	var played := 0
	for manifest in ConsoleManifest.found():
		var model := Fixtures.shown_console(self, manifest.scene)
		if not _is_glb(model):
			continue
		_grazes = 0
		var animation := LaunchAnimation.read(manifest.launch, model)
		var seated := LaunchAnimation.moment(animation, &"seated", -1.0)
		assert_float(seated).override_failure_message("%s: nothing seated" % manifest.platform).is_greater(0.0)
		for part in model.moving_parts():
			var track := animation.find_track(NodePath("Consoles/%s:%s" % [model.name, part.property]),
				Animation.TYPE_VALUE)
			var values := range(animation.track_get_key_count(track)).map(func(key: int) -> float:
				return animation.track_get_key_value(track, key))
			if part.role in [MovingPart.Role.OPENING, MovingPart.Role.FLAP]:
				assert_float(animation.value_track_interpolate(track, seated)).override_failure_message(
					"%s: %s not fully open by the seat" % [manifest.platform, part.property]) \
					.is_equal_approx(part.open, EPSILON)
			for other in model.moving_parts():
				model.set(other.property, other.rest)
			var low: float = values.min()
			var high: float = values.max()
			_assert_swept_clear(model, part, Vector2(low, high))
		for part in model.moving_parts():
			model.set(part.property, part.rest)
		_assert_grazes(manifest.platform)
		played += 1
	assert_int(played).is_equal(5)


func test_a_glb_console_fades_through_copies_and_never_touches_the_glb_s_own_materials() -> void:
	var faded := 0
	for manifest in ConsoleManifest.found():
		var model := Fixtures.shown_console(self, manifest.scene)
		if not _is_glb(model):
			continue
		var surfaces: Array[Array] = []
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in geometry.mesh.get_surface_count():
				surfaces.append([geometry, surface, geometry.get_active_material(surface)])
		model.fade(0.5)
		for each in surfaces:
			var geometry: MeshInstance3D = each[0]
			var own: Material = each[2]
			var surface: int = each[1]
			var drawn := geometry.get_active_material(surface)
			if own is BaseMaterial3D:
				var standard := drawn as BaseMaterial3D
				assert_float(standard.albedo_color.a).override_failure_message(
					"%s: %s does not fade" % [manifest.platform, geometry.name]).is_less(1.0)
				assert_int(standard.transparency).is_not_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
				assert_object(drawn).is_not_same(own)
				faded += 1
			else:
				assert_float(geometry.get_instance_shader_parameter(&"fade")).is_equal_approx(0.5, EPSILON)
			# The glb's own material, shared by every surface that has it, is never touched.
			assert_float((own as BaseMaterial3D).albedo_color.a if own is BaseMaterial3D else 1.0).is_equal(1.0)
		model.fade(0.0)
		for each in surfaces:
			var geometry: MeshInstance3D = each[0]
			var surface: int = each[1]
			assert_object(geometry.get_active_material(surface)).is_same(each[2])
	assert_int(faded).is_greater(10)


func test_INV_E12_M1_01_a_glb_console_s_meshes_never_fold_nor_degenerate_and_their_winding_agrees_with_their_normals() -> void:
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


func test_a_console_s_lights_show_on_what_it_is_drawn_with_lit_before_it_is_ready_or_after_faded_or_not() -> void:
	var lit := 0
	var declaring := 0
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var dark: ConsoleModel = auto_free(scene.instantiate())
		var console: ConsoleModel = auto_free(scene.instantiate())
		var lights := console.moving_parts().filter(func(part: MovingPart) -> bool:
			return part.role == MovingPart.Role.LIGHT)
		declaring += 1 if not lights.is_empty() else 0
		for part: MovingPart in lights:
			console.set(part.property, part.open)
		add_child(dark)
		add_child(console)
		# What lighting changes, on this console alone: another of its kind stays dark.
		var at_rest := _drawn(dark)
		var on := _drawn(console)
		var changed := on.keys().filter(func(key: String) -> bool: return on[key] != at_rest[key])
		assert_bool(lights.is_empty() or not changed.is_empty()).override_failure_message(
			"%s: its lights show on nothing" % manifest.platform).is_true()
		# On its light alone.
		var glows: Array = console._lights().map(func(light: MeshInstance3D) -> String: return "%s/" % light.name)
		assert_bool(changed.all(func(key: String) -> bool: return glows.any(key.begins_with))) \
			.override_failure_message("%s: %s lit" % [manifest.platform, changed]).is_true()
		console.fade(0.5)
		var faded_on := _drawn(console)
		for part: MovingPart in lights:
			console.set(part.property, part.rest)
		var faded_off := _drawn(console)
		console.fade(0.0)
		var off := _drawn(console)
		for key: String in changed:
			assert_str(var_to_str([faded_on[key], faded_off[key], off[key]])).override_failure_message(
				"%s: %s" % [manifest.platform, key]).is_equal(var_to_str([on[key], at_rest[key], at_rest[key]]))
		lit += 1 if not changed.is_empty() else 0
	assert_int(lit).is_equal(declaring)


func test_every_console_is_drawn_with_the_shaders_the_carousel_already_has_its_clear_plastic_clear() -> void:
	var shaders: Array[Shader] = [CLEAR_PLASTIC]
	shaders.append_array(ModelFade.FADING.keys())
	for manifest in ConsoleManifest.found():
		var scene: PackedScene = load(manifest.scene)
		var model: ConsoleModel = auto_free(scene.instantiate())
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			assert_object(geometry.material_overlay).is_null()
			for surface in geometry.mesh.get_surface_count():
				var material := geometry.get_active_material(surface)
				# A glb's atlas is a standard material, which [ModelFade] fades too; its light a shader of ours.
				var standard := _is_glb(model) and material is StandardMaterial3D
				assert_bool(standard or material is ShaderMaterial and (material as ShaderMaterial).shader in shaders) \
					.override_failure_message("%s: %s drawn with %s" % [manifest.platform, geometry.name, material]) \
					.is_true()
				# Clear plastic darkens a disc's rim, its vertices marked green: a console has none.
				if material is ShaderMaterial and (material as ShaderMaterial).shader == CLEAR_PLASTIC:
					var colours: PackedColorArray = geometry.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
					assert_bool(Array(colours).all(func(colour: Color) -> bool: return colour.g == 0.0)) \
						.override_failure_message("%s: %s drawn as a rim" % [manifest.platform, geometry.name]) \
						.is_true()


func test_INV_E10_03_a_console_without_steps_of_its_own_plays_the_placeholder() -> void:
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


func test_INV_E10_03_the_placeholder_opens_seats_closes_and_reaches_black_within_2_4_s() -> void:
	var random := Fixtures.cases(72)
	var roles: Dictionary[MovingPart.Role, int] = {}
	var turned := 0
	for i in 200:
		var console: Presented = auto_free(Presented.new())
		console.name = "Console"
		console.moving = Fixtures.moving_parts(random)
		# The first has a part of each role: how the roles follow one another is always checked.
		if i == 0:
			console.moving.assign(MovingPart.Role.values().map(func(role: MovingPart.Role) -> MovingPart:
				return MovingPart.new(StringName("part_%d" % role), role, 0.0, 1.0)))
		console.seated = Transform3D(_turn(random), Vector3.ZERO)
		console.way_in = _turn(random) * Vector3.BACK
		console.facing = _turn(random) if random.randf() < 0.5 else Basis()
		var medium := AABB(-Vector3(random.randf_range(0.01, 0.8), random.randf_range(0.01, 0.8),
			random.randf_range(0.01, 0.8)), Vector3(random.randf_range(0.02, 1.6), random.randf_range(0.02, 1.6),
			random.randf_range(0.02, 1.6)))
		var animation := LaunchAnimation.placeholder(console, medium)
		var launch := LaunchAnimation.moment(animation, &"launch")
		var seated := LaunchAnimation.moment(animation, &"seated", INF)
		var black := LaunchAnimation.moment(animation, &"black", INF)
		assert_float(black - launch).is_less_equal(2.4)
		assert_float(seated).is_between(launch, black)
		var games := LaunchAnimation.moment(animation, &"games")
		var times: Array[float] = [0.0, games, seated, black]
		var away := animation.find_track(^"Sequence:disc_away", Animation.TYPE_VALUE)
		var out_of_row := range(animation.track_get_key_count(away)).filter(func(key: int) -> bool:
			return animation.track_get_key_value(away, key) == 1.0)
		var first_out: int = out_of_row[0]
		var over := animation.track_get_key_time(away, first_out)
		for part in console.moving:
			var track := animation.find_track(NodePath("Consoles/Console:%s" % part.property), Animation.TYPE_VALUE)
			for k in times.size():
				var placed: bool = PLACED[part.role][k]
				assert_float(animation.value_track_interpolate(track, times[k])).override_failure_message(
					"role %d at %.2f s" % [part.role, times[k]]).is_equal_approx(
					part.open if placed else part.rest, EPSILON)
			# A press is let go before the game is chosen, once pressed as the console came forward; a
			# power press is let go before the black, once pressed after the medium is seated; a flap is
			# open once the medium is out of the row, over the seat; a pose never moves.
			var keys := range(animation.track_get_key_count(track))
			var value_at := func(key: int) -> float: return animation.track_get_key_value(track, key)
			var pressed := keys.filter(func(key: int) -> bool: return value_at.call(key) == part.open)
			var between: Dictionary[MovingPart.Role, Vector2] = {
				MovingPart.Role.PRESS: Vector2(LaunchAnimation.moment(animation, &"consoles"), games),
				MovingPart.Role.POWER_PRESS: Vector2(seated, black),
			}
			if part.role in between:
				assert_array(pressed).is_not_empty()
				for key: int in pressed:
					var time := animation.track_get_key_time(track, key)
					assert_bool(between[part.role].x < time and time < between[part.role].y).is_true()
			if part.role == MovingPart.Role.FLAP:
				assert_float(animation.value_track_interpolate(track, over)).is_equal_approx(part.open, EPSILON)
			if part.role == MovingPart.Role.POSE:
				assert_bool(keys.all(func(key: int) -> bool: return value_at.call(key) == part.rest)).is_true()
			roles[part.role] = roles.get(part.role, 0) + 1
		# A press is let go once an opening is first open; the openings are closed before the black, and
		# what comes on is on once they are.
		var openings := console.moving.filter(func(part: MovingPart) -> bool:
			return part.role == MovingPart.Role.OPENING)
		if not openings.is_empty():
			var track := animation.find_track(NodePath("Consoles/Console:%s" % openings[0].property),
				Animation.TYPE_VALUE)
			var keys := range(animation.track_get_key_count(track)).map(func(key: int) -> float:
				return animation.track_get_key_time(track, key))
			var opened: float = keys.filter(func(time: float) -> bool:
				return openings.any(func(part: MovingPart) -> bool:
					return _share(animation, part, time) >= 1.0 - EPSILON))[0]
			var closed: float = keys.filter(func(time: float) -> bool:
				return time > seated and openings.all(func(part: MovingPart) -> bool:
					return _share(animation, part, time) <= EPSILON))[0]
			assert_float(closed).is_less(black)
			for part in console.moving:
				if part.role == MovingPart.Role.PRESS:
					assert_float(_share(animation, part, opened)).override_failure_message(
						"a press held as the console opens").is_less_equal(EPSILON)
				elif part.role in [MovingPart.Role.POWER, MovingPart.Role.LIGHT, MovingPart.Role.SPIN]:
					assert_float(_share(animation, part, closed)).override_failure_message(
						"role %d not on once closed" % part.role).is_greater_equal(1.0 - EPSILON)
		# The medium comes from its own length, and more, away along the way in.
		var lift := animation.find_track(^"Sequence:disc_lift", Animation.TYPE_VALUE)
		var length := absf(medium.size.dot(console.way_in.abs()))
		assert_float(animation.value_track_interpolate(lift, launch)).is_greater(length)
		# The console stands as it is presented, once forward and on the consoles screen.
		var rotation := animation.find_track(^"Consoles:console_rotation", Animation.TYPE_VALUE)
		for at: float in [0.0, launch]:
			var stood: Vector3 = animation.value_track_interpolate(rotation, at)
			assert_bool(ConsoleRow._three_euler(stood).is_equal_approx(console.presented())).is_true()
		turned += 0 if console.facing == Basis() else 1
	for role: int in MovingPart.Role.values():
		assert_int(roles.get(role, 0)).is_greater(50)
	assert_int(turned).is_between(60, 140)


func test_INV_E10_03_a_console_is_presented_with_its_way_in_towards_the_camera_unless_it_says_otherwise() -> void:
	var random := Fixtures.cases(74)
	for i in 200:
		var console: Fixtures.Console = auto_free(Fixtures.Console.new())
		# Straight up, away from the camera and sideways first.
		var straight: Array[Vector3] = [Vector3.UP, Vector3.FORWARD, Vector3.LEFT]
		console.seated = Transform3D(_turn(random), Vector3.ZERO) if i >= straight.size() else Transform3D.IDENTITY
		console.way_in = _turn(random) * Vector3.BACK if i >= straight.size() else straight[i]
		var way_in := console.presented() * console.seated.basis * console.way_in
		assert_float(way_in.y).is_equal_approx(0.0, EPSILON)
		assert_float(way_in.z).is_greater_equal(-EPSILON)


func test_INV_E10_03_the_medium_comes_down_the_console_s_way_in_onto_its_seat() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var console := Fixtures.Console.new()
	console.name = "Leaning"
	console.seated = Transform3D(Basis.from_euler(Vector3(0.3, -0.5, 0.2)), Vector3(0.1, 0.2, -0.1))
	console.way_in = Vector3(0.6, -0.3, 0.74).normalized()
	var items: Array[ConsoleRow.Item] = [ConsoleRow.Item.new(console, ConsoleRow.Rest.new())]
	carousel._consoles.show_consoles(items, 0)
	var sequence := carousel._sequence
	sequence.use(LaunchAnimation.placeholder(console, AABB(Vector3(-0.6, -0.6, -0.01), Vector3(1.2, 1.2, 0.02))))
	var row := carousel._row
	var lifted := 0
	var seated := 0
	var t := 0.0
	while t < sequence.launch_duration():
		t += Fixtures.FRAME_S
		sequence.launch_at(t, Fixtures.FRAME_S)
		if sequence.disc_away < 1.0:
			continue
		row._process(0.0)
		var seat := console.global_transform * console.seat()
		var from_seat := row.global_transform * row.selected_stand().origin - seat.origin
		if sequence.disc_lift > 0.01:
			var way_in := (console.global_transform.basis * console.seated.basis * console.way_in).normalized()
			assert_float(from_seat.normalized().dot(way_in)).is_equal_approx(1.0, EPSILON)
			lifted += 1
		elif sequence.disc_lift == 0.0:
			assert_float(from_seat.length()).is_equal_approx(0.0, EPSILON)
			seated += 1
	assert_int(lifted).is_greater(5)
	assert_int(seated).is_greater(5)
	# The console replaced is freed at the end of the frame.
	await await_idle_frame()


func test_a_medium_moved_across_the_way_in_stays_as_far_along_it() -> void:
	var random := Fixtures.cases(75)
	var carousel := await Fixtures.shown_carousel(self)
	var console := Fixtures.Console.new()
	console.name = "Across"
	var items: Array[ConsoleRow.Item] = [ConsoleRow.Item.new(console, ConsoleRow.Rest.new())]
	carousel._consoles.show_consoles(items, 0)
	var sequence := carousel._sequence
	var row := carousel._row
	for i in 40:
		console.seated = Transform3D(_turn(random), Vector3.ZERO)
		console.way_in = [Vector3.BACK, Vector3.UP, Vector3.FORWARD, Vector3.LEFT][i % 4] if i < 20 \
			else _turn(random) * Vector3.BACK
		var lift := random.randf_range(0.0, 10.0)
		var across := Vector2(random.randf_range(-5.0, 5.0), random.randf_range(-5.0, 5.0))
		sequence.use(LaunchAnimation.build({"choice": 1, "steps": [{}, {"dur": 0.1},
			{"dur": 0.1, "disc": {"inRow": 0.0, "lift": lift, "dx": across.x, "dy": across.y}}]}, console))
		sequence.launch_at(1.0, Fixtures.FRAME_S)
		row._process(0.0)
		var seat := console.global_transform * console.seat()
		var from_seat := seat.basis.inverse() * (row.global_transform * row.selected_stand().origin - seat.origin)
		var along := from_seat.dot(console.way_in)
		assert_float(along).is_equal_approx(lift / 10.0, EPSILON)
		assert_float((from_seat - console.way_in * along).length()).is_equal_approx(across.length() / 10.0, EPSILON)
	await await_idle_frame()


func test_INV_E10_04_only_the_consoles_of_the_library_are_loaded() -> void:
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


func test_INV_E10_04_only_the_library_s_media_are_loaded_the_shown_shelf_s_made_with_their_launch_animations() -> void:
	var carousel := ScreenFixtures.carousel_for(self, ScreenFixtures.past_first_launch(self, {"snes": 2, "psx": 2}))
	add_child(carousel)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	# Not the cartridge nor the disc their kinds fall back to.
	assert_array(carousel._appearance._models.keys()).contains_exactly_in_any_order(["snes_pal_cart", "ps1_cd"])
	_assert_shown_shelf_made(carousel, [["snes_pal_cart"]])
	# A game of the PlayStation's on a PS2 disc: both made as its shelf shows, the other shelf's kept.
	var library: AndroidServices.Library = carousel._screens.library
	library.shelves[1].games[1].medium = "ps2_dvd"
	carousel._show_library(library, "psx")
	_assert_shown_shelf_made(carousel, [["ps1_cd", "ps2_dvd"], ["snes_pal_cart"]])
	# Gone from the library, the other shelf's medium is freed.
	library.shelves.remove_at(0)
	carousel._show_library(library)
	_assert_shown_shelf_made(carousel, [["ps1_cd", "ps2_dvd"]])
	carousel.queue_free()
	await await_idle_frame()


func test_INV_E10_05_a_console_s_own_steps_are_read_once_for_every_medium() -> void:
	var appearance := Appearance.read(APPEARANCE)
	var ps2 := Fixtures.platform("ps2")
	assert_str(appearance.console_of("ps2").launch).is_not_empty()
	var animation := appearance.animation_of(ps2, "ps2_dvd")
	for medium: String in ["ps1_cd", ""]:
		assert_object(appearance.animation_of(ps2, medium)).is_same(animation)


func test_a_version_is_a_model_code_in_lower_case_its_words_joined_by_hyphens() -> void:
	var manifest: ConsoleManifest = ConsoleManifest.found()[0].duplicate()
	for version: StringName in [&"dol-001", &"scph-70004", &"original"]:
		manifest.version = version
		assert_array(manifest.problems()).is_empty()
	for version: StringName in [&"", &"dol_001", &"DOL-001", &"dol 001", &"-dol", &"dol-", &"dol--001"]:
		manifest.version = version
		assert_array(manifest.problems()).override_failure_message(version).is_equal([&"version_a_model_code"])


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


## How far [param part] of the console named `Console` is moved at [param time] of [param animation],
## from 0 at rest to 1 fully moved.
static func _share(animation: Animation, part: MovingPart, time: float) -> float:
	var track := animation.find_track(NodePath("Consoles/Console:%s" % part.property), Animation.TYPE_VALUE)
	var value: float = animation.value_track_interpolate(track, time)
	return inverse_lerp(part.rest, part.open, value)


static func _turn(random: RandomNumberGenerator) -> Basis:
	return Basis.from_euler(Vector3(random.randf_range(-PI, PI), random.randf_range(-PI, PI), random.randf_range(-PI, PI)))


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


## Each shader parameter of what [param model] is drawn with now, by mesh, surface and name.
static func _drawn(model: ConsoleModel) -> Dictionary[String, Variant]:
	var found: Dictionary[String, Variant] = {}
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in geometry.mesh.get_surface_count():
			var material := geometry.get_active_material(surface) as ShaderMaterial
			if not material:
				continue
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				var parameter: String = uniform["name"]
				found["%s/%d/%s" % [geometry.name, surface, parameter]] = material.get_shader_parameter(parameter)
	return found


## Each logo of [param model] is one of the images of its [param folder], each of them shown, drawn as
## [method _assert_logo] has it: on a face of the console, facing out of it, nothing that moves with
## it over it (a door may hide it).
func _assert_logos(model: ConsoleModel, folder: String) -> void:
	var to_mm := _to_mm(model)
	var parts := model.moving_parts()
	var resting := _boxes(model)
	# The parts that move each mesh.
	var movers: Dictionary[MeshInstance3D, Array] = {}
	for geometry in resting:
		movers[geometry] = []
	for part in parts:
		model.set(part.property, part.open)
		for geometry in _moved(resting, _boxes(model)):
			movers[geometry].append(part.property)
		model.set(part.property, part.rest)
	var images := {}
	for logo: MeshInstance3D in resting:
		# Printed with the label shader, as a grained surface is too, a logo shows its image.
		var printed := logo.get_active_material(0) as ShaderMaterial
		if not printed or printed.shader != LABEL or not printed.get_shader_parameter(&"has_label"):
			continue
		_assert_logo(logo, folder)
		var image: Texture2D = printed.get_shader_parameter(&"label_texture")
		images[image.resource_path] = true
		# From the middle of a triangle of its face.
		var placed := to_mm * logo.global_transform
		var corners: PackedVector3Array = placed * Fixtures.triangles(logo.mesh.surface_get_arrays(0))[0]
		var centre := (corners[0] + corners[1] + corners[2]) / 3.0
		var normals: PackedVector3Array = logo.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var normal := (placed.basis * normals[0]).normalized()
		var over := centre + normal * LOGO_CLEAR_MM
		var under := centre - normal * LOGO_ON_MM
		var walls := PackedVector3Array()
		for geometry in resting:
			if geometry != logo and movers[geometry] == movers[logo]:
				walls.append_array(_triangles(geometry, to_mm, AABB(under, Vector3.ZERO).expand(over)))
		assert_bool(_crosses(centre, over, walls)).override_failure_message(
			"%s: %s faces into the console" % [folder, logo.name]).is_false()
		assert_bool(_crosses(centre, under, walls)).override_failure_message(
			"%s: %s lies on no face" % [folder, logo.name]).is_true()
	var files := Array(ResourceLoader.list_directory(folder)).filter(func(file: String) -> bool:
		return file.get_extension() == "svg")
	assert_array(images.keys()).override_failure_message("%s: its logos" % folder) \
		.contains_exactly_in_any_order(files.map(func(file: String) -> String: return folder.path_join(file)))


## [param logo] prints its image whole on its face, flat, with its mipmaps, at
## [constant LOGO_PX_PER_MM] at least each way, not mirrored.
func _assert_logo(logo: MeshInstance3D, console: String) -> void:
	var printed: ShaderMaterial = logo.get_active_material(0)
	var image: Texture2D = printed.get_shader_parameter(&"label_texture")
	assert_object(image).override_failure_message("%s: a logo without its image" % console).is_not_null()
	if image == null:
		return
	assert_float(printed.get_shader_parameter(&"grain")).override_failure_message(
		"%s: %s not printed flat" % [console, logo.name]).is_equal(0.0)
	assert_bool(image.get_image().has_mipmaps()).override_failure_message(
		"%s: %s blurs and shimmers without its mipmaps" % [console, logo.name]).is_true()
	var arrays := logo.mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var square := Rect2(uvs[0], Vector2.ZERO)
	for uv in uvs:
		square = square.expand(uv)
	assert_bool(square.is_equal_approx(Rect2(0.0, 0.0, 1.0, 1.0))).override_failure_message(
		"%s: %s shows part of its image" % [console, logo.name]).is_true()
	# Its millimetres along the image's width (U) and height (V), from a triangle of its face.
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var along: Array[Vector3] = [points[corners[1]] - points[corners[0]], points[corners[2]] - points[corners[0]]]
	var turn := Transform2D(uvs[corners[1]] - uvs[corners[0]], uvs[corners[2]] - uvs[corners[0]], Vector2.ZERO) \
		.affine_inverse()
	var per_u := (along[0] * turn.x.x + along[1] * turn.x.y) / MM
	var per_v := (along[0] * turn.y.x + along[1] * turn.y.y) / MM
	assert_float(minf(image.get_width() / per_u.length(), image.get_height() / per_v.length())) \
		.override_failure_message("%s: %s not sharp" % [console, logo.name]).is_greater_equal(LOGO_PX_PER_MM)
	# Seen from the side it faces, the image's width runs to the right of its height, which runs down.
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_float(per_u.cross(per_v).dot(normals[corners[0]])).override_failure_message(
		"%s: %s mirrored" % [console, logo.name]).is_less(0.0)


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


## Each part of [param model] moving through all [param placeholder] moves it, its rebound included,
## the others as the placeholder holds them at each step it moves in; a part only a console's own
## steps move, from rest to fully moved, the others at rest. Its points that go further than
## [constant SWING_MM] cross none of the parts it does not move on their way.
func _assert_nothing_passed_through(model: ConsoleModel, placeholder: Animation) -> void:
	var parts := model.moving_parts()
	for part in parts:
		var track := placeholder.find_track(NodePath("Consoles/%s:%s" % [model.name, part.property]),
			Animation.TYPE_VALUE)
		var values := range(placeholder.track_get_key_count(track)).map(func(key: int) -> float:
			return placeholder.track_get_key_value(track, key))
		var low: float = values.min()
		var high: float = values.max()
		var steps := range(1, LaunchAnimation._PLACEHOLDER.size()).filter(func(step: int) -> bool:
			return LaunchAnimation._moved(part.role, step) != LaunchAnimation._moved(part.role, step - 1))
		for step: int in steps if not steps.is_empty() else [-1]:
			for other in parts:
				var held := step >= 0 and LaunchAnimation._moved(other.role, step)
				model.set(other.property, other.open if held else other.rest)
			_assert_swept_clear(model, part, Vector2(low, high) if step >= 0 else Vector2(part.rest, part.open))
	for part in parts:
		model.set(part.property, part.rest)


func _assert_grazes(platform: String) -> void:
	assert_int(_grazes).override_failure_message("%s: %d grazes" % [platform, _grazes]).is_equal(GRAZES.get(platform, 0))
	_grazes = 0


## Moving [param part] of [param model] across [param span], the points of what it moves that go
## further than [constant SWING_MM] (the vertices of a glb's meshes, all of them, else a sample) cross none of the
## parts it does not move on their way, but for grazes, counted in `_grazes`.
func _assert_swept_clear(model: ConsoleModel, part: MovingPart, span: Vector2) -> void:
	var to_mm := _to_mm(model)
	model.set(part.property, span.x)
	var start := _boxes(model)
	model.set(part.property, span.y)
	var moved := _moved(start, _boxes(model))
	if moved.is_empty():
		return
	var ways: Array[PackedVector3Array] = []
	for step in STEPS + 1:
		model.set(part.property, lerpf(span.x, span.y, float(step) / STEPS))
		var points := PackedVector3Array()
		for geometry in moved:
			var vertices: PackedVector3Array = geometry.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var placed := to_mm * geometry.global_transform
			# Every vertex of a glb's meshes, a sample of those built from a shape.
			var every := 1 if _is_glb(model) else ceili(vertices.size() / float(FOLLOWED))
			for i in range(0, vertices.size(), every):
				points.append(placed * vertices[i])
		ways.append(points)
	var reached := Fixtures.bounds(ways[0])
	for points in ways:
		reached = reached.merge(Fixtures.bounds(points))
	var walls := PackedVector3Array()
	for geometry in start:
		if geometry not in moved:
			walls.append_array(_triangles(geometry, to_mm, reached.grow(1.0)))
	var rims := _rims(walls)
	for i in ways[0].size():
		if ways[0][i].distance_to(ways[-1][i]) < SWING_MM:
			continue
		for step in STEPS:
			var met := _crossing(ways[step][i], ways[step + 1][i], walls, rims)
			_grazes += 1 if met == Meeting.GRAZED else 0
			assert_bool(met == Meeting.CROSSED).override_failure_message(
				"%s passes through the console at %s, step %d" % [part.property, ways[step][i], step]).is_false()


## Fully moved, each part pressed or slid without turning (a press, a power press, a power part, a
## pose) keeps its outermost point, the way it came from, outside every part that does not move and
## that it was outside of at rest: nothing of them lies beyond it that way. A pressed button still
## shows.
func _assert_pressed_parts_show(model: ConsoleModel) -> void:
	var to_mm := _to_mm(model)
	var resting := _boxes(model)
	var moved_by: Dictionary[MovingPart, Array] = {}
	var moving: Dictionary[MeshInstance3D, bool] = {}
	for part in model.moving_parts():
		model.set(part.property, part.open)
		moved_by[part] = _moved(resting, _boxes(model))
		for geometry: MeshInstance3D in moved_by[part]:
			moving[geometry] = true
		model.set(part.property, part.rest)
	var still := resting.keys().filter(func(geometry: MeshInstance3D) -> bool: return geometry not in moving)
	var reach := 0.0
	for geometry: MeshInstance3D in resting:
		reach = maxf(reach, resting[geometry].size.length() / MM)
	var pressed := [MovingPart.Role.PRESS, MovingPart.Role.POWER_PRESS, MovingPart.Role.POWER, MovingPart.Role.POSE]
	for part: MovingPart in moved_by:
		if part.role not in pressed:
			continue
		for geometry: MeshInstance3D in moved_by[part]:
			var at_rest := to_mm * geometry.global_transform
			model.set(part.property, part.open)
			var moved := to_mm * geometry.global_transform
			model.set(part.property, part.rest)
			var travel := moved.origin - at_rest.origin
			if not moved.basis.is_equal_approx(at_rest.basis) or travel.length() < EPSILON:
				continue
			var out := -travel.normalized()
			var vertices: PackedVector3Array = geometry.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var outermost := at_rest * vertices[0]
			for vertex in vertices:
				if (at_rest * vertex).dot(out) > outermost.dot(out):
					outermost = at_rest * vertex
			# Outside by what a pressed button shows at least: flush with a face is in it.
			outermost -= out * (ConsoleModel.PRESSED_SHOWS_MM - EPSILON)
			var swept := AABB(outermost, Vector3.ZERO).expand(outermost + travel).expand(outermost + out * reach)
			for other: MeshInstance3D in still:
				var walls := _triangles(other, to_mm, swept.grow(1.0))
				if not _crosses(outermost, outermost + out * reach, walls):
					assert_bool(_crosses(outermost + travel, outermost + travel + out * reach, walls)) \
						.override_failure_message("%s: %s sinks into %s" % [part.property, geometry.name, other.name]) \
						.is_false()


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


## The most transforms one of [param probes] heard.
static func _loudest(probes: Array) -> int:
	var most := 0
	for probe: Fixtures.TransformProbe in probes:
		most = maxi(most, probe.heard)
	return most


## From the world to [param model]'s space, in millimetres: what is crossed is checked there, as a
## small triangle in world units seems flat.
static func _to_mm(model: ConsoleModel) -> Transform3D:
	return Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * model.global_transform.affine_inverse()


## Whether a mesh filling [param box] placed at [param rest], then at [param now], moved as far as can
## be seen: [constant SEEN_MM] or [constant SEEN_DEGREES].
static func _shifted(rest: Transform3D, now: Transform3D, box: AABB) -> bool:
	return (rest.basis.inverse() * now.basis).get_rotation_quaternion().get_angle() >= deg_to_rad(SEEN_DEGREES) \
		or range(8).any(func(corner: int) -> bool:
			return (now * box.get_endpoint(corner)).distance_to(rest * box.get_endpoint(corner)) >= SEEN_MM)


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


## The edges of [param corners]' triangles that only one of them has, as their two ends: the rims of the walls,
## where a surface stops.
static func _rims(corners: PackedVector3Array) -> PackedVector3Array:
	var edges: Dictionary[String, PackedVector3Array] = {}
	var uses: Dictionary[String, int] = {}
	for i in range(0, corners.size(), 3):
		for k in 3:
			var ends := [corners[i + k], corners[i + (k + 1) % 3]]
			var keys := ends.map(func(end: Vector3) -> String: return str(Vector3i((end * 1000.0).round())))
			keys.sort()
			var key := "%s %s" % keys
			uses[key] = uses.get(key, 0) + 1
			edges[key] = PackedVector3Array(ends)
	var found := PackedVector3Array()
	for key in edges:
		if uses[key] == 1:
			found.append_array(edges[key])
	return found


## How the segment from [param from] to [param to] meets a triangle of [param corners]: not at all, as a graze
## (every crossing within [constant CONTACT_MM] of one of [param rims], a part sliding by the edge where a surface
## stops: a wall narrower than twice that is excused whole, so the sweeps count their grazes and the tests pin each
## console's count), or through a surface (a seam inside it, or the middle of a wide wall).
static func _crossing(from: Vector3, to: Vector3, corners: PackedVector3Array,
		rims := PackedVector3Array()) -> Meeting:
	var met := Meeting.CLEAR
	for i in range(0, corners.size(), 3):
		var found: Variant = Geometry3D.segment_intersects_triangle(from, to, corners[i], corners[i + 1], corners[i + 2])
		if found == null:
			continue
		var at: Vector3 = found
		var grazes := false
		for r in range(0, rims.size(), 2):
			grazes = grazes or at.distance_to(Geometry3D.get_closest_point_to_segment(at, rims[r], rims[r + 1])) <= CONTACT_MM
		if not grazes:
			return Meeting.CROSSED
		met = Meeting.GRAZED
	return met


## Whether the segment from [param from] to [param to] goes through a triangle of [param corners] (see
## [method _crossing]).
static func _crosses(from: Vector3, to: Vector3, corners: PackedVector3Array, rims := PackedVector3Array()) -> bool:
	return _crossing(from, to, corners, rims) == Meeting.CROSSED


## A console of the tests whose way of being presented is given.
class Presented extends Fixtures.Console:
	var facing := Basis()

	func presented() -> Basis:
		return facing
