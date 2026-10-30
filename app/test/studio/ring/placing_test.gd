# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Placing a console just added on the ring of the others: the state machine on its own, then the whole flow from
## Ajouter to the consoles screen, with the form and the order the plugin keeps.

const Fixtures := preload("res://test/screens/fixtures.gd")


## The states each press leaves a state for, and what it asks: the table of the flow.
func _expected(state: Placing.State, pressed: Placing.Press) -> Array:
	if state != Placing.State.ARRIVING and state != Placing.State.CHOOSING:
		return [state, Placing.Action.IGNORED]
	match pressed:
		Placing.Press.A:
			return [Placing.State.FLYING, Placing.Action.FLY]
		Placing.Press.B:
			return [Placing.State.BACK, Placing.Action.LEAVE]
	return [state, Placing.Action.MOVE]


func _ring(count: int) -> Array[String]:
	var ids: Array[String] = []
	for k in count:
		ids.append("c%d" % k)
	return ids


## A flow put in [param state] by the presses and the ends that lead there.
func _in(state: Placing.State, count := 4) -> Placing:
	var placing := Placing.new(_ring(count))
	match state:
		Placing.State.FORM:
			return placing
		Placing.State.ARRIVING:
			placing.start()
		Placing.State.CHOOSING:
			placing.start()
			placing.done()
		Placing.State.BACK:
			placing.start()
			placing.press(Placing.Press.B)
		_:
			placing.start()
			placing.press(Placing.Press.A)
			for step: Placing.State in [Placing.State.FLYING, Placing.State.LANDING, Placing.State.MORPHING, Placing.State.DONE]:
				if state == step:
					break
				placing.done()
	assert_int(placing.state).is_equal(state)
	return placing


func test_every_press_in_every_state_does_what_the_table_says() -> void:
	for state: Placing.State in Placing.State.values():
		for pressed: Placing.Press in Placing.Press.values():
			var placing := _in(state, 4)
			var gap := placing.gap
			var expected := _expected(state, pressed)
			assert_int(placing.press(pressed)).is_equal(expected[1])
			assert_int(placing.state).is_equal(expected[0])
			var moved := gap
			if expected[1] == Placing.Action.MOVE:
				moved = posmod(gap + (1 if pressed == Placing.Press.RIGHT else -1), 4)
			assert_int(placing.gap).is_equal(moved)


func test_a_timed_state_ends_on_the_next_and_the_others_stay() -> void:
	var next := {Placing.State.ARRIVING: Placing.State.CHOOSING, Placing.State.FLYING: Placing.State.LANDING,
		Placing.State.LANDING: Placing.State.MORPHING, Placing.State.MORPHING: Placing.State.DONE,
		Placing.State.BACK: Placing.State.FORM}
	for state: Placing.State in Placing.State.values():
		var placing := _in(state)
		placing.done()
		assert_int(placing.state).is_equal(next.get(state, state))


func test_the_form_starts_the_flow_once_and_the_gap_first_opens_after_the_last_console() -> void:
	for count in range(1, 13):
		var placing := Placing.new(_ring(count))
		assert_int(placing.gap).is_equal(count - 1)
		assert_int(placing.press(Placing.Press.A)).is_equal(Placing.Action.IGNORED)
		placing.start()
		assert_int(placing.state).is_equal(Placing.State.ARRIVING)
		placing.done()
		placing.start()
		assert_int(placing.state).is_equal(Placing.State.CHOOSING)


func test_the_gap_wraps_both_ways_and_a_ring_of_one_has_nothing_to_move() -> void:
	var placing := _in(Placing.State.CHOOSING, 3)
	placing.press(Placing.Press.RIGHT)
	assert_int(placing.gap).is_equal(0)
	placing.press(Placing.Press.LEFT)
	assert_int(placing.gap).is_equal(2)
	var alone := _in(Placing.State.CHOOSING, 1)
	assert_int(alone.press(Placing.Press.LEFT)).is_equal(Placing.Action.IGNORED)
	assert_int(alone.press(Placing.Press.RIGHT)).is_equal(Placing.Action.IGNORED)
	assert_int(alone.gap).is_equal(0)
	assert_int(alone.press(Placing.Press.A)).is_equal(Placing.Action.FLY)


