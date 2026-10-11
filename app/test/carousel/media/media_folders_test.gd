# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every medium folder must hold to be shown, whichever medium it is.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"
const MM := MeshBuilder.UNITS_PER_MM
## Dimensions drawn per medium at least, and of them, media built whole.
const SHAPES := 60
const MODELS := 12
const EPSILON := 0.001
## A black plastic's colour is darker than this; gold's hue lies between these, in degrees.
const DARK := 0.15
## A silver disc's mirror is lighter than this.
const SILVER := 0.7
const GOLD_HUE := Vector2(25.0, 50.0)
## The media a console's platform declares whose folder is still to be made: each folder made takes
## its medium off.
const AWAITING: Array[String] = [
]
## The media made for a later stage, which shows a console's regional cartridges: no platform's games
## come in them yet, though the fronts of their scans may be declared already.
const LATER: Array[String] = ["famicom_cart", "sfc_cart", "snes_us_cart"]
## How far a cartridge's label face may be from the proportions of the labels cut for it.
const LABEL_SHAPE := 0.02
## Fronts whose scans are of another shape than their model's front: their crop is not the model's.
const UNLIKE_THEIR_MODEL: Array[String] = ["snes_pal_cart"]
## How far, as a fraction of its cartridge, a label crop's edge may be from its model's label.
const CROP_EDGE := 0.005
## Each medium's real width, height and thickness in millimetres, as sourced or measured, and how
## far its model may be from them: the reliefs proud of a body measured without them.
const REAL_SIZES: Dictionary[String, Vector3] = {
	"nes_cart": Vector3(119.0, 133.0, 19.0), "famicom_cart": Vector3(108.0, 71.0, 17.0),
	"snes_pal_cart": Vector3(128.0, 87.0, 20.0), "sfc_cart": Vector3(128.0, 87.0, 20.0),
	"snes_us_cart": Vector3(136.0, 88.0, 20.0), "n64_cart": Vector3(116.0, 76.6, 18.5),
	"gb_cart": Vector3(58.0, 65.5, 7.5), "gbc_cart": Vector3(58.0, 65.5, 7.5), "gba_cart": Vector3(57.5, 33.0, 7.9),
	"ps1_cd": Vector3(120.0, 120.0, 1.2), "ps2_dvd": Vector3(120.0, 120.0, 1.2), "wii_dvd": Vector3(120.0, 120.0, 1.2),
	"xbox_dvd": Vector3(120.0, 120.0, 1.2), "xbox360_dvd": Vector3(120.0, 120.0, 1.2),
	"gc_mini_dvd": Vector3(80.0, 80.0, 1.2),
}
const REAL_SIZE_MM := 0.7


func test_INV_E10_07_every_medium_folder_holds_a_manifest_the_app_can_show_of_its_platforms_kind() -> void:
	var insertions: Dictionary = _json(APPEARANCE)["insertions"]
	var profiles: Dictionary = _json(PROFILES)
	var found := MediumManifest.found()
	assert_array(found.keys()).contains(["ps2_dvd", "gc_mini_dvd", "gba_cart"])
	for medium in found:
		var manifest := found[medium]
		assert_array(manifest.problems()).override_failure_message("%s: %s" % [medium, manifest.problems()]).is_empty()
		assert_bool(insertions.has(manifest.media)).override_failure_message("%s: no kind %s" % [
			medium, manifest.media]).is_true()
		var showing := 0
		for platform: String in profiles:
			if medium in Fixtures.media(platform) or medium in _fronts(platform):
				showing += 1 if medium in Fixtures.media(platform) else 0
				assert_str(Fixtures.platform(platform).media).override_failure_message(
					"%s declared by %s, of another kind" % [medium, platform]).is_equal(manifest.media)
		assert_bool((showing > 0) != (medium in LATER)).override_failure_message("%s: %s" % [medium,
			"shown by a platform, still listed for later" if showing else "shown by no platform"]).is_true()
		var model: Node3D = auto_free((load(manifest.scene) as PackedScene).instantiate())
		var label: MeshInstance3D = model.get_node_or_null(^"Label")
		assert_bool(label != null and label.mesh is ShapedMesh).override_failure_message(
			"%s: no label built from its shape" % medium).is_true()


