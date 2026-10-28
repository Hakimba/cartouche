# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The bridge's live launch: steps not in any file played at a time, and where the picture's grabbable
## things stand.

const LaunchView := preload("res://dev/bridge/launch_view.gd")
const Screens := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")
const LAUNCH := "res://carousel/consoles/ps2_slim/launch.json"


func _games() -> Carousel:
	var carousel := Screens.fresh_carousel(self, Screens.past_first_launch(self, {"ps2": 3}))
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	return carousel


func _values(at: float) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAUNCH))
	return {"steps": data["steps"], "choice": data["choice"], "t": at}


func test_the_steps_given_are_the_ones_played_at_the_time_given_with_the_black_drawn() -> void:
	var carousel := await _games()
	var length: float = LaunchView.tune(carousel, _values(0.0))["length"]
	assert_float(length).is_greater(3.0)
	assert_bool(carousel._game_launch.is_inserting()).is_true()
	assert_float(carousel._sequence.black).is_equal(0.0)
	var done := LaunchView.tune(carousel, _values(length))
	assert_float(done["t"]).is_equal_approx(length, 1e-4)
	assert_float(carousel._sequence.black).is_equal(1.0)
	assert_float(LaunchView.tune(carousel, _values(length + 9.0))["t"]).is_equal_approx(length, 1e-4)
	# Other steps, other picture: without the black in them, the end of the launch is not dark.
	var edited := _values(length)
	var steps: Array = edited["steps"]
	for step: Dictionary in steps:
		step["fx"] = {"black": 0.0, "fade": 0.0}
	LaunchView.tune(carousel, edited)
	assert_float(carousel._sequence.black).is_equal(0.0)


func test_a_preview_played_past_its_end_gives_the_carousel_back_and_a_real_launch_is_never_tuned() -> void:
	var carousel := await _games()
	var launch := carousel._game_launch
	var length: float = LaunchView.tune(carousel, _values(0.0))["length"]
	assert_bool(launch.is_busy()).is_true()
	# Tuned again while it previews, as a scrub does.
	assert_bool(LaunchView.tune(carousel, _values(1.0)).get("ok", true)).is_true()
	LaunchView.tune(carousel, _values(length))
	launch._process(0.1)
	launch._process(GameLaunch.SHOW_S + 0.1)
	assert_bool(launch.is_busy()).is_false()
	assert_bool(carousel._touchable()).is_true()
	# A launch of a game is not a preview: it is refused, and its stage stays.
	launch._enter(GameLaunch.Stage.CHECKING)
	assert_bool(LaunchView.tune(carousel, _values(1.0))["ok"]).is_false()
	assert_bool(launch.is_inserting()).is_false()


func test_a_console_without_the_part_or_steps_not_a_list_is_refused_and_nothing_changes() -> void:
	var carousel := await _games()
	assert_bool(LaunchView.tune(carousel, {"steps": "none", "t": 1.0})["ok"]).is_false()
	assert_bool(LaunchView.tune(carousel, {"steps": [], "t": 1.0})["ok"]).is_false()
	var values := _values(1.0)
	var steps: Array = values["steps"]
	var second: Dictionary = steps[1]
	second["parts"] = {"not_a_part": 1.0}
	assert_bool(LaunchView.tune(carousel, values)["ok"]).is_false()
	assert_bool(carousel._game_launch.is_inserting()).is_false()
	assert_bool(LaunchView.tune(null, _values(1.0))["ok"]).is_false()


func test_handles_stand_on_the_console_and_a_dragged_value_moves_its_point_by_the_move_given() -> void:
	var carousel := await _games()
	LaunchView.tune(carousel, _values(1.2))
	var handles := LaunchView.handles(carousel)
	var console: Dictionary = handles["console"]
	var moves: Array = console["moves"]
	assert_int(moves.size()).is_equal(2)
	var viewport := carousel.get_viewport().get_visible_rect().size
	assert_float(console["x"]).is_between(0.0, viewport.x)
	assert_float(console["y"]).is_between(0.0, viewport.y)
	# One centimetre of the first value moves the console on the picture by the move given, and the handles
	# leave the console where it was.
	var rest := carousel._consoles.console_position
	var model := carousel._consoles.selected().model
	var camera := carousel.get_viewport().get_camera_3d()
	var here := camera.unproject_position(model.global_position)
	carousel._consoles.console_position = rest + Vector3(0.1, 0.0, 0.0)
	carousel._consoles.arrange()
	var moved := camera.unproject_position(model.global_position) - here
	carousel._consoles.console_position = rest
	carousel._consoles.arrange()
	var first: Array = moves[0]
	assert_float(first[0]).is_equal_approx(moved.x, 1e-3)
	assert_float(first[1]).is_equal_approx(moved.y, 1e-3)
	assert_vector(carousel._consoles.console_position).is_equal(rest)
	assert_bool(handles.has("disc")).is_false()


func test_the_disc_is_grabbable_once_out_of_the_row_and_a_part_gives_its_limits_and_its_own_move() -> void:
	var carousel := await _games()
	LaunchView.tune(carousel, _values(0.0))
	var found := LaunchView.handles(carousel)
	var parts: Dictionary = found["parts"]
	var lid: Dictionary = parts["lid_degrees"]
	assert_array(lid["limits"]).is_equal([0.0, 88.0])
	var lid_moves: Array = lid["moves"]
	assert_int(lid_moves.size()).is_equal(1)
	assert_float(LaunchView.tune(carousel, _values(3.4))["t"]).is_equal_approx(3.4, 1e-4)
	var out := LaunchView.handles(carousel)
	assert_bool(out.has("disc")).is_true()
	var disc: Dictionary = out["disc"]
	var disc_moves: Array = disc["moves"]
	assert_int(disc_moves.size()).is_equal(3)
	var raw: Variant = disc_moves[2]
	var lift: Array = raw
	var dx: float = lift[0]
	var dy: float = lift[1]
	assert_float(absf(dx) + absf(dy)).is_greater(0.0)


func test_launch_answer_names_the_model_and_every_parts_endpoints_and_console_space() -> void:
	var carousel := await _games()
	var values := _values(1.0)
	var steps: Array = values["steps"]
	steps[1]["note"] = "A note has no animation track."
	var answer := LaunchView.tune(carousel, values)
	var model := carousel._consoles.selected().model as ConsoleModel
	assert_str(answer["model_hash"]).is_equal(model.fingerprint())
	var parts: Array = answer["parts"]
	assert_int(parts.size()).is_equal(model.moving_parts().size())
	var lid: Dictionary = parts.filter(func(part: Dictionary) -> bool: return part["property"] == "lid_degrees")[0]
	assert_float(lid["rest"]).is_equal(0.0)
	assert_float(lid["open"]).is_equal(88.0)
	var handles := LaunchView.handles(carousel)
	var console: Dictionary = handles["console"]
	var space: Dictionary = console["space"]
	assert_array(space["projection"]).has_size(16)
	assert_array(space["model"]).has_size(12)


func test_stopping_a_preview_returns_the_games_and_leaves_no_preview_callback() -> void:
	var carousel := await _games()
	LaunchView.tune(carousel, _values(1.0))
	assert_bool(carousel._game_launch.is_inserting()).is_true()
	assert_bool(LaunchView.stop(carousel)["ok"]).is_true()
	assert_bool(carousel._game_launch.is_inserting()).is_false()
	assert_bool(carousel._game_launch._inserted.is_connected(carousel._game_launch.end_preview)).is_false()
	assert_bool(LaunchView.stop(carousel)["ok"]).is_true()
