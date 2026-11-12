# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

func test_every_console_has_its_plinth_pictures_at_the_sizes_the_plinth_draws_them() -> void:
	for console in ConsoleManifest.found():
		var folder := ConsoleManifest.folder_of(console)
		for times: float in Plinth.PICTURES:
			var picture := load(Plinth.picture_of(folder, times)) as Texture2D
			assert_object(picture).override_failure_message(
				"%s has no plinth picture at %s: scripts/bake_plinths.sh" % [folder, times]).is_not_null()
			if picture:
				assert_vector(picture.get_size()).is_equal((StudioTokens.TURNTABLE.size * times).ceil())


func test_the_plinth_shows_nothing_until_the_picture_is_loaded_then_the_console_s_own() -> void:
	var plinth := _plinth("xbox")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_object(turntable.texture).is_null()
	await _loaded(plinth)
	assert_str(turntable.texture.resource_path).is_equal(Plinth.picture_of("xbox"))
	assert_str(plinth.console()).is_equal("xbox")


func test_a_console_asked_for_while_others_load_is_the_one_shown() -> void:
	var plinth := _plinth("nes")
	for passed: String in ["snes", "gba", "gbc", "gb"]:
		plinth.show_console(passed)
	var turntable: TextureRect = plinth.get_node("Turntable")
	await _loaded(plinth)
	assert_str(turntable.texture.resource_path).is_equal(Plinth.picture_of("gb"))


func test_a_plinth_freed_before_its_picture_is_loaded_leaves_none_with_the_loader() -> void:
	var plinth := Plinth.create()
	add_child(plinth)
	plinth.show_console("gba")
	plinth.free()
	assert_int(ResourceLoader.load_threaded_get_status(Plinth.picture_of("gba"))).is_equal(
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)


func test_a_cleared_plinth_shows_no_picture_and_shows_one_again_when_asked() -> void:
	var plinth := _plinth("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	await _loaded(plinth)
	plinth.clear()
	assert_object(turntable.texture).is_null()
	assert_str(plinth.console()).is_empty()
	plinth.show_console("gb")
	await _loaded(plinth)


## A plinth showing [param folder] where the Console chooser has it, on the frame it appears.
func _plinth(folder: String) -> Plinth:
	var plinth: Plinth = auto_free(Plinth.create())
	plinth.position = StudioTokens.PLINTH.position
	add_child(plinth)
	plinth.show_console(folder)
	return plinth


## Waits until [param plinth] took every picture it asked for. The loader's thread needs the machine's time, which
## a headless run's frames do not take.
func _loaded(plinth: Plinth) -> void:
	for frame in 800:
		if not plinth.is_processing():
			break
		OS.delay_msec(5)
		await await_idle_frame()
	assert_bool(plinth.is_processing()).is_false()
