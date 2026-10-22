# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## A game's properties: its disc staged in the middle under the light, its label and its name to
## pick, and the images its label can show.

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")
const IMAGES := "user://test-labels"

## The images every game can show, as the art sources list them: two downloaded, one to come.
var _variants: Array[Dictionary] = []
## Where the two downloaded ones are.
var _red := ""
var _blue := ""
## Whether [method _deeper] goes to the name next time, rather than to the images.
var _to_name := false


func after() -> void:
	for file in DirAccess.get_files_at(IMAGES):
		DirAccess.remove_absolute(IMAGES.path_join(file))


func before() -> void:
	DirAccess.make_dir_recursive_absolute(IMAGES)
	for region: String in ["Europe", "North America"]:
		var image := Image.create_empty(32, 32, false, Image.FORMAT_RGB8)
		image.fill(Color.RED if region == "Europe" else Color.BLUE)
		var path := IMAGES.path_join(region + ".png")
		image.save_png(path)
		_variants.append(_scan(region, ProjectSettings.globalize_path(path)))
	_red = _variants[0]["path"]
	_blue = _variants[1]["path"]
	_variants.append(_scan("Japan"))


## An image as the plugin lists it, at [param path] when downloaded.
func _scan(region: String, path := "", source := "launchbox") -> Dictionary:
	var listed := {"region": region, "source": source,
		"source_name": "ScreenScraper" if source == "screenscraper" else "LaunchBox"}
	if path:
		listed["path"] = path
	return listed


## A device past its first launch with three PS2 games, each with [param variants] (the usual
## ones by default), its carousel on the games screen.
func _on_games(variants: Array[Dictionary] = _variants) -> Array:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.variants = variants
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	return [carousel, device]


## Frames until [param carousel], its properties and its launches stop moving.
func _settled(carousel: Carousel) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool:
		return not carousel._properties._busy and not carousel._game_launch.is_busy() \
			and carousel.screen() not in [Carousel.Screen.ENTERING, Carousel.Screen.LEAVING])).is_true()
	await await_idle_frame()


func _cards(carousel: Carousel) -> Array[LabelCard]:
	var cards: Array[LabelCard] = []
	cards.assign(carousel._properties._cards.get_children())
	return cards


## The part of its label texture the selected game shows.
func _window(carousel: Carousel) -> Vector4:
	var row := carousel._row
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var label: ShaderMaterial = place.shown._label_mesh.get_active_material(0)
	return label.get_shader_parameter(&"label_window")


func _light(carousel: Carousel) -> OperatingLight:
	return carousel.get_node("%Light")


## The label the selected game shows now.
func _label(carousel: Carousel) -> Texture2D:
	var row := carousel._row
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var label: ShaderMaterial = place.shown._label_mesh.get_active_material(0)
	return label.get_shader_parameter(&"label_texture")


func test_the_light_given_each_frame_goes_to_the_gpu_only_when_it_changes() -> void:
	var light: OperatingLight = auto_free(OperatingLight.new())
	var material := ShaderMaterial.new()
	material.shader = preload("res://carousel/properties/operating_light.gdshader")
	light.material = material
	add_child(light)
	light.look(Vector2(10.0, 20.0), 30.0, 0.5)
	assert_float(material.get_shader_parameter(&"radius")).is_equal(30.0)
	assert_bool(light.visible).is_true()
	# Something else in its place shows that the same light is not sent again.
	material.set_shader_parameter(&"radius", 99.0)
	light.look(Vector2(10.0, 20.0), 30.0, 0.5)
	assert_float(material.get_shader_parameter(&"radius")).is_equal(99.0)
	light.look(Vector2(10.0, 20.0), 31.0, 0.5)
	assert_float(material.get_shader_parameter(&"radius")).is_equal(31.0)
	light.look(Vector2(11.0, 20.0), 31.0, 0.5)
	assert_vector(material.get_shader_parameter(&"centre")).is_equal(Vector2(11.0, 20.0))
	light.look(Vector2(11.0, 20.0), 31.0, 0.0)
	assert_bool(light.visible).is_false()


func test_the_callout_pointed_each_frame_draws_its_arrow_again_only_when_it_moves() -> void:
	var callout: FocusCallout = auto_free(FocusCallout.new())
	var caption := Label.new()
	caption.name = "Caption"
	callout.add_child(caption)
	add_child(callout)
	var draws := [0]
	callout.draw.connect(func() -> void: draws[0] += 1)
	for frame in 5:
		callout.point("Name", Vector2(10.0, 20.0), Vector2(40.0, 20.0))
		await await_idle_frame()
	assert_int(draws[0]).is_equal(1)
	callout.point("Name", Vector2(10.0, 20.0), Vector2(41.0, 20.0))
	await await_idle_frame()
	assert_int(draws[0]).is_equal(2)


