# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const DEMO := "res://dev/demo/desktop.json"
const PS2 := preload("res://carousel/consoles/ps2_slim.tscn")
const MOVING: Array[Carousel.Screen] = [Carousel.Screen.ENTERING, Carousel.Screen.LEAVING]
## Turns of this size or more show a turn happened.
const TURNED := 0.0001


func test_INV_E5_01_INV_E5_02_the_stick_turns_the_console_on_the_consoles_screen_the_disc_on_the_games_screen_and_nothing_else() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var random := Fixtures.cases(55)
	var console_turns := 0
	var disc_turns := 0
	for frame in 3000:
		_act(carousel, random)
		var console := carousel._consoles._turn.turned
		var disc := carousel._row._turn.turned
		Fixtures.step_frame(carousel)
		# The stick acts on the screen as the frame's animation leaves it.
		var screen := carousel._screen
		if not carousel._consoles._turn.turned.is_equal_approx(console):
			# Turned by the stick, or back to the front as the console is left.
			var by_stick := carousel._consoles._turn.turned != Basis.IDENTITY
			assert_bool(not by_stick or screen == Carousel.Screen.CONSOLES).is_true()
			console_turns += 1 if by_stick else 0
		if not carousel._row._turn.turned.is_equal_approx(disc) and carousel._row._turn.turned != Basis.IDENTITY:
			assert_int(screen).is_equal(Carousel.Screen.GAMES)
			disc_turns += 1
		_assert_alone(carousel)
	assert_int(console_turns).is_greater(20)
	assert_int(disc_turns).is_greater(20)


func test_INV_E5_01_going_into_the_console_turns_it_back_to_the_front() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	Input.action_press(&"inspect_right", 1.0)
	Fixtures.step_frames(carousel, 30)
	Input.action_release(&"inspect_right")
	assert_bool(carousel._consoles._turn.turned.is_equal_approx(Basis.IDENTITY)).is_false()
	Fixtures.press(carousel, &"ui_accept")
	_until(carousel, Carousel.Screen.GAMES)
	assert_bool(carousel._consoles._turn.turned.is_equal_approx(Basis.IDENTITY)).is_true()
	# Then, behind the games, it finishes turning back.
	Fixtures.step_frames(carousel, 60)
	var selected := carousel._consoles.selected_index()
	assert_bool(carousel._consoles._turn.of(selected).is_equal_approx(Basis.IDENTITY)).is_true()


func test_INV_E5_04_going_in_then_back_out_leaves_the_consoles_screen_and_the_games_as_they_were() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var random := Fixtures.cases(56)
	for i in 3 * carousel._consoles._items.size():
		_select(carousel, i % carousel._consoles._items.size())
		var consoles := carousel._consoles
		var standing := _stands(consoles)
		var looks := _looks(consoles)
		var game := carousel._row.selected_game().id
		Fixtures.press(carousel, &"ui_accept")
		_until(carousel, Carousel.Screen.GAMES)
		assert_str(carousel._row.selected_game().id).is_equal(game)
		# Moving along the shelf, then back out.
		var steps := random.randi_range(0, 3)
		for k in steps:
			Fixtures.press(carousel, &"carousel_right")
			Fixtures.step_frames(carousel, 20)
		var chosen := carousel._row.selected_game().id
		var index := consoles.selected_index()
		Fixtures.press(carousel, &"screen_back")
		_until(carousel, Carousel.Screen.CONSOLES)
		assert_int(consoles.selected_index()).is_equal(index)
		assert_float(carousel._sequence._at_s).is_equal(0.0)
		for property: StringName in standing:
			assert_bool(_same(consoles.get(property), standing[property])) \
				.override_failure_message("%s changed" % property).is_true()
		assert_array(_looks(consoles)).is_equal(looks)
		# To another console and back, then in again.
		var other := 1 if index == 0 else index - 1
		_select(carousel, other)
		_select(carousel, index)
		Fixtures.press(carousel, &"ui_accept")
		_until(carousel, Carousel.Screen.GAMES)
		assert_str(carousel._row.selected_game().id).is_equal(chosen)
		Fixtures.press(carousel, &"screen_back")
		_until(carousel, Carousel.Screen.CONSOLES)


