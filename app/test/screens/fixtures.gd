# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## What the tests of the screens in front of the carousel share: a device as a first launch finds
## it, the presses the screens take, and where the flow stands.

const CarouselFixtures := preload("res://test/carousel/fixtures.gd")
const CAROUSEL := preload("res://carousel/carousel.tscn")
const NAVIGATION: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
## The flags a screen sets while it takes no press (a screen without one, or a signal of that name, is not guarded),
## and must have cleared once it is shown and still.
const _GUARDS: Array[StringName] = [&"_busy", &"_leaving", &"_closing", &"saving"]
const _FRAME_MS := 16

static var clock := Clock.new()


## The carousel on [param device], the welcome as short as can be, not added yet.
static func carousel_for(suite: GdUnitTestSuite, device: NewDevice) -> Carousel:
	var carousel: Carousel = suite.auto_free(CAROUSEL.instantiate())
	carousel.android = device
	carousel.clock = clock.now
	var screens: ScreenFlow = carousel.get_node("%Screens")
	screens.welcome_waits = false
	# Left alone between two presses, the app would rest: these tests keep it awake. Not ready yet,
	# the carousel is reached by its scene.
	(carousel.get_node(^"%Resting") as Resting).stays_awake = true
	return carousel


## A device past its first launch whose library holds [param consoles] (games by platform id, in
## their order; the catalog lists gba before ps2), freed with [param suite]'s test.
static func past_first_launch(suite: GdUnitTestSuite, consoles: Dictionary[String, int]) -> NewDevice:
	var made: NewDevice = suite.auto_free(NewDevice.new())
	made.first_launch = false
	made.curtain = true
	made.consoles = consoles
	return made


## Once the properties of a console and the ring putting the consoles in order have stopped moving.
static func settled_consoles(suite: GdUnitTestSuite, carousel: Carousel) -> void:
	suite.assert_bool(await until(suite, func() -> bool:
		return not carousel._console_properties._busy and not carousel._order._busy \
			and not (carousel.get_node("%Screens/Settings") as SettingsMenu).is_processing())).is_true()
	await suite.await_idle_frame()


## [method carousel_for], added to [param suite]; not waited for.
static func fresh_carousel(suite: GdUnitTestSuite, device: NewDevice) -> Carousel:
	var carousel := carousel_for(suite, device)
	suite.add_child(carousel)
	return carousel


## On the form, the focus on the type, chooses [param platform_id].
static func choose_type(suite: GdUnitTestSuite, carousel: Carousel, platform_id := "ps2") -> void:
	suite.assert_str(focus(suite).name).is_equal("Type")
	await joypad(suite, JOY_BUTTON_A)
	await choose_in_list(suite, carousel, platform_id)


## The catalog's name of [param platform_id]; fails the test when there is none.
static func platform_name(device: NewDevice, platform_id: String) -> String:
	for platform in device.catalog.platforms:
		if platform.id == platform_id:
			return platform.name
	assert(false, "no platform " + platform_id)
	return ""


## [param device]'s carousel on the form adding a console, the curtain allowed; with
## [param chosen], the PS2 and its first emulator chosen, the focus on the folder.
static func on_form(suite: GdUnitTestSuite, device: NewDevice, chosen := true) -> Carousel:
	device.curtain = true
	var carousel := fresh_carousel(suite, device)
	suite.assert_bool(await on(suite, carousel, "ButtonStyle")).is_true()
	await joypad(suite, JOY_BUTTON_A)
	await choose_initial_region(suite, carousel)
	suite.assert_bool(await on(suite, carousel, "NoConsole")).is_true()
	await joypad(suite, JOY_BUTTON_A)
	suite.assert_bool(await on(suite, carousel, "AddConsole")).is_true()
	if chosen:
		await choose_console(suite, carousel, device)
	return carousel


static func choose_initial_region(suite: GdUnitTestSuite, carousel: Carousel, region := "") -> void:
	suite.assert_bool(await on(suite, carousel, "PreferredRegion")).is_true()
	var screen := carousel.get_node("%Screens/PreferredRegion") as PreferredRegionScreen
	var index := screen._choices.find(region)
	(screen._cards.get_child(index) as Control).grab_focus()
	await joypad(suite, JOY_BUTTON_A)


