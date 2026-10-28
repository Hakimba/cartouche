# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func after_test() -> void:
	StudioTokens.try_timing(&"TR_SETTINGS_OPEN_S", 0.36)
	StudioTokens.try_timing(&"TR_SETTINGS_CLOSE_S", 0.36)
	StudioTokens.try_timing(&"TR_PROPERTIES_ZONE_AT_S", 0.24)
	StudioTokens.try_timing(&"TR_PROPERTIES_TRAVEL_S", 0.36)
	StudioTokens.try_timing(&"TR_REVERSE", 0.0)
	StudioTokens.try_timing(&"TR_SETTLE_S", 0.0)


func test_transition_defaults_keep_the_existing_durations_and_distances() -> void:
	assert_int(StudioTokens.TR_REVERSE).is_equal(0)
	assert_float(FormEntry.OPEN_S).is_equal(0.38)
	assert_float(FormEntry.CARD_OUT_S).is_equal(0.2)
	assert_float(FormEntry.FORM_AT_S).is_equal(0.06)
	assert_float(Placing.BACK_S).is_equal(0.4)
	assert_float(Placing.ARRIVE_LIFT).is_equal(38.4)
	assert_float(ConsoleRail.SINK_PX).is_equal(51.2)
	assert_float(SettingsMenu.DURATION_S).is_equal(0.36)
	assert_float(StudioTokens.TR_CHOOSER_IN_S).is_equal_approx(0.23, 1e-6)
	assert_float(StudioTokens.TR_GAMES_LOGO_S).is_equal(0.0)


func test_settings_open_and_close_read_independent_live_durations() -> void:
	var menu: SettingsMenu = auto_free(SettingsMenu.new())
	StudioTokens.try_timing(&"TR_SETTINGS_OPEN_S", 0.8)
	assert_float(menu._duration()).is_equal(0.8)
	menu._closing = true
	assert_float(menu._duration()).is_equal(0.36)
	StudioTokens.try_timing(&"TR_SETTINGS_CLOSE_S", 1.1)
	assert_float(menu._duration()).is_equal(1.1)


func test_properties_rebuild_the_profile_from_the_live_start_and_duration_before_travelling() -> void:
	var properties: DiscProperties = auto_free(DiscProperties.new())
	properties.add_child(properties._reader)
	properties.add_child(properties._picture_reader)
	properties._refresh_profiles()
	var original := properties._opening_parts[DiscProperties.Part.ZONE]
	assert_float(original.start).is_equal(0.24)
	assert_float(original.duration).is_equal_approx(0.16, 1e-6)
	StudioTokens.try_timing(&"TR_PROPERTIES_ZONE_AT_S", 0.32)
	StudioTokens.try_timing(&"TR_PROPERTIES_TRAVEL_S", 0.9)
	properties._refresh_profiles()
	var edited := properties._opening_parts[DiscProperties.Part.ZONE]
	assert_float(edited.start).is_equal(0.32)
	assert_float(edited.duration).is_equal_approx(0.08, 1e-6)
	assert_float(properties._opening_parts[DiscProperties.Part.MEDIUM].duration).is_equal(0.9)
	assert_float(properties._back_parts[DiscProperties.Part.MEDIUM].duration).is_equal(0.9)


func test_a_shared_clock_keeps_delay_endpoints_and_retraces_the_same_position() -> void:
	for easing: Motion.Easing in [Motion.Easing.LINEAR, Motion.Easing.ARRIVE, Motion.Easing.GLIDE]:
		assert_float(Motion.phase(0.05, 0.1, 0.4, easing)).is_equal(0.0)
		assert_float(Motion.phase(0.8, 0.1, 0.4, easing)).is_equal(1.0)
		var forward := Motion.phase(0.23, 0.1, 0.4, easing)
		Motion.phase(0.4, 0.1, 0.4, easing)
		assert_float(Motion.phase(0.23, 0.1, 0.4, easing)).is_equal(forward)