func test_INV_E5_05_while_the_console_opens_or_closes_nothing_pressed_acts() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var random := Fixtures.cases(57)
	var android: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	carousel._game_launch.android = android
	var buttons: Array[StringName] = [&"carousel_left", &"carousel_right", &"ui_accept", &"screen_back", &"app_back"]
	var pressed := 0
	for i in 40:
		if carousel._screen == Carousel.Screen.CONSOLES:
			_select(carousel, i % carousel._consoles._items.size())
		var leaving := carousel._screen == Carousel.Screen.GAMES
		Fixtures.press(carousel, &"screen_back" if leaving else &"ui_accept")
		var console := carousel._consoles.selected_index()
		var game := carousel._row.selected_game().id
		while carousel._screen in MOVING:
			if random.randf() < 0.5:
				carousel._unhandled_input(Fixtures.button(buttons[random.randi_range(0, buttons.size() - 1)], random.randf() < 0.5))
				pressed += 1
			if random.randf() < 0.1:
				Input.action_press(&"inspect_right", random.randf_range(0.3, 1.0))
			elif random.randf() < 0.1:
				Input.action_release(&"inspect_right")
			Fixtures.step_frame(carousel)
			assert_int(carousel._consoles.selected_index()).is_equal(console)
			assert_str(carousel._row.selected_game().id).is_equal(game)
			assert_bool(carousel._game_launch.is_busy()).is_false()
			assert_bool(carousel._hold_select.is_stopped()).is_true()
		assert_int(carousel._screen).is_equal(Carousel.Screen.CONSOLES if leaving else Carousel.Screen.GAMES)
		Input.action_release(&"inspect_right")
		# Nor once there.
		Fixtures.step_frames(carousel, 30)
		assert_int(carousel._consoles.selected_index()).is_equal(console)
		assert_str(carousel._row.selected_game().id).is_equal(game)
	assert_int(android.checks).is_equal(0)
	assert_int(pressed).is_greater(50)


func test_INV_E5_06_the_carousel_opens_on_the_consoles_screen_with_the_remembered_console() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var demo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEMO))
	var library: Dictionary = demo["library"]
	var shelves: Dictionary = library["shelves"]
	var listed: Array = shelves["shelves"]
	for selected in listed.size():
		shelves["selected"] = selected
		carousel._show_library(AndroidServices.Library.new(library))
		assert_int(carousel._screen).is_equal(Carousel.Screen.CONSOLES)
		assert_int(carousel._consoles.selected_index()).is_equal(selected)
		assert_int(carousel._shelf).is_equal(selected)
		assert_float(carousel._sequence._at_s).is_equal(0.0)
		assert_bool(carousel._sequence.is_processing()).is_false()
		assert_int(carousel._consoles._turn.index).is_equal(-1)
		assert_float(carousel._consoles._scroll).is_equal(float(selected))
		# The console opened is named over it, as the appearance names it.
		var platform_id := carousel._shelves[selected].platform_id
		assert_str(carousel._console_name.text).is_equal(
			carousel._appearance.console_names.get(platform_id, carousel._platforms[platform_id].name))
	# The consoles each library replaced are freed at the end of the frame.
	await await_idle_frame()


