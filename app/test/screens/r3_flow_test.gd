# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")


func _shown(device: Fixtures.NewDevice) -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	carousel._arrival.custom_step(10.0)
	if carousel._title_fade:
		carousel._title_fade.custom_step(10.0)
	carousel._resting.set_process(false)
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


class SlowRegionDevice extends Fixtures.NewDevice:
	func save_preferred_region(region: String) -> AndroidServices.Result:
		saved_regions.append(region)
		await released
		preferred_region = region
		return AndroidServices.Result.new({"ok": true})


func test_two_presses_on_a_region_card_start_only_one_save() -> void:
	var device: SlowRegionDevice = auto_free(SlowRegionDevice.new())
	device.curtain = true
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saved_regions).is_equal([""])
	device.released.emit()
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(device.saved_regions).is_equal([""])


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


func test_light_profiles_can_be_empty_or_null_and_an_empty_cached_set_is_not_reloaded() -> void:
	assert_dict(ConsoleRow._rigs_from("null")).is_empty()
	assert_dict(ConsoleRow._rigs_from('{"lights": {}}')).is_empty()
	assert_dict(ConsoleRow._rigs_from('{"lights": {"a": {"consoles": {}}, "b": {"plinth": {}}}}')).is_equal({"a": true, "b": false})
	var saved := ConsoleRow._with_rig
	var loaded := ConsoleRow._rigs_read
	ConsoleRow._with_rig = {}
	ConsoleRow._rigs_read = true
	for repeat in 3:
		assert_bool(ConsoleRow.has_rig("ps2_slim")).is_false()
	assert_dict(ConsoleRow._with_rig).is_empty()
	ConsoleRow._with_rig = saved
	ConsoleRow._rigs_read = loaded


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
