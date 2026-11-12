# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Never a dead screen, and never the wrong one (INV-20): whatever the presses and whenever they land, the app is on
## the screen its scenarios say (screen_model.gd), with the consoles, the selection and the focus they say, the device
## asked what they say, and something shows and takes the next press.

const Fixtures := preload("res://test/screens/fixtures.gd")
const ScreenModel := preload("res://test/screens/screen_model.gd")
const ScreenWatch := preload("res://test/screens/screen_watch.gd")
## The findings the walk meets, names and goes on from: the fix of one deletes its line, and its test below then
## expects none.
const KNOWN: Array[String] = []
## Draws of a walk, the least times each screen it must reach is come to, and the most frames it may take.
const STEPS := 900
const VISITS := 2
const MOST_FRAMES := 60000
## The environment variable giving how many seeds each start walks (one when unset), and the gap between a start's seed
## and the next ones derived from it.
const WALK_SEEDS := "WALK_SEEDS"
const _SEED_STRIDE := 7919
## The longest fade the carousel plays once it may stand still, in frames at 60 a second, rounded up: the rail rising
## and the console's name coming back as the ring closes (carousel.gd `_on_order_closing`: `_RING_RISE_AFTER_S` +
## `TR_GAMES_RAIL_BACK_S`, `_RING_BACK_AFTER_S` + `_RING_BACK_S`, 0.62 s each). What still disagrees after it fails.
const AGREE_FRAMES := 38
## Beside the console or the game in the middle, by touch; held this long, a finger long-presses.
const BESIDE := Vector2(420.0, 0.0)
const HELD_S := 0.7
const _BUTTONS: Dictionary[String, JoyButton] = {
	"LEFT": JOY_BUTTON_DPAD_LEFT, "RIGHT": JOY_BUTTON_DPAD_RIGHT, "DOWN": JOY_BUTTON_DPAD_DOWN, "A": JOY_BUTTON_A,
	"B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y, "START": JOY_BUTTON_START,
}
const _PADS: Array[String] = ["LEFT", "RIGHT", "UP", "DOWN", "A", "A", "A", "B", "X", "Y", "START"]
const _FINGERS: Array[String] = ["TAP", "TAP_LEFT", "TAP_RIGHT", "LONG", "FLICK"]
## Dragged sideways past one step of the ring ([constant ConsoleOrder._DRAG_STEP]): only the placing's.
const _DRAGS: Array[String] = ["DRAG_LEFT", "DRAG_RIGHT"]
const _DRAG := Vector2(170.0, 0.0)
## The requests an answer is held for, and those that fail. A save of the settings held, its two seconds pass at once
## with a lapse of the fake clock (the token "lapse").
const _HOLDABLE: Array[StringName] = [&"pick_folder", &"scan", &"order_consoles", &"preview", &"save_button_style",
	&"save_edge_smoothing", &"save_backdrop", &"save_pixel_veil", &"save_games_float", &"save_games_in_line"]
const _FAILABLE: Array[StringName] = [&"pick_folder", &"set_up", &"scan", &"remove", &"order_consoles",
	&"save_button_style", &"save_edge_smoothing", &"save_backdrop", &"save_preferred_region", &"save_language",
	&"save_pixel_veil", &"save_games_float", &"save_games_in_line", &"rename_game"]
## Consoles the form can add, and the one emulator the fake device has for each.
const _READY: Array[String] = ["psx", "gc", "gba", "ps2", "n64", "snes"]
const _EMULATOR := "ps2.armsx2"
## The screens a re-read shows on; where a finger is drawn, these and the placing.
const _FREE: Array[ScreenModel.At] = [ScreenModel.At.CONSOLES, ScreenModel.At.GAMES]
const _TOUCHED: Array[ScreenModel.At] = [ScreenModel.At.CONSOLES, ScreenModel.At.GAMES, ScreenModel.At.PLACING]
## The screens every walk must reach, and those a walk reaches more from the number of consoles it starts with.
const _COMMON: Array[ScreenModel.At] = [ScreenModel.At.CONSOLES, ScreenModel.At.GAMES, ScreenModel.At.SEARCH,
	ScreenModel.At.PROPERTIES, ScreenModel.At.LABELS, ScreenModel.At.NAMING, ScreenModel.At.FORM,
	ScreenModel.At.FORM_LIST, ScreenModel.At.SETTINGS, ScreenModel.At.SETTINGS_PAGE]
