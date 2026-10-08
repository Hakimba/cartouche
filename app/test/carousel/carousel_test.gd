# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_the_art_bar_follows_a_run_greys_while_it_waits_and_fades_once_it_is_over() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var progress: Control = carousel.get_node("%ArtProgress")
	var bar: ProgressBar = carousel.get_node("%Bar")
	var text: Label = carousel.get_node("%ArtText")
	var content: Control = carousel.get_node("%Content")
	var tell := func(payload: Dictionary) -> void:
		carousel._on_art_changed(AndroidServices.ArtChange.new(payload))
		# The bar moves on its tween: moved to its end here, rather than waited for.
		if carousel._art_tween:
			carousel._art_tween.custom_step(Carousel._ART_STEP_S + 0.01)
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()
	tell.call({"done": 12, "total": 55})
	assert_bool(progress.visible).is_true()
	assert_float(bar.value).is_equal(12.0)
	assert_float(bar.max_value).is_equal(55.0)
	assert_str(text.text).is_equal("Disc images · 12 / 55")
	assert_str(bar.theme_type_variation).is_equal("ArtBar")
	var messages := {
		"offline": "Disc images · offline, resuming when the network is back",
		"refused": "Disc images · server unavailable, trying again later",
		"storage": "Disc images · no room left on the device",
	}
	for stall: String in messages:
		tell.call({"done": 12, "total": 55, "stall": stall})
		assert_str(text.text).is_equal(messages[stall])
		assert_str(bar.theme_type_variation).is_equal("ArtBarStalled")
		assert_float(bar.value).is_equal(12.0)
	# A launch failure's message shows where the bar is: the bar hides for it.
	carousel._show_message("No emulator.")
	assert_bool(content.visible).is_false()
	carousel._on_message_timer_timeout()
	assert_bool(content.visible).is_true()
	tell.call({"done": 55, "total": 55})
	assert_float(bar.value).is_equal(55.0)
	assert_bool(progress.visible).is_true()
	carousel._art_tween.custom_step(Carousel._ART_FULL_S + Carousel._ART_FADE_S + 0.1)
	assert_bool(progress.visible).is_false()
	# A later run with nothing to look for shows nothing.
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()


func test_the_battery_shows_its_level_and_the_bolt_exactly_while_plugged_in_as_soon_as_told() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var chip: BatteryChip = carousel.get_node("%Battery")
	var tell := func(payload: Dictionary) -> void: carousel.android.battery_changed.emit(AndroidServices.Battery.new(payload))
	tell.call({"level_percent": 57, "plugged": false})
	assert_str(chip.text).is_equal("57 %")
	assert_array(chip.bolt()).is_empty()
	var without := chip.get_combined_minimum_size().x
	tell.call({"level_percent": 57, "plugged": true})
	assert_str(chip.text).is_equal("57 %")
	# The bolt after the level, inside the chip, which makes room for it.
	assert_float(chip.get_combined_minimum_size().x).is_greater(without)
	chip.size = chip.get_combined_minimum_size()
	var bolt := chip.bolt()
	assert_int(bolt.size()).is_equal(7)
	var level_ends := chip.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT) \
		+ chip.get_theme_font(&"font").get_string_size(chip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip.get_theme_font_size(&"font_size")).x
	for point in bolt:
		assert_bool(Rect2(Vector2.ZERO, chip.size).has_point(point) and point.x > level_ends).is_true()
	tell.call({"plugged": true})
	assert_str(chip.text).is_empty()
	assert_array(chip.bolt()).is_not_empty()
	tell.call({"level_percent": 57, "plugged": false})
	assert_str(chip.text).is_equal("57 %")
	assert_array(chip.bolt()).is_empty()
	assert_float(chip.get_combined_minimum_size().x).is_equal(without)


func test_what_moves_by_itself_goes_at_the_pace_of_the_rest() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	get_tree().set_group(Resting.PACED, &"pace", 0.25)
	for node: Node in [carousel._row, carousel._consoles, carousel.get_node("Backdrop/Gradient")]:
		assert_float(node.get(&"pace")).is_equal(0.25)
	get_tree().set_group(Resting.PACED, &"pace", 1.0)


func test_while_labels_download_the_app_does_not_rest_once_they_wait_or_are_over_it_does() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var tell := func(payload: Dictionary) -> void:
		carousel._on_art_changed(AndroidServices.ArtChange.new(payload))
	assert_bool(carousel._resting.moving.call()).is_false()
	for stall: String in ["offline", "refused", "storage"]:
		tell.call({"done": 3, "total": 50})
		assert_bool(carousel._resting.moving.call()).is_true()
		tell.call({"done": 3, "total": 50, "stall": stall})
		assert_bool(carousel._resting.moving.call()).is_false()
	tell.call({"done": 4, "total": 50})
	assert_bool(carousel._resting.moving.call()).is_true()
	tell.call({"done": 50, "total": 50})
	assert_bool(carousel._resting.moving.call()).is_false()


func test_the_carousel_coming_in_wakes_the_app() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var awake_fps := Engine.max_fps
	carousel._resting._process(7.0)
	assert_float(carousel._resting.pace).is_equal(0.0)
	carousel._come_in()
	assert_float(carousel._resting.pace).is_equal(1.0)
	assert_int(Engine.max_fps).is_equal(awake_fps)
	assert_bool(OS.low_processor_usage_mode).is_false()


func test_still_the_carousel_changes_nothing_frame_after_frame() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	for screen: Carousel.Screen in [Carousel.Screen.CONSOLES, Carousel.Screen.GAMES]:
		if screen == Carousel.Screen.GAMES:
			Fixtures.press(carousel, &"ui_accept")
			Fixtures.step_until(carousel, Carousel.Screen.GAMES)
		get_tree().set_group(Resting.PACED, &"pace", 0.0)
		# Settled first: the labels drawn, the consoles behind the games gone, what the press started
		# (the hints coming in) over.
		Fixtures.step_frames(carousel, 60)
		for frame in 300:
			if not get_tree().get_processed_tweens().any(func(tween: Tween) -> bool: return tween.is_running()):
				break
			await await_idle_frame()
		var still := _shown(carousel)
		Fixtures.step_frames(carousel, 120)
		for frame in 5:
			await await_idle_frame()
		assert_dict(_shown(carousel)).is_equal(still)
		get_tree().set_group(Resting.PACED, &"pace", 1.0)


## What [param carousel] shows: where every 3D node stands, whether every 2D item shows and in which
## colour and place, the backdrop's dots, and whether the consoles' blurred view is drawn again.
func _shown(carousel: Carousel) -> Dictionary:
	var shown := {}
	for node in carousel.find_children("*", "", true, false):
		var path := str(carousel.get_path_to(node))
		if node is Node3D:
			shown[path] = (node as Node3D).transform
		elif node is CanvasItem:
			var item := node as CanvasItem
			shown[path] = [item.visible, item.modulate, item.self_modulate, (item as Control).position if item is Control else Vector2.ZERO]
	shown["drift"] = ((carousel.get_node("Backdrop/Gradient") as CanvasItem).material as ShaderMaterial).get_shader_parameter(&"drift")
	shown["blurred view"] = carousel._sequence.layer.view.render_target_update_mode
	return shown
