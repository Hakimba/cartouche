# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Placing a console just added on the ring of the others: the state machine and its geometry on their own, then the
## whole flow from Ajouter to the consoles screen, with the form and the order the plugin keeps.

const Fixtures := preload("res://test/screens/fixtures.gd")

## The window the suites share is put back as it was: some tests of other folders measure in its size.
var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size


func after_test() -> void:
	get_window().size = _window


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


func test_INV_E12_02_the_arrow_is_only_ever_between_two_consoles_never_on_one() -> void:
	for count in range(1, 13):
		for opened in count:
			var ring := Placing.angles(count, opened)
			var arrow := Placing.arrow_angle(count, opened)
			for k in count:
				var away := absf(wrapf(arrow - ring[k], -PI, PI))
				# The gap's two sides are half a gap away at least; the others are further.
				assert_float(away).is_greater((TAU - Placing.OPENING) / count / 2.0 - 1e-9)
			if count == 1:
				continue
			# Between console `after` and the next, along the way the angles grow, with no console on that stretch.
			var next := ring[(opened + 1) % count]
			var reach := fposmod(next - ring[opened], TAU)
			var along := fposmod(arrow - ring[opened], TAU)
			assert_float(along).is_between(reach * 0.45, reach * 0.55)
			for k in count:
				if k != opened and k != (opened + 1) % count:
					assert_bool(fposmod(ring[k] - ring[opened], TAU) > reach).is_true()


func test_the_first_gap_faces_the_user_at_the_bottom_where_the_arrow_points() -> void:
	for count in range(1, 13):
		assert_float(wrapf(Placing.arrow_angle(count, count - 1), -PI, PI)).is_equal_approx(0.0, 1e-9)
	# The ring's mean angle gap is the opening alone and the others stand evenly by their step.
	var ring := Placing.angles(5, 4)
	var step := (TAU - Placing.OPENING) / 5.0
	for k in 4:
		assert_float(ring[k + 1] - ring[k]).is_equal_approx(step, 1e-9)
	assert_float(ring[0] + TAU - ring[4]).is_equal_approx(step + Placing.OPENING, 1e-9)


func test_one_other_console_stands_at_the_top_and_the_arrow_at_the_bottom() -> void:
	assert_array(Array(Placing.angles(1, 0))).is_equal([PI])
	assert_float(Placing.arrow_angle(1, 0)).is_equal(0.0)


func test_the_ring_once_landed_stands_evenly_the_new_console_where_the_arrow_was_and_the_others_in_order() -> void:
	for count in range(1, 12):
		for opened in count:
			var landed := Placing.landed(count, opened)
			assert_int(landed.size()).is_equal(count + 1)
			assert_float(wrapf(landed[opened + 1] - Placing.arrow_angle(count, opened), -PI, PI)).is_equal_approx(0.0, 1e-9)
			for k in count + 1:
				assert_float(fposmod(landed[(k + 1) % (count + 1)] - landed[k], TAU)).is_equal_approx(TAU / (count + 1), 1e-9)


func test_the_flight_starts_and_ends_where_it_says_and_arcs_by_sin_pi_e() -> void:
	var from := Vector2(100.0, 500.0)
	var to := Vector2(600.0, 300.0)
	assert_vector(Placing.flight(from, to, 0.0, 64.0)).is_equal_approx(from, Vector2.ONE * 1e-6)
	assert_vector(Placing.flight(from, to, 1.0, 64.0)).is_equal_approx(to, Vector2.ONE * 1e-4)
	var middle := Placing.flight(from, to, 0.5, 64.0)
	assert_vector(middle).is_equal_approx(Vector2(350.0, 400.0 - 64.0), Vector2.ONE * 1e-4)
	assert_float(Placing.bounce(0.0)).is_equal(1.0)
	assert_float(Placing.bounce(0.5)).is_equal_approx(1.12, 1e-9)
	assert_float(Placing.bounce(1.0)).is_equal_approx(1.0, 1e-9)


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
		for _step in 200:
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
	assert_int(presses).is_greater(2000)


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