func test_a_form_card_turned_back_mid_flight_starts_from_its_current_rectangle_and_alpha() -> void:
	StudioTokens.TR_REVERSE = 1
	var ball: AddBall = auto_free(AddBall.new())
	var entry: FormEntry = auto_free(FormEntry.new())
	add_child(ball)
	add_child(entry)
	var opening := entry.open(ball)
	opening.custom_step(0.12)
	var rectangle := entry._card.get_rect()
	var alpha := entry._card.modulate.a
	var closing := entry.close(ball)
	closing.pause()
	assert_bool(entry._card.get_rect().is_equal_approx(rectangle)).is_true()
	assert_float(entry._card.modulate.a).is_equal(alpha)
	closing.custom_step(1.0)
	assert_bool(entry._card.visible).is_false()


func test_settle_waits_for_a_moving_start_but_never_delays_an_idle_start_or_navigation() -> void:
	var fixture := preload("res://test/carousel/fixtures.gd")
	var carousel := await fixture.shown_carousel(self)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	assert_bool(carousel._needs_settle(accept)).is_false()
	StudioTokens.try_timing(&"TR_SETTLE_S", 0.4)
	assert_bool(carousel._needs_settle(accept)).is_false()
	carousel._consoles.step(1)
	assert_bool(carousel._needs_settle(accept)).is_true()
	var direction := InputEventAction.new()
	direction.action = &"carousel_right"
	direction.pressed = true
	assert_bool(carousel._needs_settle(direction)).is_false()
	carousel._unhandled_input(accept)
	assert_bool(carousel._settle_waiting).is_true()
	assert_int(carousel._screen).is_equal(Carousel.Screen.CONSOLES)
	carousel._consoles.settle()
	carousel._consoles._swap_s = ConsoleRow._IN_S
	await await_idle_frame()
	assert_bool(carousel._settle_waiting).is_false()
	assert_int(carousel._screen).is_equal(Carousel.Screen.ENTERING)