const _NEEDED: Dictionary[int, Array] = {
	0: [ScreenModel.At.NO_CONSOLE],
	1: [],
	2: [ScreenModel.At.ORDER, ScreenModel.At.ORDER_HOLDING],
	3: [ScreenModel.At.ORDER, ScreenModel.At.ORDER_HOLDING, ScreenModel.At.PLACING, ScreenModel.At.CONFIRM,
		ScreenModel.At.FORM_MODELS],
}


func after_test() -> void:
	Controls.style = &"xbox"
	EdgeSmoothingScreen.smooth(get_viewport(), Viewport.MSAA_4X)
	# A walk stopped between up held and up let go would hand the next test a held up.
	Input.action_release(&"ui_up")


# The walk may run several seeds (WALK_SEEDS): GdUnit's five minutes per test would cut it short.
@warning_ignore("unused_parameter")
func test_inv_20_a_walk_of_presses_from_no_console_never_leaves_a_dead_screen(timeout := 3600000) -> void:
	await _walk({}, 360442)


@warning_ignore("unused_parameter")
func test_inv_20_a_walk_of_presses_from_one_console_never_leaves_a_dead_screen(timeout := 3600000) -> void:
	await _walk({"ps2": 3}, 360413)


@warning_ignore("unused_parameter")
func test_inv_20_a_walk_of_presses_from_two_consoles_never_leaves_a_dead_screen(timeout := 3600000) -> void:
	await _walk({"ps2": 3, "gc": 2}, 360433)


@warning_ignore("unused_parameter")
func test_inv_20_a_walk_of_presses_from_three_consoles_never_leaves_a_dead_screen(timeout := 3600000) -> void:
	# A seed whose walk comes to every screen it needs at least twice: 360414 comes to the naming once.
	await _walk({"ps2": 3, "gc": 2, "gba": 2}, 360415)


## The folder field pressed twice before the first picker answers asks for one picker only.
func test_the_folder_pressed_twice_asks_for_one_picker() -> void:
	var run := await _replay({"ps2": 3}, ["settle", "UP", "A", "LET_UP", "wait:90", "look", "hold:pick_folder",
		"focus:Folder", "A", "A", "look", "release:pick_folder", "wait:2", "look"])
	assert_bool(run.stopped).is_false()
	assert_int(run.device.picks).is_equal(1)


## A folder answered once the form was left and opened again does not show in the new form.
func test_a_folder_answered_late_does_not_show_in_the_form_opened_since() -> void:
	var run := await _replay({"ps2": 3}, ["settle", "UP", "A", "LET_UP", "wait:90", "look", "hold:pick_folder",
		"focus:Folder", "A", "B", "wait:150", "look", "UP", "A", "LET_UP", "wait:90", "look", "release:pick_folder",
		"wait:2", "look"])
	assert_bool(run.stopped).is_false()
	assert_bool((run.carousel.get_node("%Screens/AddConsole") as AddConsole).setup().has_folder_uri).is_false()


## The carousel's own 3D is drawn on every frame something of its world shows, not only once a press settled: checked
## at each frame as it is drawn (when the next one starts: headless, the renderer gives no frame_pre_draw), into the
## games and out, through a game's properties, a launch and a toss.
func test_the_carousel_s_3d_is_drawn_on_every_frame_its_world_shows_something() -> void:
	var run := await _begin({"ps2": 6}, 0)
	var device := run.device
	var carousel := run.carousel
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


