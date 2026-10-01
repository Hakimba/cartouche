# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## What the tests of the screens in front of the carousel share: a device as a first launch finds
## it, the presses the screens take, and where the flow stands.

const CAROUSEL := preload("res://carousel/carousel.tscn")
const NAVIGATION: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]


## The carousel on [param device], the welcome as short as can be, not added yet.
static func carousel_for(suite: GdUnitTestSuite, device: NewDevice) -> Carousel:
	var carousel: Carousel = suite.auto_free(CAROUSEL.instantiate())
	carousel.android = device
	var screens: ScreenFlow = carousel.get_node("%Screens")
	screens.welcome_waits = false
	return carousel


## [method carousel_for], added to [param suite]; not waited for.
static func fresh_carousel(suite: GdUnitTestSuite, device: NewDevice) -> Carousel:
	var carousel := carousel_for(suite, device)
	suite.add_child(carousel)
	return carousel


## On the form, the focus on the type, chooses [param platform_id].
static func choose_type(suite: GdUnitTestSuite, carousel: Carousel, device: NewDevice, platform_id := "ps2") -> void:
	suite.assert_str(focus(suite).name).is_equal("Type")
	await joypad(suite, JOY_BUTTON_A)
	await choose_in_list(suite, carousel, platform_name(device, platform_id))


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
	suite.assert_bool(await on(suite, carousel, "NoConsole")).is_true()
	await joypad(suite, JOY_BUTTON_A)
	suite.assert_bool(await on(suite, carousel, "AddConsole")).is_true()
	if chosen:
		await choose_console(suite, carousel, device)
	return carousel


## On the form just opened (the focus on the type), chooses [param platform_id] and its first
## emulator; the focus ends on the folder.
static func choose_console(suite: GdUnitTestSuite, carousel: Carousel, device: NewDevice, platform_id := "ps2") -> void:
	await choose_type(suite, carousel, device, platform_id)
	await action(suite, &"ui_down")
	await joypad(suite, JOY_BUTTON_A)
	await choose_in_list(suite, carousel, device.installed_players(platform_id)[0].emulator_name)
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


## Frames until [param condition] holds, four seconds at most; whether it did.
static func until(suite: GdUnitTestSuite, condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 4000:
		if condition.call():
			return true
		await suite.await_idle_frame()
	return condition.call()


## Forty moves drawn by [param random] on [param carousel]'s screen [param screen_name], once it
## shows: after each, exactly one control of that screen has the focus, visible (INV-E6-01).
static func wander(suite: GdUnitTestSuite, carousel: Carousel, screen_name: String, random: RandomNumberGenerator) -> void:
	suite.assert_bool(await on(suite, carousel, screen_name)).is_true()
	for move in 40:
		await action(suite, NAVIGATION[random.randi() % NAVIGATION.size()])
		var focused := focus(suite)
		suite.assert_object(focused).is_not_null()
		if focused == null:
			return
		suite.assert_bool(focused.is_visible_in_tree()).is_true()
		suite.assert_bool(shown_screen(carousel).is_ancestor_of(focused)).is_true()


## Chooses [param option] in the list the form of [param carousel] shows now.
static func choose_in_list(suite: GdUnitTestSuite, carousel: Carousel, option: String) -> void:
	var list: Control = carousel.get_node("%Screens/AddConsole/%Choice")
	suite.assert_bool(await until(suite, func() -> bool: return list.visible)).is_true()
	await suite.await_idle_frame()
	for item: Button in list.get_node("%Items").get_children():
		if item.text == option:
			item.grab_focus()
	suite.assert_str((focus(suite) as Button).text).is_equal(option)
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


## [param name] held down, or let go when not [param pressed]; returns a frame on.
static func hold(suite: GdUnitTestSuite, name: StringName, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = name
	await _send(suite, event, pressed)


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
	## The button style stored, as the settings send it; none when empty.
	var button_style := ""
	## Whether the library already has games (the desktop demo's, set up nowhere).
	var has_games := false
	## The platforms set up, by id, with how many games each has.
	var consoles: Dictionary[String, int] = {}
	## Choices of [member consoles] other than the usual ones (sub-folders, discs grouped, ARMSX2), by id.
	var setups: Dictionary[String, Dictionary] = {}
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
	var previews: Array[AndroidServices.PlatformSetup] = []
	var previewed_platforms: Array[String] = []
	var set_up: Array[AndroidServices.PlatformSetup] = []
	var scans := 0
	var removed: Array[String] = []
	var setting_opened := false

	func _init() -> void:
		catalog = AndroidServices.CatalogSummary.new(AndroidServices._desktop_demo("catalog"))

	func _ready() -> void:
		pass

	func is_available() -> bool:
		return true

	func settings() -> AndroidServices.SettingsAnswer:
		var answer := {"ok": true, "first_launch": first_launch}
		if button_style:
			answer["button_style"] = button_style
		return AndroidServices.SettingsAnswer.new(answer)

	func library() -> AndroidServices.LibraryAnswer:
		if has_games:
			return AndroidServices.LibraryAnswer.new({"ok": true, "library": JSON.stringify(AndroidServices._desktop_demo("library"))})
		return AndroidServices.LibraryAnswer.new({"ok": true, "library": _library()})

	func curtain_allowed() -> bool:
		return curtain

	func request_curtain_permission() -> AndroidServices.Result:
		setting_opened = true
		return AndroidServices.Result.new(_payload(&"curtain"))

	func save_button_style(style: StringName) -> AndroidServices.Result:
		saved_styles.append(style)
		return AndroidServices.Result.new({"ok": true})

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
		return AndroidServices.Battery.new({"level_percent": 99, "charging": false})

	func select_game(_game: AndroidServices.Game) -> AndroidServices.Result:
		return AndroidServices.Result.new({"ok": true})

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
					"regions": [], "languages": [], "serials": [], "discs": [{"name": "%d.iso" % i}], "last_disc": 0,
					"identified": false})
			if not indices.is_empty():
				shelves.append({"platform": platform_id, "games": indices, "selected": 0})
		return JSON.stringify({"setups": sent, "games": listed, "shelves": {"shelves": shelves, "selected": 0}})

	static func _folder_uri(platform_id: String) -> String:
		return "content://tree/card%3AROMs%2F" + platform_id

	## A failure for [param request] if it is one of [member failing], a success otherwise.
	func _payload(request: StringName) -> Dictionary:
		return {"ok": false, "code": &"unexpected"} if request in failing else {"ok": true}