func test_X_stages_the_selected_disc_under_the_light_and_B_puts_it_back_in_the_row() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var properties := carousel._properties
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.PROPERTIES)
	await _settled(carousel)
	assert_float(carousel._row.stage).is_equal(1.0)
	assert_float(carousel._row.neighbours).is_equal(0.0)
	# In the middle, 1.12 times its size in the row, facing the camera, still.
	var stand := carousel._row.selected_stand()
	assert_vector(carousel._row.to_global(stand.origin)).is_equal_approx(Vector3(0.0, 0.14, 0.0), Vector3.ONE * 0.0001)
	assert_vector(stand.basis.get_scale()).is_equal_approx(Vector3.ONE * 1.12, Vector3.ONE * 0.0001)
	assert_bool(stand.basis.orthonormalized().is_equal_approx(Basis.IDENTITY)).is_true()
	for frame in 10:
		await await_idle_frame()
	assert_bool(carousel._row.selected_stand().is_equal_approx(stand)).is_true()
	assert_bool(_light(carousel).visible).is_true()
	assert_bool(carousel._pill.visible).is_false()
	assert_object(Fixtures.focus(self)).is_same(properties._zone)
	assert_str(properties._name.text).is_equal(carousel._row.selected_game().title)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	assert_float(carousel._row.stage).is_equal(0.0)
	assert_float(carousel._row.neighbours).is_equal(1.0)
	assert_bool(_light(carousel).visible).is_false()
	assert_bool(carousel._pill.visible).is_true()
	assert_float(carousel._pill.modulate.a).is_equal(1.0)
	assert_bool(properties.visible).is_false()


func test_up_and_down_go_from_the_label_to_the_name_and_back_and_nowhere_else() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	for move: StringName in [&"ui_left", &"ui_up", &"ui_right"]:
		await Fixtures.action(self, move)
		assert_object(Fixtures.focus(self)).is_same(properties._zone)
	await Fixtures.action(self, &"ui_down")
	assert_object(Fixtures.focus(self)).is_same(properties._name)
	for move: StringName in [&"ui_left", &"ui_down", &"ui_right"]:
		await Fixtures.action(self, move)
		assert_object(Fixtures.focus(self)).is_same(properties._name)
	await Fixtures.action(self, &"ui_up")
	assert_object(Fixtures.focus(self)).is_same(properties._zone)


func test_A_on_the_label_offers_its_images_by_region_the_one_shown_first_and_the_user_s_own_picture_last() -> void:
	var carousel: Carousel = (await _on_games())[0]
	carousel._row.selected_game().has_label_region = true
	carousel._row.selected_game().label_region = "North America"
	carousel._row.selected_game().label_source = "launchbox"
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_array(cards.map(func(card: LabelCard) -> String: return card.region)).contains_exactly(["Europe", "North America", "Japan", ""])
	assert_object(Fixtures.focus(self)).is_same(cards[1])
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[0].is_ready() and cards[1].is_ready())).is_true()
	assert_bool(cards[2].is_ready()).is_false()
	assert_bool(cards[3].own and cards[3].is_ready()).is_true()
	await Fixtures.action(self, &"ui_right")
	assert_object(Fixtures.focus(self)).is_same(cards[2])
	await Fixtures.action(self, &"ui_right")
	assert_object(Fixtures.focus(self)).is_same(cards[3])


func test_INV_E7_03_an_image_of_each_source_is_offered_named_by_region_and_source_and_the_one_chosen_is_remembered_with_its_source() -> void:
	var both: Array[Dictionary] = [_scan("Europe", _blue, "screenscraper"), _scan("Europe", _red), _scan("Japan")]
	var setup := await _on_games(both)
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var game := carousel._row.selected_game()
	game.has_label_region = true
	game.label_region = "Europe"
	game.label_source = "launchbox"
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	var captions := cards.map(func(card: LabelCard) -> String: return (card.get_child(0).get_child(1) as Label).text)
	assert_array(captions).contains_exactly(["Europe · ScreenScraper", "Europe · LaunchBox", "Japan · LaunchBox", "My own image"])
	# The focus on the image chosen: the region's scan, not its texture.
	assert_object(Fixtures.focus(self)).is_same(cards[1])
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[0].is_ready() and cards[1].is_ready())).is_true()
	assert_object(cards[0].label).is_not_same(cards[1].label)
	await Fixtures.action(self, &"ui_left")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).contains_exactly(["screenscraper/Europe"])
	assert_str(game.label_region).is_equal("Europe")
	assert_str(game.label_source).is_equal("screenscraper")


