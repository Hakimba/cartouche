# SPDX-License-Identifier: GPL-3.0-or-later
class_name Carousel
extends Control
## The main screens. The consoles screen shows one console per platform with games ([ConsoleRow]);
## A goes into the selected one, as its launch animation has it ([ConsoleSequence]), to the games
## screen: the platform's shelf of games, the selected game in the middle. There, left and right
## move along the shelf (held, faster and faster), A launches the selected game into its console
## ([GameLaunch]), B goes back out to the consoles, X opens the selected game's properties
## ([DiscProperties]); down opens the ribbon that searches the shelf, L1 and R1 go from letter to
## letter ([GameSearch]). The right stick turns the selected console on the consoles screen, the
## selected game on the games screen and in its properties, nothing in between. Where the user
## was is remembered across restarts. The games' disc scans arrive as the plugin finds them
## ([GameArt]), a bar at the bottom right, beside the hints, telling how it goes.
##
## By touch ([Finger]): on the consoles screen, a tap on the console in the middle goes into it, one
## beside it moves one console that way, a long press on it opens its properties, and a swipe
## anywhere moves one console; on the games screen, a tap beside the game in the middle moves one
## game, a long press on it opens its properties, a swipe beside it moves one game, however long or
## fast, a drag on it turns it, and nothing launches but A. A drag over the properties turns what
## they stage; what was turned comes back to the front once let go. The system's back gesture is B.
##
## Left alone, the app rests ([Resting]): drawn 30 times a second, then still until something
## changes; not while labels download. On the games screen the consoles behind are not drawn: they
## fade out once there, back in for a launch or to go out.
##
## In front of it, [ScreenFlow] shows the welcome at each start while the library loads, the first
## launch's screens, and the screens adding a console while none has games; Y on the consoles
## screen or the games screen opens the settings over it. On the consoles screen, holding up turns
## the "+" ball above the console into a button ([AddBall]), until up is let go: A then adds one
## more console, the consoles coming in again on it; down (or "Change place" in a console's
## properties) opens the ring putting the consoles in order ([ConsoleOrder]). The carousel waits for
## the screens in front to close.
##
## In debug builds, holding Select opens the device check, and command-line arguments set up
## measurements: `--welcome=skip` goes past the welcome without a press, `--demo-games=N` shows a
## made-up library of N games (all on one console with `--demo-shelf=ps2`), `--bench=scroll`, `enter`, `turn` or `launch` runs [CarouselBench],
## `--launch=rehearse` plays launches without starting anything (see [method AndroidServices.launch_game]),
## `--turntable=T` turns the selected game T times a second to show all its sides, `--shelf=gba`
## opens on that platform, `--shots=DIR` saves pictures at set frames ([FrameShots]). Without the
## Android plugin (the editor, a desktop run), the demo library is shown.

## The screen changed; in between, the animation into or out of the console plays.
signal screen_changed(screen: Screen)

enum Screen { CONSOLES, ENTERING, GAMES, LEAVING, PROPERTIES, CONSOLE_PROPERTIES, ORDER }

const _APPEARANCE := "res://data/carousel/appearance.json"
const _DEVICE_CHECK := "res://dev/device_check/device_check.tscn"
const _MESSAGE_S := 4.0
## The art bar moves to each new count in this time; once full, it stays a moment, then fades.
const _ART_STEP_S := 0.3
const _ART_FULL_S := 1.0
const _ART_FADE_S := 0.4
const _MOVING: Array[Screen] = [Screen.ENTERING, Screen.LEAVING]
## The screens with the selected console in the middle, which the right stick turns; and with the
## selected game.
const _CONSOLE_SCREENS: Array[Screen] = [Screen.CONSOLES, Screen.CONSOLE_PROPERTIES]
const _GAME_SCREENS: Array[Screen] = [Screen.GAMES, Screen.PROPERTIES]
## The console's name above it fades out as the animation into it starts, back in once out.
const _TITLE_FADE_S := 0.2
## The carousel comes in once the screens in front of it are gone: the consoles grow out of
## their centres, overshooting a little, then the console's name (or, over the games, the pill)
## fades in.
const _ARRIVAL_S := 0.45
const _TITLE_ARRIVES_S := 0.3
const _PILL_ARRIVES_S := 0.4
## The size the consoles come out of, as a part of theirs.
const _ARRIVAL_POINT := 0.01
## How much lower the consoles stand than the camera centres them, in pixels of the screen: room
## for the "+" ball above their name.
const _CONSOLES_LOWER_PX := 58.0
## How far down the screen the camera centres the selected console.
const _CONSOLE_Y := 420.0
## The games rise this much, in pixels of the screen, while the ribbon is open under them.
const _SEARCH_LIFT_PX := 54.0
## A finger this close to the console or game in the middle, in pixels, is on it; swiped this far
## sideways from where it came down, it moves one console or game.
const _ON_SELECTED_PX := 270.0
const _SWIPE_PX := 80.0
## The consoles behind the games fade out or back in in this time.
const _BEHIND_FADE_S := 0.3

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read: the engine's clock, a fake one in tests.
var clock := Callable(Time, &"get_ticks_msec"):
	set(read):
		clock = read
		if is_node_ready():
			_share_clock()