func test_INV_E5_04_the_selected_console_stands_as_its_animation_has_it_the_others_as_they_rest() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	var unposed := 0
	for index in consoles._items.size():
		_select(carousel, index)
		# The others, beside it, are not posed: they stand exactly where they rest.
		var shown := CarouselLayout.offsets(consoles._items.size(), consoles._scroll)
		for other in shown:
			if other == index:
				continue
			var item: ConsoleRow.Item = consoles._items[other]
			var place := CarouselLayout.place(shown[other])
			var rest := item.rest
			var basis := place.basis * ConsoleRow._three_euler(rest.console_rotation).scaled(Vector3.ONE * rest.console_scale)
			assert_vector(item.model.position).is_equal_approx(rest.console_position + place.origin, Vector3.ONE * 0.0001)
			assert_bool(item.model.basis.is_equal_approx(basis)).is_true()
		Fixtures.press(carousel, &"ui_accept")
		_until(carousel, Carousel.Screen.GAMES)
		var selected := consoles.selected()
		if consoles.pose_amount == 0.0:
			var turned := ConsoleRow._three_euler(consoles.console_rotation).scaled(Vector3.ONE * consoles.console_scale)
			assert_vector(selected.model.position).is_equal_approx(consoles.console_position, Vector3.ONE * 0.0001)
			assert_bool(selected.model.basis.is_equal_approx(turned)).is_true()
			unposed += 1
		Fixtures.press(carousel, &"screen_back")
		_until(carousel, Carousel.Screen.CONSOLES)
	assert_int(unposed).is_greater(0)


func test_INV_E5_01_a_console_turned_turns_back_to_the_front_once_another_is_selected() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	Input.action_press(&"inspect_right", 1.0)
	Fixtures.step_frames(carousel, 30)
	Input.action_release(&"inspect_right")
	var turned := consoles.selected_index()
	assert_bool(consoles._turn.of(turned).is_equal_approx(Basis.IDENTITY)).is_false()
	Fixtures.press(carousel, &"carousel_right")
	Fixtures.step_frames(carousel, 120)
	assert_bool(consoles._turn.of(turned).is_equal_approx(Basis.IDENTITY)).is_true()
	assert_bool(consoles._turn.of(consoles.selected_index()).is_equal_approx(Basis.IDENTITY)).is_true()


func test_INV_E5_03_put_into_the_console_the_disc_leaves_from_where_it_stood_without_a_jump() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	while carousel._shelves[carousel._shelf].platform_id != "ps2":
		Fixtures.press(carousel, &"carousel_right")
		Fixtures.step_frame(carousel)
	Fixtures.press(carousel, &"ui_accept")
	_until(carousel, Carousel.Screen.GAMES)
	# Turned by the stick first (INV-E5-02).
	Input.action_press(&"inspect_right", 1.0)
	Fixtures.step_frames(carousel, 20)
	Input.action_release(&"inspect_right")
	Fixtures.step_frames(carousel, 60)
	var row := carousel._row
	var sequence := carousel._sequence
	var stood := row.selected_stand()
	assert_bool(row._turn.turned.is_equal_approx(Basis.IDENTITY)).is_false()
	var console: ConsoleModel = consoles.selected().model
	var t := 0.0
	var first := true
	var now := stood
	while t < sequence.seated_s():
		t += Fixtures.FRAME_S
		sequence.launch_at(t, Fixtures.FRAME_S)
		row._process(0.0)
		now = row.selected_stand()
		if sequence.disc_away <= 0.0:
			continue
		if first:
			# Its first step out: a little way from where it stood, turned as it stood.
			assert_float(now.origin.distance_to(stood.origin)).is_less(0.02)
			assert_float(now.basis.z.normalized().dot(stood.basis.z.normalized())).is_greater(0.99)
			first = false
		# On its way, as far as the animation has it, from where it stood to over the spindle.
		var tilt := Basis(Vector3.RIGHT, sequence.disc_tilt.x) * Basis(Vector3.UP, sequence.disc_tilt.y)
		var above := Transform3D(tilt, Vector3(sequence.disc_offset.x, sequence.disc_offset.y, sequence.disc_lift))
		var over := row.global_transform.affine_inverse() * console.seat() * above
		var expected := stood.interpolate_with(over, sequence.disc_away)
		assert_vector(now.origin).is_equal_approx(expected.origin, Vector3.ONE * 0.0001)
		assert_bool(now.basis.is_equal_approx(expected.basis)).is_true()
	assert_bool(first).is_false()
	var seat := row.global_transform.affine_inverse() * console.seat()
	assert_vector(now.origin).is_equal_approx(seat.origin, Vector3.ONE * 0.0001)