func test_all_transition_defaults_keep_the_app_values_recorded_before_tokenization() -> void:
	assert_float(StudioTokens.TR_GAMES_FADE_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_GAMES_RAIL_S).is_equal_approx(0.3, 1e-6)
	assert_float(StudioTokens.TR_GAMES_DROP_PX).is_equal_approx(51.2, 1e-6)
	assert_float(StudioTokens.TR_GAMES_LOGO_S).is_equal_approx(0.0, 1e-6)
	assert_float(StudioTokens.TR_GAMES_RAIL_BACK_S).is_equal_approx(0.31, 1e-6)
	assert_float(StudioTokens.TR_GAMES_HINTS_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_RING_OPEN_S).is_equal_approx(0.4, 1e-6)
	assert_float(StudioTokens.TR_RING_SINK_S).is_equal_approx(0.24, 1e-6)
	assert_float(StudioTokens.TR_RING_RISE_S).is_equal_approx(0.36, 1e-6)
	assert_float(StudioTokens.TR_RING_RISE_AT_S).is_equal_approx(0.04, 1e-6)
	assert_float(StudioTokens.TR_RING_MARKS_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_RING_MARKS_AT_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_RING_MIDDLE_AT_S).is_equal_approx(0.16, 1e-6)
	assert_float(StudioTokens.TR_RING_MIDDLE_S).is_equal_approx(0.24, 1e-6)
	assert_float(StudioTokens.TR_RING_CLOSE_S).is_equal_approx(0.62, 1e-6)
	assert_float(StudioTokens.TR_FORM_OPEN_S).is_equal_approx(0.38, 1e-6)
	assert_float(StudioTokens.TR_FORM_AT_S).is_equal_approx(0.06, 1e-6)
	assert_float(StudioTokens.TR_FORM_FADE_S).is_equal_approx(0.3, 1e-6)
	assert_float(StudioTokens.TR_FORM_OUT_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_FORM_SLIDE_PX).is_equal_approx(64.0, 1e-6)
	assert_float(StudioTokens.TR_FORM_LIFT_PX).is_equal_approx(51.2, 1e-6)
	assert_float(StudioTokens.TR_FORM_BACK_S).is_equal_approx(0.38, 1e-6)
	assert_float(StudioTokens.TR_FORM_LEAVE_S).is_equal_approx(0.26, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_OPEN_S).is_equal_approx(0.38, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_AT_S).is_equal_approx(0.06, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_OUT_S).is_equal_approx(0.15, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_LINES_AT_S).is_equal_approx(0.15, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_IN_S).is_equal_approx(0.23, 1e-6)
	assert_float(StudioTokens.TR_FORM_CHOOSER_TITLE_PX).is_equal_approx(10.24, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_CARD_S).is_equal_approx(0.24, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_LAYER_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_MODEL_S).is_equal_approx(0.08, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_CARD_S).is_equal_approx(0.32, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_SHIFT_PX).is_equal_approx(38.4, 1e-6)
	assert_float(StudioTokens.TR_CHOOSER_TITLE_PX).is_equal_approx(10.24, 1e-6)
	assert_float(StudioTokens.TR_PLACE_BACK_S).is_equal_approx(0.4, 1e-6)
	assert_float(StudioTokens.TR_PLACE_ARC_PX).is_equal_approx(38.4, 1e-6)
	assert_float(StudioTokens.TR_PLACE_OTHERS_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_PLACE_MARKS_S).is_equal_approx(0.16, 1e-6)
	assert_float(StudioTokens.TR_PLACE_AT_S).is_equal_approx(0.08, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_OPEN_S).is_equal_approx(0.36, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_LEAVE_S).is_equal_approx(0.18, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_RECEDE).is_equal_approx(0.96, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_DROP_PX).is_equal_approx(51.2, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_SINK_S).is_equal_approx(0.24, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_VEIL_AT_S).is_equal_approx(0.08, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_VEIL_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_CARD_AT_S).is_equal_approx(0.12, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_RISE_PX).is_equal_approx(38.4, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_HINTS_S).is_equal_approx(0.15, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_CLOSE_S).is_equal_approx(0.36, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_CARD_OUT_S).is_equal_approx(0.18, 1e-6)
	assert_float(StudioTokens.TR_SETTINGS_BACK_AT_S).is_equal_approx(0.14, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_OPEN_S).is_equal_approx(0.4, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_TRAVEL_S).is_equal_approx(0.36, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_FADE_S).is_equal_approx(0.15, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_POOL_S).is_equal_approx(0.36, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_ZONE_AT_S).is_equal_approx(0.24, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_NAME_AT_S).is_equal_approx(0.2, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_RISE_PX).is_equal_approx(20.48, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_CALLOUT_AT_S).is_equal_approx(0.28, 1e-6)
	assert_float(StudioTokens.TR_PROPERTIES_BACK_S).is_equal_approx(0.38, 1e-6)


func test_the_add_ball_duration_keeps_its_app_default() -> void:
	assert_float(StudioTokens.TR_BALL_MORPH_S).is_equal(0.34)


func test_unknown_curve_values_are_refused_without_changing_the_curve() -> void:
	var original_curve := StudioTokens.TR_FORM_OPEN_S_CURVE
	assert_bool(StudioTokens.try_timing(&"TR_FORM_OPEN_S_CURVE", 99.0)).is_false()
	assert_int(StudioTokens.TR_FORM_OPEN_S_CURVE).is_equal(original_curve)
	StudioTokens.TR_FORM_OPEN_S_CURVE = original_curve