var _shelves: Array[AndroidServices.Shelf] = []
var _shelf := 0
var _screen := Screen.CONSOLES
## Index of the game each platform showed last in this session, by platform id.
var _positions: Dictionary[String, int] = {}
## The names the user gave consoles, by platform id.
var _console_names: Dictionary[String, String] = {}
var _platforms: Dictionary[String, AndroidServices.Platform] = {}
## The model of each medium each shelf's games come in, by platform id, then by medium.
var _shelf_models: Dictionary[String, Dictionary] = {}
var _appearance: Appearance
## Whether the library shown is made up: its labels get made-up artwork.
var _demo := false
## Set once the library is shown: until then there is nothing to move, launch or remember.
var _shown := false
var _direction := HeldDirection.new()
var _art_tween: Tween
## Whether labels download, neither waiting nor over: the app does not rest meanwhile.
var _downloading := false
var _arrival: Tween
## The console's name fading: one at a time, the latest wins.
var _title_fade: Tween
var _finger := Finger.new()
## Whether the finger came down on the console or game in the middle, and whether its swipe has
## moved one already.
var _finger_on_selected := false
var _swiped := false
## The row's height, the ribbon closed, and how much it rises while it is open, in world units.
var _row_y := 0.0
var _search_lift := 0.0
var _lift: Tween

