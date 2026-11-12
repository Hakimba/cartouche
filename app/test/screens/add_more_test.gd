# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## One more console, from the consoles screen: up turns the "+" ball into "Add a platform", A
## opens the form, and the console added is the one the carousel comes back on.

const Fixtures := preload("res://test/screens/fixtures.gd")


## The carousel shown on a device whose library holds [param consoles] (games by platform id),
## an emulator installed for every platform.
func _shown(consoles: Dictionary[String, int]) -> Array:
	var device := Fixtures.past_first_launch(self, consoles)
	device.players_everywhere = true
	return [device, await Fixtures.shown(self, device)]


## The ring placing the console added, once the console is in the middle and a gap can be chosen.
func _placing(carousel: Carousel) -> void:
	await Fixtures.wait(self, func() -> bool:
		return carousel._order.placing_state() == Placing.State.CHOOSING)


func _ball(carousel: Carousel) -> AddBall:
	return carousel.get_node("%AddBall")


func test_A_on_the_button_adds_one_more_console_chosen_from_nothing_and_the_carousel_comes_back_on_it() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	# Only the media of the library's consoles are loaded: the PS2's disc.
	assert_array(carousel._appearance._models.keys()).contains_exactly(["ps2_dvd"])
	await Fixtures.open_add_console(self, carousel)
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	assert_str((form.get_node("%Title") as Label).text).is_equal("Add a console")
	# Nothing chosen in advance; a console set up already is not offered again.
	assert_str(form.platform_id).is_empty()
	assert_str((form.get_node("%Type") as StepField).text).is_equal("Choose…")
	assert_str((form.get_node("%Emulator") as StepField).text).is_equal("Choose…")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var list: Control = form.get_node("%Choice")
	await Fixtures.wait(self, func() -> bool: return list.visible)
	assert_array(Array((list as StudioChooser).ids())).not_contains(["ps2"])
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	var added := form.platform_id
	device.order = PackedStringArray(["ps2"])
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel.is_shown())
	assert_array(device.placed).is_empty()
	assert_bool(carousel._order.is_open()).is_false()
	assert_bool(device.consoles.has(added)).is_true()
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal(added)
	assert_array(carousel._appearance._models.keys()).contains_exactly_in_any_order(["ps2_dvd", "gba_cart"])
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_true()
	assert_bool(_ball(carousel).is_open).is_false()
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)


func test_the_added_console_is_saved_at_the_chosen_gap_and_the_consoles_come_back_in_that_order() -> void:
	var shown := await _shown({"ps2": 3, "gc": 1})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	device.order = PackedStringArray(["ps2", "gc"])
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _placing(carousel)
	# The first gap is after the last console; one step right is after the first: between the PS2 and the GameCube.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel.is_shown())
	assert_array(device.placed).is_equal([["gba", 1]])
	assert_array(device.order).is_equal(PackedStringArray(["ps2", "gba", "gc"]))
	assert_array(carousel._platform_ids()).is_equal(["ps2", "gba", "gc"])
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gba")


## A stick held up lightly dips under its dead zone and back: up is still held, the button stays.
func test_up_held_lightly_on_the_stick_keeps_the_button_and_A_opens_the_form() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3}))[1]
	for value: float in [-0.6, -0.45, -0.55]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_Y
		stick.axis_value = value
		Input.parse_input_event(stick)
		await await_idle_frame()
	assert_bool(_ball(carousel).is_open).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	var centre := InputEventJoypadMotion.new()
	centre.axis = JOY_AXIS_LEFT_Y
	Input.parse_input_event(centre)


func test_the_models_loaded_ahead_for_types_changed_or_given_up_are_let_go_of() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3}))[1]
	var appearance := carousel._appearance
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_type(self, carousel, "gba")
	await Fixtures.choose_type(self, carousel, "psx")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel.is_shown())
	await Fixtures.wait(self, func() -> bool: return appearance._loading.is_empty())
	assert_array(appearance._models.keys()).contains_exactly(["ps2_dvd"])
	for platform_id: String in ["gba", "psx"]:
		var platform := carousel._platforms[platform_id]
		var scene := appearance._media[appearance._shown(platform.medium, platform.media)].scene
		assert_int(ResourceLoader.load_threaded_get_status(scene)).override_failure_message(platform_id) \
			.is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)


## Frames until the form is gone: whether [param carousel]'s consoles stayed hidden while it showed at all, and show
## from the frame it is gone.
func _consoles_back_once_form_gone(carousel: Carousel) -> bool:
	var consoles: Node3D = carousel.get_node("%Consoles")
	var backdrop: Control = carousel.get_node("%Screens/AddConsole/Backdrop")
	var hidden := true
	while Fixtures.shown_screen(carousel) != null:
		hidden = hidden and not (consoles.visible and backdrop.modulate.a > 0.0)
		await await_idle_frame()
	return hidden and consoles.visible


## The form's life over the consoles, frame by frame: asked by the "+", it comes in over the consoles, which go at once
## as it starts to show (seen through it, a console reads as half transparent), the "+" closed once it covers them;
## given up, they come back whole once it is gone. Given up while it still comes in, the same; asked again then, the
## new form covers them in its turn.
func test_the_form_covers_the_consoles_once_in_and_gives_them_back_whether_given_up_before_or_after() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	var consoles: Node3D = carousel.get_node("%Consoles")
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var backdrop: Control = form.get_node(^"Backdrop")
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_object(Fixtures.shown_screen(carousel)).is_null()
	assert_bool(_ball(carousel).is_open).is_true()
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == form)
	assert_bool(consoles.visible).is_true()
	await Fixtures.wait(self, func() -> bool: return backdrop.modulate.a > 0.0)
	assert_bool(consoles.visible).is_false()
	await Fixtures.wait(self, func() -> bool: return not _ball(carousel).is_open)
	await Fixtures.hold(self, &"ui_up", false)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _consoles_back_once_form_gone(carousel)).is_true()
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.hold(self, &"ui_up", false)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == form)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _consoles_back_once_form_gone(carousel)).is_true()
	assert_bool(carousel.is_shown()).is_true()
	# Given up, nothing is set up and the one shelf stays.
	assert_array(device.set_up).is_empty()
	assert_int(carousel._shelves.size()).is_equal(1)
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.wait(self, func() -> bool: return not consoles.visible)


## The form the placing ring sends back takes no press until its console is back, a push of the stick included.
func test_the_stick_moves_nothing_on_the_form_sent_back_while_its_console_flies_back() -> void:
	var shown := await _shown({"ps2": 3, "gc": 1})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _placing(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return form.phase == Page.Phase.ENTERING)
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	for value: float in [-1.0, 0.0]:
		var push := InputEventJoypadMotion.new()
		push.axis = JOY_AXIS_LEFT_Y
		push.axis_value = value
		Input.parse_input_event(push)
		await await_idle_frame()
	assert_int(form.phase).is_equal(Page.Phase.ENTERING)
	assert_str(Fixtures.focus(self).name).is_equal("Add")


## The form sent back keeps the focus on Add when the app comes back to the screen: its games are counted again and
## Add, greyed meanwhile, takes the focus back once they are.
func test_the_form_sent_back_keeps_the_focus_on_add_as_the_app_comes_back() -> void:
	var shown := await _shown({"ps2": 3, "gc": 1})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _placing(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return form.phase == Page.Phase.LIVE)
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	var previews := device.previews.size()
	await Fixtures.pause(self)
	await Fixtures.resume(self)
	await Fixtures.wait(self, func() -> bool: return device.previews.size() > previews)
	await await_idle_frame()
	assert_str(Fixtures.focus(self).name).is_equal("Add")