## On the form just opened (the focus on the type), chooses [param platform_id] and its first
## emulator; the focus ends on the folder.
static func choose_console(suite: GdUnitTestSuite, carousel: Carousel, device: NewDevice, platform_id := "ps2") -> void:
	await choose_type(suite, carousel, platform_id)
	await action(suite, &"ui_down")
	await joypad(suite, JOY_BUTTON_A)
	await choose_in_list(suite, carousel, device.installed_players(platform_id)[0].id)
	await action(suite, &"ui_down")
	suite.assert_str(focus(suite).name).is_equal("Folder")


## The screen in front of [param carousel] now; none once the carousel took over.
static func shown_screen(carousel: Carousel) -> Control:
	for screen: Control in carousel.get_node("%Screens").get_children():
		if screen.is_visible_in_tree() and not screen.is_queued_for_deletion():
			return screen
	return null


## Whether [param carousel] comes to show the screen [param screen_name], laid out (its containers
## sort the frame after it shows, as a person would see it).
static func on(suite: GdUnitTestSuite, carousel: Carousel, screen_name: String) -> bool:
	var shown := await until(suite, func() -> bool:
		var screen := shown_screen(carousel)
		return screen != null and screen.name == screen_name)
	await suite.await_idle_frame()
	return shown


## Frames until [param condition] holds, four seconds of the game's time at most (not the machine's, which load
## stretches); whether it did.
static func until(suite: GdUnitTestSuite, condition: Callable) -> bool:
	var waited := 0.0
	while waited < 4.0:
		if condition.call():
			return true
		await suite.await_idle_frame()
		waited += suite.get_process_delta_time()
	return condition.call()


## Forty moves drawn by [param random] on [param carousel]'s screen [param screen_name], once it
## shows: after each, exactly one control of that screen has the focus, visible and whole in view (INV-20).
static func wander(suite: GdUnitTestSuite, carousel: Carousel, screen_name: String, random: RandomNumberGenerator) -> void:
	suite.assert_bool(await on(suite, carousel, screen_name)).is_true()
	await until(suite, func() -> bool: return focus(suite) != null and in_view(focus(suite)))
	for move in 40:
		await action(suite, NAVIGATION[random.randi() % NAVIGATION.size()])
		var focused := focus(suite)
		suite.assert_object(focused).is_not_null()
		if focused == null:
			return
		suite.assert_bool(focused.is_visible_in_tree()).is_true()
		suite.assert_bool(in_view(focused)).is_true()
		suite.assert_bool(shown_screen(carousel).is_ancestor_of(focused)).is_true()


## Whether a person can act on [param carousel] now (INV-20): the focus is on a control seen (no ancestor fully
## faded) that takes presses, inside the screen in front when one shows, and no input guard of that screen is left set;
## or no screen is in front and the carousel, shown and processing, or its ring takes the presses.
static func alive(carousel: Carousel) -> bool:
	var screen := shown_screen(carousel)
	var focused := carousel.get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree() and focused.can_process() and _seen(focused):
		return screen == null or (screen.is_ancestor_of(focused) and not _guarded(screen))
	return screen == null and ((carousel._shown and carousel.is_visible_in_tree() and carousel.can_process())
		or carousel._order.is_open())


## Whether an input guard of [param screen] is set.
static func _guarded(screen: Control) -> bool:
	for guard in _GUARDS:
		var flag: Variant = screen.get(guard)
		if flag is bool and flag:
			return true
	return false


## Whether [param control] shows whole: inside the screen and inside every scrolling container holding it.
static func in_view(control: Control) -> bool:
	var rect := control.get_global_rect()
	var node: Node = control
	while node is Control:
		if node is ScrollContainer and not (node as Control).get_global_rect().encloses(rect):
			return false
		node = node.get_parent()
	return control.get_viewport_rect().encloses(rect)