func test_INV_E10_05_every_medium_a_console_s_platform_declares_has_its_folder_the_others_show_their_kind_s() -> void:
	var appearance := Appearance.read(APPEARANCE)
	var found := MediumManifest.found()
	var kind_media: Dictionary = _json(APPEARANCE)["kind_media"]
	for console in ConsoleManifest.found():
		for medium in Fixtures.media(console.platform):
			assert_bool((medium in found) != (medium in AWAITING)).override_failure_message(
				"%s: %s" % [medium, "made, still awaited" if medium in found else "no folder"]).is_true()
	# A medium with a folder is shown from it as its own kind, taken for another as that kind's; each
	# kind falls back to one of its own.
	for medium in found:
		for media: String in kind_media:
			var own: String = medium if found[medium].media == media else kind_media[media]
			assert_str(appearance.model_of(medium, media).resource_path).is_equal(found[own].scene)
	for media: String in kind_media:
		assert_str(found[kind_media[media]].media).is_equal(media)
	var profiles: Dictionary = _json(PROFILES)
	for platform: String in profiles:
		var media := Fixtures.platform(platform).media
		for medium: String in Fixtures.media(platform) + [""]:
			var shown: String = medium if medium in found else kind_media[media]
			assert_str(appearance.model_of(medium, media).resource_path).override_failure_message(
				"%s of %s" % [medium, platform]).is_equal(found[shown].scene)


func test_INV_E10_07_a_medium_built_from_any_dimensions_its_rules_accept_is_closed_its_label_on_it() -> void:
	for medium in MediumManifest.found():
		var shipped := Fixtures.medium_shape(medium)
		assert_array(shipped.parts()).contains([&"label"])
		assert_array(shipped.problems()).override_failure_message("%s: its own dimensions refused: %s" % [medium,
			shipped.problems()]).is_empty()
		var refused := 0
		var built := 0
		var drawn := 0
		while drawn < SHAPES or built < MODELS and drawn < 10 * SHAPES:
			# Each medium's shapes drawn on their own: a folder added changes no other's shapes.
			var random := Fixtures.cases(medium.hash() + drawn)
			drawn += 1
			var shape: ModelShape = shipped.duplicate()
			Fixtures.disturb(shape, random)
			if not shape.problems().is_empty():
				refused += 1
				for part in shape.parts():
					assert_array(shape.mesh_arrays(part, 32)).override_failure_message(
						"%s: %s built though %s" % [medium, part, shape.problems()]).is_empty()
				continue
			built += 1
			var detail := random.randi_range(16, 64)
			var meshes: Array[Array] = []
			for part in shape.parts():
				meshes.append(shape.mesh_arrays(part, detail))
				assert_array(meshes[-1]).override_failure_message("%s: %s built nothing from %s" % [
					medium, part, shape.dimensions()]).is_not_empty()
			if is_failure():
				return
			assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s is open: %s" % [
				medium, shape.dimensions()]).is_empty()
			for volume in Fixtures.volumes(meshes):
				assert_float(volume).override_failure_message("%s turned inwards" % medium).is_greater(0.0)
			_assert_label_on(medium, shape, meshes)
			if is_failure():
				return
		assert_int(built).override_failure_message("%s: few accepted" % medium).is_greater_equal(MODELS)
		assert_int(refused).override_failure_message("%s: none refused" % medium).is_greater(0)


func test_INV_E10_06_every_medium_s_label_face_has_the_proportions_of_the_labels_cut_for_it() -> void:
	var found := MediumManifest.found()
	var checked: Array[String] = []
	var uncropped: Array[String] = []
	for platform: String in _json(PROFILES):
		var fronts := _fronts(platform)
		for medium: String in fronts:
			var front: Dictionary = fronts[medium]
			var crop: Dictionary = front["label"]
			# A scan's label is cut at the crop's fractions of a front of the front's proportion.
			var cut: float = crop["width"] * front["proportion"] / crop["height"]
			assert_float(_face(found[medium]) / cut - 1.0).override_failure_message("%s: its label face %.3f, its labels %.3f" % [
				medium, _face(found[medium]), cut]).is_between(-LABEL_SHAPE, LABEL_SHAPE)
			# A scan of the model's shape shows the label where the model has it.
			var place := _label_place(found[medium])
			var proportion: float = front["proportion"]
			if absf(proportion / place.proportion - 1.0) > LABEL_SHAPE:
				uncropped.append(medium)
			else:
				var at: Vector2 = Vector2.RIGHT * crop["left"] + Vector2.DOWN * crop["top"]
				var size: Vector2 = Vector2.RIGHT * crop["width"] + Vector2.DOWN * crop["height"]
				var cropped := Rect2(at, size)
				for corner: Vector2 in [cropped.position - place.label.position, cropped.end - place.label.end]:
					assert_vector(corner).override_failure_message("%s: its crop %s, its model's label %s" % [
						medium, cropped, place.label]).is_equal_approx(Vector2.ZERO, Vector2.ONE * CROP_EDGE)
			checked.append(medium)
	for medium in found:
		# A disc's label is its whole face on a square, a cartridge's cut by its front.
		if found[medium].media == "cartridge":
			assert_bool(medium in checked or medium in LATER).override_failure_message("%s: no front" % medium).is_true()
		else:
			assert_float(_face(found[medium])).is_equal_approx(1.0, 0.001)
	assert_array(checked).contains(["nes_cart", "famicom_cart", "snes_pal_cart", "snes_us_cart", "gba_cart"])
	# Only the fronts whose scans are of another shape than the model's are left uncropped by it.
	assert_array(uncropped).contains_exactly_in_any_order(UNLIKE_THEIR_MODEL)