@onready var _row: ShelfRow = %Row
@onready var _consoles: ConsoleRow = %Consoles
@onready var _sequence: ConsoleSequence = %Sequence
@onready var _clock: Label = %Clock
@onready var _console_title: Control = %ConsoleTitle
@onready var _console_name: Label = %ConsoleName
@onready var _console_model: Label = %ConsoleModel
@onready var _add_ball: AddBall = %AddBall
@onready var _camera: Camera3D = $Camera
@onready var _battery: BatteryChip = %Battery
@onready var _resting: Resting = %Resting
## Shown while a run looks for art; its content, apart, hides for a message and fades once done.
@onready var _art_progress: Control = %ArtProgress
@onready var _art_content: Control = %Content
@onready var _art_bar: ProgressBar = %Bar
@onready var _art_text: Label = %ArtText
@onready var _art: GameArt = %Art
@onready var _pill: Control = %Pill
@onready var _console_properties: ConsoleProperties = %ConsoleProperties
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _message_timer: Timer = %MessageTimer
@onready var _screens: ScreenFlow = %Screens
@onready var _top_bar: Control = %TopBar
@onready var _hold_select: Timer = %HoldSelect
## Fires once the selection has settled: the game on screen and its neighbours get their art first.
@onready var _art_focus: Timer = %ArtFocus
@onready var _game_launch: GameLaunch = %GameLaunch
@onready var _games_hints: Control = %GamesHints
@onready var _properties: DiscProperties = %Properties
@onready var _order: ConsoleOrder = %ConsoleOrder
@onready var _arrange_hint: Control = %Arrange
@onready var _search: GameSearch = %Search
@onready var _title_marks: TitleMarks = %TitleMarks
@onready var _clear_hint: Control = %ClearFilter
@onready var _previous_letter_hint: ButtonHint = %PreviousLetter
@onready var _next_letter_hint: ButtonHint = %NextLetter


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_screens.android = android
	_screens.covering.connect(_show_front.bind(true))
	_game_launch.android = android
	_share_clock()
	_resting.moving = func() -> bool:
		return _downloading or _game_launch.is_busy() or _screen in _MOVING or _screens.is_playing()
	if Diagnostics.argument("welcome") == "skip":
		_screens.welcome_waits = false
	# The welcome shows first, without the bar.
	_top_bar.hide()
	_show_front(true)
	# Asked first, its art looked for as soon as it is sent: the plugin reads the library while the
	# scene sets itself up.
	android.art_changed.connect(_on_art_changed)
	var demo_games := Diagnostics.argument("demo-games").to_int()
	_demo = demo_games > 0 or not android.is_available()
	var asked_library := AndroidServices.Asked.new(
		android.use_demo_library.bind(demo_games, Diagnostics.argument("demo-shelf")) if _demo else android.library)
	var asked_settings := AndroidServices.Asked.new(android.settings)
	for platform in android.catalog.platforms:
		_platforms[platform.id] = platform
	_appearance = Appearance.read(_APPEARANCE)
	var read_ms := Time.get_ticks_msec()
	var shown := get_viewport_rect().size
	_consoles.position.y -= _world_height(_CONSOLES_LOWER_PX, _consoles)
	_screens.console_point = Vector2(shown.x / 2.0, _CONSOLE_Y + _CONSOLES_LOWER_PX)
	_row_y = _row.position.y
	_search_lift = _world_height(_SEARCH_LIFT_PX, _row)
	_search.android = android
	_search.row = _row
	_search.changed.connect(_on_search_changed)
	_search.opened.connect(_on_search_opened)
	_screens.appearance = _appearance
	_screens.console_of = _console_shown
	_row.pose = _appearance.pose
	# The same pose, but for its sway, which each console's launch animation has.
	_consoles.pose.tilt = _appearance.pose.tilt
	_consoles.pose.turn = _appearance.pose.turn
	_consoles.pose.sway_period_s = _appearance.pose.sway_period_s
	_row.label_images = _art
	for properties: PropertiesScreen in [_properties, _console_properties]:
		properties.android = android
		properties.light = %Light
		properties.rename_failed.connect(_show_message.bind(tr("This name could not be kept.")))
	_properties.row = _row
	_properties.art = _art
	_properties.behind.assign([_pill, _games_hints, _search])
	_properties.closed.connect(_go.bind(Screen.GAMES))
	_properties.choice_failed.connect(func() -> void:
		_show_message(tr("This image could not be kept.")))
	_properties.name_kept.connect(_show_title)
	_console_properties.consoles = _consoles
	# The add ball is the title's: it goes with it.
	_console_properties.behind.assign([_console_title])
	_console_properties.closed.connect(_on_console_properties_closed)
	_console_properties.name_kept.connect(_on_console_renamed)
	_console_properties.order_asked.connect(_open_order)
	_order.android = android
	_order.consoles = _consoles
	_order.name_of = _console_name_of
	_order.ordered.connect(_on_consoles_ordered)
	_order.order_failed.connect(_show_message.bind(tr("This order could not be kept.")))
	_order.closed.connect(_on_order_closed)
	# The ring's centre in the middle of the screen, at the row's depth (it stands further back).
	_consoles.ring_centre = _consoles.to_local(Vector3(_camera.global_position.x, _camera.global_position.y,
		_consoles.global_position.z))
	_row.turntable = Diagnostics.argument("turntable").to_float()
	_on_clock_timeout()
	_battery.show_battery(android.battery())
	android.battery_changed.connect(_battery.show_battery)
	var awaited_ms := Time.get_ticks_msec()
	var answer: AndroidServices.LibraryAnswer = await asked_library.taken()
	if not answer.ok:
		Diagnostics.trace("carousel", "library not read (%s): %s" % [answer.code, answer.detail])
	var settings: AndroidServices.SettingsAnswer = await asked_settings.taken()
	var answered_ms := Time.get_ticks_msec()
	if settings.has_button_style:
		Controls.style = settings.button_style
	get_viewport().msaa_3d = EdgeSmoothingScreen.MSAA[settings.edge_smoothing]
	for art in answer.art:
		_art.add(art)
	_show_library(answer.library)
	var library_shown_ms := Time.get_ticks_msec()
	_screens.library = answer.library
	await _screens.run(settings)
	var screens_ms := Time.get_ticks_msec()
	_come_in()
	_shown = true
	# Once the carousel is on screen: reading sounds must not delay it.
	get_tree().process_frame.connect(_game_launch.prepare.bind(_appearance.insertions.values()),
		CONNECT_ONE_SHOT)
	if Diagnostics.enabled:
		await get_tree().process_frame
		var shown_ms := Time.get_ticks_msec()
		Diagnostics.trace("carousel", "shown: %d games on %d shelves, %d ms after the scene started" % [
			answer.library.games.size(), _shelves.size(), shown_ms - started])
		Diagnostics.trace("carousel", ("start: scene from %d ms, appearance read in %d ms, set up by %d ms, "
			+ "answers by %d ms, library shown by %d ms, screens passed by %d ms") % [started, read_ms - started,
			awaited_ms - started, answered_ms - started, library_shown_ms - started, screens_ms - started])
		var frames := PackedStringArray()
		for frame in 3:
			var frame_started := Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append("%.1f" % ((Time.get_ticks_usec() - frame_started) / 1000.0))
		Diagnostics.trace("carousel", "first frames: %s ms" % ", ".join(frames))
		_trace_selected_label(shown_ms)
		var bench := Diagnostics.argument("bench")
		if bench:
			add_child(CarouselBench.new(bench, self, _row))
		var shots := Diagnostics.argument("shots")
		if shots:
			add_child(FrameShots.new(shots))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_let_go()
		_remember()
		# Up let go meanwhile never reaches the app.
		_add_ball.close(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Diagnostics.trace("touch", "back requested")
		_press_back.call_deferred()


func _process(delta: float) -> void:
	var gone := _screen in _GAME_SCREENS and not _game_launch.is_inserting()
	# While a launch is checked, and as the black fades after the game, they stay away.
	var behind := 0.0 if gone and _game_launch.is_busy() \
		else move_toward(_sequence.behind_amount, 0.0 if gone else 1.0, delta / _BEHIND_FADE_S)
	# Outside a launch, they leave as the games come, and come back as the games leave.
	if not _game_launch.is_inserting():
		behind = minf(behind, 1.0 - _row.neighbours)
	if behind != _sequence.behind_amount:
		_sequence.behind_amount = behind
	var now: int = clock.call()
	if _finger_on_selected and _touchable() and _finger.held(now):
		_long_press()
	var stick := Input.get_vector(&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down")
	_consoles.inspect(stick if _screen in _CONSOLE_SCREENS and _shown else Vector2.ZERO)
	if not _game_launch.is_busy():
		_row.inspect(stick if _screen in _GAME_SCREENS else Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	var moved := _direction.update(event)
	# Nothing acts from A until the carousel shows again after the game, nor while the animation
	# into or out of the console plays.
	# The properties take their own presses.
	if event.is_echo() or not _shown or _game_launch.is_busy() or _screen in _MOVING \
			or _screen in [Screen.PROPERTIES, Screen.CONSOLE_PROPERTIES, Screen.ORDER]:
		return
	if event.is_action_pressed(&"app_back") and Diagnostics.enabled:
		_hold_select.start()
	elif event.is_action_released(&"app_back"):
		_hold_select.stop()
	elif not _row.has_games():
		return
	elif _screen == Screen.GAMES and _search.is_open():
		_search.take(event, _direction, moved)
	elif _screen in [Screen.CONSOLES, Screen.GAMES] and event.is_action_pressed(&"open_settings"):
		_open_settings()
	elif _screen == Screen.CONSOLES and moved and _direction.held:
		_add_ball.close()
		_consoles.step(_direction.direction)
	elif _screen == Screen.CONSOLES and event.is_action(&"ui_up"):
		# Up as the stick and the D-pad hold it together: either one held keeps the button.
		if Input.is_action_pressed(&"ui_up"):
			_add_ball.open()
		else:
			_add_ball.close()
	elif _screen == Screen.CONSOLES and event.is_action_pressed(&"open_properties"):
		_open_console_properties()
	elif _screen == Screen.CONSOLES and event.is_action_pressed(&"ui_down") and _shelves.size() > 1:
		_open_order()
	elif _screen == Screen.CONSOLES and event.is_action_pressed(&"ui_accept"):
		if _add_ball.is_open:
			_add_console()
		else:
			_enter()
	elif _screen == Screen.GAMES and moved:
		if _direction.held:
			_row.hold(_direction.direction)
		else:
			_row.release(_direction.direction)
	elif _screen == Screen.GAMES and event.is_action_pressed(&"ui_accept"):
		_launch()
	elif _screen == Screen.GAMES and event.is_action_pressed(&"ui_down"):
		_row.freeze()
		_search.open()
	elif _screen == Screen.GAMES and event.is_action_pressed(&"previous_letter"):
		_search.leap(-1)
	elif _screen == Screen.GAMES and event.is_action_pressed(&"next_letter"):
		_search.leap(1)
	elif _screen == Screen.GAMES and event.is_action_pressed(&"screen_back") and _search.is_filtered():
		_search.clear()
	elif _screen == Screen.GAMES and event.is_action_pressed(&"screen_back"):
		_leave()
	elif _screen == Screen.GAMES and event.is_action_pressed(&"open_properties"):
		_open_properties()
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	accept_event()
	var now: int = clock.call()
	var gesture := _finger.read(event, now)
	if gesture == Finger.Gesture.DOWN:
		_finger_on_selected = _touchable() and _selected_point().distance_to(_finger.start) <= _ON_SELECTED_PX
		_swiped = false
	elif not _finger.is_down:
		# Lifted, or taken back by the system: what it turned comes back to the front.
		_let_go()
	if not _touchable():
		return
	match gesture:
		Finger.Gesture.TAP:
			_tap()
		Finger.Gesture.DRAG:
			_drag(_finger.moved)


## The screen shown, or the one the animation goes to.
func screen() -> Screen:
	return _screen


## The system's back, a gesture or a button, is B on every screen: pressed, then let go a frame
## later, as a real press is.
func _press_back() -> void:
	for pressed: bool in [true, false]:
		var back := InputEventAction.new()
		back.action = &"screen_back"
		back.pressed = pressed
		Input.parse_input_event(back)
		if pressed:
			await get_tree().process_frame


func _share_clock() -> void:
	_order.clock = clock
	_properties.clock = clock


## Whether a finger acts on the carousel now: not before it shows, nor during a launch, the
## animation into or out of a console, or the ring (which reads its own).
func _touchable() -> bool:
	return _shown and _row.has_games() and not _game_launch.is_busy() and _screen not in _MOVING \
		and _screen != Screen.ORDER and not _search.is_open()


## Where the console or the game in the middle rests on the screen (not where it is passing
## through as it slides there).
func _selected_point() -> Vector2:
	if _screen in _CONSOLE_SCREENS:
		return _screens.console_point
	return _camera.unproject_position(_row.to_global(Vector3.ZERO))


## [param pixels] of the screen's height, in world units at [param part]'s depth: there, the screen's
## height spans 2·d·tan(fov / 2).
func _world_height(pixels: float, part: Node3D) -> float:
	var depth := _camera.global_position.z - part.global_position.z
	return pixels / get_viewport_rect().size.y * 2.0 * depth * tan(deg_to_rad(_camera.fov / 2.0))


## Forgets the finger, as if lifted: a screen changing under it leaves nothing pending.
func _let_go() -> void:
	if _finger.is_down:
		_finger = Finger.new()
	_consoles.let_go()
	_row.let_go()
	_search.let_go()


func _tap() -> void:
	if _screen == Screen.CONSOLES and _finger_on_selected:
		Diagnostics.trace("touch", "tap on the console")
		_add_ball.close(false)
		_enter()
	elif _screen in [Screen.CONSOLES, Screen.GAMES] and not _finger_on_selected:
		_step_beside(1 if _finger.at.x > _selected_point().x else -1)


func _long_press() -> void:
	if _screen == Screen.CONSOLES:
		Diagnostics.trace("touch", "long press on the console")
		_open_console_properties()
	elif _screen == Screen.GAMES:
		Diagnostics.trace("touch", "long press on the game")
		_open_properties()


## A finger dragged [param relative] pixels: over the properties, or on the game in the middle, it
## turns what they stage or that game; anywhere else (on the consoles screen, even on the console,
## so that a swipe there is never mistaken for a turn), once swiped far enough, it moves one console
## or game, the way the finger goes, and no more until it is lifted.
func _drag(relative: Vector2) -> void:
	if _screen == Screen.CONSOLE_PROPERTIES:
		_consoles.touch_turn(relative)
		return
	if _screen == Screen.PROPERTIES or (_screen == Screen.GAMES and _finger_on_selected):
		_row.touch_turn(relative)
		return
	var swipe := _finger.start.x - _finger.at.x
	if _swiped or absf(swipe) < _SWIPE_PX:
		return
	_swiped = true
	var towards := 1 if swipe > 0.0 else -1
	Diagnostics.trace("touch", "swiped %d" % towards)
	_step_beside(towards)


## Moves one console or game [param towards] (-1 or 1), for a tap or a swipe beside the one in the
## middle.
func _step_beside(towards: int) -> void:
	if _screen == Screen.CONSOLES:
		_add_ball.close()
		_consoles.step(towards)
	else:
		_row.step(towards)


## Debug builds: how long after the carousel showed, at [param shown_ms], the selected game's label
## replaced its title, for `dev/bench.sh`.
func _trace_selected_label(shown_ms: int) -> void:
	if not _row.has_games() or not _art.has_art(_row.selected_game()):
		return
	var game := _row.selected_game()
	while not _art.has_texture(game):
		await _art.loaded
	Diagnostics.trace("art", "selected label shown %d ms after the carousel" % (Time.get_ticks_msec() - shown_ms))


## Shows how looking for art goes: a bar that moves to each count, grey with the reason while the
## run waits, full then fading once it is over; nothing for a run with nothing to look for.
func _show_art_progress(progress: AndroidServices.ArtProgress) -> void:
	if _screens.visible or _properties.is_open() or _console_properties.is_open() or _order.is_open():
		return
	var over := progress.done >= progress.total
	if progress.total == 0 or (over and not _art_progress.visible):
		_art_progress.hide()
		return
	if not over:
		_art_progress.show()
		_art_content.modulate.a = 1.0
	_art_bar.max_value = progress.total
	_art_bar.theme_type_variation = &"ArtBar" if progress.stall.is_empty() else &"ArtBarStalled"
	match progress.stall:
		&"offline":
			_art_text.text = tr("Disc images · offline, resuming when the network is back")
		&"refused":
			_art_text.text = tr("Disc images · server unavailable, trying again later")
		&"storage":
			_art_text.text = tr("Disc images · no room left on the device")
		_:
			_art_text.text = tr("Disc images · {done} / {total}").format({"done": progress.done, "total": progress.total})
	if _art_tween:
		_art_tween.kill()
	_art_tween = create_tween()
	_art_tween.tween_property(_art_bar, ^"value", float(progress.done), _ART_STEP_S)
	if over:
		_art_tween.tween_interval(_ART_FULL_S)
		_art_tween.tween_property(_art_content, ^"modulate:a", 0.0, _ART_FADE_S)
		_art_tween.tween_callback(_art_progress.hide)


## Shows [param library], on the console of [param shown] (a platform id) if it has one, else
## where the selection left the user.
func _show_library(library: AndroidServices.Library, shown := "") -> void:
	var started := Time.get_ticks_usec()
	_shelves = library.shelves
	_shelf = library.selected_shelf
	_console_names = library.console_names
	var asked := shown if shown else Diagnostics.argument("shelf")
	for i in _shelves.size():
		if _shelves[i].platform_id == asked:
			_shelf = i
	if _shelves.is_empty():
		return
	# Only the media of the library's games: the others are never loaded.
	_shelf_models.clear()
	var models: Array[PackedScene] = []
	var items: Array[ConsoleRow.Item] = []
	for shelf in _shelves:
		_shelf_models[shelf.platform_id] = _models_of(shelf)
		models.append_array(_shelf_models[shelf.platform_id].values())
		_positions[shelf.platform_id] = shelf.selected
		items.append(_console_item(shelf))
	_row.keep_models(models)
	_consoles.show_consoles(items, _shelf)
	# A console alone has no order to be put in.
	_arrange_hint.visible = _shelves.size() > 1
	_console_properties.orderable = _shelves.size() > 1
	_show_platform()
	if Diagnostics.enabled:
		var game := _row.selected_game()
		Diagnostics.trace("carousel", "restored %s on %s in %.1f ms" % [
			game.title, game.platform_id, (Time.get_ticks_usec() - started) / 1000.0])


## The console of [param shelf]'s platform as the consoles screen shows it ([method _console_shown]),
## resting as the launch animation of its selected game starts.
func _console_item(shelf: AndroidServices.Shelf) -> ConsoleRow.Item:
	var animation := _appearance.animation_of(_platforms[shelf.platform_id], shelf.games[shelf.selected].medium)
	return ConsoleRow.Item.new(_console_shown(shelf.platform_id), ConsoleRow.Rest.of(animation))


## The model of [param platform_id]'s console, or else its medium, labelled with the platform's name.
func _console_shown(platform_id: String) -> Node3D:
	if _appearance.console_of(platform_id):
		return _appearance.console(platform_id)
	var platform := _platforms[platform_id]
	var medium := ShelfRow.LabelledModel.new(_appearance.model_of("", platform.media))
	medium.draw_label(platform.name, _look(platform_id))
	return medium


## The platform selected on the consoles screen: its shelf behind, ready for the games screen, and
## the launch animation of each of its media made now rather than on A, its selected game's in use.
func _show_platform() -> void:
	var started := Time.get_ticks_usec()
	var shelf := _shelves[_shelf]
	var platform := _platforms[shelf.platform_id]
	var models: Dictionary[String, PackedScene] = _shelf_models[shelf.platform_id]
	for medium in models:
		_appearance.animation_of(platform, medium)
	_row.show_shelf(shelf.games, _positions[shelf.platform_id], models, _look(shelf.platform_id))
	_art_focus.start()
	_search.use_shelf(shelf.platform_id, shelf.games)
	_sequence.use(_appearance.animation_of(platform, _row.selected_game().medium))
	_console_name.text = _console_name_of(shelf.platform_id)
	var console := _appearance.console_of(shelf.platform_id)
	_console_model.text = console.model_name if console else ""
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "shelf %s prepared in %.1f ms, %d label viewports alive" % [shelf.platform_id,
			(Time.get_ticks_usec() - started) / 1000.0, ShelfRow.LabelledModel.alive])


## The model of each medium [param shelf]'s games come in, by medium.
func _models_of(shelf: AndroidServices.Shelf) -> Dictionary[String, PackedScene]:
	var media := _platforms[shelf.platform_id].media
	var models: Dictionary[String, PackedScene] = {}
	for game in shelf.games:
		if game.medium not in models:
			models[game.medium] = _appearance.model_of(game.medium, media)
	return models


## How the labels of [param platform_id]'s games look.
func _look(platform_id: String) -> ShelfRow.LabelLook:
	var look := ShelfRow.LabelLook.new()
	look.color = _appearance.colors.get(platform_id, _appearance.default_color)
	look.platform_name = _platforms[platform_id].name
	look.demo_art = _demo
	if platform_id in _appearance.bands:
		var band: Dictionary = _appearance.bands[platform_id]
		var color: String = band["color"]
		look.band = Color(color)
		look.band_text = band["text"]
	return look


func _enter() -> void:
	# A press begun before A must not act once it is let go.
	_hold_select.stop()
	_go(Screen.ENTERING)
	_consoles.face_front()
	_sequence.enter()
	await _sequence.finished
	_show_title()
	_go(Screen.GAMES)


func _leave() -> void:
	_hold_select.stop()
	_go(Screen.LEAVING)
	_row.freeze()
	_remember()
	_sequence.leave()
	await _sequence.finished
	_show_title()
	_go(Screen.CONSOLES)


## The pill names the selected game, the words typed in the ribbon underlined; it shows over the
## games only. L1 and R1's hints tell where they lead from it.
func _show_title() -> void:
	_title.text = _row.selected_game().title
	_title_marks.marks = _search.marks()
	for hint: ButtonHint in [_previous_letter_hint, _next_letter_hint]:
		hint.text = _search.leap_label(-1 if hint == _previous_letter_hint else 1)
		hint.visible = not hint.text.is_empty()
	_clear_hint.visible = _search.is_filtered()


func _go(screen_to: Screen) -> void:
	var games := screen_to == Screen.GAMES and _screen != Screen.PROPERTIES
	_screen = screen_to
	_let_go()
	if screen_to in [Screen.ENTERING, Screen.CONSOLES, Screen.CONSOLE_PROPERTIES, Screen.ORDER]:
		_fade_title(1.0 if screen_to == Screen.CONSOLES else 0.0)
	# The games screen's hints come and go with it; its properties hide and show them themselves.
	if games or screen_to in [Screen.LEAVING, Screen.CONSOLES]:
		_games_hints.create_tween().tween_property(_games_hints, ^"modulate:a",
			1.0 if screen_to == Screen.GAMES else 0.0, _TITLE_FADE_S)
	Diagnostics.trace("carousel", "screen %s" % Screen.keys()[screen_to])
	screen_changed.emit(screen_to)


func _launch() -> void:
	var game := _row.selected_game()
	# A press begun before A must not act once it is let go.
	_hold_select.stop()
	_remember()
	var platform := _platforms[game.platform_id]
	# The placeholder brings the game's own medium from its own length away.
	_sequence.use(_appearance.animation_of(platform, game.medium), &"games")
	_game_launch.launch(game, game.last_disc, _appearance.insertions[platform.media])


## Stores the selected game and its platform, for the next start.
func _remember() -> void:
	if _shelves.is_empty() or not _row.has_games():
		return
	_positions[_shelves[_shelf].platform_id] = _search.shown_position()
	var result := await android.select_game(_row.selected_game())
	if not result.ok:
		Diagnostics.trace("carousel", "selection not saved (%s): %s" % [result.code, result.detail])


func _show_message(text: String) -> void:
	_message.text = text
	_message.show()
	# It shows where the art bar is.
	_art_content.hide()
	_message_timer.start(_MESSAGE_S)


func _on_art_changed(change: AndroidServices.ArtChange) -> void:
	var progress := change.progress
	_downloading = progress.done < progress.total and progress.stall.is_empty()
	if change.has_found:
		_art.add(change.found)
		_row.refresh_label(change.found.game_id)
	_show_art_progress(progress)


func _on_row_selection_changed(_game: AndroidServices.Game) -> void:
	_art_focus.start()
	if _screen == Screen.GAMES:
		_show_title()


## What the ribbon shows changed: over the games, the pill and the hints follow.
func _on_search_changed() -> void:
	if _screen in _GAME_SCREENS:
		_show_title()


## The ribbon opened or closed: the games rise above it, or come back down; the games screen's
## hints give way to the ribbon's.
func _on_search_opened(open: bool) -> void:
	_games_hints.visible = not open
	if _lift:
		_lift.kill()
	_lift = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift.tween_property(_row, ^"position:y", _row_y + (_search_lift if open else 0.0), GameSearch.RISE_S)


func _on_consoles_selection_changed(index: int) -> void:
	_shelf = index
	_show_platform()
	Diagnostics.trace("carousel", "platform %s" % _shelves[_shelf].platform_id)
	_remember()


func _on_clock_timeout() -> void:
	_clock.text = Time.get_time_string_from_system().left(5)


func _on_game_launch_failed(code: StringName) -> void:
	Diagnostics.trace("carousel", "launch failed: %s" % code)
	var platform := _platforms[_shelves[_shelf].platform_id].name
	match code:
		&"not_installed", &"no_player":
			_show_message(tr("No {platform} emulator is installed.").format({"platform": platform}))
		&"game_missing":
			_show_message(tr("This game's file cannot be found: is its SD card or folder still there?"))
		&"rehearsed":
			pass
		_:
			_show_message(tr("The game could not be launched."))


## Shows the screens in front of the carousel, which then shows nothing of its own but its
## background, or the carousel itself.
func _show_front(front: bool) -> void:
	for part: Node3D in [_row, _consoles]:
		part.visible = not front
	_console_title.visible = not front
	_search.visible = not front
	_pill.visible = not front and not _shelves.is_empty()
	_games_hints.visible = not front
	_sequence.blur_dots()
	if front:
		_sequence.behind_amount = 0.0
		_art_progress.hide()


## The consoles come in, no longer hidden by the screens in front.
func _come_in() -> void:
	_resting.wake()
	_show_front(false)
	_arrive()


## The consoles fade in and grow to their size, then their name comes in (and the pill, over the games).
func _arrive() -> void:
	_consoles.arrival = _ARRIVAL_POINT
	_console_title.modulate.a = 0.0
	_pill.modulate.a = 0.0
	_arrival = create_tween().set_parallel()
	_arrival.tween_property(_consoles, ^"arrival", 1.0, _ARRIVAL_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# The pill names a game: it shows only over the games; the console's name only over the consoles.
	if _screen == Screen.GAMES:
		_arrival.tween_property(_pill, ^"modulate:a", 1.0, _TITLE_FADE_S).set_delay(_PILL_ARRIVES_S)
	elif _screen == Screen.CONSOLES:
		_fade_title(1.0, _TITLE_ARRIVES_S)


## The console's name fades to [param alpha] after [param delay_s], instead of any fade under way:
## going into a console while it still comes in must not show it there.
func _fade_title(alpha: float, delay_s := 0.0) -> void:
	if _title_fade:
		_title_fade.kill()
	_title_fade = create_tween()
	_title_fade.tween_property(_console_title, ^"modulate:a", alpha, _TITLE_FADE_S).set_delay(delay_s)


func _on_screens_library_changed(library: AndroidServices.Library) -> void:
	_demo = false
	# Drawn as a point under the screens in front, the consoles have their shaders ready when
	# they come out of it. A point before they are placed: placed full size, they would show so
	# for a frame.
	_consoles.arrival = _ARRIVAL_POINT
	_show_library(library)
	_consoles.show()


## The settings over the consoles screen or the games screen, until closed; the consoles come in
## again if a console had to be added meanwhile, the last one removed.
func _open_settings() -> void:
	_cover()
	if await _screens.open_settings():
		_come_in()
	else:
		_show_front(false)
	_shown = true


## The selected console's properties, until they close.
func _open_console_properties() -> void:
	_leave_consoles(Screen.CONSOLE_PROPERTIES)
	var platform_id := _shelves[_shelf].platform_id
	_console_properties.open(platform_id, _console_name_of(platform_id), _own_console_name(platform_id))


## Still held up, the button is still there.
func _reopen_add_ball() -> void:
	if Input.is_action_pressed(&"ui_up"):
		_add_ball.open()


func _on_console_properties_closed() -> void:
	# Closed for the ring, the carousel is already there.
	if _screen == Screen.CONSOLE_PROPERTIES:
		_go(Screen.CONSOLES)
		_reopen_add_ball()


## The ring putting the consoles in order, on the selected one, until it closes.
func _open_order() -> void:
	_leave_consoles(Screen.ORDER)
	_order.open(_platform_ids(), _shelf)


## For [param screen], over the consoles screen: no press held over, no ball, no art bar.
func _leave_consoles(screen_to: Screen) -> void:
	_hold_select.stop()
	_add_ball.close(false)
	_art_progress.hide()
	_go(screen_to)


## The platform ids of the shelves, in their order.
func _platform_ids() -> Array[String]:
	var platform_ids: Array[String] = []
	for shelf in _shelves:
		platform_ids.append(shelf.platform_id)
	return platform_ids


## The consoles are in [param order] (platform ids) from now on: their shelves too, the one shown
## still shown.
func _on_consoles_ordered(order: Array[String]) -> void:
	var row := _platform_ids()
	var indices: Array[int] = []
	var shelves: Array[AndroidServices.Shelf] = []
	for platform_id in order:
		indices.append(row.find(platform_id))
		shelves.append(_shelves[indices.back()])
	_shelves = shelves
	_shelf = indices.find(_shelf)
	_consoles.reorder(indices)


## The ring closed: the consoles screen whole again, its title too when the ring came from a
## console's properties, which hid it.
func _on_order_closed() -> void:
	_console_title.show()
	_go(Screen.CONSOLES)
	_reopen_add_ball()


## [param platform_id]'s console shows as [param shown] from now on, a name given when [param named].
func _on_console_renamed(platform_id: String, named: bool, shown: String) -> void:
	if named:
		_console_names[platform_id] = shown
	else:
		_console_names.erase(platform_id)
	_console_name.text = shown


## The name a console shows: the one the user gave it, else its own.
func _console_name_of(platform_id: String) -> String:
	return _console_names.get(platform_id, _own_console_name(platform_id))


## A console's own name, as the consoles screen shows it.
func _own_console_name(platform_id: String) -> String:
	var console := _appearance.console_of(platform_id)
	return console.name if console else _platforms[platform_id].name


## The selected game's properties, until they close.
func _open_properties() -> void:
	_hold_select.stop()
	_row.freeze()
	_art_progress.hide()
	_go(Screen.PROPERTIES)
	_properties.open()


## The form adding one more console, over the consoles; the consoles come in again on the one
## added.
func _add_console() -> void:
	_cover()
	await _screens.add_console()
	_show_front(false)
	_reopen_add_ball()
	_shown = true


## Before screens open over the consoles: the carousel takes no press, its message goes, and the
## art's progress is not followed under them.
func _cover() -> void:
	_shown = false
	_hold_select.stop()
	_message_timer.stop()
	_on_message_timer_timeout()
	# A direction let go under the screens never reaches the row, nor the ribbon.
	_row.freeze()
	_search.let_go()
	_art_progress.hide()
	_add_ball.close(false)


func _on_screens_console_added(library: AndroidServices.Library, platform_id: String) -> void:
	_show_library(library, platform_id)
	_remember()
	_arrive()


func _on_screens_library_edited(library: AndroidServices.Library) -> void:
	_art.keep_only(library.games)
	_show_library(library)
	# Shown again from the start, the carousel is back on the consoles screen.
	if _screen == Screen.GAMES:
		_go(Screen.CONSOLES)


func _on_screens_welcome_closed() -> void:
	_top_bar.show()


func _on_message_timer_timeout() -> void:
	_message.hide()
	_art_content.show()


func _on_art_focus_timeout() -> void:
	if _row.has_games():
		android.art_focus(_row.games_around(CarouselLayout.REACH))


func _on_hold_select_timeout() -> void:
	# Awaited: its answer must not come back to a freed scene.
	await _remember()
	get_tree().change_scene_to_file(_DEVICE_CHECK)