func test_the_oracle_names_a_part_of_the_carousel_left_shown_over_a_page_in_front() -> void:
	var carousel := (await _begin({"ps2": 3}, 0)).carousel
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.wait(self, func() -> bool:
		return Fixtures.checked_page(carousel) == "Settings" and Fixtures.shown_under_page(carousel).is_empty())
	var rail := carousel._rail
	rail.show()
	rail.sunk = 0.0
	rail.ground_alpha = 1.0
	assert_str(Fixtures.shown_under_page(carousel)).is_equal("rail over Settings")


func test_the_oracle_names_a_rail_left_half_sunk_over_a_page_in_front() -> void:
	var carousel := (await _begin({"ps2": 3}, 0)).carousel
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.wait(self, func() -> bool:
		return Fixtures.checked_page(carousel) == "Settings" and Fixtures.shown_under_page(carousel).is_empty())
	var rail := carousel._rail
	rail.show()
	rail.sunk = 0.5
	rail.ground_alpha = 0.0
	assert_str(Fixtures.shown_under_page(carousel)).is_equal("rail over Settings")


## The walk of [param walk_seed] from a library holding [param consoles], which must reach every screen its start
## allows. With [constant WALK_SEEDS] set to n, n walks, the next seeds derived from that one: each is walked to its end
## and each failure printed with its own seed and path; the screens are counted over all of them, and the seeds that
## failed are listed at the end.
func _walk(consoles: Dictionary[String, int], walk_seed: int) -> void:
	var seeds := maxi(1, OS.get_environment(WALK_SEEDS).to_int())
	var visits: Dictionary[int, int] = {}
	var checked: Dictionary[String, bool] = {}
	var known: Dictionary[String, int] = {}
	var failed: Array[int] = []
	for walk in seeds:
		var drawn := walk_seed + _SEED_STRIDE * walk
		var run := await _walk_seed(consoles, drawn)
		if run.stopped:
			failed.append(drawn)
		for at in run.visits:
			visits[at] = visits.get(at, 0) + run.visits[at]
		checked.merge(run.checked)
		for finding in run.known:
			known[finding] = known.get(finding, 0) + run.known[finding]
	if seeds == 1 and not failed.is_empty():
		return
	var walked := "the walk of seed %d" % walk_seed if seeds == 1 else "the %d walks from seed %d" % [seeds, walk_seed]
	# Against a walk that stays where it started.
	var needed: Array[ScreenModel.At] = _COMMON.duplicate()
	needed.append_array(_NEEDED[consoles.size()])
	for at in needed:
		var visited: int = visits.get(at, 0)
		assert_int(visited).override_failure_message("%s reached %d times by %s, known findings met: %s" % [
			ScreenModel.At.keys()[at], visited, walked, known]).is_greater_equal(VISITS)
	# The pages the under-page check really looked at (not skipped for a page not up, presses held, or a sequence moving).
	assert_array(checked.keys()).override_failure_message("pages checked by %s: %s" % [walked, checked.keys()]) \
		.contains(["Settings", "AddConsole"])
	assert_array(failed).override_failure_message("%d of %s failed, seeds %s (each printed above with its path)" % [
		failed.size(), walked, failed]).is_empty()


## A walk of [constant STEPS] draws by [param walk_seed] from a library holding [param consoles], its carousel freed
## after. Frames are fixed at 60 a second (scripts/test_godot.sh), so a seed walks the same path whatever the machine's
## load.
func _walk_seed(consoles: Dictionary[String, int], walk_seed: int) -> Run:
	var run := await _begin(consoles, walk_seed)
	var started := Engine.get_process_frames()
	await _walk_run(run)
	if not run.stopped:
		assert_int(Engine.get_process_frames() - started).is_less(MOST_FRAMES)
	Input.action_release(&"ui_up")
	run.carousel.queue_free()
	await await_idle_frame()
	return run


