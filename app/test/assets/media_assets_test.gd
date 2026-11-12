# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The shipped media as data and as meshes: every medium has its folder or is awaited, its label face has the proportions
## of the labels cut for it, every model draws a label, and every part is built closed and turned outwards. Asset checks,
## run when a medium folder or the data changes and before a release (scripts/test_godot.sh), not on every run.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
## The media a console's platform declares whose folder is still to be made: each folder made takes
## its medium off.
const AWAITING: Array[String] = ["psp_umd", "psvita_card", "nds_card"]
## How far a cartridge's label face may be from the proportions of the labels cut for it.
const LABEL_SHAPE := 0.02
## Fronts whose scans are of another shape than their model's front: their crop is not the model's.
const UNLIKE_THEIR_MODEL: Array[String] = ["snes_pal_cart"]
## How far, as a fraction of its cartridge, a label crop's edge may be from its model's label.
const CROP_EDGE := 0.005


func test_every_medium_a_console_s_platform_declares_has_its_folder_the_others_show_their_kind_s() -> void:
	var appearance := Appearance.read(APPEARANCE)
	var found := MediumManifest.found()
	var kind_media: Dictionary = Fixtures.json(APPEARANCE)["kind_media"]
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
	var profiles: Dictionary = Fixtures.json(Fixtures.PROFILES)
	for platform: String in profiles:
		var media := Fixtures.platform(platform).media
		for medium: String in Fixtures.media(platform) + [""]:
			var shown: String = medium if medium in found else kind_media[media]
			assert_str(appearance.model_of(medium, media).resource_path).override_failure_message(
				"%s of %s" % [medium, platform]).is_equal(found[shown].scene)


func test_every_medium_s_label_face_has_the_proportions_of_the_labels_cut_for_it() -> void:
	var found := MediumManifest.found()
	var checked: Array[String] = []
	var uncropped: Array[String] = []
	for platform: String in Fixtures.json(Fixtures.PROFILES):
		var fronts := Fixtures.fronts(platform)
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
			assert_bool(medium in checked or medium in Fixtures.LATER_MEDIA).override_failure_message("%s: no front" % medium).is_true()
		else:
			assert_float(_face(found[medium])).is_equal_approx(1.0, 0.001)
	assert_array(checked).contains(["nes_cart", "famicom_cart", "snes_pal_cart", "snes_us_cart", "gba_cart"])
	# Only the fronts whose scans are of another shape than the model's are left uncropped by it.
	assert_array(uncropped).contains_exactly_in_any_order(UNLIKE_THEIR_MODEL)


func test_every_model_loads_with_a_label_the_carousel_draws_on() -> void:
	for path in Fixtures.medium_scenes():
		var scene: PackedScene = load(path)
		var model: LabelledModel = auto_free(LabelledModel.new(scene))
		add_child(model)
		model.draw_label("Title", ShelfRow.LabelLook.new())
		var label: ShaderMaterial = model._label_mesh.get_active_material(0)
		var uniforms := label.shader.get_shader_uniform_list().map(func(uniform: Dictionary) -> String: return uniform["name"])
		assert_array(uniforms).override_failure_message("%s: its label cannot be drawn" % path).contains(["label_texture", "has_label"])


func test_every_shipped_medium_is_accepted_and_built_closed_with_its_label_on_it() -> void:
	var media := MediumManifest.found()
	assert_int(media.size()).is_greater(0)
	for medium: String in media:
		var model: Node3D = auto_free((load(media[medium].scene) as PackedScene).instantiate())
		var label: MeshInstance3D = model.get_node(^"Label")
		var meshes: Array[Array] = []
		if label.mesh is ShapedMesh:
			var shape := (label.mesh as ShapedMesh).shape
			assert_array(shape.problems()).override_failure_message("%s refused: %s" % [medium,
				shape.problems()]).is_empty()
			for part in shape.parts():
				meshes.append(shape.mesh_arrays(part, Fixtures.SHAPE_DETAIL))
		else:
			for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				meshes.append(part.mesh.surface_get_arrays(0))
		_assert_whole(medium, meshes, true)


func test_every_shipped_part_exported_already_built_draws_the_arrays_its_code_builds() -> void:
	var scenes: Array[String] = []
	for medium: String in MediumManifest.found():
		scenes.append(MediumManifest.found()[medium].scene)
	var stored := "user://exported_part.res"
	var checked := 0
	for scene in scenes:
		var model: Node3D = auto_free((load(scene) as PackedScene).instantiate())
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := part.mesh as ShapedMesh
			if not mesh:
				continue
			checked += 1
			assert_int(ResourceSaver.save(mesh.baked(), stored)).is_equal(OK)
			var exported: ShapedMesh = ResourceLoader.load(stored, "", ResourceLoader.CACHE_MODE_IGNORE)
			assert_bool(exported.built.is_empty()).override_failure_message("%s %s exported unbuilt" % [scene,
				mesh.part]).is_false()
			assert_bool(exported.get_mesh_arrays() == mesh.get_mesh_arrays()).override_failure_message(
				"%s %s exported differs from its code" % [scene, mesh.part]).is_true()
	DirAccess.remove_absolute(stored)
	assert_int(checked).is_greater(0)


## Asserts that [param meshes] hold faces and, when [param solid], that they close round a volume
## turned outwards.
func _assert_whole(what: String, meshes: Array[Array], solid: bool) -> void:
	for arrays in meshes:
		assert_array(arrays).override_failure_message("%s built nothing" % what).is_not_empty()
		if arrays.is_empty():
			return
	if not solid:
		return
	assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s is open" % what).is_empty()
	for volume in Fixtures.volumes(meshes):
		assert_float(volume).override_failure_message("%s turned inwards" % what).is_greater(0.0)


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

