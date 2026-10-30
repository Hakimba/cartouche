# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every medium folder must hold to be shown, whichever medium it is.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"
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
func test_inv_14_every_medium_folder_holds_a_manifest_the_app_can_show_of_its_platforms_kind() -> void:
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


func test_every_medium_a_console_s_platform_declares_has_its_folder_the_others_show_their_kind_s() -> void:
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


func test_every_medium_s_label_face_has_the_proportions_of_the_labels_cut_for_it() -> void:
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