func test_the_gap_counts_among_all_the_others_shown_the_consoles_without_a_model_included() -> void:
	var placing := Placing.new(["a", "c"] as Array[String])
	var shown: Array[String] = ["a", "x", "c", "y"]
	# After "a" is the gap before "x"; after "c" the one before "y".
	placing.gap = 0
	assert_int(placing.shown_gap(shown)).is_equal(1)
	placing.gap = 1
	assert_int(placing.shown_gap(shown)).is_equal(3)


func test_a_seeded_walk_of_presses_keeps_to_the_table_and_the_gap_in_range() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1202
	var presses := 0
	for walk in 40:
		var count := random.randi_range(1, 12)
		var placing := Placing.new(_ring(count))
		placing.start()
		var model := Placing.State.ARRIVING
		var gap := count - 1
		for _step in 60:
			if random.randf() < 0.25:
				placing.done()
				model = {Placing.State.ARRIVING: Placing.State.CHOOSING, Placing.State.FLYING: Placing.State.LANDING,
					Placing.State.LANDING: Placing.State.MORPHING, Placing.State.MORPHING: Placing.State.DONE,
					Placing.State.BACK: Placing.State.FORM}.get(model, model)
			else:
				var pressed: Placing.Press = Placing.Press.values()[random.randi() % 4]
				var expected := _expected(model, pressed)
				if expected[1] == Placing.Action.MOVE and count > 1:
					gap = posmod(gap + (1 if pressed == Placing.Press.RIGHT else -1), count)
				elif expected[1] == Placing.Action.MOVE:
					expected = [model, Placing.Action.IGNORED]
				assert_int(placing.press(pressed)).is_equal(expected[1])
				model = expected[0]
				presses += 1
			assert_int(placing.state).is_equal(model)
			assert_int(placing.gap).is_equal(gap)
			assert_int(placing.gap).is_between(0, count - 1)
	assert_int(presses).is_greater(1000)


## The carousel on a device holding [param consoles] (games by platform id) with the form filled for [param added],
## the order the plugin keeps [param order]; the form's Add is next.
func _form_filled(consoles: Dictionary[String, int], added: String, order: PackedStringArray) -> Array:
	var device := Fixtures.past_first_launch(self, consoles)
	device.players_everywhere = true
	device.order = order
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_console(self, carousel, device, added)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	return [carousel, device]


## The ring once the form's Add is pressed and the console is in the middle, a gap to choose.
func _on_ring(carousel: Carousel) -> ConsoleOrder:
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var order := carousel._order
	assert_bool(await Fixtures.until(self, func() -> bool:
		return order._placing != null and order._placing.state == Placing.State.CHOOSING)).is_true()
	# The consoles are placed a frame after the state changes.
	await await_idle_frame()
	return order


func _placed(carousel: Carousel) -> bool:
	return await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)


