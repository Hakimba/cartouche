# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const DEMO := "res://dev/demo/desktop.json"
const MOVING: Array[Carousel.Screen] = [Carousel.Screen.ENTERING, Carousel.Screen.LEAVING]


func after_test() -> void:
	for action: StringName in [&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down"]:
		Input.action_release(action)


func test_going_in_then_back_out_leaves_the_consoles_screen_and_the_games_as_they_were() -> void:
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


func test_inv_20_while_the_console_opens_or_closes_nothing_pressed_acts() -> void:
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


func test_the_carousel_opens_on_the_consoles_screen_with_the_remembered_console() -> void:
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
		# The rail stands on it, and no name or model is written over the console.
		assert_int(posmod(roundi(carousel._rail.spring().target), carousel._shelves.size())).is_equal(selected)
		assert_float(carousel._rail.spring().position).is_equal(carousel._rail.spring().target)
	# The consoles each library replaced are freed at the end of the frame.
	await await_idle_frame()


func test_every_console_of_the_demo_takes_its_medium_onto_its_seat_and_turns_it_on_its_spindle() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var sequence := carousel._sequence
	var row := carousel._row
	var launched := 0
	var spindles := 0
	for index in carousel._consoles._items.size():
		_select(carousel, index)
		var console := carousel._consoles.selected().model as ConsoleModel
		if not console:
			continue
		sequence.launch_at(sequence.seated_s() + 0.01, Fixtures.FRAME_S)
		row._process(0.0)
		# The medium itself, not its presentation pivot (a cartridge is centred in its place).
		var medium: Node3D = row._placed[row.selected_index()].shown._label_mesh.get_parent()
		assert_vector(medium.global_position).override_failure_message(console.name) \
			.is_equal_approx((console.global_transform * console.seat()).origin, Vector3.ONE * 0.0001)
		for spindle: Node in console.find_children("*", "Node3D", true, false).filter(func(node: Node) -> bool:
				return node is Spindle):
			console.hold(1.0)
			assert_bool((spindle.get_node(^"Rotor") as Node3D).basis.is_equal_approx(Basis(Vector3.BACK, 1.0))) \
				.override_failure_message("%s holds its disc still" % console.name).is_true()
			spindles += 1
		launched += 1
	assert_int(launched).is_equal(Appearance.defaults(ConsoleManifest.found()).size())
	assert_int(spindles).is_equal(3)


func test_going_in_a_launch_checked_late_and_going_out_keep_the_app_awake() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var android: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	carousel._game_launch.android = android
	var resting := carousel._resting
	var awake_fps := Engine.max_fps
	# Each frame, the rest node too, as the engine runs it: never slowed meanwhile.
	var awake_until := func(done: Callable) -> void:
		for frame in 600:
			assert_bool(resting.moving.call()).is_true()
			Fixtures.step_frame(carousel)
			resting._process(Fixtures.FRAME_S)
			assert_float(resting.pace).is_equal(1.0)
			assert_int(Engine.max_fps).is_equal(awake_fps)
			if done.call():
				break
	_select(carousel, carousel._platform_ids().find("ps2"))
	assert_bool(resting.moving.call()).is_false()
	Fixtures.press(carousel, &"ui_accept")
	awake_until.call(func() -> bool: return carousel._screen == Carousel.Screen.GAMES)
	assert_bool(resting.moving.call()).is_false()
	android.late = true
	Fixtures.press(carousel, &"ui_accept")
	# The check, answered late (longer than the rest takes to slow), then the insertion.
	var waited := [0]
	awake_until.call(func() -> bool:
		waited[0] += 1
		if waited[0] == 200:
			android.late = false
			android.replied.emit()
		return carousel._game_launch._stage == GameLaunch.Stage.AWAY)
	carousel._game_launch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	carousel._game_launch.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	awake_until.call(func() -> bool: return not carousel._game_launch.is_busy())
	assert_bool(resting.moving.call()).is_false()
	Fixtures.press(carousel, &"screen_back")
	awake_until.call(func() -> bool: return carousel._screen == Carousel.Screen.CONSOLES)
	assert_bool(resting.moving.call()).is_false()


func test_the_consoles_row_has_no_end() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	var count := consoles._items.size()
	assert_int(count).is_greater(CarouselLayout.WHOLE_SHELF)
	var changes: Array[int] = []
	consoles.selection_changed.connect(func(index: int) -> void: changes.append(index))
	_select(carousel, count - 1)
	changes.clear()
	Fixtures.press(carousel, &"carousel_right")
	Fixtures.press(carousel, &"carousel_left")
	Fixtures.press(carousel, &"carousel_left")
	assert_array(changes).is_equal([0, count - 1, count - 2])
	var random := RandomNumberGenerator.new()
	random.seed = 8
	var walked := 0
	for i: int in 3 * count:
		var direction := 1 if random.randf() < 0.6 else -1
		Fixtures.press(carousel, &"carousel_right" if direction > 0 else &"carousel_left")
		walked += direction
		assert_int(consoles.selected_index()).is_equal(posmod(count - 2 + walked, count))
	Fixtures.step_frames(carousel, 60)
	var selected := consoles.selected_index()
	for index in count:
		assert_bool(consoles._items[index].model.visible).is_equal(index == selected)


func test_a_short_consoles_row_goes_round_and_a_single_console_stays() -> void:
	for count: int in [1, 2, 3]:
		var row: ConsoleRow = auto_free(ConsoleRow.new())
		add_child(row)
		var items: Array[ConsoleRow.Item] = []
		for i: int in count:
			items.append(ConsoleRow.Item.new(Fixtures.new_console(Fixtures.PS2_SLIM), ConsoleRow.Rest.new()))
		row.show_consoles(items, count - 1)
		var changes: Array[int] = []
		row.selection_changed.connect(func(index: int) -> void: changes.append(index))
		row.step(1)
		row.step(-1)
		assert_array(changes).is_equal([] if count == 1 else [0, count - 1])
		assert_int(row.selected_index()).is_equal(count - 1)


func test_a_console_chosen_as_the_row_still_moves_goes_in_from_the_middle() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	_select(carousel, 0)
	Fixtures.press(carousel, &"carousel_right")
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_frame(carousel)
	assert_int(consoles.selected_index()).is_equal(1)
	var shown := CarouselLayout.offsets(consoles._items.size(), consoles._scroll)
	assert_float(shown[1]).is_equal(0.0)


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
			&"sway_degrees", &"bob_height", &"others_opacity"]:
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


