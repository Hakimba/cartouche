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
	# The validated fit, facing the camera, still.
	var stand := carousel._row.selected_stand()
	assert_vector(carousel._row.to_global(stand.origin)).is_equal_approx(Vector3(0.0, 0.2, 0.0), Vector3.ONE * 0.0001)
	assert_vector(stand.basis.get_scale()).is_equal_approx(Vector3.ONE * 0.98, Vector3.ONE * 0.0001)
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


func test_a_long_name_is_cut_so_the_caption_pointing_at_it_stays_on_the_screen() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	properties._show_name(properties._name, "Berserk - Millennium Falcon-hen - Seima Senki no Shou (Japan)")
	await Fixtures.action(self, &"ui_down")
	await await_idle_frame()
	var box: Rect2 = properties._callout._target_box
	assert_float(box.size.x).is_greater(0.0)
	assert_float(box.end.x).is_less_equal(properties.size.x - DiscProperties._CAPTION_EDGE)


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


func test_the_image_under_the_cursor_is_drawn_on_the_still_disc_without_a_press_and_B_draws_the_saved_one_again() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var saved := _label(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return cards[1].is_ready())).is_true()
	# The staged disc stands still: only a redraw asked for shows what its label became.
	var view := carousel._properties._medium.view()
	for card: LabelCard in [cards[1], cards[-1]]:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		card.grab_focus()
		assert_object(_label(carousel)).is_same(card.label if not card.own else saved)
		await await_idle_frame()
		assert_int(view.render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
	cards[1].grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_object(_label(carousel)).is_same(saved)
	assert_object(Fixtures.focus(self)).is_same(carousel._properties._zone)


func test_the_ring_of_a_label_downloading_keeps_drawing_on_the_still_disc() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var view := carousel._properties._medium.view()
	var game := carousel._row.selected_game()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await await_idle_frame()
	await await_idle_frame()
	assert_int(view.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	carousel._row.downloading(game.id, -1.0)
	for frame in 3:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await await_idle_frame()
		assert_int(view.render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
	carousel._row.downloaded(game.id)
	await await_idle_frame()
	# Once the ring is gone and drawn out, the idle disc is drawn no more.
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await await_idle_frame()
	await await_idle_frame()
	assert_int(view.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_the_cards_follow_the_focus_whole_in_view_to_the_last_and_back() -> void:
	var many: Array[Dictionary] = []
	for region: String in ["Europe", "North America", "Japan", "France", "Germany", "Spain", "Italy", "Korea"]:
		many.append(_scan(region, _red))
	var carousel: Carousel = (await _on_games(many))[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	var cards := _cards(carousel)
	for move: StringName in [&"ui_right", &"ui_left"]:
		for step in cards.size() - 1:
			await Fixtures.action(self, move)
			assert_bool(Fixtures.in_view(Fixtures.focus(self))).is_true()
		assert_object(Fixtures.focus(self)).is_same(cards[-1] if move == &"ui_right" else cards[0])


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


func test_B_during_opening_reverses_to_the_games() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	assert_float(carousel._row.stage).is_equal(0.0)
	assert_bool(carousel._properties.visible).is_false()


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
				assert_object(properties._staging).is_same(properties._on_properties)
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
				var naming := properties._naming
				if naming._typed:
					# The name with its caret, from the first character that keeps the caret in view.
					assert_bool(naming._typed.insert(naming._caret, "|").ends_with(naming._field.text)).is_true()
					assert_str(naming._field.text).contains("|")
				else:
					assert_str(naming._field.text).is_equal(carousel._row.selected_game().own_title())
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
	_pinch(centre, 1.5)
	Input.flush_buffered_events()
	_pinch(centre, 1.5)
	Input.flush_buffered_events()
	assert_float(properties._framing.zoom).is_equal_approx(1.5, 0.0001)
	_pinch(centre, 1.2)
	Input.flush_buffered_events()
	assert_float(properties._framing.zoom).is_equal_approx(1.8, 0.0001)
	var framed_before := _window(carousel)
	var centre_before := properties._framing.centre
	var label_width := properties._label_px
	var touch := InputEventScreenTouch.new()
	touch.position = get_tree().root.get_final_transform() * centre
	touch.pressed = true
	_send_touch_now(touch)
	for step in range(1, 13):
		var drag := InputEventScreenDrag.new()
		drag.position = get_tree().root.get_final_transform() * (centre + Vector2(10.0 * step, 0.0))
		_send_touch_now(drag)
	touch.position = get_tree().root.get_final_transform() * (centre + Vector2(120.0, 0.0))
	touch.pressed = false
	_send_touch_now(touch)
	var moved := 120.0 / label_width * framed_before.z
	var centre_after := centre_before.x - moved
	assert_float(properties._framing.centre.x).is_equal_approx(centre_after, 0.000001)
	var width := properties._picture.size.x
	var left_pixel := int(centre_after * width - framed_before.z * width / 2.0)
	assert_float(_window(carousel).x).is_equal_approx(float(left_pixel) / width, 0.000001)
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


## The keyboard of [param carousel]'s selected game's name, open; the caret taken to the name's end with R1
## when [param at_end].
func _on_keyboard(carousel: Carousel, at_end := true) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _settled(carousel)
	if at_end:
		for letter in carousel._properties._naming.typed():
			await Fixtures.joypad(self, JOY_BUTTON_RIGHT_SHOULDER)


func test_A_on_the_name_opens_a_keyboard_under_the_disc_the_name_ready_to_edit() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	var game := carousel._row.selected_game()
	await _on_keyboard(carousel, false)
	assert_int(properties._step).is_equal(DiscProperties.Step.NAMING)
	assert_object(properties._staging).is_same(DiscProperties._on_naming)
	# The caret before the name's first letter, R1 and L1 moving it through the name.
	assert_str(properties._naming._field.text).is_equal("|" + game.title)
	await Fixtures.joypad(self, JOY_BUTTON_RIGHT_SHOULDER)
	await Fixtures.joypad(self, JOY_BUTTON_RIGHT_SHOULDER)
	await Fixtures.joypad(self, JOY_BUTTON_LEFT_SHOULDER)
	assert_str(properties._naming._field.text).is_equal(game.title.insert(1, "|"))
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


func test_INV_E12_08_the_zone_shape_follows_every_medium_kind_and_its_projected_label() -> void:
	var subjects: Array[Array] = [
		["ps2", "ps2_dvd"], ["psx", "ps1_cd"], ["gc", "gc_mini_dvd"], ["wii", "wii_dvd"],
		["xbox", "xbox_dvd"], ["xbox360", "xbox360_dvd"], ["nes", "nes_cart"], ["snes", "snes_pal_cart"],
		["n64", "n64_cart"], ["gb", "gb_cart"], ["gbc", "gbc_cart"], ["gba", "gba_cart"],
		["nes", "famicom_cart"], ["snes", "sfc_cart"], ["snes", "snes_us_cart"],
	]
	var covered: Array[String] = []
	for subject in subjects:
		var platform: String = subject[0]
		var medium: String = subject[1]
		var device := Fixtures.past_first_launch(self, {platform: 1})
		var carousel := Fixtures.fresh_carousel(self, device)
		assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
		await Fixtures.joypad(self, JOY_BUTTON_A)
		assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
		var game := carousel._row.selected_game()
		game.medium = medium
		var games: Array[AndroidServices.Game] = [game]
		var manifest: MediumManifest = load(MediumManifest.FOLDERS.path_join(medium).path_join(MediumManifest.FILE))
		var models: Dictionary[String, PackedScene] = {medium: load(manifest.scene)}
		carousel._row.show_shelf(games, 0, models, ShelfRow.LabelLook.new())
		covered.append(medium)
		await await_idle_frame()
		await Fixtures.joypad(self, JOY_BUTTON_X)
		await _settled(carousel)
		var properties := carousel._properties
		var zone := properties._zone
		var cartridge := platform in ["nes", "snes", "n64", "gb", "gbc", "gba"]
		assert_int(zone.shape).is_equal(LabelZone.Shape.RECTANGLE if cartridge else LabelZone.Shape.DISC)
		var label := properties._label_mesh
		var camera := carousel.get_viewport().get_camera_3d()
		var bounds := label.get_aabb()
		var box := Rect2(camera.unproject_position(label.to_global(bounds.get_endpoint(0))), Vector2.ZERO)
		for corner in range(1, 8):
			box = box.expand(camera.unproject_position(label.to_global(bounds.get_endpoint(corner))))
		var expected := box.grow(10.0)
		if not cartridge:
			var diameter := maxf(expected.size.x, expected.size.y)
			expected = Rect2(expected.get_center() - Vector2.ONE * diameter / 2.0, Vector2.ONE * diameter)
		assert_vector(zone.position).is_equal_approx(expected.position, Vector2.ONE * 0.02)
		assert_vector(zone.size).is_equal_approx(expected.size, Vector2.ONE * 0.02)
		assert_float(zone.corner_radius).is_equal_approx(20.48 if cartridge else expected.size.x / 2.0, 0.02)
		assert_float(zone._material.get_shader_parameter(&"radius")).is_equal_approx(zone.corner_radius, 0.001)
		assert_vector(zone._material.get_shader_parameter(&"box_size")).is_equal_approx(expected.size, Vector2.ONE * 0.02)
		var expected_rig := StudioLights.mixed(StudioLights.rig_of(carousel._row.selected_game().medium, &"properties"),
			StudioLights.rig_of(carousel._row.selected_game().medium, &"properties", true), 0.0 if properties.art.has_texture(carousel._row.selected_game()) else 1.0)
		var sources := properties._medium.lights()
		assert_int(sources.size()).is_equal(expected_rig.sources.size())
		for i in sources.size():
			assert_float(sources[i].light_energy).is_equal_approx(expected_rig.sources[i].energy, 0.001)
		var pool := _light(carousel).material as ShaderMaterial
		assert_bool(pool.get_shader_parameter(&"shaped")).is_true()
		var body := Plinth.bounds(properties._model, properties._medium.holder())
		var world := properties._medium.holder().global_transform
		assert_vector(world * body.get_center()).is_equal_approx(Vector3(0.0, 0.2, 0.0), Vector3.ONE * 0.001)
		var extent := body.size * world.basis.get_scale()
		assert_float(maxf(extent.x, extent.y)).is_equal_approx(1.2 * (0.92 if cartridge else 0.98), 0.001)
		var body_box := Rect2(camera.unproject_position(world * body.get_endpoint(0)), Vector2.ZERO)
		for corner in range(1, 8):
			body_box = body_box.expand(camera.unproject_position(world * body.get_endpoint(corner)))
		if cartridge:
			# A cartridge's body is its meshes' own vertices, not the corners of their box.
			body_box = Rect2(camera.unproject_position(properties._model.global_position), Vector2.ZERO)
			for mesh: MeshInstance3D in properties._model.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						body_box = body_box.expand(camera.unproject_position(mesh.global_transform * point))
		assert_float(properties._name.position.y).is_equal_approx(
			maxf(zone.get_rect().end.y, body_box.end.y) + 23.04, 0.02)
		await Fixtures.joypad(self, JOY_BUTTON_A)
		await _settled(carousel)
		for card in _cards(carousel):
			var thumbnail := card.get_child(0).get_child(0) as TextureRect
			var material := thumbnail.material as ShaderMaterial
			assert_bool(material.get_shader_parameter(&"cartridge")).is_equal(cartridge)
			assert_float(material.get_shader_parameter(&"proportion")).is_equal_approx(carousel._row.selected_label_proportion(), 0.001)
		await Fixtures.joypad(self, JOY_BUTTON_B)
		await _settled(carousel)
		await Fixtures.joypad(self, JOY_BUTTON_B)
		await _settled(carousel)
		assert_bool(properties.is_open()).is_false()
		assert_bool(properties._model == null).is_true()
		assert_int(carousel._row.selected_game().medium.length()).is_greater(0)
		carousel.queue_free()
		await await_idle_frame()

	covered.sort()
	var expected := MediumManifest.found().keys()
	expected.sort()
	assert_array(covered).contains_exactly(expected)


func test_the_properties_travel_reverses_without_jumping_and_ignores_other_presses() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	var initial_stand := carousel._row.selected_stand()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	for frame in 5:
		await await_idle_frame()
	var progress := properties._travel
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_int(properties._direction).is_equal(-1)
	assert_float(properties._travel).is_less_equal(progress)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_int(properties._step).is_equal(DiscProperties.Step.PROPERTIES)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_int(properties._direction).is_equal(1)
	await _settled(carousel)
	assert_object(Fixtures.focus(self)).is_same(properties._zone)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _settled(carousel)
	assert_float(carousel._row.stage).is_equal(0.0)
	assert_vector(carousel._row.selected_stand().origin).is_equal_approx(initial_stand.origin, Vector3(0.001, 0.05, 0.001))
	assert_vector(carousel._row.selected_stand().basis.get_scale()).is_equal_approx(initial_stand.basis.get_scale(), Vector3.ONE * 0.001)


func test_a_long_properties_name_is_one_line_with_a_fitted_ellipsis() -> void:
	var carousel: Carousel = (await _on_games())[0]
	carousel._row.selected_game().title = "The Long Adventure ".repeat(20)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var properties := carousel._properties
	var line := properties._name_text.line
	assert_float(properties._name.size.x).is_less_equal(1160.0)
	assert_float(properties._name.size.y).is_equal_approx(93.44, 0.01)
	assert_int(line.placements(Vector2.ZERO).size()).is_less(properties._name.text.length())
	var dots := StudioText.new("…", StudioTokens.Face.JAKARTA_800, 53.76, -0.035).placements(Vector2.ZERO)
	var placed := line.placements(Vector2.ZERO)
	assert_int(placed[-1].index).is_equal(dots[-1].index)


func test_the_zone_morphs_between_label_shapes_in_320_ms() -> void:
	var zone: LabelZone = auto_free(LabelZone.new())
	add_child(zone)
	zone.place(Rect2(100.0, 100.0, 120.0, 120.0), LabelZone.Shape.DISC, Color.BLUE)
	var original := zone.get_rect()
	zone.place(Rect2(200.0, 180.0, 240.0, 80.0), LabelZone.Shape.RECTANGLE, Color.BLUE)
	assert_vector(zone.position).is_equal(original.position)
	for frame in 3:
		await await_idle_frame()
	assert_float(zone.corner_radius).is_between(20.48, 70.0)
	assert_bool(await Fixtures.until(self, func() -> bool: return zone._morph == null)).is_true()
	assert_vector(zone.position).is_equal(Vector2(190.0, 170.0))
	assert_vector(zone.size).is_equal(Vector2(260.0, 100.0))
	assert_float(zone.corner_radius).is_equal_approx(20.48, 0.000001)


func test_the_travel_clock_caps_a_slow_frame_and_reversal_preserves_the_drawn_transform() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	var properties := carousel._properties
	properties.set_process(false)
	var started := properties._travel
	properties._process(1.0)
	assert_float(properties._travel - started).is_equal_approx(0.25, 0.001)
	for back_profile: bool in [false, true]:
		properties._back_profile = back_profile
		properties._direction = -1 if back_profile else 1
		properties._travel = 0.55
		properties._process(0.0)
		var drawn := properties._medium.holder().global_transform
		var duration := 0.38 if back_profile else 0.4
		var step := 0.02 / duration
		var direction := 1 if back_profile else -1
		properties._input(_travel_press(&"open_properties" if back_profile else &"screen_back"))
		assert_bool(properties._back_profile).is_equal(back_profile)
		assert_float(properties._travel).is_equal(0.55)
		properties._process(0.02)
		var expected_progress := 0.55 + direction * step
		assert_float(properties._travel).is_equal_approx(expected_progress, 0.000001)
		assert_bool(properties._back_profile).is_equal(back_profile)
		var expected := _expected_stand(properties, expected_progress, back_profile)
		var actual := properties._medium.holder().global_transform
		assert_vector(actual.origin).is_equal_approx(expected.origin, Vector3.ONE * 0.0001)
		assert_bool(actual.basis.is_equal_approx(expected.basis)).is_true()
		var bound := drawn.origin.distance_to(expected.origin) + 0.0001
		assert_float(actual.origin.distance_to(drawn.origin)).is_less_equal(bound)
		properties._input(_travel_press(&"screen_back" if back_profile else &"open_properties"))
		properties._process(0.02)
		assert_bool(properties._back_profile).is_equal(back_profile)
		assert_float(properties._travel).is_equal_approx(0.55, 0.000001)
	properties.set_process(true)
	await _settled(carousel)


@warning_ignore("unused_parameter")
func test_the_zone_border_and_glow_obey_both_focus_and_transition_opacity(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var zone := LabelZone.new()
	view.add_child(zone)
	add_child(view)
	zone.place(Rect2(78.0, 78.0, 100.0, 100.0), LabelZone.Shape.RECTANGLE, Color.RED)
	for alpha: float in [1.0, 0.5, 0.0]:
		zone._outline.modulate.a = alpha
		var picture := await _viewport_frame(view)
		assert_float(picture.get_pixel(70, 128).a).is_equal_approx(alpha, 2.0 / 255.0)
	zone._outline.modulate.a = 1.0
	zone.modulate.a = 0.0
	var hidden := await _viewport_frame(view)
	assert_float(hidden.get_pixel(70, 128).a).is_less(1.0 / 255.0)


func _send_touch_now(event: InputEvent) -> void:
	Fixtures.clock.ms += 16
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _viewport_frame(view: SubViewport) -> Image:
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await await_idle_frame()
	RenderingServer.force_draw(false)
	return view.get_texture().get_image()


func _travel_press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _reference_curve(points: Vector4, t: float) -> float:
	var low := 0.0
	var high := 1.0
	for iteration in 60:
		var u := (low + high) / 2.0
		var x := 3.0 * (1.0 - u) * (1.0 - u) * u * points.x + 3.0 * (1.0 - u) * u * u * points.z + u * u * u
		if x < clampf(t, 0.0, 1.0):
			low = u
		else:
			high = u
	var u := (low + high) / 2.0
	return 3.0 * (1.0 - u) * (1.0 - u) * u * points.y + 3.0 * (1.0 - u) * u * u * points.w + u * u * u


func _expected_stand(properties: DiscProperties, progress: float, back: bool) -> Transform3D:
	var elapsed := (1.0 - progress) * 0.38 if back else progress * 0.4
	var moved := _reference_curve(Vector4(0.2, 0.8, 0.2, 1.0), elapsed / 0.36)
	if back:
		moved = 1.0 - moved
	var basis := Basis.from_scale(Vector3.ONE * properties._on_properties.size)
	var centre := properties.row.to_local(Vector3(0.0, 0.2, properties.row.global_position.z))
	var box := Plinth.bounds(properties._model, properties._medium.holder())
	var target := Transform3D(basis, centre - basis * box.get_center())
	return properties.row.global_transform * properties._row_stand.interpolate_with(target, moved)


func test_the_opening_and_back_profiles_follow_the_briefs_intervals() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	var properties := carousel._properties
	properties.set_process(false)
	for back: bool in [false, true]:
		properties._back_profile = back
		properties._direction = -1 if back else 1
		for progress: float in [0.25, 0.5, 0.625, 0.75, 0.9, 1.0]:
			properties._travel = progress
			properties._apply_travel()
			var t := (1.0 - progress) * 0.38 if back else progress * 0.4
			var zone := 1.0 - clampf(t / 0.1, 0.0, 1.0) if back \
				else _reference_curve(Vector4(0.0, 0.0, 0.58, 1.0), (t - 0.24) / 0.16)
			var name_alpha := 1.0 - _reference_curve(Vector4(0.42, 0.0, 1.0, 1.0), t / 0.16) if back \
				else _reference_curve(Vector4(0.2, 0.9, 0.25, 1.04), (t - 0.2) / 0.2)
			var callout := 1.0 - clampf(t / 0.12, 0.0, 1.0) if back else clampf((t - 0.28) / 0.12, 0.0, 1.0)
			assert_float(properties._zone.modulate.a).is_equal_approx(zone, 0.00001)
			assert_float(properties._name.modulate.a).is_equal_approx(name_alpha, 0.00001)
			assert_float(properties._callout.modulate.a).is_equal_approx(callout, 0.00001)
			assert_float(properties._name_drop()).is_equal_approx(20.48 * (1.0 - name_alpha), 0.00001)
			properties._process(0.0)
			var actual := properties._medium.holder().global_transform
			var expected := _expected_stand(properties, progress, back)
			assert_vector(actual.origin).is_equal_approx(expected.origin, Vector3.ONE * 0.0001)
			assert_bool(actual.basis.is_equal_approx(expected.basis)).is_true()
	properties._close()
	properties.set_process(true)
	await _settled(carousel)


func test_B_on_settled_properties_returns_the_model_and_the_games_chrome() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var properties := carousel._properties
	var model := properties._model
	var parent := properties._model_parent
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(properties._back_profile).is_true()
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	assert_bool(properties.visible).is_false()
	assert_object(model.get_parent()).is_same(parent)
	assert_object(parent.get_child(0)).is_same(model)
	assert_float(carousel._row.stage).is_equal(0.0)
	for item in properties.behind:
		assert_bool(item.visible).is_true()
		assert_float(item.modulate.a).is_equal(1.0)


func test_a_repeated_target_and_new_tint_during_a_morph_finish_on_the_requested_box() -> void:
	var zone: LabelZone = auto_free(LabelZone.new())
	add_child(zone)
	var target := Rect2(200.0, 180.0, 240.0, 80.0)
	zone.place(Rect2(100.0, 100.0, 120.0, 120.0), LabelZone.Shape.DISC, Color.BLUE)
	zone.place(target, LabelZone.Shape.RECTANGLE, Color.BLUE)
	for frame in 3:
		await await_idle_frame()
	var partial := zone.get_rect()
	zone.place(target, LabelZone.Shape.RECTANGLE, Color.RED)
	zone.place(target, LabelZone.Shape.RECTANGLE, Color.RED)
	assert_vector(zone.position).is_equal(partial.position)
	assert_vector(zone.size).is_equal(partial.size)
	assert_bool(zone._morph != null).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return zone._morph == null)).is_true()
	assert_vector(zone.position).is_equal(target.grow(10.0).position)
	assert_vector(zone.size).is_equal(target.grow(10.0).size)
	assert_float(zone.corner_radius).is_equal_approx(20.48, 0.000001)
	assert_that(zone.gel).is_equal(Color.RED)


func test_clearing_a_timeline_driven_callout_resets_its_fade_target() -> void:
	var callout: FocusCallout = auto_free(FocusCallout.new())
	var caption := Label.new()
	caption.name = "Caption"
	callout.add_child(caption)
	add_child(callout)
	callout.point("Name", Vector2(10.0, 20.0), Vector2(40.0, 20.0))
	callout.timeline = true
	callout.modulate.a = 0.4
	callout.clear()
	assert_float(callout._fade_alpha).is_equal(0.0)
	callout.timeline = false
	callout.point("Name", Vector2(10.0, 20.0), Vector2(40.0, 20.0))
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(callout.modulate.a, 1.0))).is_true()


func test_an_absent_or_incomplete_selected_model_closes_properties_without_moving_nodes() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var properties := carousel._properties
	var row := carousel._row
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var model := place.shown.get_child(0)
	var label: MeshInstance3D = model.get_node("Label")
	var mesh := label.mesh
	for missing: String in ["place", "model", "label", "mesh", "body"]:
		row.set_process(false)
		var extra := MeshInstance3D.new()
		match missing:
			"place": place.game = -1
			"model": place.shown.remove_child(model)
			"label": label.name = "MissingLabel"
			"mesh": label.mesh = null
			"body": model.add_child(extra)
		carousel._open_properties()
		assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
		assert_bool(properties.is_open()).is_false()
		assert_bool(properties.visible).is_false()
		assert_object(properties._medium).is_null()
		assert_float(row.stage).is_equal(0.0)
		match missing:
			"place": place.game = row.selected_index()
			"model":
				place.shown.add_child(model)
				place.shown.move_child(model, 0)
			"label": label.name = "Label"
			"mesh": label.mesh = mesh
			"body": model.remove_child(extra)
		extra.free()
		assert_object(model.get_parent()).is_same(place.shown)
		row.set_process(true)
		await await_idle_frame()


func test_resting_properties_only_reproject_when_the_medium_or_view_changes() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 1})
	var carousel := Fixtures.carousel_for(self, device)
	var properties: DiscProperties = carousel.get_node("%Properties")
	# Replacing an unready script does not free Nodes created by its field initializers.
	properties._reader.free()
	properties._picture_reader.free()
	properties._zone = properties.get_node("%Zone")
	properties._zone._outline.free()
	properties.set_script(_CountingProperties)
	properties.get_node("%Zone").set_script(_CountingZone)
	carousel.get_node("%Light").set_script(_CountingLight)
	add_child(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await _settled(carousel)
	var counted: _CountingProperties = carousel._properties
	var zone: _CountingZone = counted._zone
	var light: _CountingLight = counted.light
	var projections := counted.projections
	var places := zone.places
	var pools := light.pools
	for frame in 8:
		await await_idle_frame()
	assert_int(counted.projections).is_equal(projections)
	assert_int(zone.places).is_equal(places)
	assert_int(light.pools).is_equal(pools)
	var camera := get_viewport().get_camera_3d()
	camera.position.x += 0.01
	counted._process(0.0)
	assert_int(counted.projections).is_equal(projections + 2)
	camera.fov += 1.0
	counted._process(0.0)
	assert_int(counted.projections).is_equal(projections + 4)
	var pixels := get_window().size
	get_window().size += Vector2i(64, 0)
	counted._process(0.0)
	assert_int(counted.projections).is_equal(projections + 6)
	get_window().size = pixels
	counted._process(0.0)
	counted._travel_stand.origin.x += 0.01
	counted._process(0.0)
	assert_int(counted.projections).is_equal(projections + 10)
	counted._process(0.0)
	assert_int(counted.projections).is_equal(projections + 10)


class _CountingProperties extends DiscProperties:
	var projections := 0

	func _project(vertices: PackedVector3Array, stand: Transform3D, camera: Camera3D) -> Rect2:
		projections += 1
		return super._project(vertices, stand, camera)


class _CountingZone extends LabelZone:
	var places := 0

	func place(label: Rect2, kind: Shape, tint: Color) -> void:
		places += 1
		super.place(label, kind, tint)


class _CountingLight extends OperatingLight:
	var pools := 0

	func shaped(box: Rect2, gel: Color, opacity: float) -> void:
		pools += 1
		super.shaped(box, gel, opacity)