func test_Ajouter_brings_the_ring_of_the_others_the_new_console_in_the_middle_the_gap_open_at_the_end() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var order := await _on_ring(carousel)
	var consoles := carousel._consoles
	# The form is gone, the ring shows, the console placed is the one free of it.
	assert_object(order._placing).is_not_null()
	assert_bool(carousel._order.is_open()).is_true()
	assert_int(consoles.flier).is_equal(carousel._platform_ids().find("psx"))
	assert_vector(consoles.flier_stand.centre).is_equal_approx(Placing.MIDDLE, Vector2.ONE * 0.01)
	assert_float(consoles.flier_stand.size).is_equal_approx(
		RingFit.width(RingFit.weight_of("psx"), consoles.ring_target, 0.0) * Placing.MIDDLE_GROWTH / 100.0, 1e-6)
	# The three others stand on the ring opened after the last of them.
	var opened := Placing.angles(3, 2)
	for k in 3:
		var at := carousel._platform_ids().find(["ps2", "gc", "gba"][k])
		assert_float(consoles.ring_angles[at]).is_equal_approx(opened[k], 1e-3)
	assert_float(order._arrow_angle).is_equal_approx(0.0, 1e-3)
	assert_object(order._logo.texture).is_same(load("res://studio/logos/ring-middle/psx.png"))
	assert_bool(order._before.visible and order._after.visible).is_true()
	assert_int(order._where.get_child_count()).is_equal(4)
	# Nothing of the ring is kept once the console is placed: Ajouter is not pressed again by A.
	assert_array(setup[1].placed).is_empty()


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
	assert_float(form.modulate.a).is_equal(0.0)
	assert_array(device.set_up).is_empty()
	form.resume()
	assert_int(form.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_bool(form.visible).is_true()
	assert_bool(add.disabled).is_false()
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	assert_str(form.platform_id).is_equal("psx")
	assert_bool(await Fixtures.until(self, func() -> bool: return form.modulate.a == 1.0)).is_true()


func test_the_console_flying_free_is_nearer_the_camera_than_the_ones_on_the_ring_so_it_is_drawn_over_them() -> void:
	var setup := await _form_filled({"ps2": 1, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	await _on_ring(carousel)
	var consoles := carousel._consoles
	var camera := get_viewport().get_camera_3d().global_transform.affine_inverse()
	var flier := -(camera * consoles.console_at(consoles.flier).model.global_position).z
	for k in carousel._platform_ids().size():
		if k != consoles.flier:
			assert_float(flier).is_less(-(camera * consoles.console_at(k).model.global_position).z)


func test_INV_E12_S5_01_the_ring_at_rest_keeps_the_room_between_the_others_whatever_the_gap_chosen() -> void:
	var setup := await _form_filled({"ps2": 1, "gc": 1, "gba": 1, "nes": 1, "wii": 1}, "psx",
		PackedStringArray(["ps2", "gc", "gba", "nes", "wii"]))
	var carousel: Carousel = setup[0]
	var order := await _on_ring(carousel)
	var consoles := carousel._consoles
	var ids := ["ps2", "gc", "gba", "nes", "wii"]
	for press in 6:
		var boxes: Array[Rect2] = []
		var weights := PackedFloat64Array()
		var angles := PackedFloat64Array()
		for id: String in ids:
			var at := carousel._platform_ids().find(id)
			boxes.append(consoles.silhouette(at))
			weights.append(RingFit.weight_of(consoles.console_at(at).folder))
		angles = Placing.angles(5, order._placing.gap)
		var scale := RingFit.scale(boxes, weights, angles, RingFit.WIDEST / RingFit.PS2_BOX.size.x)
		assert_float(RingFit.least_room(boxes, weights, angles, scale)).is_greater_equal(RingFit.ROOM * RingFit.CQW - 1e-3)
		# Settled on the gap's targets, the ring stands where it says.
		assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(consoles.ring_scale, scale))).is_true()
		assert_float(order._arrow_to).is_equal_approx(Placing.arrow_angle(5, order._placing.gap), 1e-9)
		for k in 5:
			assert_float(absf(wrapf(order._arrow_to - angles[k], -PI, PI))).is_greater(0.3)
		await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)


func test_A_flies_the_console_into_the_chosen_gap_saves_the_order_and_opens_the_consoles_on_it() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var order := await _on_ring(carousel)
	# The first gap is after the last console; two steps right is after the second.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_int(order._placing.gap).is_equal(1)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_int(order._placing.state).is_equal(Placing.State.FLYING)
	assert_bool(await _placed(carousel)).is_true()
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


func test_A_during_the_arrival_flies_the_console_from_where_it_is_with_no_jump() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var order := carousel._order
	assert_bool(await Fixtures.until(self, func() -> bool: return order._placing != null)).is_true()
	assert_int(order._placing.state).is_equal(Placing.State.ARRIVING)
	# Held a third of the way, so that nothing moves between the reading and the press.
	order._arriving.pause()
	order._move = 0.35
	var earlier := order._flier_stand()
	var middle := Placing.MIDDLE
	assert_float(earlier.centre.distance_to(middle)).is_greater(40.0)
	order._press_placing(0, true)
	assert_int(order._placing.state).is_equal(Placing.State.FLYING)
	assert_vector(order._from.centre).is_equal_approx(earlier.centre, Vector2.ONE * 1e-3)
	assert_float(order._from.size).is_equal_approx(earlier.size, 1e-9)
	# The first frame of the flight is where it was.
	assert_vector(order._flier_stand().centre).is_equal_approx(earlier.centre, Vector2.ONE * 1e-3)
	assert_bool(await _placed(carousel)).is_true()
	assert_array(setup[1].placed).is_equal([["psx", 3]])


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


func test_the_form_comes_back_once_after_B_never_rising_again_from_nothing() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	var order := await _on_ring(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	var peak := 0.0
	var fall := 0.0
	var frames := 0
	while (order._placing != null or frames < 40) and frames < 600:
		peak = maxf(peak, form.modulate.a)
		fall = maxf(fall, peak - form.modulate.a)
		frames += 1
		await await_idle_frame()
	assert_float(peak).is_equal(1.0)
	assert_float(fall).is_less(0.02)
	# And asked again it does nothing: it is back.
	form.modulate.a = 1.0
	form.resume()
	await await_idle_frame()
	assert_float(form.modulate.a).is_equal(1.0)


func test_the_console_flying_free_follows_the_order_when_it_changes_through_the_pause() -> void:
	var setup := await _form_filled({"ps2": 2, "gc": 1, "gba": 1}, "psx", PackedStringArray(["ps2", "gc", "gba"]))
	var carousel: Carousel = setup[0]
	var consoles := carousel._consoles
	var order := await _on_ring(carousel)
	# One step right: the console goes between the PS2 and the GameCube, not at the end where the row had it.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var seen := 0
	var frames := 0
	while order._placing != null and frames < 600:
		frames += 1
		if consoles.flier >= 0:
			assert_str(consoles.console_at(consoles.flier).folder).is_equal("psx")
			if carousel._platform_ids().find("psx") == 1:
				seen += 1
			for slot in consoles.wheel_slots:
				assert_int(slot).is_greater_equal(0)
		await await_idle_frame()
	assert_int(seen).is_greater(0)


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
	var legal: Dictionary[Placing.State, Array] = {Placing.State.FORM: [Placing.State.ARRIVING], Placing.State.ARRIVING: [Placing.State.CHOOSING,
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
