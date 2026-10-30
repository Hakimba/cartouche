# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## At rest a screen is not drawn again: once still, nothing on it writes to the renderer, so the low processor
## mode the app rests in (see [Resting]) draws no frame until something changes. Any write counts, even of a value
## unchanged: the renderer then draws the whole screen again, thirty times a second.

const Fixtures := preload("res://test/screens/fixtures.gd")
## Frames watched once still; a writer at rest writes at every one of them.
const WATCHED := 20
## The clock's minute turning over while watched is a change, drawn once.
const CLOCK_TURNS := 1


func after_test() -> void:
	OS.low_processor_usage_mode = false


func _carousel(consoles: Dictionary[String, int] = {"ps2": 3, "gc": 2}) -> Carousel:
	var device := Fixtures.past_first_launch(self, consoles)
	device.players_everywhere = true
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.alive(carousel))).is_true()
	return carousel


func _on(carousel: Carousel, screen: Carousel.Screen) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == screen)).is_true()


## Of [param frames] frames, how many wrote to the renderer.
func _drawn(frames: int) -> int:
	var drawn := 0
	for frame in frames:
		# Headless never draws: drawing by hand takes the writes so far, the next frame's are its own.
		RenderingServer.force_draw(false)
		await await_idle_frame()
		drawn += 1 if RenderingServer.has_changed() else 0
	return drawn


## [param carousel] left alone until still draws at most the clock's turn; when it draws more, the nodes whose
## processing writes are named.
func _assert_still_draws_nothing(carousel: Carousel) -> void:
	# Whatever a screen plays as it shows ends within this.
	for frame in 180:
		await await_idle_frame()
	carousel._resting.stays_awake = false
	carousel._resting._process(Resting.STILL_AFTER_S + Resting.STOPPING_S)
	await await_idle_frame()
	assert_float(carousel._resting.pace).is_equal(0.0)
	if await _drawn(WATCHED) <= CLOCK_TURNS:
		return
	var processing := ([carousel] + carousel.find_children("*", "Node", true, false)).filter(func(node: Node) -> bool:
		return node.is_processing())
	for node: Node in processing:
		node.set_process(false)
	var writers: Array[String] = []
	for node: Node in processing:
		node.set_process(true)
		if await _drawn(3) > 0:
			writers.append(str(carousel.get_path_to(node)))
		node.set_process(false)
	fail("drawn again at rest, written by the processing of %s" % [writers])


func test_the_consoles_screen_at_rest_draws_nothing_even_after_the_games_were_shown() -> void:
	var carousel := await _carousel()
	await _assert_still_draws_nothing(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _on(carousel, Carousel.Screen.GAMES)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _on(carousel, Carousel.Screen.CONSOLES)
	await _assert_still_draws_nothing(carousel)


func test_the_games_screen_at_rest_draws_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _on(carousel, Carousel.Screen.GAMES)
	await _assert_still_draws_nothing(carousel)


func test_a_game_s_properties_at_rest_draw_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _on(carousel, Carousel.Screen.GAMES)
	await Fixtures.action(self, &"open_properties")
	await _on(carousel, Carousel.Screen.PROPERTIES)
	await _assert_still_draws_nothing(carousel)


func test_a_console_s_properties_at_rest_draw_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.action(self, &"open_properties")
	await _on(carousel, Carousel.Screen.CONSOLE_PROPERTIES)
	await _assert_still_draws_nothing(carousel)


func test_the_settings_at_rest_draw_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.action(self, &"open_settings")
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await Fixtures.until(self, func() -> bool: return menu.state == SettingsMenu.State.OPEN)).is_true()
	await _assert_still_draws_nothing(carousel)


func test_the_form_adding_a_console_at_rest_draws_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.open_add_console(self, carousel)
	await _assert_still_draws_nothing(carousel)


func test_the_screen_without_a_console_at_rest_draws_nothing() -> void:
	var carousel := await _carousel({})
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	await _assert_still_draws_nothing(carousel)


func test_the_platforms_at_rest_draw_nothing() -> void:
	var carousel := await _carousel()
	await Fixtures.action(self, &"open_settings")
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await Fixtures.until(self, func() -> bool: return menu.state == SettingsMenu.State.OPEN)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	await _assert_still_draws_nothing(carousel)