func test_INV_E10_07_every_medium_fills_exactly_its_real_size() -> void:
	var appearance := Appearance.read(APPEARANCE)
	var found := MediumManifest.found()
	assert_array(REAL_SIZES.keys()).contains_exactly_in_any_order(found.keys())
	for medium in found:
		var size := appearance.medium_box(medium, found[medium].media).size / MM
		assert_vector(size).override_failure_message("%s: %s, really %s" % [medium, size, REAL_SIZES[medium]]) \
			.is_equal_approx(REAL_SIZES[medium], Vector3.ONE * REAL_SIZE_MM)


func test_INV_E10_07_every_medium_is_drawn_within_its_triangle_budget() -> void:
	var found := MediumManifest.found()
	for medium in found:
		var model: Node3D = auto_free((load(found[medium].scene) as PackedScene).instantiate())
		var triangles := 0
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in geometry.mesh.get_surface_count():
				var indices: PackedInt32Array = geometry.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3.0)
		assert_int(triangles).override_failure_message("%s: %d triangles" % [medium, triangles]) \
			.is_between(1, found[medium].triangle_budget)


func test_INV_E10_07_every_medium_s_title_and_platform_name_are_drawn_on_its_label_s_face() -> void:
	for medium in MediumManifest.found():
		var shape := Fixtures.medium_shape(medium)
		var label := shape.mesh_arrays(&"label", 64)
		var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = label[Mesh.ARRAY_INDEX]
		for area: Rect2 in [shape.title_area(), shape.platform_area()]:
			# Drawn centred: its centre on the face, its text around it.
			var on_face := range(0, indices.size(), 3).any(func(t: int) -> bool:
				return _within(area.get_center(), uvs[indices[t]], uvs[indices[t + 1]], uvs[indices[t + 2]]))
			assert_bool(area.has_area() and on_face).override_failure_message("%s: %s drawn off its label's face" % [
				medium, area]).is_true()


func test_INV_E10_07_a_medium_known_by_its_colour_keeps_it() -> void:
	# Every disc but the PlayStation's silver underneath, as their pressed aluminium is.
	var found := MediumManifest.found()
	for medium in found:
		if found[medium].media != "cartridge" and medium != "ps1_cd":
			var mirror := _material(medium, ^"Mirror")
			for side: StringName in [&"mirror_color", &"recorded_color"]:
				var silver: Color = mirror.get_shader_parameter(side)
				assert_float(silver.get_luminance()).override_failure_message("%s %s not silver" % [medium, side]) \
					.is_greater(SILVER)
	# The PlayStation's disc black underneath and all through.
	var disc := _material("ps1_cd", ^"Mirror")
	var plastic := _material("ps1_cd", ^"Shell")
	var blacks: Dictionary[String, Color] = {"ps1_cd mirror": disc.get_shader_parameter(&"mirror_color"),
		"ps1_cd data": disc.get_shader_parameter(&"recorded_color"), "ps1_cd hub": plastic.get_shader_parameter(&"tint"),
		"ps1_cd rim": plastic.get_shader_parameter(&"edge_tint")}
	for look in blacks:
		assert_float(blacks[look].get_luminance()).override_failure_message("%s not black" % look).is_less(DARK)
	assert_float(plastic.get_shader_parameter(&"opacity")).is_equal(1.0)
	# The Nintendo 64's contacts gold.
	var contacts := _material("n64_cart", ^"Contacts")
	var gold: Color = contacts.get_shader_parameter(&"albedo")
	assert_float(gold.h * 360.0).is_between(GOLD_HUE.x, GOLD_HUE.y)
	assert_float(gold.s).is_greater(0.4)
	assert_float(contacts.get_shader_parameter(&"metallic")).is_greater_equal(0.9)