func _walk_run(run: Run) -> void:
	for step in STEPS:
		for token in _draw(run):
			await _obey(run, token)
			if run.stopped:
				return
	await _obey(run, "settle")


## [param path] obeyed from a library holding [param consoles], as a failure of a walk prints it.
func _replay(consoles: Dictionary[String, int], path: Array[String]) -> Run:
	var run := await _begin(consoles, 0)
	for token in path:
		await _obey(run, token)
		if run.stopped:
			break
	return run


## The carousel of a device past its first launch whose library holds [param consoles], an emulator installed for
## every platform, once a person can act on it; and its model. Its labels' images are listed and never downloaded,
## its picker of pictures gives none: what a label then shows is read on a thread, in the machine's time, not the
## walk's.
func _begin(consoles: Dictionary[String, int], walk_seed: int) -> Run:
	var run := Run.new()
	run.start = consoles
	run.walk_seed = walk_seed
	run.random.seed = walk_seed
	var device: WalkDevice = auto_free(WalkDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = consoles.duplicate()
	device.players_everywhere = true
	device.variants = [
		{"region": "Europe", "source": "launchbox", "source_name": "LaunchBox"},
		{"region": "USA", "source": "launchbox", "source_name": "LaunchBox"},
	]
	device.fail(&"pick_label_picture")
	run.device = device
	run.carousel = Fixtures.fresh_carousel(self, device)
	run.model.slow = device.slow
	run.model.failing = device.failing
	run.model.start(ScreenWatch.with_games(device))
	await Fixtures.wait(self, func() -> bool: return Fixtures.alive(run.carousel))
	return run


## What comes next, drawn by the walk's seed: a wait of 0 to 12 frames, answers held, failing or let go, then one
## of a pad press, an errand towards another screen, a finger, the "+", the app put aside, the system's back, a
## settle. A finger, the "+" and the back each span frames: they come on a settled screen.
func _draw(run: Run) -> Array[String]:
	var random := run.random
	var tokens: Array[String] = ["wait:%d" % random.randi_range(0, 12)]
	for request in _HOLDABLE:
		if request in run.device.slow:
			if random.randf() < 0.3:
				tokens.append("release:%s" % request)
		elif random.randf() < 0.04:
			tokens.append("hold:%s" % request)
	for request in _FAILABLE:
		if request in run.device.failing:
			if random.randf() < 0.5:
				tokens.append("mend:%s" % request)
		elif random.randf() < 0.02:
			tokens.append("fail:%s" % request)
	# A save of the settings held: its two seconds pass, B then most often pressed to leave it.
	if not run.model.held_save.is_empty() and random.randf() < 0.5:
		tokens.append("lapse")
		if random.randf() < 0.7:
			tokens.append("B")
	var at := run.model.at
	var drawn := random.randf()
	if drawn < 0.5:
		var pad := _PADS[random.randi_range(0, _PADS.size() - 1)]
		# A on the confirmation may be on Remove: B instead, unless a removal is allowed ([method _above_start]).
		if pad == "A" and at == ScreenModel.At.CONFIRM and not _above_start(run, run.model.consoles):
			pad = "B"
		# Up held spans frames, like the "+": a transition ending under it would open the ball by itself.
		if pad == "UP":
			tokens.append("settle")
		tokens.append(pad)
		if pad == "UP":
			tokens.append("LET_UP")
	elif drawn < 0.68:
		# The screen an errand reaches is waited for and compared: a screen left before it took a press is not one the
		# walk has seen. The pads drawn alone still land during the transitions.
		tokens.append_array(_errand(run))
		tokens.append("settle")
	elif drawn < 0.76 and at in _TOUCHED:
		tokens.append("settle")
		var fingers := _FINGERS + _DRAGS if at == ScreenModel.At.PLACING else _FINGERS
		tokens.append(fingers[random.randi_range(0, fingers.size() - 1)])
	elif drawn < 0.82 and at == ScreenModel.At.CONSOLES:
		tokens.append_array(_plus())
	elif drawn < 0.88:
		tokens.append_array(_aside(run))
	elif drawn < 0.94:
		tokens.append("settle")
		tokens.append("BACK")
	else:
		tokens.append("settle")
	return tokens


## Up held, A, up let go, on a settled screen: the "+" on the consoles screen.
func _plus() -> Array[String]:
	var presses: Array[String] = ["settle", "UP", "A", "LET_UP"]
	return presses


## A few presses towards another screen from the one the model is on, drawn among those that lead somewhere.
func _errand(run: Run) -> Array[String]:
	var model := run.model
	var ways: Array[Array] = []
	match model.at:
		ScreenModel.At.NO_CONSOLE:
			ways = [["focus:Add", "A"], ["Y"]]
		ScreenModel.At.CONSOLES:
			# Edit's swatches and confirmation lie two screens away: an errand also goes there in one go.
			ways = [["A"], ["X"], ["X", "settle", "focus:Model", "A"], ["X", "settle", "focus:Cancel", "A"], ["DOWN"], ["Y"],
				_plus()]
		ScreenModel.At.GAMES:
			ways = [["X"], ["DOWN"], ["Y"], ["B"], ["UP", "LET_UP"]]
		ScreenModel.At.SEARCH:
			ways = [["UP", "LET_UP"], ["B"], ["START"]]
		ScreenModel.At.PROPERTIES:
			ways = [["focus:Zone", "A"], ["focus:Name", "A"], ["B"]]
		ScreenModel.At.LABELS:
			ways = [["A"], ["RIGHT", "A"], ["RIGHT", "RIGHT", "A"], ["B"]]
		ScreenModel.At.FRAMING:
			ways = [["A"], ["B"]]
		ScreenModel.At.NAMING:
			ways = [["A", "START"], ["START"], ["B"]]
		ScreenModel.At.ORDER:
			ways = [["A"], ["RIGHT", "A"], ["B"]]
		ScreenModel.At.ORDER_HOLDING:
			ways = [["LEFT", "A"], ["RIGHT", "RIGHT", "A"], ["A"], ["B"]]
		ScreenModel.At.FORM:
			if model.editing:
				ways = [["focus:Model", "A"], ["focus:Cancel", "A"], ["focus:Add", "A"], ["B"]]
			else:
				ways = [_filling(run), _filling(run), ["focus:Folder", "A"], ["B"]]
		ScreenModel.At.FORM_LIST:
			ways = [["A"], ["B"]]
		ScreenModel.At.FORM_MODELS:
			ways = [["RIGHT", "A"], ["B"]]
		ScreenModel.At.CONFIRM:
			ways = [["focus:Cancel", "A"], ["B"]]
			if _above_start(run, run.model.consoles):
				ways.append(["focus:Remove", "A"])
		ScreenModel.At.PLACING:
			ways = [["A"], ["LEFT", "A"], ["RIGHT", "RIGHT", "A"], ["B"]]
		ScreenModel.At.SETTINGS:
			var rows := ScreenModel.PAGES.keys()
			ways = [["focus:%s" % rows[run.random.randi_range(0, rows.size() - 1)], "A"], ["focus:PixelVeil", "A"],
				["focus:GamesFloat", "A"], ["focus:GamesInLine", "A"], ["B"]]
		ScreenModel.At.SETTINGS_PAGE:
			ways = [["A"], ["RIGHT", "A"], ["B"]]
	var presses: Array[String] = []
	presses.assign(ways[run.random.randi_range(0, ways.size() - 1)])
	return presses


## The presses that fill the form and add a console the ring does not have: its type, its emulator, a folder, Add.
func _filling(run: Run) -> Array[String]:
	var presses: Array[String] = ["B"]
	var free := _READY.filter(func(id: String) -> bool: return id not in run.model.consoles)
	if not free.is_empty():
		var chosen: String = free[run.random.randi_range(0, free.size() - 1)]
		presses = ["focus:Type", "A", "wait:2", "row:%s" % chosen, "A", "focus:Emulator", "A", "wait:2",
			"row:%s" % _EMULATOR, "A", "focus:Folder", "A", "wait:2", "focus:Add", "A"]
	return presses


## The app put aside and brought back 0 to 12 frames later; two times in three, unless a console is being placed,
## one console's folder changed meanwhile: a game copied in, or all its games deleted while another keeps some and the
## consoles stay as many as the walk started with.
func _aside(run: Run) -> Array[String]:
	var random := run.random
	var tokens: Array[String] = ["pause"]
	var with_games := ScreenWatch.with_games(run.device)
	if random.randi_range(0, 2) > 0 and not with_games.is_empty() and run.model.at != ScreenModel.At.PLACING:
		var changed := with_games[random.randi_range(0, with_games.size() - 1)]
		var emptied := _above_start(run, with_games) and with_games.size() > 1 and random.randi_range(0, 1) == 0
		tokens.append(("none:%s" if emptied else "more:%s") % changed)
	tokens.append("wait:%d" % random.randi_range(0, 12))
	tokens.append("resume")
	return tokens


## Whether [param shown] holds more consoles than the walk started with: only then does the draw confirm a removal
## or empty a folder, so a walk never ends below its start and every screen its start allows ([constant _NEEDED]) stays
## reachable; removals and emptyings still come whenever the form added consoles.
func _above_start(run: Run, shown: Array[String]) -> bool:
	return shown.size() > run.start.size()


## Obeys one token of a path, kept in the run's path.
func _obey(run: Run, token: String) -> void:
	run.path.append(token)
	var word := token.get_slice(":", 0)
	var what := token.get_slice(":", 1)
	match word:
		"wait":
			for frame in what.to_int():
				await await_idle_frame()
		"hold":
			run.device.hold(StringName(what))
		"fail":
			run.device.fail(StringName(what))
		"mend":
			run.device.mend(StringName(what))
		"release":
			await _release(run, StringName(what))
		"focus":
			_focus(run, what)
		"row":
			_focus_row(run, what)
		"pause":
			await Fixtures.pause(self)
			run.model.paused()
		"resume":
			await Fixtures.resume(self)
			run.model.resumed()
		"more":
			run.device.consoles[what] += 1
		"lapse":
			Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
		"none":
			run.device.consoles[what] = 0
		"look":
			var seen := _look(run)
			if seen.phase == ScreenModel.Phase.LIVE:
				_agree(run, seen)
		"settle":
			await _settle(run)
		_:
			# A finger is drawn for the screen the model was on before the settle that comes first; one landing on
			# another (a placing refused as it settled shows the form) is not sent: the walk's fingers are the
			# consoles', the games' and the placing's.
			if (token in _FINGERS and run.model.at not in _TOUCHED) or (token in _DRAGS and run.model.at != ScreenModel.At.PLACING):
				return
			await _press(run, token)


## One press: what the app says of itself is read, compared when it takes presses, the press sent, then given to
## the model with what was read.
func _press(run: Run, pressed: String) -> void:
	var seen := _look(run)
	if seen.phase == ScreenModel.Phase.LIVE and not _agree(run, seen):
		return
	var point := run.carousel._selected_point()
	match pressed:
		"UP":
			await Fixtures.hold(self, &"ui_up")
		"LET_UP":
			await Fixtures.hold(self, &"ui_up", false)
		"TAP":
			await Fixtures.touch(self, [point])
		"TAP_LEFT":
			await Fixtures.touch(self, [point - BESIDE])
		"TAP_RIGHT":
			await Fixtures.touch(self, [point + BESIDE])
		"LONG":
			await Fixtures.touch(self, [point], HELD_S)
		"FLICK":
			await Fixtures.touch(self, [point, point - Vector2(40.0, 200.0)])
		"DRAG_LEFT":
			await Fixtures.touch(self, [point, point - _DRAG])
		"DRAG_RIGHT":
			await Fixtures.touch(self, [point, point + _DRAG])
		"BACK":
			run.carousel.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			for frame in 3:
				await await_idle_frame()
		_:
			await Fixtures.joypad(self, _BUTTONS[pressed])
	var sent := ScreenModel.Press.keys().find("B" if pressed == "BACK" else pressed) as ScreenModel.Press
	run.row = run.model.press(sent, seen, _look(run))


## The held answer to [param request] is given: the app takes it at once, then the model.
func _release(run: Run, request: StringName) -> void:
	if request not in run.device.slow:
		return
	run.device.let_go(request)
	run.model.answered(request, ScreenWatch.with_games(run.device))
	await await_idle_frame()


## The focus on the control named [param control] of the page in front, or of a game's properties, as a few
## direction presses put it: only while that page takes presses, its list and its swatches closed.
func _focus(run: Run, control: String) -> void:
	var seen := _look(run)
	if seen.phase != ScreenModel.Phase.LIVE or seen.at in [ScreenModel.At.FORM_LIST, ScreenModel.At.FORM_MODELS]:
		return
	var surface: Node = Fixtures.shown_screen(run.carousel)
	if surface == null:
		surface = run.carousel.get_node("%Properties")
	var target := surface.find_child(control, true, false) as Control
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
		run.model.focus = ""


## The focus on the row [param id] of the list the form shows, if it shows one with that row.
func _focus_row(run: Run, id: String) -> void:
	var list: StudioChooser = run.carousel.get_node("%Screens/AddConsole/%Choice")
	var index := list.ids().find(id)
	if list.visible and index >= 0:
		list.rows()[index].grab_focus()
		run.model.focus = ""


func _look(run: Run) -> ScreenModel.Seen:
	var seen := ScreenWatch.read(run.carousel, run.device)
	seen.picks = run.device.picks
	return seen


## Whether the app, taking presses, shows what the model has, names the screen it names and leaves nothing of its
## 3D unseen; a known finding is counted and passed.
func _agree(run: Run, seen: ScreenModel.Seen) -> bool:
	var wrong := run.model.check(seen)
	var finding := wrong.get_slice(":", 0)
	if finding in KNOWN:
		run.known[finding] = _met(run, finding) + 1
		wrong = ""
	var named := run.model.screen()
	if wrong.is_empty() and not named.is_empty() and seen.screen != named:
		wrong = "the app names its screen %s, the model %s" % [seen.screen, named]
	var unseen := _unseen_3d(run.carousel)
	if wrong.is_empty() and not unseen.is_empty():
		wrong = "the carousel's 3D is not drawn but %s shows in it" % unseen
	if not wrong.is_empty():
		_stop(run, wrong)
		return false
	if run.model.at != run.last:
		run.last = run.model.at
		var visits: int = run.visits.get(run.last, 0)
		run.visits[run.last] = visits + 1
	return true


## How many times the walk met the known finding [param finding].
func _met(run: Run, finding: String) -> int:
	var met: int = run.known.get(finding, 0)
	return met


## Every held answer given, then frames until the app takes presses again (four seconds of its time at most: a dead
## screen otherwise), shows the folders read again where it can, stands still, and shows what the model has.
func _settle(run: Run) -> void:
	for request: StringName in run.device.slow.duplicate():
		await _release(run, request)
	var carousel := run.carousel
	var live := func() -> bool: return _look(run).phase == ScreenModel.Phase.LIVE and Fixtures.alive(carousel)
	if not await Fixtures.until(self, live):
		_stop(run, "dead on %s, focus %s" % [_look(run).screen, Fixtures.focus(self)])
		return
	if not _agree(run, _look(run)):
		return
	var read_again := func() -> bool: return _look(run).consoles == ScreenWatch.with_games(run.device)
	if run.model.due and run.model.at in _FREE and not await Fixtures.until(self, read_again):
		_stop(run, "the folders read again never showed: %s on screen, %s on the device" % [_look(run).consoles,
			ScreenWatch.with_games(run.device)])
		return
	var still := func() -> bool:
		var standing: bool = Fixtures.ScreenAgreement.shown(carousel)["still"]
		return standing or Fixtures.shown_screen(carousel) != null
	await Fixtures.until(self, still)
	# Still is not the end of every fade: the rail and the console's name may come in for a while more.
	for frame in AGREE_FRAMES:
		if Fixtures.ScreenAgreement.disagreement(carousel).is_empty():
			break
		await await_idle_frame()
	var disagreement := Fixtures.ScreenAgreement.disagreement(carousel)
	if not disagreement.is_empty():
		_stop(run, disagreement)
		return
	if not await Fixtures.until(self, func() -> bool: return Fixtures.shown_under_page(carousel).is_empty()):
		_stop(run, Fixtures.shown_under_page(carousel))
		return
	var checked := Fixtures.checked_page(carousel)
	if not checked.is_empty():
		run.checked[checked] = true
	var seen := _look(run)
	if seen.phase == ScreenModel.Phase.LIVE:
		_agree(run, seen)


## Fails the test with [param why], the seed and the path walked, as [method _replay] takes it.
func _stop(run: Run, why: String) -> void:
	run.stopped = true
	fail("%s\nlast row applied: %s\nwalk of seed %d, %d tokens; to replay it: await _replay(%s, %s)" % [why, run.row,
		run.walk_seed, run.path.size(), run.start, run.path])


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


## One walk: the app, its fake device, the model beside it, and what was walked.
class Run:
	var carousel: Carousel
	var device: WalkDevice
	var model := ScreenModel.new()
	var random := RandomNumberGenerator.new()
	var start: Dictionary[String, int] = {}
	var walk_seed := 0
	var path: Array[String] = []
	## The source of the last row the model applied.
	var row := ""
	## How many times each known finding was met, and each screen come to.
	var known: Dictionary[String, int] = {}
	var visits: Dictionary[int, int] = {}
	var last := -1
	## The pages the under-page check really looked at.
	var checked: Dictionary[String, bool] = {}
	var stopped := false


## The walk's fake device: it counts the folder picks, holds or cancels one as any other request, and keeps its
## consoles in the order a placing answered, as the plugin's library does.
class WalkDevice extends Fixtures.NewDevice:
	## The requests held and those failing, by their names in snake case: the model reads these very arrays.
	var slow: Array[StringName] = []
	var failing: Array[StringName] = []
	var picks := 0

	## [param request] answered only once let go: held as NEVER, so that letting one go leaves the others held.
	func hold(request: StringName) -> void:
		if request not in slow:
			slow.append(request)
			answers[_scripted(request)] = Answer.NEVER

	## [param request]'s held answer given now, the others still held.
	func let_go(request: StringName) -> void:
		slow.erase(request)
		answers.erase(_scripted(request))
		released.emit()

	## [param request] fails whenever it is answered; a folder pick, as the person gave up the picker.
	func fail(request: StringName) -> void:
		if request not in failing:
			failing.append(request)
			failures[_scripted(request)] = &"cancelled" if request == &"pick_folder" else &"unexpected"

	func mend(request: StringName) -> void:
		failing.erase(request)
		failures.erase(_scripted(request))

	func pick_folder() -> AndroidServices.Pick:
		picks += 1
		return await super()

	static func _scripted(request: StringName) -> Request:
		return Request[String(request).to_upper()]

	func place_console(platform_id: String, gap: int) -> AndroidServices.Placed:
		order = PackedStringArray(ScreenWatch.with_games(self))
		var answer := super(platform_id, gap)
		if answer.ok:
			var ordered: Dictionary[String, int] = {}
			for id in order:
				ordered[id] = consoles[id]
			ordered.merge(consoles)
			consoles = ordered
		return answer