func test_each_image_picked_shows_on_the_disc_at_once_and_B_brings_back_the_label_it_had() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var own := _label(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[0].is_ready() and cards[1].is_ready())).is_true()
	assert_object(_label(carousel)).is_same(cards[0].label)
	await Fixtures.action(self, &"ui_right")
	assert_object(_label(carousel)).is_same(cards[1].label)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_object(_label(carousel)).is_same(own)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._zone)


func test_A_keeps_the_image_picked_and_remembers_its_region() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[1].is_ready())).is_true()
	var picked := cards[1].label
	await Fixtures.action(self, &"ui_right")
	# Pressed again while the plugin keeps it: nothing more.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).contains_exactly(["launchbox/North America"])
	assert_object(_label(carousel)).is_same(picked)
	assert_bool(carousel._row.selected_game().has_label_region).is_true()
	assert_str(carousel._row.selected_game().label_region).is_equal("North America")
	assert_str(carousel._row.selected_game().label_source).is_equal("launchbox")
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._zone)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	assert_object(_label(carousel)).is_same(picked)


func test_an_image_still_to_come_cannot_be_kept_and_one_that_could_not_be_is_told() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.choice_failed.connect(func() -> void: told.append("failed"))
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	_cards(carousel)[2].grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.chosen_labels).is_empty()
	device.failing.append(&"choose_label")
	var first := _cards(carousel)[0]
	assert_bool(await Fixtures.until(self, func() -> bool: return first.is_ready())).is_true()
	first.grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).contains_exactly(["launchbox/Europe"])
	assert_int(told.size()).is_equal(1)
	assert_object(Fixtures.focus(self)).is_same(first)
	assert_object(_label(carousel)).is_same(first.label)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_bool(carousel._row.selected_game().has_label_region).is_false()


func test_a_game_with_no_image_by_region_says_so_offers_only_the_user_s_own_picture_and_B_goes_back() -> void:
	var carousel: Carousel = (await _on_games([]))[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(_cards(carousel).size()).is_equal(1)
	assert_bool(_cards(carousel)[0].own).is_true()
	assert_object(Fixtures.focus(self)).is_same(_cards(carousel)[0])
	assert_str(carousel._properties._prompt.text).is_equal("No other image of this game is known")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._zone)


func test_A_and_B_pressed_while_the_images_are_listed_do_nothing() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_int(_cards(carousel).size()).is_equal(4)
	assert_bool(carousel._properties._labels.visible).is_true()
	assert_bool(carousel._properties._properties.visible).is_false()


func test_after_a_launch_the_games_screen_and_the_properties_still_hide_the_console_s_name() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var title: Control = carousel._console_title
	assert_bool(await Fixtures.until(self, func() -> bool: return title.modulate.a == 0.0)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_float(title.modulate.a).is_equal(0.0)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	assert_float(title.modulate.a).is_equal(0.0)


func test_B_pressed_while_the_properties_open_does_nothing() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.PROPERTIES)
	assert_float(carousel._row.stage).is_equal(1.0)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._zone)


func test_the_game_s_own_image_arriving_while_another_is_shown_waits_until_it_is_put_back() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var first := _cards(carousel)[0]
	assert_bool(await Fixtures.until(self, func() -> bool: return first.is_ready())).is_true()
	var game := carousel._row.selected_game()
	var arrived := ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGB8))
	carousel._art.add(AndroidServices.Art.new({"game_id": game.id, "path": "unused"}), arrived)
	assert_object(_label(carousel)).is_same(first.label)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_object(_label(carousel)).is_same(arrived)


