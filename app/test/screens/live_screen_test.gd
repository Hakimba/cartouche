# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Never a dead screen: whatever the presses, something shows and takes the next one (INV-20).

const Fixtures := preload("res://test/screens/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"
	get_viewport().msaa_3d = Viewport.MSAA_4X


## The carousel of a device whose library holds [param consoles], an emulator installed for every platform, once a
## person can act on it.
func _shown(consoles: Dictionary[String, int]) -> Array:
	var device := Fixtures.past_first_launch(self, consoles)
	device.players_everywhere = true
	var carousel := Fixtures.fresh_carousel(self, device)
	await Fixtures.wait(self, func() -> bool: return Fixtures.alive(carousel))
	return [device, carousel]


## [param platform_id] added through the form, from "No console" or the "+", and placed after the last console when
## the ring places it; the consoles screen back on it.
func _add(carousel: Carousel, device: Fixtures.NewDevice, platform_id: String) -> void:
	device.order = PackedStringArray(device.consoles.keys())
	if device.consoles.is_empty():
		assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
		await Fixtures.joypad(self, JOY_BUTTON_A)
		assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	else:
		await Fixtures.open_add_console(self, carousel)
	await Fixtures.wait(self, func() -> bool: return Fixtures.alive(carousel))
	await Fixtures.choose_console(self, carousel, device, platform_id)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	if device.consoles.size() > 2:
		await Fixtures.wait(self, func() -> bool:
			return carousel._order._placing != null and carousel._order._placing.state == Placing.State.CHOOSING)
		await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal(platform_id)


func test_after_a_console_added_the_form_opened_again_from_the_plus_shows_with_its_focus_and_adds_a_third_through_the_ring() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	await _add(carousel, device, "gc")
	await Fixtures.open_add_console(self, carousel)
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.wait(self, func() -> bool: return form.modulate.a == 1.0 and Fixtures.alive(carousel))
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	assert_str(form.platform_id).is_empty()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)
	await _add(carousel, device, "gba")
	assert_array(carousel._platform_ids()).contains_exactly_in_any_order(["ps2", "gc", "gba"])
	# Once more after the ring placed it.
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.wait(self, func() -> bool: return form.modulate.a == 1.0 and Fixtures.alive(carousel))
	assert_str(Fixtures.focus(self).name).is_equal("Type")


func test_after_a_console_added_X_on_the_ring_shows_its_form_and_B_goes_back_to_the_ring() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	await _add(carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.wait(self, func() -> bool: return form.modulate.a == 1.0 and Fixtures.alive(carousel))
	assert_str(Fixtures.focus(self).name).is_equal("Emulator")
	assert_bool(form.is_editing()).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool:
		return Fixtures.shown_screen(carousel) == null and Fixtures.alive(carousel))
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


## From a library holding [param consoles], one console added through the form, then [param count] steps drawn by
## [param random]: the pad's directions, A, B, X, Y, the "+" (up held, A), and the app put aside and brought back, the
## consoles' folders as they were or with games copied in or all deleted from one of them. After each, a person can
## act within the wait's bound, whatever transition the step started, and what the carousel shows settles to its
## screen's; the walk reaches the form again. Frames are fixed at 60 a second (scripts/test_godot.sh), so a seed walks
## the same path whatever the machine's load.
func _walk(consoles: Dictionary[String, int], test_seed: int, count := 150) -> void:
	var shown := await _shown(consoles)
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	await _add(carousel, device, "psx")
	var random := RandomNumberGenerator.new()
	random.seed = test_seed
	var pads: Array[JoyButton] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
	var seen := {}
	for press in count:
		# After the pads, two draws of the "+", for the walk to come back to the form, then three of the app put aside:
		# one with its folders as they were, two with them changed.
		var drawn := random.randi_range(0, pads.size() + 4)
		if drawn < pads.size():
			await Fixtures.joypad(self, pads[drawn])
		elif drawn <= pads.size() + 1:
			await Fixtures.hold(self, &"ui_up")
			await Fixtures.joypad(self, JOY_BUTTON_A)
			await Fixtures.hold(self, &"ui_up", false)
		else:
			await _put_aside(carousel, device, random if drawn > pads.size() + 2 else null)
		if not await Fixtures.until(self, func() -> bool: return Fixtures.alive(carousel)):
			fail("dead after press %d (%d) on %s, focus %s" % [press, drawn, Fixtures.shown_screen(carousel),
				Fixtures.focus(self)])
			return
		if not await Fixtures.until(self, func() -> bool: return Fixtures.ScreenAgreement.disagreement(carousel).is_empty()):
			fail("after press %d (%d), %s" % [press, drawn, Fixtures.ScreenAgreement.disagreement(carousel)])
			return
		var unseen := _unseen_3d(carousel)
		if unseen:
			fail("after press %d (%d), the carousel's 3D is not drawn but %s shows in it" % [press, drawn, unseen])
			return
		var screen := Fixtures.shown_screen(carousel)
		seen[screen.name if screen else Carousel.Screen.keys()[carousel.screen()]] = true
	# Against an empty walk: it went back to the form after the console added.
	assert_dict(seen).contains_keys(["AddConsole"])


