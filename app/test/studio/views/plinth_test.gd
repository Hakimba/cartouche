# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const StillStandIn := preload("res://test/studio/views/still_stand_in.gd")


func before_test() -> void:
	Plinth._stills.clear()
	StillStandIn.install()


func after_test() -> void:
	StillStandIn.restore()


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_a_console_s_picture_is_rendered_once_at_the_size_shown_and_kept(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	var drawn := await _picture("nes")
	var size := Vector2i((StudioTokens.TURNTABLE.size * StudioTokens.window_scale(get_window())).ceil())
	assert_vector(drawn.get_size()).is_equal(Vector2(size))
	assert_object(Plinth.still_of("nes")).is_same(drawn)
	assert_object(await _picture("nes")).is_same(drawn)


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_the_view_a_picture_is_drawn_in_is_freed_once_it_is_rendered(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	await _picture("snes")
	await await_idle_frame()
	assert_array(get_tree().root.find_children("*", "SubViewport", false, false)).is_empty()


func test_the_plinth_shows_nothing_until_the_picture_exists() -> void:
	var plinth := _plinth("xbox")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_object(turntable.texture).is_null()
	assert_bool(await Fixtures.until(self, func() -> bool: return turntable.texture != null)).is_true()
	assert_object(turntable.texture).is_same(Plinth.still_of("xbox"))
	assert_str(plinth.console()).is_equal("xbox")


func test_a_console_asked_for_while_another_renders_is_the_one_shown() -> void:
	var plinth := _plinth("snes")
	plinth.show_console("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gb") != null)).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("snes") != null)).is_true()
	await await_idle_frame()
	assert_object(turntable.texture).is_same(Plinth.still_of("gb"))
	assert_object(Plinth.still_of("gb")).is_not_same(Plinth.still_of("snes"))


func test_a_plinth_freed_before_its_picture_is_ready_leaves_the_picture_for_the_next() -> void:
	var plinth := Plinth.create()
	add_child(plinth)
	plinth.show_console("gba")
	plinth.free()
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gba") != null)).is_true()


func test_a_cleared_plinth_shows_no_picture_and_a_cached_one_is_shown_at_once() -> void:
	var plinth := _plinth("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_bool(await Fixtures.until(self, func() -> bool: return turntable.texture != null)).is_true()
	plinth.clear()
	assert_object(turntable.texture).is_null()
	assert_str(plinth.console()).is_empty()
	plinth.show_console("gb")
	assert_object(turntable.texture).is_same(Plinth.still_of("gb"))


## A plinth showing [param folder] where the Console chooser has it, on the frame it appears.
func _plinth(folder: String) -> Plinth:
	var plinth: Plinth = auto_free(Plinth.create())
	plinth.position = StudioTokens.PLINTH.position
	add_child(plinth)
	plinth.show_console(folder)
	return plinth


## The picture of [param folder], once rendered.
func _picture(folder: String) -> Texture2D:
	var asked: Array[Texture2D] = []
	Plinth.request_still(folder, func(picture: Texture2D) -> void: asked.append(picture))
	await Fixtures.until(self, func() -> bool: return not asked.is_empty())
	return asked[0]