func test_an_image_arriving_after_the_list_can_be_shown_and_kept_and_one_that_failed_cannot() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var game := carousel._row.selected_game()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	# Before the list is answered: kept for when the card comes.
	device.arrive(game.id, "North America", _blue)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[1].is_ready())).is_true()
	cards[2].grab_focus()
	device.arrive("ps2/another", "Japan", _red)
	device.arrive(game.id, "Japan", "", &"offline")
	for frame in 10:
		await await_idle_frame()
	assert_bool(cards[2].is_ready()).is_false()
	assert_float(cards[2].modulate.a).is_less(1.0)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.chosen_labels).is_empty()
	device.arrive(game.id, "Japan", _red)
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[2].is_ready())).is_true()
	assert_object(_label(carousel)).is_same(cards[2].label)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).contains_exactly(["launchbox/Japan"])
	# Late, once the images are gone: nothing happens.
	device.arrive(game.id, "Europe", _red)
	await await_idle_frame()


func test_an_image_of_no_named_region_is_offered_as_such_and_a_region_no_longer_offered_starts_first() -> void:
	var nameless: Array[Dictionary] = [_scan("Japan", _red), _scan("", _blue)]
	var setup := await _on_games(nameless)
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var game := carousel._row.selected_game()
	game.has_label_region = true
	game.label_region = ""
	game.label_source = "launchbox"
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_object(Fixtures.focus(self)).is_same(cards[1])
	assert_bool(cards[1].own).is_false()
	assert_str((cards[1].get_child(0).get_child(1) as Label).text).is_equal("No region · LaunchBox")
	# The last region: right goes on to the user's own picture, and no further.
	await Fixtures.action(self, &"ui_right")
	assert_object(Fixtures.focus(self)).is_same(cards[2])
	await Fixtures.action(self, &"ui_right")
	assert_object(Fixtures.focus(self)).is_same(cards[2])
	await Fixtures.action(self, &"ui_left")
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[1].is_ready())).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).contains_exactly(["launchbox/"])
	game.label_region = "Atlantis"
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_object(Fixtures.focus(self)).is_same(_cards(carousel)[0])


## From where the properties of [param carousel] settled, one screen deeper: the properties, the
## images or the keyboard of its name (in turn), the framing of the user's own picture.
func _deeper(carousel: Carousel) -> void:
	match carousel._properties._step:
		DiscProperties.Step.CLOSED:
			await Fixtures.joypad(self, JOY_BUTTON_X)
		DiscProperties.Step.PROPERTIES:
			_to_name = not _to_name
			await Fixtures.action(self, &"ui_down" if _to_name else &"ui_up")
			await Fixtures.joypad(self, JOY_BUTTON_A)
		DiscProperties.Step.LABELS:
			for card in _cards(carousel):
				if (Fixtures.focus(self) as LabelCard).own:
					break
				await Fixtures.action(self, &"ui_right")
			await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)


