# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const CONSOLES: Array[String] = ["ps2", "gc", "gba", "snes", "n64", "psx"]


## Some of the consoles, in an order drawn by [param random].
func _drawn(random: RandomNumberGenerator) -> Array[String]:
	var consoles: Array[String] = CONSOLES.duplicate()
	for i in range(consoles.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swapped: String = consoles[i]
		consoles[i] = consoles[j]
		consoles[j] = swapped
	return consoles.slice(0, random.randi_range(1, consoles.size()))


func test_the_ring_has_no_end_n_steps_either_way_come_back_to_the_same_console() -> void:
	var random := Fixtures.cases(91)
	for case in 200:
		var consoles := _drawn(random)
		var wheel := ConsoleWheel.new(consoles, random.randi_range(0, consoles.size() - 1))
		var start := wheel.selected()
		var direction := Fixtures.direction(random)
		var steps := random.randi_range(0, 20)
		for step in steps:
			wheel.step(direction)
		for step in steps:
			wheel.step(-direction)
		assert_str(wheel.selected()).is_equal(start)
		for step in consoles.size():
			wheel.step(direction)
		assert_str(wheel.selected()).is_equal(start)
		assert_array(wheel.order).is_equal(consoles)


func test_the_order_holds_every_console_once_let_go_as_before_put_down_as_shown() -> void:
	var random := Fixtures.cases(92)
	var moved := 0
	var let_go := 0
	for case in 300:
		var consoles := _drawn(random)
		var wheel := ConsoleWheel.new(consoles, random.randi_range(0, consoles.size() - 1))
		var kept := consoles.duplicate()
		for press in random.randi_range(1, 30):
			match random.randi() % 5:
				0, 1:
					wheel.step(Fixtures.direction(random))
				2:
					if not wheel.is_holding():
						wheel.take()
				3:
					if wheel.is_holding():
						var held := wheel.selected()
						var shown := wheel.order.duplicate()
						var changed := wheel.put_down()
						assert_bool(changed).is_equal(shown != kept)
						assert_array(wheel.order).is_equal(shown)
						assert_str(wheel.selected()).is_equal(held)
						kept = shown
						moved += 1 if changed else 0
				4:
					if wheel.is_holding():
						var held := wheel.selected()
						wheel.let_go()
						assert_array(wheel.order).is_equal(kept)
						assert_str(wheel.selected()).is_equal(held)
						let_go += 1
			assert_array(wheel.order).contains_exactly_in_any_order(consoles)
			assert_bool(wheel.is_moved()).is_equal(wheel.is_holding() and wheel.order != kept)
			if is_failure():
				return
	assert_int(moved).is_greater(50)
	assert_int(let_go).is_greater(50)


func test_a_console_held_takes_the_place_of_each_one_it_passes() -> void:
	var wheel := ConsoleWheel.new(["ps2", "gc", "gba"] as Array[String], 2)
	wheel.take()
	wheel.step(-1)
	assert_array(wheel.order).is_equal(["ps2", "gba", "gc"])
	assert_array(wheel.neighbours()).is_equal(["ps2", "gc"])
	wheel.step(-1)
	assert_array(wheel.order).is_equal(["gba", "ps2", "gc"])
	# Round the end: it comes in at the other one.
	wheel.step(-1)
	assert_array(wheel.order).is_equal(["gc", "ps2", "gba"])
	assert_int(wheel.cursor).is_equal(2)


func test_letting_go_with_nothing_held_changes_nothing() -> void:
	var wheel := ConsoleWheel.new(["ps2", "gc"] as Array[String], 1)
	wheel.let_go()
	assert_array(wheel.order).is_equal(["ps2", "gc"])
	assert_int(wheel.cursor).is_equal(1)


func test_neighbours_are_the_one_other_console_twice_with_two_and_none_alone() -> void:
	assert_array(ConsoleWheel.new(["ps2", "gc"] as Array[String], 0).neighbours()).is_equal(["gc", "gc"])
	assert_array(ConsoleWheel.new(["ps2"] as Array[String], 0).neighbours()).is_empty()


func test_the_cursor_goes_to_a_console_only_while_none_is_held() -> void:
	var wheel := ConsoleWheel.new(["ps2", "gc", "gba"] as Array[String], 0)
	wheel.point(2)
	assert_str(wheel.selected()).is_equal("gba")
	wheel.take()
	wheel.point(0)
	assert_str(wheel.selected()).is_equal("gba")