func test_every_track_of_a_launch_animation_drives_a_property_of_the_carousel() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	for track in LaunchAnimation.TRACKS:
		var path := NodePath(track)
		var node := carousel.get_node_or_null(NodePath(path.get_concatenated_names()))
		assert_object(node).override_failure_message("no node for %s" % track).is_not_null()
		var value: Variant = node.get_indexed(NodePath(path.get_concatenated_subnames()))
		assert_bool(value != null).override_failure_message("no property for %s" % track).is_true()


func test_going_back_out_ends_as_soon_as_the_consoles_stand_as_they_rest() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	for index in carousel._consoles._items.size():
		_select(carousel, index)
		Fixtures.press(carousel, &"ui_accept")
		_until(carousel, Carousel.Screen.GAMES)
		var animation := carousel._sequence._animation
		var expected := LaunchAnimation.moment(animation, &"games") - LaunchAnimation.moment(animation, &"consoles")
		Fixtures.press(carousel, &"screen_back")
		var frames := 0
		while carousel._screen == Carousel.Screen.LEAVING:
			Fixtures.step_frame(carousel)
			frames += 1
		# To the frame, give or take the one the frames' rounding adds.
		assert_int(frames).is_between(ceili(expected / Fixtures.FRAME_S) - 1, ceili(expected / Fixtures.FRAME_S) + 1)
		assert_float(carousel._sequence._at_s).is_equal(0.0)


func test_the_consoles_are_drawn_in_one_view_the_blurred_one_once_behind_the_games() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var main: Camera3D = carousel.get_node("Camera")
	var layer := carousel._sequence.layer
	assert_int(main.cull_mask & ConsoleLayer.BEHIND).is_equal(0)
	assert_int(layer.camera.cull_mask).is_equal(ConsoleLayer.BEHIND)
	var blurred := 0
	for index in carousel._consoles._items.size():
		_select(carousel, index)
		for action: StringName in [&"ui_accept", &"screen_back"]:
			Fixtures.press(carousel, action)
			for frame in 600:
				if layer.visible:
					_assert_drawn_in(carousel, ConsoleLayer.BEHIND)
					blurred += 1
				if carousel._screen not in MOVING:
					break
				Fixtures.step_frame(carousel)
			assert_bool(layer.visible).is_equal(carousel._screen == Carousel.Screen.GAMES
				and carousel._sequence.layer_opacity > 0.001)
		_assert_drawn_in(carousel, ConsoleLayer.FRONT)
	assert_int(blurred).is_greater(0)


func test_the_pill_names_the_game_over_the_games_and_never_shows_over_the_consoles() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	for index in carousel._consoles._items.size():
		_select(carousel, index)
		assert_float(carousel._pill.modulate.a).is_equal(0.0)
		for action: StringName in [&"ui_accept", &"screen_back"]:
			Fixtures.press(carousel, action)
			for frame in 600:
				Fixtures.step_frame(carousel)
				# Never over the consoles, nor naming them.
				if carousel._row.selected_presence < 0.5:
					assert_float(carousel._pill.modulate.a).is_less(0.5)
				if carousel._screen not in MOVING:
					break
			if action == &"ui_accept":
				assert_str(carousel._title.text).is_equal(carousel._row.selected_game().title)
				assert_float(carousel._pill.modulate.a).is_equal(1.0)
				assert_float(carousel._console_title.modulate.a).is_equal(0.0)
			else:
				assert_float(carousel._pill.modulate.a).is_equal(0.0)


func test_the_consoles_stop_at_the_ends_of_the_row_and_a_single_one_stays() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	var last := consoles._items.size() - 1
	var changes: Array[int] = []
	consoles.selection_changed.connect(func(index: int) -> void: changes.append(index))
	for end: int in [0, last]:
		_select(carousel, end)
		changes.clear()
		Fixtures.press(carousel, &"carousel_left" if end == 0 else &"carousel_right")
		Fixtures.step_frames(carousel, 20)
		assert_int(consoles.selected_index()).is_equal(end)
		assert_array(changes).is_empty()
	var alone: ConsoleRow = auto_free(ConsoleRow.new())
	add_child(alone)
	var console: ConsoleModel = PS2.instantiate()
	var items: Array[ConsoleRow.Item] = [ConsoleRow.Item.new(console, ConsoleRow.Rest.new())]
	alone.show_consoles(items, 0)
	alone.selection_changed.connect(func(index: int) -> void: changes.append(index))
	for direction: int in [-1, 1]:
		alone.step(direction)
		assert_int(alone.selected_index()).is_equal(0)
	assert_array(changes).is_empty()