func test_INV_E7_02_whatever_is_pressed_and_when_the_properties_settle_on_one_whole_screen() -> void:
	var random := CarouselFixtures.cases(71)
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	# A and X twice as likely: they lead deeper.
	var presses: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_X, JOY_BUTTON_B,
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_START]
	var seen: Dictionary[int, bool] = {}
	_to_name = false
	for attempt in 36:
		# Every third attempt first goes one screen deeper, so that the framing, rarely reached by
		# chance, is pressed on too.
		if attempt % 3 == 2:
			await _deeper(carousel)
		for press in random.randi_range(1, 4):
			# The images read first, as each frame of a person's press would find them.
			assert_bool(await Fixtures.until(self, func() -> bool:
				return properties._reader.is_idle() and properties._picture_reader.is_idle())).is_true()
			await Fixtures.joypad(self, presses[random.randi() % presses.size()])
			for frame in random.randi_range(0, 8):
				await await_idle_frame()
		await _settled(carousel)
		var step := properties._step
		seen[step] = true
		var staged := carousel.screen() == Carousel.Screen.PROPERTIES
		assert_bool(staged).is_equal(step != DiscProperties.Step.CLOSED)
		assert_float(carousel._row.stage).is_equal(1.0 if staged else 0.0)
		# The consoles screen hides the shelf itself.
		if carousel.screen() != Carousel.Screen.CONSOLES:
			assert_float(carousel._row.neighbours).is_equal(0.0 if staged else 1.0)
		assert_bool(properties.visible).is_equal(staged)
		assert_bool(carousel._pill.visible).is_equal(not staged)
		var focused := Fixtures.focus(self)
		match step:
			DiscProperties.Step.PROPERTIES:
				assert_object(properties._staging).is_same(DiscProperties._on_properties)
				assert_bool(properties._labels.visible or properties._framing_screen.visible).is_false()
				assert_float(properties._properties.modulate.a).is_equal(1.0)
				assert_bool(focused in [properties._zone, properties._name]).is_true()
			DiscProperties.Step.LABELS:
				assert_object(properties._staging).is_same(DiscProperties._on_labels)
				assert_bool(properties._properties.visible).is_false()
				assert_bool(properties._framing_screen.visible).is_false()
				assert_float(properties._labels.modulate.a).is_equal(1.0)
				assert_bool(focused is LabelCard).is_true()
			DiscProperties.Step.FRAMING:
				assert_object(properties._staging).is_same(DiscProperties._on_framing)
				assert_bool(properties._properties.visible or properties._labels.visible).is_false()
				assert_float(properties._framing_screen.modulate.a).is_equal(1.0)
				assert_object(focused).is_null()
				assert_object(_label(carousel)).is_same(properties._picture_texture)
				var framed := properties._framing.window(properties._picture.size)
				assert_vector(_window(carousel)).is_equal_approx(
					Vector4(framed.position.x, framed.position.y, framed.size.x, framed.size.y), Vector4.ONE * 0.0001)
			DiscProperties.Step.NAMING:
				assert_object(properties._staging).is_same(DiscProperties._on_naming)
				assert_bool(properties._properties.visible or properties._labels.visible or properties._framing_screen.visible).is_false()
				assert_float(properties._naming.modulate.a).is_equal(1.0)
				assert_bool(focused is Button and properties._naming._keyboard.is_ancestor_of(focused)).is_true()
				assert_str(properties._naming._field.text).is_equal(properties._naming._typed + "|" if properties._naming._typed
					else carousel._row.selected_game().own_title())
		if step != DiscProperties.Step.NAMING:
			assert_bool(properties._naming.visible).is_false()
		# Outside the framing, the label shows its texture covering it (the kept picture, once read,
		# too): whole one way, centred.
		if step != DiscProperties.Step.FRAMING and properties._framed_game == "":
			var shown := _window(carousel)
			assert_bool(is_equal_approx(shown.z, 1.0) or is_equal_approx(shown.w, 1.0)).is_true()
			assert_vector(Vector2(shown.x + shown.z / 2.0, shown.y + shown.w / 2.0)).is_equal_approx(Vector2.ONE * 0.5, Vector2.ONE * 0.0001)
		if carousel.screen() == Carousel.Screen.CONSOLES:
			await Fixtures.joypad(self, JOY_BUTTON_A)
			assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
		# The first broken case is enough to tell.
		if is_failure():
			return
	# Every screen was reached.
	assert_int(seen.size()).is_equal(5)


## On the cards of [param carousel]'s selected game, the focus on the user's own picture.
func _on_own_card(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	for move in 3:
		await Fixtures.action(self, &"ui_right")
	assert_bool((Fixtures.focus(self) as LabelCard).own).is_true()


func test_the_user_s_own_picture_picked_shows_on_the_disc_its_largest_square_in_its_middle() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var properties := carousel._properties
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(properties._step).is_equal(DiscProperties.Step.FRAMING)
	assert_object(properties._staging).is_same(DiscProperties._on_framing)
	assert_object(_label(carousel)).is_same(properties._picture_texture)
	# A picture 64 by 48: the square 48 wide in its middle.
	assert_vector(_window(carousel)).is_equal_approx(Vector4(8.0 / 64.0, 0.0, 48.0 / 64.0, 1.0), Vector4.ONE * 0.001)


func test_on_a_cartridge_the_user_s_own_picture_is_framed_and_kept_at_its_label_s_proportions() -> void:
	var device := Fixtures.past_first_launch(self, {"gba": 3})
	device.variants = _variants
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.FRAMING)
	# The GBA cartridge's label, 44 by 22.5: on a picture 64 by 48, its full width, 32 tall in the middle.
	var proportion := carousel._row.selected_label_proportion()
	assert_float(proportion).is_equal_approx(44.0 / 22.5, 0.001)
	# Within a pixel of it: the label covers its face with it.
	assert_vector(_window(carousel)).is_equal_approx(Vector4(0.0, 8.0 / 48.0, 1.0, 32.0 / 48.0), Vector4.ONE * 0.025)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.kept_framings).is_equal([{"zoom": 1.0, "centre": Vector2(0.5, 0.5), "proportion": proportion}])