## Whether [param item] shows: neither it nor any ancestor fully transparent.
static func _seen(item: CanvasItem) -> bool:
	var node: Node = item
	while node is CanvasItem:
		if (node as CanvasItem).modulate.a <= 0.0 or (node as CanvasItem).self_modulate.a <= 0.0:
			return false
		node = node.get_parent()
	return true


## Chooses the platform or player [param id] in the chooser the form of [param carousel] shows now.
static func choose_in_list(suite: GdUnitTestSuite, carousel: Carousel, id: String) -> void:
	var list: StudioChooser = carousel.get_node("%Screens/AddConsole/%Choice")
	suite.assert_bool(await until(suite, func() -> bool: return list.visible)).is_true()
	await suite.await_idle_frame()
	var at := list.ids().find(id)
	suite.assert_int(at).is_greater_equal(0)
	list.rows()[at].grab_focus()
	suite.assert_int(list.focused()).is_equal(at)
	await joypad(suite, JOY_BUTTON_A)


static func focus(suite: GdUnitTestSuite) -> Control:
	return suite.get_viewport().gui_get_focus_owner()


## Whether a press of joypad button [param button] is the action [param name] for the input map now.
static func presses(button: JoyButton, name: StringName) -> bool:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event.is_action_pressed(name)


## A press of joypad button [param button], as the device sends it, to whatever has the focus;
## returns once [param suite] is a frame on.
static func joypad(suite: GdUnitTestSuite, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(suite, event)


## A press of [param name], through the whole input path (focus navigation included).
static func action(suite: GdUnitTestSuite, name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = name
	await _press(suite, event)


## From the consoles screen, the form adding one more console: up held turns the "+" ball into its
## button, A opens the form.
static func open_add_console(suite: GdUnitTestSuite, carousel: Carousel) -> void:
	await hold(suite, &"ui_up")
	await joypad(suite, JOY_BUTTON_A)
	await hold(suite, &"ui_up", false)
	suite.assert_bool(await on(suite, carousel, "AddConsole")).is_true()


## [param name] held down, or let go when not [param pressed]; returns a frame on.
static func hold(suite: GdUnitTestSuite, name: StringName, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = name
	await _send(suite, event, pressed)


## The time fingers are read at in tests ([member Carousel.clock]): it moves a frame's worth with
## each touch event the helpers below send, and as long as a finger is held, so that a tap, a long
## press or a swipe reads the same on any machine.
class Clock:
	var ms := 0

	func now() -> int:
		return ms


## A finger on the screen at [param points]' first (in the screen's own pixels, the window being
## another size), moved through the others a frame apart, then lifted after [param held_s] seconds
## more.
static func touch(suite: GdUnitTestSuite, points: Array[Vector2], held_s := 0.0) -> void:
	await finger(suite, points[0], true)
	for point: Vector2 in points.slice(1):
		await finger_to(suite, point)
	if held_s > 0.0:
		clock.ms += int(held_s * 1000.0)
		# A frame for the long press to be seen.
		await suite.await_idle_frame()
	await finger(suite, points[-1], false)


## The finger [param index] put down ([param down]) or lifted at [param at], in the screen's own
## pixels; lifted [param canceled], the system took the touch back.
static func finger(suite: GdUnitTestSuite, at: Vector2, down: bool, index := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = suite.get_tree().root.get_final_transform() * at
	event.pressed = down
	event.index = index
	event.canceled = canceled
	clock.ms += _FRAME_MS
	Input.parse_input_event(event)
	await suite.await_idle_frame()


## The finger, down, moved to [param to], in the screen's own pixels.
static func finger_to(suite: GdUnitTestSuite, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = suite.get_tree().root.get_final_transform() * to
	clock.ms += _FRAME_MS
	Input.parse_input_event(event)
	await suite.await_idle_frame()


## A press of the Enter key.
static func enter(suite: GdUnitTestSuite) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	await _press(suite, event)


## The app back to the front, as after an Android screen.
static func resume(suite: GdUnitTestSuite) -> void:
	suite.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await suite.await_idle_frame()


static func _press(suite: GdUnitTestSuite, event: InputEvent) -> void:
	for pressed: bool in [true, false]:
		await _send(suite, event, pressed)


static func _send(suite: GdUnitTestSuite, event: InputEvent, pressed: bool) -> void:
	var sent: InputEvent = event.duplicate()
	sent.set(&"pressed", pressed)
	Input.parse_input_event(sent)
	Input.flush_buffered_events()
	await suite.await_idle_frame()


## A device just installed on: no settings, no library, the curtain not allowed, one PS2
## emulator installed (none for any other platform, unless [member players_everywhere]), and a
## folder of [member games] games to pick ([member scanned_games] once added). Its library holds
## the [member consoles] set up. Counts what it is asked. The requests named in [member slow]
## answer only once [signal released]; those in [member failing] fail.
class NewDevice extends AndroidServices:
	signal released

	var first_launch := true
	## The button style and the preferred region stored, as the settings send them; none when empty.
	var button_style := ""
	var preferred_region := ""
	## Whether the selected game floats, as the settings send it.
	var games_float := false
	## The regions the plugin takes, as the settings send them.
	var preferred_regions := PackedStringArray(["Europe", "North America", "Japan"])
	## Whether the library already has games (the desktop demo's, set up nowhere).
	var has_games := false
	## The platforms set up, by id, with how many games each has.
	var consoles: Dictionary[String, int] = {}
	## Choices of [member consoles] other than the usual ones (sub-folders, discs grouped, ARMSX2), by id.
	var setups: Dictionary[String, Dictionary] = {}
	var console_variants: Dictionary[String, String] = {}
	var variants_kept: Array[Array] = []
	## The platforms whose folder access is gone.
	var lost_folders: Array[String] = []
	var players_everywhere := false
	var curtain := false
	var games := 55
	var scanned_games := 55
	var players: Array[Dictionary] = [{"player_id": "ps2.armsx2", "player_name": "ps2 - ARMSX2 (Refresh/GitHub)",
		"emulator_name": "ARMSX2 (Refresh/GitHub)", "extensions": PackedStringArray(["iso", "chd", "bin"])}]
	var slow: Array[StringName] = []
	var failing: Array[StringName] = []
	var saved_styles: Array[StringName] = []
	var saved_smoothings: Array[StringName] = []
	var saved_regions: Array[String] = []
	var saved_floats: Array[bool] = []
	## The consoles placed, each as `[platform id, gap]`.
	var placed: Array[Array] = []
	## The order the consoles are in, as placing answers it.
	var order := PackedStringArray()
	var previews: Array[AndroidServices.PlatformSetup] = []
	var previewed_platforms: Array[String] = []
	var set_up: Array[AndroidServices.PlatformSetup] = []
	var scans := 0
	var removed: Array[String] = []
	var setting_opened := false
	var titles_prepared := 0
	## The images every game's label can show, as the plugin lists them:
	## `{"region", "source", "source_name", "path"?}`.
	var variants: Array[Dictionary] = []
	var art_focus_calls: Array[PackedStringArray] = []
	## The images chosen for a label, in order, each as `source/region`.
	var chosen_labels: Array[String] = []
	## The picture of the user's own [method pick_label_picture] answers with: this size, drawn in
	## two halves (red, then blue) at [member picture_path]; when it is [member failing], none, for
	## [member picture_failure].
	var picture_size := Vector2i(64, 48)
	var picture_failure := &"cancelled"
	## Whether the picture answered is one the app then cannot read.
	var picture_unreadable := false
	var picture_path := "user://picked.png"
	## The framings kept with [method keep_own_label], as `{"zoom", "centre", "proportion"}`, in order.
	var kept_framings: Array[Dictionary] = []
	## How many launches were asked for ([method check_launch] is a launch's first call).
	var launches := 0
	## The names given with [method rename_game], in order.
	var names_given: Array[String] = []
	## The orders the consoles were put in ([method order_consoles]), in turn.
	var orders: Array[PackedStringArray] = []

	func _init() -> void:
		catalog = AndroidServices.CatalogSummary.new(DesktopPlugin.demo("catalog"))

	func _ready() -> void:
		pass

	func is_available() -> bool:
		return true

	## A frame after it is asked for, as the plugin answers: after the scene's first frame.
	func settings() -> AndroidServices.SettingsAnswer:
		await _frames(1)
		var answer := {"ok": true, "first_launch": first_launch, "games_float": games_float,
			"preferred_regions": preferred_regions}
		if button_style:
			answer["button_style"] = button_style
		if preferred_region:
			answer["preferred_region"] = preferred_region
		return AndroidServices.SettingsAnswer.new(answer)

	func library() -> AndroidServices.LibraryAnswer:
		await _frames(1)
		if has_games:
			return AndroidServices.LibraryAnswer.new({"ok": true, "library": JSON.stringify(DesktopPlugin.demo("library"))})
		return AndroidServices.LibraryAnswer.new({"ok": true, "library": _library()})

	func curtain_allowed() -> bool:
		return curtain

	func request_curtain_permission() -> AndroidServices.Result:
		setting_opened = true
		return AndroidServices.Result.new(_payload(&"curtain"))

	func save_button_style(style: StringName) -> AndroidServices.Result:
		saved_styles.append(style)
		return AndroidServices.Result.new({"ok": true})

	func save_edge_smoothing(smoothing: StringName) -> AndroidServices.Result:
		saved_smoothings.append(smoothing)
		return AndroidServices.Result.new({"ok": true})

	func save_games_float(floating: bool) -> AndroidServices.Result:
		saved_floats.append(floating)
		games_float = floating
		return AndroidServices.Result.new({"ok": true})

	## Places as the plugin does, answering as it sends it: `not_in_library` for a console not set up or without games,
	## `gap_out_of_range`, else the whole order.
	func place_console(platform_id: String, gap: int) -> AndroidServices.Placed:
		placed.append([platform_id, gap])
		var others := Array(order).filter(func(id: String) -> bool: return id != platform_id)
		var answer := {"ok": true}
		if consoles.get(platform_id, 0) == 0:
			answer = {"ok": false, "code": "not_in_library", "detail": "No console %s in the library to place" % platform_id}
		elif gap < 0 or gap > others.size():
			answer = {"ok": false, "code": "gap_out_of_range", "detail": "No gap %d among %d other consoles" % [gap, others.size()]}
		else:
			others.insert(gap, platform_id)
			order = PackedStringArray(others)
			answer["order"] = order
		return AndroidServices.Placed.new(answer)

	func save_preferred_region(region: String) -> AndroidServices.Result:
		saved_regions.append(region)
		var answer := _payload(&"save_preferred_region")
		if answer["ok"]:
			preferred_region = region
		return AndroidServices.Result.new(answer)

	func installed_players(platform_id: String) -> Array[AndroidServices.Player]:
		var found: Array[AndroidServices.Player] = []
		if platform_id != "ps2" and not players_everywhere:
			return found
		for player in players:
			found.append(AndroidServices.Player.new(player))
		return found

	func pick_folder() -> AndroidServices.Pick:
		return AndroidServices.Pick.new({"ok": true, "folder": {"uri": "content://tree/card%3AROMs%2Fps2", "name": "ps2",
			"place": {"volume": "card", "folders": PackedStringArray(["ROMs", "ps2"])}}})

	func prepare_titles() -> void:
		titles_prepared += 1

	func preview_platform(platform_id: String, setup: AndroidServices.PlatformSetup) -> AndroidServices.PreviewAnswer:
		previewed_platforms.append(platform_id)
		previews.append(setup)
		while &"preview" in slow:
			await released
		return AndroidServices.PreviewAnswer.new({"ok": true, "report": {"games": games, "files": games}})

	func set_up_platform(platform_id: String, setup: AndroidServices.PlatformSetup) -> AndroidServices.LibraryAnswer:
		set_up.append(setup)
		var answer := _payload(&"set_up")
		if answer["ok"]:
			consoles[platform_id] = consoles.get(platform_id, 0)
			setups[platform_id] = setup.to_wire()
			if not setup.variant_id.is_empty():
				console_variants[platform_id] = setup.variant_id
			answer["library"] = _library()
		return AndroidServices.LibraryAnswer.new(answer)

	func set_variant(platform_id: String, variant: String) -> AndroidServices.LibraryAnswer:
		variants_kept.append([platform_id, variant])
		var answer := await _later(&"set_variant")
		if platform_id not in consoles:
			answer = {"ok": false, "code": "not_in_library"}
		var base: ConsoleManifest = Appearance.defaults(ConsoleManifest.found()).get(platform_id)
		if base and not base.models().any(func(model: ConsoleManifest) -> bool:
			return ConsoleManifest.folder_of(model) == variant):
			answer = {"ok": false, "code": "unknown_variant"}
		if answer["ok"]:
			console_variants[platform_id] = variant
			answer["library"] = _library()
		return AndroidServices.LibraryAnswer.new(answer)

	func scan_platform(platform_id: String) -> AndroidServices.ScanAnswer:
		scans += 1
		while &"scan" in slow:
			await released
		if &"scan" in failing:
			return AndroidServices.ScanAnswer.new(_payload(&"scan"))
		consoles[platform_id] = scanned_games
		return AndroidServices.ScanAnswer.new({"ok": true, "library": _library(), "report": {"games": scanned_games}})

	func remove_platform(platform_id: String) -> AndroidServices.LibraryAnswer:
		var answer := _payload(&"remove")
		if answer["ok"]:
			removed.append(platform_id)
			consoles.erase(platform_id)
			console_variants.erase(platform_id)
			answer["library"] = _library()
		return AndroidServices.LibraryAnswer.new(answer)

	func persisted_folders() -> AndroidServices.FolderList:
		var folders: Array[Dictionary] = []
		for platform_id in consoles:
			if platform_id in lost_folders:
				continue
			folders.append({"uri": _folder_uri(platform_id), "name": platform_id,
				"place": {"volume": "card", "folders": PackedStringArray(["ROMs", platform_id])}})
		return AndroidServices.FolderList.new({"ok": true, "folders": folders})

	func battery() -> AndroidServices.Battery:
		return AndroidServices.Battery.new({"level_percent": 99, "plugged": false})

	func art_focus(games_on_screen: Array[AndroidServices.Game]) -> void:
		var ids := PackedStringArray()
		for selected in games_on_screen:
			ids.append(selected.id)
		art_focus_calls.append(ids)

	func select_game(_game: AndroidServices.Game) -> AndroidServices.Result:
		return AndroidServices.Result.new({"ok": true})

	# Both answer a few frames later, as the plugin does.
	func label_variants(_game: AndroidServices.Game) -> AndroidServices.LabelVariants:
		await _frames(3)
		return AndroidServices.LabelVariants.new({"ok": true, "variants": variants})

	func choose_label(game: AndroidServices.Game, region: String, source: String) -> AndroidServices.ArtAnswer:
		chosen_labels.append(source + "/" + region)
		await _frames(3)
		var answer := _payload(&"choose_label")
		if answer["ok"]:
			answer["art"] = {"game_id": game.id, "path": "chosen.jpg"}
		return AndroidServices.ArtAnswer.new(answer)

	func pick_label_picture() -> AndroidServices.LabelPicture:
		await _frames(3)
		if &"pick_label_picture" in failing:
			return AndroidServices.LabelPicture.new({"ok": false, "code": picture_failure, "detail": "no picture"})
		var image := Image.create_empty(picture_size.x, picture_size.y, false, Image.FORMAT_RGB8)
		image.fill(Color.RED)
		var half := picture_size.x >> 1
		image.fill_rect(Rect2i(half, 0, picture_size.x - half, picture_size.y), Color.BLUE)
		image.save_png(picture_path)
		var path := "user://no-such-picture.png" if picture_unreadable else picture_path
		return AndroidServices.LabelPicture.new({"ok": true, "picture": {
			"path": ProjectSettings.globalize_path(path), "width": picture_size.x, "height": picture_size.y}})

	func keep_own_label(game: AndroidServices.Game, framing: LabelFraming) -> AndroidServices.ArtAnswer:
		kept_framings.append({"zoom": framing.zoom, "centre": framing.centre, "proportion": framing.proportion})
		await _frames(3)
		var answer := _payload(&"keep_own_label")
		if answer["ok"]:
			# The kept image: the picture itself will do.
			answer["art"] = {"game_id": game.id, "path": ProjectSettings.globalize_path(picture_path)}
		return AndroidServices.ArtAnswer.new(answer)

	func check_launch(_game: AndroidServices.Game, _disc: int) -> AndroidServices.Result:
		launches += 1
		return AndroidServices.Result.new({"ok": false, "code": &"unavailable"})

	## Puts [member consoles] in [param platform_ids]' order, as the library sends them from then on.
	func order_consoles(platform_ids: PackedStringArray) -> AndroidServices.Result:
		orders.append(platform_ids)
		var answer := await _later(&"order_consoles")
		if answer["ok"]:
			var ordered: Dictionary[String, int] = {}
			for platform_id in platform_ids:
				ordered[platform_id] = consoles[platform_id]
			ordered.merge(consoles)
			consoles = ordered
		return AndroidServices.Result.new(answer)

	## Keeps a name as `DisplayName.of` and `Library.withDisplayName` do: one line, single spaces,
	## trimmed, 80 characters at most; blank or the game's own title, no name.
	func rename_game(game: AndroidServices.Game, shown: String) -> AndroidServices.Renamed:
		names_given.append(shown)
		var answer := await _later(&"rename_game")
		if answer["ok"]:
			var kept := _display_name(shown)
			var original := game.own_title()
			answer["title"] = kept if kept else original
			if kept and kept != original:
				answer["original_title"] = original
		return AndroidServices.Renamed.new(answer)

	## [param request]'s answer, a few frames later, once [signal released] when it is [member slow].
	func _later(request: StringName) -> Dictionary:
		await _frames(3)
		while request in slow:
			await released
		return _payload(request)

	## [param shown] as `DisplayName.of` keeps it.
	static func _display_name(shown: String) -> String:
		return RegEx.create_from_string("\\s+").sub(shown, " ", true).strip_edges().left(80).strip_edges()

	## An image [method label_variants] listed arrives for [param game_id]: at [param path], or
	## not, for [param failure].
	func arrive(game_id: String, region: String, path := "", failure := &"", source := "launchbox") -> void:
		var told := {"game_id": game_id, "region": region, "source": source,
			"source_name": "ScreenScraper" if source == "screenscraper" else "LaunchBox"}
		if path:
			told["path"] = path
		else:
			told["failure"] = failure
		label_variant_downloaded.emit(AndroidServices.LabelVariant.new(told))

	static func _frames(count: int) -> void:
		for frame in count:
			await (Engine.get_main_loop() as SceneTree).process_frame

	## [member consoles] as the plugin sends a library: each set up with its folder, then its games.
	func _library() -> String:
		var sent := {}
		var listed: Array[Dictionary] = []
		var shelves: Array[Dictionary] = []
		for platform_id in consoles:
			sent[platform_id] = setups.get(platform_id, {"folder_uri": _folder_uri(platform_id), "player_id": "ps2.armsx2",
				"disc_grouping": "grouped", "folder_depth": "subfolders"})
			var indices: Array[int] = []
			for i in consoles[platform_id]:
				indices.append(listed.size())
				listed.append({"id": "%s/%d" % [platform_id, i], "platform_id": platform_id, "title": "%s %d" % [platform_id, i],
					"regions": [], "medium": CarouselFixtures.media(platform_id)[0], "languages": [], "serials": [],
					"discs": [{"name": "%d.iso" % i}], "last_disc": 0, "identified": false})
			if not indices.is_empty():
				shelves.append({"platform": platform_id, "games": indices, "selected": 0})
		return JSON.stringify({"setups": sent, "games": listed, "shelves": {"shelves": shelves, "selected": 0},
			"console_variants": console_variants})

	static func _folder_uri(platform_id: String) -> String:
		return "content://tree/card%3AROMs%2F" + platform_id

	## A failure for [param request] if it is one of [member failing], a success otherwise.
	func _payload(request: StringName) -> Dictionary:
		return {"ok": false, "code": &"unexpected"} if request in failing else {"ok": true}
