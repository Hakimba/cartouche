# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


## The angle between [param turned] and the front, in radians.
func _off_front(turned: Basis) -> float:
	return turned.get_rotation_quaternion().angle_to(Quaternion.IDENTITY)


func test_a_finger_dragged_across_turns_the_selected_model_about_the_vertical_and_along_about_the_horizontal() -> void:
	var turn := StickTurn.new()
	turn.follow(Vector2.ZERO, 2, 0.0)
	turn.touch(Vector2(100.0, 0.0))
	turn.follow(Vector2.ZERO, 2, 0.0)
	assert_bool(turn.of(2).is_equal_approx(Basis.from_euler(Vector3(0.0, 100.0 * StickTurn.PER_PIXEL, 0.0)))).is_true()
	assert_bool(turn.of(1).is_equal_approx(Basis.IDENTITY)).is_true()
	var along := StickTurn.new()
	along.follow(Vector2.ZERO, 0, 0.0)
	along.touch(Vector2(0.0, 50.0))
	assert_bool(along.of(0).is_equal_approx(Basis.from_euler(Vector3(50.0 * StickTurn.PER_PIXEL, 0.0, 0.0)))).is_true()


func test_a_model_held_by_a_finger_stays_turned_and_comes_back_to_the_front_once_let_go() -> void:
	var turn := StickTurn.new()
	turn.follow(Vector2.ZERO, 0, 0.0)
	turn.touch(Vector2(200.0, 0.0))
	var held := _off_front(turn.of(0))
	turn.follow(Vector2.ZERO, 0, 5.0)
	assert_float(_off_front(turn.of(0))).is_equal_approx(held, 0.0001)
	turn.let_go()
	turn.follow(Vector2.ZERO, 0, 0.1)
	assert_float(_off_front(turn.of(0))).is_greater(0.3 * held)
	turn.follow(Vector2.ZERO, 0, StickTurn.BACK_S - 0.1)
	assert_float(_off_front(turn.of(0))).is_less(0.06 * held)


func test_a_model_turned_by_a_finger_keeps_coming_back_after_another_is_selected() -> void:
	var turn := StickTurn.new()
	turn.follow(Vector2.ZERO, 0, 0.0)
	turn.touch(Vector2(200.0, 0.0))
	turn.let_go()
	var touched := _off_front(turn.of(0))
	turn.follow(Vector2.ZERO, 1, 0.05)
	assert_float(_off_front(turn.of(0))).is_greater(0.5 * touched)
	assert_bool(turn.of(1).is_equal_approx(Basis.IDENTITY)).is_true()