func test_the_stick_and_L1_R1_frame_the_picture_and_A_keeps_it_as_framed() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._properties
	var game := carousel._row.selected_game()
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	for held: StringName in [&"label_zoom_in", &"ui_right"]:
		await Fixtures.hold(self, held)
		for frame in 30:
			await await_idle_frame()
		await Fixtures.hold(self, held, false)
	var framing := properties._framing
	assert_float(framing.zoom).is_greater(1.0)
	# The picture follows the stick: pushed right, the label shows more of its left.
	assert_float(framing.centre.x).is_less(0.5)
	# The disc shows the square kept, as it moves.
	var framed := framing.window(properties._picture.size)
	assert_vector(_window(carousel)).is_equal_approx(
		Vector4(framed.position.x, framed.position.y, framed.size.x, framed.size.y), Vector4.ONE * 0.0001)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.kept_framings).is_equal([{"zoom": framing.zoom, "centre": framing.centre, "proportion": 1.0}])
	assert_int(properties._step).is_equal(DiscProperties.Step.PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(properties._zone)
	assert_bool(game.label_own and not game.has_label_region).is_true()
	# The picture as framed shows until the kept image is read, then the kept image.
	assert_bool(await Fixtures.until(self, func() -> bool: return properties._framed_game == "")).is_true()
	assert_object(_label(carousel)).is_same(carousel._art.texture(game))
	# The kept image, 64 by 48 here, covers the disc's label: its middle square.
	assert_vector(_window(carousel)).is_equal_approx(Vector4(0.125, 0.0, 0.75, 1.0), Vector4.ONE * 0.0001)


func _pinch(at: Vector2, factor: float) -> void:
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = get_tree().root.get_final_transform() * at
	pinch.factor = factor
	Input.parse_input_event(pinch)


func test_by_touch_pinching_zooms_the_picture_and_a_drag_moves_it_with_the_finger() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var centre := Vector2(640.0, 480.0)
	# The same pinch handed over twice in a frame counts once; the next frame's counts again.
	_pinch(centre, 1.5)
	_pinch(centre, 1.5)
	await await_idle_frame()
	assert_float(properties._framing.zoom).is_equal_approx(1.5, 0.0001)
	_pinch(centre, 1.2)
	await await_idle_frame()
	assert_float(properties._framing.zoom).is_equal_approx(1.8, 0.0001)
	# Dragged right 10 pixels at a time, the picture goes right with the finger, as far: the label
	# shows more of its left.
	var framed_before := _window(carousel)
	var path: Array[Vector2] = []
	for step in 13:
		path.append(centre + Vector2(10.0 * step, 0.0))
	await Fixtures.touch(self, path)
	var moved := 120.0 / properties._label_px * framed_before.z
	# Within the label's breathing as the disc floats.
	assert_float(_window(carousel).x).is_equal_approx(framed_before.x - moved, 0.002)
	var framed := properties._framing.window(properties._picture.size)
	assert_vector(_window(carousel)).is_equal_approx(
		Vector4(framed.position.x, framed.position.y, framed.size.x, framed.size.y), Vector4.ONE * 0.0001)
	# Nothing turned the disc meanwhile.
	assert_bool(carousel._row._turn.of(carousel._row.selected_index()).is_equal_approx(Basis.IDENTITY)).is_true()


func test_B_while_framing_goes_back_to_the_cards_keeping_nothing() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var shown := _label(carousel)
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_bool((Fixtures.focus(self) as LabelCard).own).is_true()
	assert_object(_label(carousel)).is_same(shown)
	assert_array(device.kept_framings).is_empty()


func test_a_picture_that_cannot_be_read_brings_the_cards_back_and_is_told() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.choice_failed.connect(func() -> void: told.append("failed"))
	device.failing.append(&"pick_label_picture")
	device.picture_failure = &"unreadable_image"
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(told.size()).is_equal(1)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_object(carousel._properties._staging).is_same(DiscProperties._on_labels)


func test_a_picture_the_app_then_cannot_read_brings_the_cards_back_and_is_told() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.choice_failed.connect(func() -> void: told.append("failed"))
	device.picture_unreadable = true
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return told.size() == 1)).is_true()
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_object(carousel._properties._staging).is_same(DiscProperties._on_labels)
	assert_bool((Fixtures.focus(self) as LabelCard).own).is_true()


func test_the_picker_closed_without_a_picture_brings_the_cards_back_and_is_no_failure() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.choice_failed.connect(func() -> void: told.append("failed"))
	device.failing.append(&"pick_label_picture")
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	assert_float(carousel._properties._labels.modulate.a).is_equal(1.0)
	assert_bool((Fixtures.focus(self) as LabelCard).own).is_true()
	assert_array(told).is_empty()


