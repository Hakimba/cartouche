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


func test_adding_among_two_unmodelled_platforms_restores_the_whole_consoles_screen() -> void:
	var device := Fixtures.past_first_launch(self, {"psp": 1, "nds": 1, "ps2": 1})
	for id: String in ["psp", "nds"]:
		device.catalog.platforms.append(AndroidServices.Platform.new({"id": id, "name": id.to_upper(), "media": "dvd" if id == "psp" else "cartridge"}))
	var carousel := await _shown(device)
	carousel._cover()
	carousel._show_front(true)
	carousel._demo = true
	assert_bool(await carousel._place_console(carousel._screens.library, "ps2")).is_true()
	if carousel._title_fade:
		carousel._title_fade.custom_step(10.0)
	if carousel._rail._slide_fade:
		carousel._rail._slide_fade.custom_step(10.0)
	assert_bool(carousel._demo).is_false()
	assert_bool(carousel._console_title.is_visible_in_tree()).is_true()
	assert_bool(carousel._rail.is_visible_in_tree()).is_true()
	assert_float(carousel._rail.sunk).is_equal(0.0)
	assert_float(carousel._rail.ground_alpha).is_equal(1.0)


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


func test_the_settings_clock_fades_the_rail_and_games_logo_with_the_other_chrome() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	var menu := carousel._screens._settings
	assert_bool(await Fixtures.until(self, func() -> bool: return menu.state == SettingsMenu.State.OPEN)).is_true()
	menu.transition_frame.emit(1.0, 1.0, 0.4)
	assert_float(carousel._rail.ground_alpha).is_equal_approx(0.4, 1e-6)
	assert_float(carousel._games_logo.modulate.a).is_equal_approx(0.4, 1e-6)
	await Fixtures.joypad(self, JOY_BUTTON_B)


func test_restoring_settings_after_an_arrival_keeps_its_title_fade_at_the_current_alpha() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	var menu := carousel._screens._settings
	assert_bool(await Fixtures.until(self, func() -> bool: return menu.state == SettingsMenu.State.OPEN)).is_true()
	await carousel._place_console(carousel._screens.library, "ps2")
	carousel._screens.arrived = true
	var alpha := carousel._console_title.modulate.a
	assert_float(alpha).is_less(0.1)
	menu.chosen.emit(&"close")
	assert_float(carousel._console_title.modulate.a).is_equal(alpha)


func test_reversing_a_two_console_swap_keeps_the_returning_model_continuous() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1}))
	var row := carousel._consoles
	row.step(1)
	row._process(0.04)
	row.arrange()
	var model := row._items[0].model
	var position := model.position
	var fade: ModelFade = model.get(&"_fade")
	var opacity := fade.amount
	row.step(-1)
	row.arrange()
	assert_vector(model.position).is_equal_approx(position, Vector3.ONE * 1e-6)
	assert_float(fade.amount).is_equal_approx(opacity, 1e-6)


func test_the_platform_grid_keeps_a_platform_with_no_manifest_as_a_plain_tile() -> void:
	var screen: PlatformList = auto_free(preload("res://screens/platform_list.tscn").instantiate())
	add_child(screen)
	var platform := AndroidServices.Platform.new({"id": "psp", "name": "Unmodelled platform", "media": "dvd"})
	screen.open([platform], 0)
	assert_int(screen._rows.get_child_count()).is_equal(1)
	var tile := screen._rows.get_child(0) as PlatformList.Tile
	assert_str(tile.platform_id).is_equal("psp")
	assert_object(Fixtures.focus(self)).is_same(tile)
	assert_object(tile.logo.texture).is_not_null()


func test_the_ring_uses_the_translated_sentence_order_around_its_logos() -> void:
	var translation := Translation.new()
	translation.locale = "eo"
	translation.add_message(&"between {before} and {after}", &"{after} post {before}", &"ring")
	TranslationServer.add_translation(translation)
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("eo")
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1, "gba": 1}))
	var ring := carousel._order
	ring.open(carousel._platform_ids(), 0)
	ring._wheel.take()
	ring._wheel.step(1)
	ring._describe()
	var parts: Array[String] = []
	for node: Control in ring._where.get_children():
		if node.visible:
			parts.append(node.name if node is LogoView else (node as ConsoleOrder.Word).shown())
	assert_array(parts).is_equal(["After", "post", "Before"])
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(was)


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


func test_console_and_medium_folders_share_the_resource_helper() -> void:
	assert_str(ConsoleManifest.folder_of(ConsoleManifest.of("ps2_slim"))).is_equal("ps2_slim")
	assert_str(ConsoleManifest.folder_of(preload("res://carousel/media/ps2_dvd/ps2_dvd.tscn"))).is_equal("ps2_dvd")
	assert_str(ConsoleManifest.folder_of(null)).is_empty()


func test_french_ring_forms_are_whole_translated_sentences() -> void:
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	assert_str(tr("between {before} and {after}", "ring")).is_equal("entre {before} et {after}")
	assert_str(tr("next to {name}", "ring")).is_equal("à côté de {name}")
	TranslationServer.set_locale(was)


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
