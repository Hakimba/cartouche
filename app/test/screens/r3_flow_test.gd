# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func _shown(device: Fixtures.NewDevice) -> Carousel:
	var carousel := await Fixtures.shown(self, device)
	CarouselFixtures.arrived(carousel)
	if carousel._title_fade:
		carousel._title_fade.custom_step(10.0)
	return carousel


func test_freeing_the_ring_mid_placing_returns_false_to_the_waiting_caller() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1, "gba": 1}))
	var answers: Array[bool] = []
	var wait_for_placing := func() -> void:
		answers.append(await carousel._order.place(carousel._platform_ids(), "gba"))
	wait_for_placing.call()
	carousel._order.queue_free()
	await await_idle_frame()
	assert_array(answers).is_equal([false])


func test_an_arrival_stops_and_releases_its_caller_when_its_row_leaves_the_tree() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1}))
	carousel.process_mode = Node.PROCESS_MODE_DISABLED
	var arrival: ConsoleArrival = auto_free(ConsoleArrival.new())
	add_child(arrival)
	var previous := get_tree().get_processed_tweens()
	var answers: Array[bool] = []
	var play := func() -> void:
		answers.append(await arrival.play(carousel._consoles))
	play.call()
	var motions: Array[Tween] = []
	for tween: Tween in get_tree().get_processed_tweens():
		if tween not in previous:
			motions.append(tween)
	assert_int(motions.size()).is_equal(1)
	var motion := motions[0]
	carousel._consoles.queue_free()
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(motion.is_valid()).is_false()
	assert_array(answers).is_equal([false])


func test_an_arrival_cancelled_by_a_removed_row_returns_false_to_the_carousel() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1}))
	carousel.process_mode = Node.PROCESS_MODE_DISABLED
	var answers: Array[bool] = []
	var placing := func() -> void:
		answers.append(await carousel._place_console(carousel._screens.library, "ps2"))
	placing.call()
	carousel._consoles.queue_free()
	await await_idle_frame()
	await await_idle_frame()
	assert_array(answers).is_equal([false])