func test_a_picture_that_cannot_be_kept_is_told_and_its_framing_stays() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.choice_failed.connect(func() -> void: told.append("failed"))
	device.failing.append(&"keep_own_label")
	await _on_own_card(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var framing := carousel._properties._framing
	var shown := _window(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(told.size()).is_equal(1)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.FRAMING)
	assert_bool(carousel._row.selected_game().label_own).is_false()
	assert_object(carousel._properties._framing).is_same(framing)
	assert_vector(_window(carousel)).is_equal(shown)
	# A again tries again, as framed.
	device.failing.erase(&"keep_own_label")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_int(device.kept_framings.size()).is_equal(2)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.PROPERTIES)


func test_the_images_of_a_game_showing_the_user_s_own_picture_open_on_it() -> void:
	var carousel: Carousel = (await _on_games())[0]
	carousel._row.selected_game().label_own = true
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_bool((Fixtures.focus(self) as LabelCard).own).is_true()


## The keyboard of [param carousel]'s selected game's name, open.
func _on_keyboard(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)


func test_A_on_the_name_opens_a_keyboard_under_the_disc_the_name_ready_to_edit() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	var game := carousel._row.selected_game()
	await _on_keyboard(carousel)
	assert_int(properties._step).is_equal(DiscProperties.Step.NAMING)
	assert_object(properties._staging).is_same(DiscProperties._on_naming)
	assert_str(properties._naming._field.text).is_equal(game.title + "|")
	assert_object(Fixtures.focus(self)).is_same(properties._naming._keyboard.first_letter())


func test_X_Y_and_the_keys_type_the_name_and_Start_keeps_it_everywhere_it_shows() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._properties
	var game := carousel._row.selected_game()
	var title := game.title
	await _on_keyboard(carousel)
	for letter in title:
		await Fixtures.joypad(self, JOY_BUTTON_X)
	# Empty: the title it takes back shows, faded, and the next letter is a capital.
	assert_str(properties._naming._field.text).is_equal(title)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_str(properties._naming._field.text).is_equal("Aa A|")
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_array(device.names_given).is_equal(["Aa A"])
	assert_bool(game.title == "Aa A" and game.has_original_title and game.original_title == title).is_true()
	assert_str(properties._name.text).is_equal("Aa A")
	assert_object(Fixtures.focus(self)).is_same(properties._name)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_str(carousel._title.text).is_equal("Aa A")


func test_B_on_the_keyboard_leaves_the_name_as_it_was() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var title := carousel._row.selected_game().title
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_array(device.names_given).is_empty()
	assert_str(carousel._row.selected_game().title).is_equal(title)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._name)


func test_a_blank_name_gives_the_game_its_own_title_back() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var game := carousel._row.selected_game()
	var title := game.title
	game.has_original_title = true
	game.original_title = title
	game.title = "Mine"
	await _on_keyboard(carousel)
	for letter in "Mine":
		await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_str(carousel._properties._naming._field.text).is_equal(title)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_array(device.names_given).is_equal([""])
	assert_str(game.title).is_equal(title)
	assert_bool(game.has_original_title).is_false()


func test_a_name_that_cannot_be_kept_is_told_and_the_keyboard_stays() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[String] = []
	carousel._properties.rename_failed.connect(func() -> void: told.append("failed"))
	device.failing.append(&"rename_game")
	var title := carousel._row.selected_game().title
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_int(told.size()).is_equal(1)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.NAMING)
	assert_str(carousel._row.selected_game().title).is_equal(title)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._naming._keyboard.first_letter())


func test_keys_pressed_while_the_name_is_kept_count_for_nothing() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._properties
	device.slow.append(&"rename_game")
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var typed := properties._naming._typed
	await Fixtures.joypad(self, JOY_BUTTON_START)
	for press: JoyButton in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_B, JOY_BUTTON_DPAD_RIGHT]:
		await Fixtures.joypad(self, press)
	assert_str(properties._naming._typed).is_equal(typed)
	assert_str(properties._naming._field.text).is_equal(typed + "|")
	assert_int(properties._step).is_equal(DiscProperties.Step.NAMING)
	assert_array(device.names_given).is_equal([typed])
	device.slow.clear()
	device.released.emit()
	await _settled(carousel)
	assert_str(carousel._row.selected_game().title).is_equal(typed)
	assert_int(properties._step).is_equal(DiscProperties.Step.PROPERTIES)