## How faded each console is, and where its parts stand.
static func _looks(consoles: ConsoleRow) -> Array[float]:
	var found: Array[float] = []
	for item in consoles._items:
		var fade: ModelFade = item.model.get(&"_fade")
		found.append(fade.amount)
		if item.model is ConsoleModel:
			var console: ConsoleModel = item.model
			for part in console.moving_parts():
				found.append(console.get(part.property))
	return found


## The first console whose next one has a model too.
func _modelled_pair(consoles: ConsoleRow) -> int:
	for i in consoles._items.size() - 1:
		if consoles._items[i].modelled and consoles._items[i + 1].modelled:
			return i
	return -1


func test_a_press_in_the_middle_of_a_swap_jumps_nothing() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var consoles := carousel._consoles
	_select(carousel, _modelled_pair(consoles))
	Fixtures.step_frames(carousel, 30)
	consoles.step(1)
	for frame in 4:
		consoles._process(0.016)
	var earlier := _stood(consoles)
	consoles.step(1)
	consoles.arrange()
	var later := _stood(consoles)
	# Every console drawn a frame ago keeps its opacity and place within what one frame moves them.
	for index: int in earlier:
		var was: Array = earlier[index]
		var was_opacity: float = was[0]
		var was_place: Vector3 = was[1]
		if index in later:
			var now: Array = later[index]
			var now_opacity: float = now[0]
			var now_place: Vector3 = now[1]
			assert_float(now_opacity).override_failure_message("opacity of %d jumps" % index).is_equal_approx(was_opacity, 0.05)
			assert_float(now_place.distance_to(was_place)).override_failure_message("place of %d jumps" % index).is_less(0.05)
		else:
			assert_float(was_opacity).override_failure_message("%d vanished" % index).is_less(0.02)


## Opacity and position of every console drawn now, by index.
func _stood(consoles: ConsoleRow) -> Dictionary:
	var looks := {}
	for i in consoles._items.size():
		var model := consoles._items[i].model
		if model.visible:
			var fade: ModelFade = model.get(&"_fade")
			looks[i] = [1.0 - fade.amount, model.position]
	return looks


func test_a_console_with_one_model_has_no_model_to_choose_in_its_properties() -> void:
	var screens := preload("res://test/screens/fixtures.gd")
	var carousel := screens.fresh_carousel(self, screens.past_first_launch(self, {"gc": 1}))
	assert_bool(await screens.until(self, func() -> bool: return carousel._shown)).is_true()
	await screens.action(self, &"open_properties")
	var properties := carousel._console_properties
	assert_bool(await screens.until(self, func() -> bool: return not properties._busy and properties.is_open())).is_true()
	assert_bool(properties._model.visible).is_false()
