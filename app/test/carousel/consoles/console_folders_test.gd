# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every console folder must hold to be shown and launched, whichever console it is.

## How a segment meets a wall: not at all, grazing its rim, or through it.
enum Meeting { CLEAR, GRAZED, CROSSED }

const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"
const MM := Fixtures.MM
const EPSILON := 0.0001


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
		var drawn := Fixtures.triangle_count(console)
		assert_int(drawn).override_failure_message("%s: %d triangles, over its budget of %d" % [
			manifest.scene, drawn, manifest.triangle_budget]).is_less_equal(manifest.triangle_budget)
		if manifest.launch:
			var steps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest.launch))
			assert_array(LaunchAnimation.problems(steps, console)).is_empty()
			assert_str(steps.get("model_hash", "")).override_failure_message(
				"%s: steps tuned on another model" % manifest.platform).is_equal(console.fingerprint())
		# A variant drawn from its base's glb differs by its material overrides alone, which an editor
		# save drops without the scene's [editable] line.
		for variant: ConsoleManifest in manifest.models().slice(1):
			var other: Node = auto_free((load(variant.scene) as PackedScene).instantiate())
			var shared := _glbs(console).filter(func(glb: String) -> bool: return glb in _glbs(other))
			assert_bool(shared.is_empty() or _materials(console) != _materials(other)).override_failure_message(
				"%s is drawn with %s's materials" % [variant.scene, manifest.scene]).is_true()
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
				console.moving.append(Fixtures.part(part, ConsolePart.Role.OPENING, 0.0, 1.0))
		var data := Fixtures.launch_steps(random)
		var named: Array[StringName] = []
		for step: Dictionary in data["steps"]:
			var parts: Dictionary = step.get("parts", {})
			for part: String in parts:
				if StringName(part) not in named:
					named.append(StringName(part))
		var lacking := named.filter(func(part: StringName) -> bool:
			return console.moving.all(func(moving: ConsolePart) -> bool: return moving.property != part))
		var problems := LaunchAnimation.problems(data, console)
		problems.sort()
		lacking.sort()
		assert_array(problems).is_equal(lacking)
		refused += 1 if not lacking.is_empty() else 0
	assert_int(refused).is_between(40, 160)


func test_a_console_s_fingerprint_changes_with_its_seat_any_moving_part_or_the_files_it_is_drawn_from() -> void:
	var random := Fixtures.cases(73)
	for manifest in ConsoleManifest.found():
		var shipped: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		var console: Fixtures.Console = auto_free(Fixtures.Console.new())
		console.shape = shipped.shape.duplicate()
		console.moving = Fixtures.moving_parts(random)
		var seen := {console.fingerprint(): true}
		var seat_changes := {&"seat_centre": Vector3.ONE, &"seat_degrees": Vector3.ONE, &"pivot": Vector3.ONE}
		for property: StringName in seat_changes:
			var value: Vector3 = console.shape.get(property)
			console.shape.set(property, value + seat_changes[property])
			seen[console.fingerprint()] = true
			console.shape.set(property, value)
		var carrier := console.shape.carrier
		console.shape.carrier = StringName(carrier + "_other")
		seen[console.fingerprint()] = true
		console.shape.carrier = carrier
		for part in console.moving:
			var changes := {&"property": &"other", &"role": (part.role + 1) % ConsolePart.Role.size(),
				&"rest": part.rest + 1.0, &"open": part.open + 1.0}
			for property: StringName in changes:
				var value: Variant = part.get(property)
				part.set(property, changes[property])
				seen[console.fingerprint()] = true
				part.set(property, value)
		assert_int(seen.size()).is_equal(5 + 4 * console.moving.size())
		assert_bool(console.fingerprint() in seen).is_true()
		# Drawn from other mesh files, it is another model.
		if not Fixtures.is_glb(shipped):
			var drawn := shipped.fingerprint()
			var meshes := shipped.find_children("*", "MeshInstance3D", true, false)
			(meshes[0] as MeshInstance3D).mesh = (meshes[1] as MeshInstance3D).mesh
			assert_str(shipped.fingerprint()).override_failure_message("%s: its meshes change silently"
				% manifest.platform).is_not_equal(drawn)


func test_the_contract_depends_on_the_seat_and_the_moving_parts_alone() -> void:
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


func test_every_console_stands_still_at_rest_on_the_consoles_screen_whether_its_steps_are_its_own_or_the_placeholder() -> void:
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		var steps := LaunchAnimation.read(manifest.launch, model) if manifest.launch \
			else LaunchAnimation.placeholder(model, AABB())
		var rest := ConsoleRow.Rest.of(steps)
		assert_bool(rest.sway_degrees == 0.0 and rest.bob_height == 0.0).override_failure_message(
			"%s floats" % ConsoleManifest.folder_of(manifest)).is_true()


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
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel.is_shown())).is_true()
		# What the appearance loaded, the one way a console's scene is: a scene loaded and freed again
		# would no longer be cached.
		assert_array(carousel._appearance._scenes.keys()).contains_exactly_in_any_order(consoles.keys())
		carousel.queue_free()
		await await_idle_frame()


func test_only_the_library_s_media_are_loaded_the_shown_shelf_s_made_with_their_launch_animations() -> void:
	var carousel := ScreenFixtures.carousel_for(self, ScreenFixtures.past_first_launch(self, {"snes": 2, "psx": 2}))
	add_child(carousel)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel.is_shown())).is_true()
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


## What the launch reads of [param console]: its parts, its seat, its way in and how it is presented.
static func _contract(console: ConsoleModel) -> Array:
	var parts := console.moving_parts().map(func(part: ConsolePart) -> Array:
		return [part.property, part.role, part.rest, part.open])
	return [parts, console.seat(), console.approach(), console.presented()]


## The glb files [param model] instances.
static func _glbs(model: Node) -> Array:
	return model.find_children("*", "", true, false).map(func(node: Node) -> String:
		return node.scene_file_path).filter(func(path: String) -> bool: return path.ends_with(".glb"))


## The material drawn on each surface of [param model], in tree order.
static func _materials(model: Node) -> Array:
	var drawn := []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.get_surface_override_material_count():
			drawn.append(mesh.get_active_material(surface))
	return drawn


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
	for place: ShelfPlace in carousel._row._places:
		assert_array(place._models.keys()).contains_exactly_in_any_order(models)
	var made := appearance._animations.keys()
	for medium: String in media[0]:
		appearance.animation_of(carousel._platforms[carousel._shelves[carousel._shelf].platform_id], medium)
	assert_array(appearance._animations.keys()).is_equal(made)


## The box of the default medium of [param platform]'s games, at its real size on the seat.
static func _default_medium_box(appearance: Appearance, platform: String) -> AABB:
	return appearance.medium_box(Fixtures.media(platform)[0], Fixtures.platform(platform).media)