func test_Start_on_a_name_left_as_it_was_keeps_the_game_s_own_title() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_array(device.names_given).is_empty()
	assert_bool(carousel._row.selected_game().has_original_title).is_false()
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.PROPERTIES)


func test_typing_the_game_s_own_title_back_takes_its_name_away() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var game := carousel._row.selected_game()
	var title := game.title
	game.has_original_title = true
	game.original_title = title
	game.title = "Mine"
	await _on_keyboard(carousel)
	carousel._properties._naming._typed = title
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_str(game.title).is_equal(title)
	assert_bool(game.has_original_title).is_false()


func test_a_name_is_kept_on_single_spaces_and_typed_up_to_80_characters() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._properties
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_str(properties._naming._typed).ends_with("  A")
	for key in 85:
		properties._naming._keyboard.first_letter().pressed.emit()
	assert_int(properties._naming._typed.length()).is_equal(80)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	assert_int(device.names_given[0].length()).is_equal(80)
	assert_bool(carousel._row.selected_game().title.contains("  ")).is_false()


func test_Shift_turns_the_next_letter_and_accents_are_typed_as_letters() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	var keyboard := properties._naming._keyboard
	await _on_keyboard(carousel)
	var accent: Button = keyboard.get_child(4).get_child(0)
	# The name goes on after a letter: the next one is small, unless Shift turns it.
	assert_bool(keyboard.capital).is_false()
	accent.pressed.emit()
	assert_str(properties._naming._typed).ends_with("é")
	for key: Button in keyboard.get_child(5).get_children():
		if key.text == tr("Shift"):
			key.pressed.emit()
	assert_str(accent.text).is_equal("É")
	accent.pressed.emit()
	assert_str(properties._naming._typed).ends_with("éÉ")
	assert_str(accent.text).is_equal("é")


func test_a_game_renamed_shows_its_name_on_the_label_drawn_on_its_disc() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var row := carousel._row
	# Its title is written on its blank only once a download found no image of it.
	row.label_images.mark_absent(row.selected_game().id)
	await _on_keyboard(carousel)
	carousel._properties._naming._typed = "Mine"
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await _settled(carousel)
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	if not row.label_images.has_texture(row.selected_game()):
		assert_str(place.shown._title.text).is_equal("Mine")



func test_delayed_sources_of_the_same_region_keep_their_own_pixels_and_choice() -> void:
	for early: bool in [false, true]:
		for reverse: bool in [false, true]:
			for chosen in 2:
				await _delayed_sources(early, reverse, chosen)
				if is_failure():
					return


func _delayed_sources(early: bool, reverse: bool, chosen: int) -> void:
	var both: Array[Dictionary] = [_scan("Europe", "", "launchbox"), _scan("Europe", "", "screenscraper")]
	var setup := await _on_games(both)
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var game := carousel._row.selected_game()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var sources: Array[String] = ["launchbox", "screenscraper"]
	var paths: Array[String] = [_red, _blue]
	var order: Array[int] = [0, 1]
	if reverse:
		order.reverse()
	if early:
		for index in order:
			device.arrive(game.id, "Europe", paths[index], &"", sources[index])
	await _settled(carousel)
	var cards := _cards(carousel)
	if not early:
		assert_bool(cards[0].is_ready() or cards[1].is_ready()).is_false()
		device.arrive(game.id, "Europe", paths[order[0]], &"", sources[order[0]])
		assert_bool(await Fixtures.until(self, func() -> bool: return cards[order[0]].is_ready())).is_true()
		assert_bool(cards[order[1]].is_ready()).is_false()
		device.arrive(game.id, "Europe", paths[order[1]], &"", sources[order[1]])
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[0].is_ready() and cards[1].is_ready())).is_true()
	assert_object(cards[0].label).is_not_same(cards[1].label)
	assert_bool(cards[0].label.get_image().get_pixel(16, 16).is_equal_approx(Color.RED)).is_true()
	assert_bool(cards[1].label.get_image().get_pixel(16, 16).is_equal_approx(Color.BLUE)).is_true()
	for card: LabelCard in cards.slice(0, 2):
		card.grab_focus()
		assert_object(_label(carousel)).is_same(card.label)
	cards[chosen].grab_focus()
	var picked := cards[chosen].label
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	assert_array(device.chosen_labels).is_equal([sources[chosen] + "/Europe"])
	assert_object(_label(carousel)).is_same(picked)
	carousel.queue_free()
	await await_idle_frame()