func test_INV_E5_01_a_console_chosen_as_the_row_still_moves_goes_in_from_the_middle() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	_select(carousel, 0)
	Fixtures.press(carousel, &"carousel_right")
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_frame(carousel)
	assert_int(consoles.selected_index()).is_equal(1)
	var shown := CarouselLayout.offsets(consoles._items.size(), consoles._scroll)
	assert_float(shown[1]).is_equal(0.0)


func after_test() -> void:
	for action: StringName in [&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down"]:
		Input.action_release(action)


## A random input, now and then: the stick, a direction, A, B.
func _act(carousel: Carousel, random: RandomNumberGenerator) -> void:
	match random.randi_range(0, 40):
		0:
			Input.action_press(&"inspect_right", random.randf_range(0.3, 1.0))
		1, 2:
			Input.action_release(&"inspect_right")
		3:
			Fixtures.press(carousel, &"carousel_right" if random.randf() < 0.5 else &"carousel_left")
		4:
			if carousel._screen == Carousel.Screen.CONSOLES:
				Fixtures.press(carousel, &"ui_accept")
		5:
			Fixtures.press(carousel, &"screen_back")


## The console at [param index] selected on the consoles screen, the row still.
func _select(carousel: Carousel, index: int) -> void:
	while carousel._consoles.selected_index() != index:
		Fixtures.press(carousel, &"carousel_right" if carousel._consoles.selected_index() < index else &"carousel_left")
	Fixtures.step_frames(carousel, 60)


func _until(carousel: Carousel, screen: Carousel.Screen) -> void:
	Fixtures.step_until(carousel, screen)
	assert_int(carousel._screen).is_equal(screen)


## How the consoles row stands the selected console now.
static func _stands(consoles: ConsoleRow) -> Dictionary[StringName, Variant]:
	var found: Dictionary[StringName, Variant] = {}
	for property: StringName in [&"console_position", &"console_rotation", &"console_scale", &"pose_amount",
			&"sway_degrees", &"bob_height", &"others_opacity", &"lid_degrees"]:
		found[property] = consoles.get(property)
	return found


static func _same(a: Variant, b: Variant) -> bool:
	if a is Vector3:
		var vector: Vector3 = a
		var other_vector: Vector3 = b
		return vector.is_equal_approx(other_vector)
	var number: float = a
	var other: float = b
	return is_equal_approx(number, other)


## How faded each console is, and how far the selected one's lid is open.
static func _looks(consoles: ConsoleRow) -> Array[float]:
	var found: Array[float] = []
	for item in consoles._items:
		var fade: ModelFade = item.model.get(&"_fade")
		found.append(fade.amount)
		if item.model is ConsoleModel:
			var console: ConsoleModel = item.model
			found.append(console.lid_degrees)
	return found


## On the consoles screen no game shows, on the games screen no console but the selected one.
func _assert_alone(carousel: Carousel) -> void:
	if carousel._screen == Carousel.Screen.CONSOLES:
		for place: ShelfRow.Place in carousel._row._placed.values():
			if place.visible:
				assert_float(place.shown._fade.amount).is_equal(1.0)
	elif carousel._screen == Carousel.Screen.GAMES and not carousel._game_launch.is_busy():
		var consoles := carousel._consoles
		for i in consoles._items.size():
			var item := consoles._items[i]
			if i != consoles.selected_index() and item.model.visible:
				var fade: ModelFade = item.model.get(&"_fade")
				assert_float(fade.amount).is_equal(1.0)


## Every console drawn in [param layers] only.
func _assert_drawn_in(carousel: Carousel, layers: int) -> void:
	for item in carousel._consoles._items:
		for geometry in item.geometry:
			assert_int(geometry.layers).is_equal(layers)