func test_every_transition_curve_default_uses_its_original_named_easing() -> void:
	assert_int(StudioTokens.TR_GAMES_LOGO_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_RING_OPEN_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_RING_RISE_S_CURVE).is_equal(Motion.Easing.ARRIVE)
	assert_int(StudioTokens.TR_RING_MIDDLE_S_CURVE).is_equal(Motion.Easing.EASE_OUT)
	assert_int(StudioTokens.TR_RING_CLOSE_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_FORM_OPEN_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_FORM_BACK_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_CHOOSER_CARD_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_SETTINGS_OPEN_S_CURVE).is_equal(Motion.Easing.ARRIVE)
	assert_int(StudioTokens.TR_SETTINGS_CARD_S_CURVE).is_equal(Motion.Easing.ARRIVE)
	assert_int(StudioTokens.TR_SETTINGS_LEAVE_S_CURVE).is_equal(Motion.Easing.EASE_IN)
	assert_int(StudioTokens.TR_SETTINGS_SINK_S_CURVE).is_equal(Motion.Easing.SINK)
	assert_int(StudioTokens.TR_SETTINGS_CARD_OUT_S_CURVE).is_equal(Motion.Easing.EASE_IN)
	assert_int(StudioTokens.TR_PROPERTIES_TRAVEL_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_int(StudioTokens.TR_PROPERTIES_POOL_S_CURVE).is_equal(Motion.Easing.EASE_OUT)


func test_distinct_motions_have_independent_live_values() -> void:
	assert_bool(StudioTokens.try_timing(&"TR_FORM_BACK_S_CURVE", float(Motion.Easing.EASE_IN))).is_true()
	assert_int(StudioTokens.TR_FORM_OPEN_S_CURVE).is_equal(Motion.Easing.GLIDE)
	assert_bool(StudioTokens.try_timing(&"TR_FORM_CHOOSER_TITLE_PX", 18.0)).is_true()
	assert_float(StudioTokens.TR_CHOOSER_TITLE_PX).is_equal_approx(10.24, 1e-6)
	assert_bool(StudioTokens.try_timing(&"TR_SETTINGS_CARD_S", 0.5)).is_true()
	assert_float(StudioTokens.TR_SETTINGS_OPEN_S).is_equal_approx(0.36, 1e-6)
	assert_bool(StudioTokens.try_timing(&"TR_CHOOSER_LINES_AT_S", 0.2)).is_true()
	StudioTokens.try_timing(&"TR_FORM_BACK_S_CURVE", float(Motion.Easing.GLIDE))
	StudioTokens.try_timing(&"TR_FORM_CHOOSER_TITLE_PX", 10.24)
	StudioTokens.try_timing(&"TR_SETTINGS_CARD_S", 0.24)
	StudioTokens.try_timing(&"TR_CHOOSER_LINES_AT_S", 0.15)


func test_default_interrupted_form_return_starts_at_the_field() -> void:
	StudioTokens.TR_REVERSE = 0
	var ball: AddBall = auto_free(AddBall.new())
	var entry: FormEntry = auto_free(FormEntry.new())
	add_child(ball)
	add_child(entry)
	var opening := entry.open(ball)
	opening.custom_step(0.05)
	var closing := entry.close(ball)
	closing.pause()
	assert_bool(entry._card.get_rect().is_equal_approx(FormEntry.FIELD)).is_true()
	closing.custom_step(1.0)


class CountedDirection extends HeldDirection:
	var calls := 0

	func update(event: InputEvent) -> bool:
		calls += 1
		return super.update(event)


func test_settle_processes_each_physical_input_once() -> void:
	var fixture := preload("res://test/carousel/fixtures.gd")
	var carousel := await fixture.shown_carousel(self)
	var directions := CountedDirection.new()
	carousel._direction = directions
	StudioTokens.TR_SETTLE_S = 0.4
	carousel._consoles.step(1)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	carousel._unhandled_input(accept)
	var another := InputEventAction.new()
	another.action = &"open_settings"
	another.pressed = true
	carousel._unhandled_input(another)
	assert_int(directions.calls).is_equal(2)
	carousel._consoles.settle()
	carousel._consoles._swap_s = ConsoleRow._IN_S
	await await_idle_frame()
	assert_int(directions.calls).is_equal(2)


func test_form_open_and_close_use_their_own_curves() -> void:
	StudioTokens.TR_FORM_OPEN_S_CURVE = Motion.Easing.GLIDE
	StudioTokens.TR_FORM_BACK_S_CURVE = Motion.Easing.LINEAR
	var ball: AddBall = auto_free(AddBall.new())
	var entry: FormEntry = auto_free(FormEntry.new())
	add_child(ball)
	add_child(entry)
	var opening := entry.open(ball)
	opening.custom_step(0.19)
	assert_float(entry._flown).is_equal_approx(Motion.eased(Motion.Easing.GLIDE, 0.5), 0.01)
	var closing := entry.close(ball)
	closing.custom_step(0.19)
	assert_float(entry._flown).is_equal_approx(0.5, 0.01)
	StudioTokens.TR_FORM_BACK_S_CURVE = Motion.Easing.GLIDE