func test_leave_takes_the_form_away_without_a_press_or_a_focus_and_resume_brings_it_back_filled_on_Add() -> void:
	var setup := await _form_filled({"ps2": 1, "gc": 1}, "psx", PackedStringArray(["ps2", "gc"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var add: Button = form.get_node("%Add")
	add.disabled = true
	var gone := form.leave()
	assert_object(Fixtures.focus(self)).is_null()
	assert_int(form.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	# A press reaches nothing of it.
	await Fixtures.action(self, &"ui_left")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return not gone.is_running())).is_true()
	assert_bool(form.visible).is_false()
	assert_array(device.set_up).is_empty()
	form.resume()
	assert_int(form.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_bool(form.visible).is_true()
	assert_bool(add.disabled).is_false()
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	assert_str(form.platform_id).is_equal("psx")


func test_Ajouter_brings_the_ring_and_A_flies_the_console_into_the_chosen_gap_saves_the_order_and_opens_the_consoles_on_it() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var order := await _on_ring(carousel)
	assert_bool(order.is_open()).is_true()
	assert_bool((carousel.get_node("%Screens/AddConsole") as AddConsole).is_visible_in_tree()).is_false()
	assert_int(carousel._consoles.flier).is_equal(carousel._platform_ids().find("psx"))
	assert_array(device.placed).is_empty()
	# The first gap is after the last console; two steps right is after the second.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_int(order._placing.gap).is_equal(1)
	var reordered: Array[bool] = []
	order.ordered.connect(func(_ids: Array[String]) -> void:
		var ids := carousel._platform_ids()
		assert_int(carousel._consoles.flier).is_equal(ids.find("psx"))
		for k in ids.size():
			assert_float(carousel._consoles.ring_angles[k]).is_equal(order._angle.get(ids[k], 0.0))
		reordered.append(true), CONNECT_ONE_SHOT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_int(order._placing.state).is_equal(Placing.State.FLYING)
	assert_bool(await _placed(carousel)).is_true()
	assert_array(reordered).is_equal([true])
	assert_array(device.placed).is_equal([["psx", 2]])
	assert_array(carousel._platform_ids()).is_equal(["ps2", "gc", "psx", "gba"])
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("psx")
	assert_int(carousel._consoles.selected_index()).is_equal(2)
	assert_int(carousel._consoles.flier).is_equal(-1)
	assert_int(carousel._consoles.pointed).is_equal(-1)
	assert_bool(order.visible).is_false()
	assert_object(order._placing).is_null()
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._console_title.modulate.a == 1.0)).is_true()
	assert_bool(carousel._rail.visible).is_true()
	# And the consoles screen works as before.
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)


func test_the_gap_chosen_at_either_end_is_the_one_the_order_is_saved_with() -> void:
	for steps: int in [0, 1]:
		var setup := await _form_filled({"ps2": 1, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
		var carousel: Carousel = setup[0]
		await _on_ring(carousel)
		for _step in steps:
			await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
		await Fixtures.joypad(self, JOY_BUTTON_A)
		assert_bool(await _placed(carousel)).is_true()
		# Gap 2, the end, then 0 steps on, the gap after the first console (shown gap 1).
		assert_array(setup[1].placed).is_equal([["psx", 3 if steps == 0 else 1]])
		carousel.queue_free()
		await await_idle_frame()


func test_B_flies_the_console_back_to_the_form_filled_with_its_focus_on_Add_and_places_nothing() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var order := await _on_ring(carousel)
	assert_bool(form.is_visible_in_tree()).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_int(order._placing.state).is_equal(Placing.State.BACK)
	# The form is wanted back as the ring leaves, then the ring is gone and the consoles screen is not shown.
	assert_bool(await Fixtures.until(self, func() -> bool: return form.is_visible_in_tree())).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return not order.visible)).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return form.modulate.a == 1.0)).is_true()
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	assert_str(form.platform_id).is_equal("psx")
	assert_array(device.placed).is_empty()
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_false()
	assert_float(carousel._consoles.wheel).is_equal(0.0)
	# Add again: the ring again, and A places it.
	await _on_ring(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _placed(carousel)).is_true()
	assert_array(device.placed).is_equal([["psx", 3]])


func test_every_press_is_ignored_from_A_until_the_consoles_screen_shows() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var order := await _on_ring(carousel)
	# From the gap after the last console, one step right is the gap after the first.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var gap := order._placing.gap
	var seen: Array[Placing.State] = []
	var pads: Array[JoyButton] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B, JOY_BUTTON_A]
	var step := 0
	while order._placing != null and step < 400:
		if not seen.has(order._placing.state):
			seen.append(order._placing.state)
		await Fixtures.joypad(self, pads[step % 4])
		step += 1
		if order._placing != null:
			assert_int(order._placing.gap).is_equal(gap)
			assert_int(order._placing.state).is_not_equal(Placing.State.BACK)
	assert_array(seen).contains([Placing.State.FLYING, Placing.State.LANDING, Placing.State.MORPHING])
	assert_bool(await _placed(carousel)).is_true()
	assert_array(setup[1].placed).is_equal([["psx", 1]])


## The ring after Add with the plugin refusing the placing as [param code] says: the console flies back to the filled form
## and nothing is saved nor reordered.
func _refused(code: String) -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var order := await _on_ring(carousel)
	var shown := carousel._platform_ids()
	var orders: Array[Array] = []
	order.ordered.connect(func(saved: Array[String]) -> void: orders.append(saved))
	if code == "not_in_library":
		device.consoles["psx"] = 0
	# The plugin's order knows two others, not three: the gap 3 is out of range.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return order._placing == null and form.is_visible_in_tree() and form.modulate.a == 1.0)).is_true()
	assert_array(device.placed).is_equal([["psx", 3]])
	assert_array(orders).is_empty()
	assert_array(carousel._platform_ids()).is_equal(shown)
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	assert_bool(order.visible).is_false()
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_false()
	assert_int(carousel._consoles.flier).is_equal(-1)
	assert_int(carousel._consoles.pointed).is_equal(-1)


