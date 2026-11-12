# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What every medium folder must hold to be shown, whichever medium it is.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"


func test_inv_14_every_medium_folder_holds_a_manifest_the_app_can_show_of_its_platforms_kind() -> void:
	var insertions: Dictionary = Fixtures.json(APPEARANCE)["insertions"]
	var profiles: Dictionary = Fixtures.json(Fixtures.PROFILES)
	var found := MediumManifest.found()
	assert_array(found.keys()).contains(["ps2_dvd", "gc_mini_dvd", "gba_cart"])
	for medium in found:
		var manifest := found[medium]
		assert_array(manifest.problems()).override_failure_message("%s: %s" % [medium, manifest.problems()]).is_empty()
		assert_bool(insertions.has(manifest.media)).override_failure_message("%s: no kind %s" % [
			medium, manifest.media]).is_true()
		var showing := 0
		for platform: String in profiles:
			if medium in Fixtures.media(platform) or medium in Fixtures.fronts(platform):
				showing += 1 if medium in Fixtures.media(platform) else 0
				assert_str(Fixtures.platform(platform).media).override_failure_message(
					"%s declared by %s, of another kind" % [medium, platform]).is_equal(manifest.media)
		assert_bool((showing > 0) != (medium in Fixtures.LATER_MEDIA)).override_failure_message("%s: %s" % [medium,
			"shown by a platform, still listed for later" if showing else "shown by no platform"]).is_true()
		var model: Node3D = auto_free((load(manifest.scene) as PackedScene).instantiate())
		var label: MeshInstance3D = model.get_node_or_null(^"Label")
		assert_bool(label != null and label.mesh != null).override_failure_message("%s: no label" % medium).is_true()
		var drawn := Fixtures.triangle_count(model)
		assert_int(drawn).override_failure_message("%s: %d triangles, over its budget of %d" % [
			medium, drawn, manifest.triangle_budget]).is_less_equal(manifest.triangle_budget)


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