## The carousel's own 3D is drawn on every frame something of its world shows, not only once a press settled: checked
## at each frame as it is drawn (when the next one starts: headless, the renderer gives no frame_pre_draw), into the
## games and out, through a game's properties, a launch and a toss.
func test_the_carousel_s_3d_is_drawn_on_every_frame_its_world_shows_something() -> void:
	var shown := await _shown({"ps2": 6})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	var unseen: Array[String] = []
	var frames: Array[int] = [0]
	var check := func() -> void:
		frames[0] += 1
		var part := _unseen_3d(carousel)
		if part and unseen.is_empty():
			unseen.append("%s on screen %s" % [part, Carousel.Screen.keys()[carousel.screen()]])
	get_tree().process_frame.connect(check)
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await Fixtures.action(self, &"open_properties")
	await Fixtures.on_screen(self, carousel, Carousel.Screen.PROPERTIES)
	await Fixtures.settled(self, carousel)
	await Fixtures.press_to(self, carousel, JOY_BUTTON_B, Carousel.Screen.GAMES)
	await Fixtures.settled(self, carousel)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.wait(self, func() -> bool: return not carousel._toss.is_busy())
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.launches == 1)
	await Fixtures.settled(self, carousel)
	await Fixtures.press_to(self, carousel, JOY_BUTTON_B, Carousel.Screen.CONSOLES)
	await Fixtures.settled(self, carousel)
	get_tree().process_frame.disconnect(check)
	assert_array(unseen).is_empty()
	assert_int(frames[0]).is_greater(60)


## A part of the carousel's own world its camera would show while [method Carousel.shows_3d] says nothing shows (its
## 3D is then not drawn), empty when none: what a new 3D part of the carousel must be added to.
func _unseen_3d(carousel: Carousel) -> String:
	if carousel.shows_3d():
		return ""
	var camera := carousel.get_viewport().get_camera_3d()
	var parts: Array[Node] = [carousel]
	while not parts.is_empty():
		var part: Node = parts.pop_back()
		if part is SubViewport and (part as SubViewport).own_world_3d:
			continue
		var shown := part as GeometryInstance3D
		if shown and shown.is_visible_in_tree() and shown.layers & camera.cull_mask:
			return str(carousel.get_path_to(shown))
		parts.append_array(part.get_children())
	return ""


## The app put aside and brought back, its consoles' folders read again; with [param random], one console drawn by it,
## as often the one selected as any, has a game copied in, or all of its games deleted while another console keeps some.
func _put_aside(carousel: Carousel, device: Fixtures.NewDevice, random: RandomNumberGenerator) -> void:
	await Fixtures.pause(self)
	var with_games := device.consoles.keys().filter(func(platform_id: String) -> bool:
		return device.consoles[platform_id] > 0)
	if random and not with_games.is_empty():
		var selected := carousel._shelves[carousel._shelf].platform_id if not carousel._shelves.is_empty() else ""
		var drawn: String = selected if selected in with_games and random.randi_range(0, 1) == 0 \
			else with_games[random.randi_range(0, with_games.size() - 1)]
		device.consoles[drawn] = 0 if with_games.size() > 1 and random.randi_range(0, 1) == 0 \
			else device.consoles[drawn] + 1
	await Fixtures.resume(self)
	await Fixtures.until(self, func() -> bool: return not carousel._new_games._reading)


func test_inv_20_a_walk_of_presses_from_no_console_never_leaves_a_dead_screen() -> void:
	await _walk({}, 360441)


func test_inv_20_a_walk_of_presses_from_one_console_never_leaves_a_dead_screen() -> void:
	await _walk({"ps2": 3}, 360412)


func test_inv_20_a_walk_of_presses_from_two_consoles_never_leaves_a_dead_screen() -> void:
	await _walk({"ps2": 3, "gc": 2}, 360433)


func test_inv_20_a_walk_of_presses_from_three_consoles_never_leaves_a_dead_screen() -> void:
	await _walk({"ps2": 3, "gc": 2, "gba": 2}, 360414)