func test_a_placing_the_plugin_refuses_as_out_of_range_flies_the_console_back_to_the_form_and_changes_no_order() -> void:
	await _refused("gap_out_of_range")


func test_a_placing_the_plugin_refuses_as_not_in_the_library_flies_the_console_back_to_the_form_and_changes_no_order() -> void:
	await _refused("not_in_library")


func test_a_click_or_a_tap_on_Add_while_the_console_flies_back_does_nothing() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var add: Button = form.get_node("%Add")
	var order := await _on_ring(carousel)
	var added := device.set_up.size()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return form.is_visible_in_tree())).is_true()
	assert_int(order._placing.state).is_equal(Placing.State.BACK)
	var centre := add.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = get_tree().root.get_final_transform() * centre
		click.global_position = click.position
		Input.parse_input_event(click)
		await await_idle_frame()
	await Fixtures.finger(self, centre, true)
	await Fixtures.finger(self, centre, false)
	assert_bool(await Fixtures.until(self, func() -> bool: return order._placing == null)).is_true()
	assert_int(device.set_up.size()).is_equal(added)
	assert_array(device.placed).is_empty()


func test_B_pressed_twice_flies_back_once_and_A_then_B_while_flying_places_it_once() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var order := await _on_ring(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_int(order._placing.state).is_equal(Placing.State.BACK)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return order._placing == null and form.is_visible_in_tree() and form.modulate.a == 1.0)).is_true()
	assert_array(device.placed).is_empty()
	# Again: A, then B in the middle of the flight, which it ignores.
	order = await _on_ring(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_int(order._placing.state).is_equal(Placing.State.FLYING)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_int(order._placing.state).is_not_equal(Placing.State.BACK)
	assert_bool(await _placed(carousel)).is_true()
	assert_array(device.placed).is_equal([["psx", 3]])


func test_with_one_other_console_the_added_console_glides_to_the_hero_without_a_ring() -> void:
	var setup := await _form_filled({"ps2": 2}, "gba", PackedStringArray(["ps2"]))
	var carousel: Carousel = setup[0]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _placed(carousel)).is_true()
	assert_bool(carousel._order.is_open()).is_false()
	assert_array(setup[1].placed).is_empty()
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gba")
	assert_float(carousel._consoles.wheel).is_equal(0.0)


func test_a_walk_of_presses_through_the_whole_flow_leaves_one_placing_per_A_and_nothing_stuck() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 77
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1, "nes": 1}, "psx",
		PackedStringArray(["ps2", "gc", "gba", "nes"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var order := carousel._order
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var pads: Array[JoyButton] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_B]
	var legal: Dictionary[Placing.State, Array] = {Placing.State.FORM: [Placing.State.ARRIVING],
		Placing.State.ARRIVING: [Placing.State.CHOOSING,
		Placing.State.FLYING, Placing.State.BACK], Placing.State.CHOOSING: [Placing.State.FLYING, Placing.State.BACK],
		Placing.State.FLYING: [Placing.State.LANDING], Placing.State.LANDING: [Placing.State.MORPHING],
		Placing.State.MORPHING: [Placing.State.DONE], Placing.State.BACK: [Placing.State.FORM]}
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return order._placing != null)).is_true()
	var last := Placing.State.FORM
	var gap_at_fly := -1
	var steps := 0
	while steps < 1500 and not (Fixtures.shown_screen(carousel) == null and carousel._shown):
		steps += 1
		var placing := order._placing
		if placing != null:
			if placing.state != last:
				assert_bool(legal[last].has(placing.state)).is_true()
				if placing.state == Placing.State.FLYING:
					gap_at_fly = placing.shown_gap(["ps2", "gc", "gba", "nes"] as Array[String])
				last = placing.state
			assert_int(placing.gap).is_between(0, 3)
			assert_bool(is_finite(carousel._consoles.flier_stand.centre.x)).is_true()
			await Fixtures.joypad(self, pads[random.randi() % 4])
		elif form.is_visible_in_tree() and form.modulate.a == 1.0 and Fixtures.focus(self).name == "Add":
			last = Placing.State.FORM
			await Fixtures.joypad(self, JOY_BUTTON_A)
		else:
			await await_idle_frame()
	assert_bool(await _placed(carousel)).is_true()
	assert_array(device.placed).is_equal([["psx", gap_at_fly]])