func test_a_medium_folder_with_problems_is_left_out_and_its_games_show_their_kind_s() -> void:
	var found := MediumManifest.found()
	var broken: MediumManifest = found["ps1_cd"].duplicate()
	broken.scene = ""
	found["ps1_cd"] = broken
	var shown := Appearance.shown_media(found)
	assert_bool("ps1_cd" in shown).is_false()
	assert_bool("ps2_dvd" in shown).is_true()
	var appearance := Appearance.read(APPEARANCE)
	appearance._media = shown
	assert_str(appearance.model_of("ps1_cd", "dvd").resource_path).is_equal(found["ps2_dvd"].scene)


## The label of [param shape] (of [param medium]), built as [param meshes] (its parts', in order),
## lies on the medium, within the bounds of its other parts, its image upright on it: over the
## label's own bounds on a cartridge, over the disc's square on a disc.
func _assert_label_on(medium: String, shape: ModelShape, meshes: Array[Array]) -> void:
	var at := shape.parts().find(&"label")
	var label: Array = meshes[at]
	var others := PackedVector3Array()
	for part in meshes.size():
		if part != at:
			others.append_array(Fixtures.points(meshes[part]))
	var bounds := Fixtures.bounds(others).grow(EPSILON * MM)
	var points := Fixtures.points(label)
	var box := Fixtures.bounds(points)
	var image := Rect2(box.position.x, box.position.y, box.size.x, box.size.y)
	if shape is DiscShape:
		var radius := (shape as DiscShape).radius * MM
		image = Rect2(-radius, -radius, 2.0 * radius, 2.0 * radius)
	var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
	for v in points.size():
		assert_bool(bounds.has_point(points[v])).override_failure_message("%s: its label off the medium at %s" % [
			medium, points[v] / MM]).is_true()
		var upright := Vector2(points[v].x - image.position.x, image.end.y - points[v].y) / image.size
		assert_vector(uvs[v]).override_failure_message("%s: its image at %s, upright %s" % [medium, uvs[v],
			upright]).is_equal_approx(upright, Vector2.ONE * EPSILON)


## Whether [param point] lies within the triangle [param a], [param b], [param c], its edges
## included: on the edge two triangles share, it is in both.
static func _within(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var sides := [(b - a).cross(point - a), (c - b).cross(point - b), (a - c).cross(point - c)]
	return sides.all(func(side: float) -> bool: return side >= -EPSILON) \
		or sides.all(func(side: float) -> bool: return side <= EPSILON)


## The material [param part] of [param medium]'s model is drawn with.
func _material(medium: String, part: NodePath) -> ShaderMaterial:
	var model: Node3D = auto_free((load(MediumManifest.found()[medium].scene) as PackedScene).instantiate())
	return (model.get_node(part) as MeshInstance3D).get_surface_override_material(0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The fronts of [param platform]'s cartridges whose scans its labels are cut from, by medium; none
## for a platform of discs or of no scans.
func _fronts(platform: String) -> Dictionary:
	var profile: Dictionary = _json(PROFILES)[platform]
	var art: Dictionary = profile.get("art", {})
	return art.get("fronts", {})


## The width of the label face of [param manifest]'s model over its height.
func _face(manifest: MediumManifest) -> float:
	var model: Node3D = auto_free((load(manifest.scene) as PackedScene).instantiate())
	var face := (model.get_node(^"Label") as MeshInstance3D).get_aabb().size
	return face.x / face.y


## Where the label of [param manifest]'s model lies on its front, in fractions of the front (from
## its top left), and the front's width over its height.
func _label_place(manifest: MediumManifest) -> LabelPlace:
	var model: Node3D = auto_free((load(manifest.scene) as PackedScene).instantiate())
	var front := AABB()
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := _in_model(model, geometry) * geometry.get_aabb()
		front = box if front.size == Vector3.ZERO else front.merge(box)
	var label_node: MeshInstance3D = model.get_node(^"Label")
	var label := _in_model(model, label_node) * label_node.get_aabb()
	var place := LabelPlace.new()
	place.proportion = front.size.x / front.size.y
	place.label = Rect2((label.position.x - front.position.x) / front.size.x, (front.end.y - label.end.y) / front.size.y,
		label.size.x / front.size.x, label.size.y / front.size.y)
	return place


func _in_model(model: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var at: Node = node
	while at != model:
		transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform


class LabelPlace:
	var proportion := 1.0
	var label := Rect2()
