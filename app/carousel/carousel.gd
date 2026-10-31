# SPDX-License-Identifier: GPL-3.0-or-later
class_name Carousel
extends Control
## The main screens. The consoles screen shows one console per platform with games ([ConsoleRow]);
## A goes into the selected one, as its launch animation has it ([ConsoleSequence]), to the games
## screen: the platform's shelf of games, the selected game in the middle. There, left and right
## move along the shelf (held, faster and faster), A launches the selected game into its console
## ([GameLaunch]), B goes back out to the consoles, X opens the selected game's properties
## ([DiscProperties]); down opens the ribbon that searches the shelf ([GameSearch]). The right stick
## turns the selected console on the consoles screen, the selected game on the games screen and in
## its properties, nothing in between. Where the user was is remembered across restarts. The games'
## disc scans arrive as the plugin finds them ([GameArt]), a bar at the bottom right, beside the
## hints, telling how it goes.
##
## By touch, as [CarouselTouch] reads it; what was turned comes back to the front once let go. The system's back
## gesture is B.
##
## Left alone, the app rests ([Resting]): drawn 30 times a second, then still until something
## changes; not while labels download. On the games screen the consoles behind are not drawn: they
## fade out once there, back in for a launch or to go out.
##
## In front of it, [ScreenFlow] shows the first launch's welcome and screens, and the screens adding a
## console while none has games; Y on the consoles screen or the games screen opens the settings over
## it. On the consoles screen, holding up turns the "+" ball above the console into a button
## ([AddBall]), until up is let go: A then adds one more console, the consoles coming in again on it;
## down (or "Change place" in a console's properties) opens the ring putting the consoles in order
## ([ConsoleOrder]). The carousel waits for the screens in front to close.
##
## In debug builds, holding Select opens the device check. See the diagnostics section of
## docs/README.md for the debug arguments. Without the Android plugin (the editor, a desktop
## run), the demo library is shown.

## The screen changed; in between, the animation into or out of the console plays.
signal screen_changed(screen: Screen)

enum Screen { CONSOLES, ENTERING, GAMES, LEAVING, PROPERTIES, CONSOLE_PROPERTIES, ORDER }
## The add-console form over the consoles: asked by the "+" (the screens not shown yet), coming in over the consoles
## still in view, covering them, or given up (leaving, the consoles back).
enum Form { NONE, ASKED, COMING, COVERING, GIVEN_UP }

const _APPEARANCE := "res://data/carousel/appearance.json"
const _DEVICE_CHECK := "res://dev/device_check/device_check.tscn"
const _MESSAGE_S := 4.0
const _MOVING: Array[Screen] = [Screen.ENTERING, Screen.LEAVING]
const _CONSOLE_SCREENS: Array[Screen] = [Screen.CONSOLES, Screen.CONSOLE_PROPERTIES]
## The consoles' room light, the scene's own energy; a constant, as the scene's resource is shared and the
## games change it while they are shown.
const _CONSOLE_ROOM := 0.55
const _GAME_SCREENS: Array[Screen] = [Screen.GAMES, Screen.PROPERTIES]
const _ARRIVAL_S := 0.45
const _TITLE_ARRIVES_S := 0.3
const _PILL_ARRIVES_S := 0.4
## The size the consoles come out of, as a part of theirs.
const _ARRIVAL_POINT := 0.01
## How much lower the consoles stand than the camera centres them, in pixels of the screen: room
## for the "+" ball above their name.
const _CONSOLES_LOWER_PX := 58.0
## How far down the screen the camera centres the selected console, in pixels.
const _CONSOLE_Y := 420.0
const _RING_LEAVE_S := 0.15
## The ring's closing time the next three timings are set for; a shorter close (a rewind) plays them faster.
const _RING_CLOSE_S := 0.62
const _RING_RISE_AFTER_S := 0.31
const _RING_BACK_AFTER_S := 0.341
const _RING_BACK_S := 0.279
const _FORM_BACK_RISE_AFTER_S := 0.07
const _SEARCH_LIFT_PX := 54.0
const _BEHIND_FADE_S := 0.3

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read: the engine's clock, a fake one in tests.
var clock := Callable(Time, &"get_ticks_msec"):
	set(read):
		clock = read
		if is_node_ready():
			_share_clock()

var _focus: SatinStyle = preload("res://studio/focus.tres")
var _shelves: Array[AndroidServices.Shelf] = []
var _shelf := 0
var _screen := Screen.CONSOLES
var _console_arrival: ConsoleArrival
var _positions: Dictionary[String, int] = {}
var _platforms: Dictionary[String, AndroidServices.Platform] = {}
var _shelf_models: Dictionary[String, Dictionary] = {}
var _appearance: Appearance
var _console_variants: Dictionary[String, String] = {}
var _demo := false
var _shown := false
var _direction := HeldDirection.new()
var _downloading := false
var _arrival: Tween
var _title_fade: Tween
var _settle_waiting := false
var _form_entry: FormEntry
var _form := Form.NONE
## The row's height, the ribbon closed, and how much it rises while it is open, in world units.
var _row_y := 0.0
var _search_lift := 0.0
var _lift: Tween
var _title_position := 0
var _games_hint_fade: Tween
## The room's light last given: the environment keeps it in single precision, never equal to the double it was given.
var _room_energy := NAN
## Whether the row stepped to a console whose shelf is not shown behind it yet (see [method _show_waiting_shelf]).
var _shelf_waiting := false

@onready var _room: WorldEnvironment = $Environment
@onready var _row: ShelfRow = %Row
@onready var _consoles: ConsoleRow = %Consoles
@onready var _sequence: ConsoleSequence = %Sequence
@onready var _clock: StudioPill = %Clock
@onready var _console_title: Control = %ConsoleTitle
@onready var _rail: ConsoleRail = %ConsoleRail
@onready var _add_ball: AddBall = %AddBall
@onready var _camera: Camera3D = $Camera
@onready var _battery: BatteryChip = %Battery
@onready var _resting: Resting = %Resting
@onready var _art_progress: ArtBar = %ArtProgress
@onready var _art: GameArt = %Art
@onready var _pill: GameTitlePill = %Pill
@onready var _games_logo: LogoView = %GamesLogo
@onready var _console_properties: ConsoleProperties = %ConsoleProperties
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _message_timer: Timer = %MessageTimer
@onready var _screens: ScreenFlow = %Screens
@onready var _top_bar: Control = %TopBar
@onready var _hold_select: Timer = %HoldSelect
@onready var _art_focus: Timer = %ArtFocus
@onready var _game_launch: GameLaunch = %GameLaunch
@onready var _games_hints: Control = %GamesHints
@onready var _properties: DiscProperties = %Properties
@onready var _order: ConsoleOrder = %ConsoleOrder
@onready var _arrange_hint: Control = %Arrange
@onready var _search: GameSearch = %Search
@onready var _title_marks: TitleMarks = %TitleMarks
@onready var _clear_hint: Control = %ClearFilter
@onready var _touch := CarouselTouch.new(_consoles, _row, _rail, _add_ball)


func _ready() -> void:
	add_child(ControlTokens.new())
	var started := Time.get_ticks_msec()
	_screens.android = android
	_screens.covering.connect(_on_screens_covering)
	_screens.form_leaving.connect(_on_screens_form_leaving)
	_game_launch.android = android
	_share_clock()
	_clock.position = StudioTokens.CLOCK.position
	_clock.size = StudioTokens.CLOCK.size
	_resting.smooth_motion = func() -> bool:
		return _screen == Screen.GAMES and _row.is_visible_in_tree() and _row.games_float and _row.pace > 0.0
	_resting.moving = func() -> bool:
		return _downloading or _game_launch.is_busy() or _screen in _MOVING or _screens.is_playing() \
			or _order.is_open() or (_console_arrival and _console_arrival.is_playing())
	if Diagnostics.argument("welcome") == "skip":
		_screens.welcome_waits = false
	# The bar waits for the first launch's welcome to be passed.
	_top_bar.hide()
	_show_front(true)
	# Asked first, its art looked for as soon as it is sent: the plugin reads the library while the
	# scene sets itself up.
	android.art_changed.connect(_on_art_changed)
	android.art_progress.connect(_on_art_progress)
	var demo_games := Diagnostics.argument("demo-games").to_int()
	_demo = demo_games > 0 or (not android.is_available() and not android.has_snapshot())
	var asked_library := AndroidServices.Asked.new(
		android.use_demo_library.bind(demo_games, Diagnostics.argument("demo-shelf")) if _demo else android.library)
	var asked_settings := AndroidServices.Asked.new(android.settings)
	for platform in android.catalog.platforms:
		_platforms[platform.id] = platform
	_appearance = Appearance.read(_APPEARANCE)
	var read_ms := Time.get_ticks_msec()
	var shown := get_viewport_rect().size
	_consoles.position.y -= _world_height(_CONSOLES_LOWER_PX, _consoles)
	_screens.console_point = Vector2(shown.x / 2.0, _CONSOLE_Y + _CONSOLES_LOWER_PX - ConsoleRow.RAISE_PX)
	_console_title.visibility_changed.connect(_show_rail)
	_row_y = _row.position.y
	_search_lift = _world_height(_SEARCH_LIFT_PX, _row)
	_search.android = android
	_search.row = _row
	_search.changed.connect(_on_search_changed)
	_search.opened.connect(_on_search_opened)
	_screens.place = _place_console
	_touch.entered.connect(_enter)
	_touch.long_pressed.connect(_long_press)
	_touch.lifted.connect(_let_go)
	_row.camera = _camera
	resized.connect(func() -> void:
		if _shown and _row.has_games():
			_show_title())
	# The same pose, but for its sway, which each console's launch animation has.
	_consoles.pose.tilt = _appearance.pose.tilt
	_consoles.pose.turn = _appearance.pose.turn
	_consoles.pose.sway_period_s = _appearance.pose.sway_period_s
	_row.label_images = _art
	for properties: PropertiesScreen in [_properties, _console_properties]:
		properties.android = android
		properties.light = %Light
	_properties.rename_failed.connect(func() -> void:
		_show_message(tr("This name could not be kept.")))
	_properties.row = _row
	_properties.art = _art
	_properties.behind.assign([_pill, _games_hints, _search, _games_logo])
	_properties.closed.connect(_go.bind(Screen.GAMES))
	_properties.choice_failed.connect(func() -> void:
		_show_message(tr("This image could not be kept.")))
	_properties.name_kept.connect(_show_title)
	_console_properties.consoles = _consoles
	# The add ball is the title's: it goes with it.
	_console_properties.behind.assign([_console_title, _rail])
	_console_properties.closed.connect(_on_console_properties_closed)
	_console_properties.order_asked.connect(_open_order)
	_console_properties.variant_shown.connect(_show_variant)
	_console_properties.variant_kept.connect(_keep_variant)
	_order.android = android
	_order.consoles = _consoles
	_order.ordered.connect(_on_consoles_ordered)
	_order.order_failed.connect(func() -> void:
		_show_message(tr("This order could not be kept.")))
	_order.closing.connect(_on_order_closing)
	_order.closed.connect(_on_order_closed)
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
	_row.games_float = settings.games_float
	if settings.has_button_style:
		Controls.style = settings.button_style
	get_viewport().msaa_3d = EdgeSmoothingScreen.MSAA[settings.edge_smoothing]
	for art in answer.art:
		_art.add(art)
	for game_id in answer.absent:
		_art.mark_absent(game_id)
	_show_library(answer.library)
	var library_shown_ms := Time.get_ticks_msec()
	_screens.library = answer.library
	await _screens.run(settings)
	var screens_ms := Time.get_ticks_msec()
	if _screens.arrived:
		_show_front(false)
	else:
		_come_in()
	_shown = true
	# Once the carousel is on screen: reading sounds and the other shelves' media must not delay it.
	get_tree().process_frame.connect(_game_launch.prepare.bind(_appearance.insertions.values()),
		CONNECT_ONE_SHOT)
	get_tree().process_frame.connect(func() -> void:
		for shelf in _shelves:
			_appearance.load_models_of(_platforms[shelf.platform_id], shelf.games), CONNECT_ONE_SHOT)
	if Diagnostics.enabled:
		add_child(StartTrace.new(self, _row, _art, answer.library.games.size(), _shelves.size(),
			[started, read_ms, awaited_ms, answered_ms, library_shown_ms, screens_ms]))


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
	# Wherever a medium is drawn in this world (the games, their properties, an insertion), it is lit
	# by its own room; the consoles by the scene's.
	var room := _row.room_energy if _screen in _GAME_SCREENS and _row.visible else _CONSOLE_ROOM
	if room != _room_energy:
		_room_energy = room
		_room.environment.ambient_light_energy = room
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
	_touch.hold(now, _touchable)
	var stick := Input.get_vector(&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down")
	_consoles.inspect(stick if _screen in _CONSOLE_SCREENS and _shown else Vector2.ZERO)
	if not _game_launch.is_busy():
		_row.inspect(stick if _screen in _GAME_SCREENS else Vector2.ZERO)
	if _shelf_waiting and _screen == Screen.CONSOLES and not _consoles.is_settling():
		_show_waiting_shelf()


func _unhandled_input(event: InputEvent) -> void:
	var moved := _direction.update(event)
	if _settle_waiting:
		if event.is_pressed() and not event.is_echo():
			Diagnostics.trace("carousel", "press during settle ignored: %s" % event.as_text())
		return
	if _needs_settle(event):
		_after_settle(event, moved)
		return
	_handle_input(event, moved)


func _handle_input(event: InputEvent, moved: bool) -> void:
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
		Sounds.play(SoundEffects.Cue.OPEN)
		_search.open()
	elif _screen == Screen.GAMES and event.is_action_pressed(&"screen_back") and _search.is_filtered():
		Sounds.play(SoundEffects.Cue.BACK)
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
	_touch.read(event, now, _screen, _touchable(), _selected_point())


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
	_touch.forget()
	_consoles.let_go()
	_row.let_go()
	_search.let_go()


func _long_press() -> void:
	if _screen == Screen.CONSOLES:
		Diagnostics.trace("touch", "long press on the console")
		_open_console_properties()
	elif _screen == Screen.GAMES:
		Diagnostics.trace("touch", "long press on the game")
		_open_properties()


## Shows [param library], on the console of [param shown] (a platform id) if it has one, else
## where the selection left the user.
func _show_library(library: AndroidServices.Library, shown := "") -> void:
	var started := Time.get_ticks_usec()
	_shelf_waiting = false
	_console_variants = library.console_variants
	_appearance.use_variants(_console_variants)
	_shelves = library.shelves
	_shelf = library.selected_shelf
	var asked := shown if shown else Diagnostics.argument("shelf")
	for i in _shelves.size():
		if _shelves[i].platform_id == asked:
			_shelf = i
	if _shelves.is_empty():
		_rail.show_consoles([] as Array[String], 0)
		_show_rail()
		return
	# Only the media of the library's games: the others are never loaded. At start, only the shown shelf's: the
	# others' load once the carousel shows.
	_shelf_models.clear()
	var models: Array[PackedScene] = []
	var items: Array[ConsoleRow.Item] = []
	var folders: Array[String] = []
	for shelf in _shelves:
		if _shown or shelf == _shelves[_shelf]:
			models.append_array(_models_of(shelf).values())
		_positions[shelf.platform_id] = shelf.selected
		items.append(_console_item(shelf))
		folders.append(items.back().folder)
	_row.keep_models(models)
	_consoles.show_consoles(items, _shelf)
	_rail.show_consoles(folders, _shelf)
	_show_rail()
	# A console alone has no order to be put in.
	_arrange_hint.visible = _shelves.size() > 1
	_console_properties.orderable = _shelves.size() > 1
	_show_platform()
	if Diagnostics.enabled:
		var game := _row.selected_game()
		Diagnostics.trace("carousel", "restored %s on %s in %.1f ms" % [
			game.title, game.platform_id, (Time.get_ticks_usec() - started) / 1000.0])


## The models of [param shelf]'s media, by medium (see [method Appearance.models_of]), loaded the first time.
func _models_of(shelf: AndroidServices.Shelf) -> Dictionary[String, PackedScene]:
	if shelf.platform_id not in _shelf_models:
		_shelf_models[shelf.platform_id] = _appearance.models_of(_platforms[shelf.platform_id], shelf.games)
	return _shelf_models[shelf.platform_id]


## The console of [param shelf]'s platform, resting as the launch animation of its selected game starts.
func _console_item(shelf: AndroidServices.Shelf) -> ConsoleRow.Item:
	return _appearance.console_item(_platforms[shelf.platform_id], shelf.games[shelf.selected].medium, _demo)


## The platform selected on the consoles screen: its console standing as the launch animation of its
## selected game starts, and its shelf behind.
func _show_platform() -> void:
	_use_platform()
	_show_shelf()


## The selected console stands as the launch animation of its shelf's selected game has it, and that
## game's art is looked for first once the row stops.
func _use_platform() -> void:
	var shelf := _shelves[_shelf]
	var selected := shelf.games[posmod(_positions[shelf.platform_id], shelf.games.size())]
	_art_focus.start()
	_sequence.use(_appearance.animation_of(_platforms[shelf.platform_id], selected.medium))


## The selected platform's shelf behind the consoles screen, ready for the games screen, and the launch
## animation of each of its media made now rather than on A.
func _show_shelf() -> void:
	var started := Time.get_ticks_usec()
	var shelf := _shelves[_shelf]
	var platform := _platforms[shelf.platform_id]
	var models := _models_of(shelf)
	for medium in models:
		_appearance.animation_of(platform, medium)
	var console := _appearance.console_of(shelf.platform_id)
	_games_logo.show_logo(LogoView.Slot.GAMES_TOP, ConsoleManifest.folder_of(console))
	_title_position = _positions[shelf.platform_id]
	_row.show_shelf(shelf.games, _positions[shelf.platform_id], models, _appearance.look(platform, _demo))
	_search.use_shelf(shelf.platform_id, shelf.games)
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "shelf %s prepared in %.1f ms, %d label viewports alive" % [shelf.platform_id,
			(Time.get_ticks_usec() - started) / 1000.0, ShelfRow.LabelledModel.alive])


## The shelf of the console stepped to, once the row stands still on it or as soon as something needs it,
## rather than at every step: the consoles passed on the way never make theirs.
func _show_waiting_shelf() -> void:
	if _shelf_waiting:
		_remember()


func _enter() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	# A press begun before A must not act once it is let go.
	_hold_select.stop()
	_go(Screen.ENTERING)
	_consoles.face_front()
	_play_logo(false)
	_sequence.enter()
	await _sequence.finished
	_show_title()
	_go(Screen.GAMES)


func _leave() -> void:
	Sounds.play(SoundEffects.Cue.BACK)
	_hold_select.stop()
	_go(Screen.LEAVING)
	_row.freeze()
	_remember()
	# The rail comes back as the launch ends, the frame and the rest as it does.
	_rail.rise(StudioTokens.TR_GAMES_RAIL_BACK_S, maxf(0.0, _sequence.trip_s() - StudioTokens.TR_GAMES_RAIL_BACK_S))
	_play_logo(true)
	_sequence.leave()
	await _sequence.finished
	_show_title()
	_go(Screen.CONSOLES)


func _show_title() -> void:
	_title.text = _row.selected_game().title
	_title_marks.marks = _search.marks()
	_pill.show_title(_title.text, _title_marks.marks, signi(_row.selected_position() - _title_position))
	_title_position = _row.selected_position()
	var top := _row.title_top()
	_pill.move_top(top)
	Diagnostics.trace("carousel", "pill top=%.2f medium=%s" % [top, _row.selected_game().medium])
	_clear_hint.visible = _search.is_filtered()


func _go(screen_to: Screen) -> void:
	_show_waiting_shelf()
	_games_logo.visible = screen_to in _GAME_SCREENS
	var games := screen_to == Screen.GAMES and _screen != Screen.PROPERTIES
	var from := _screen
	_screen = screen_to
	_show_rail()
	if screen_to in [Screen.ENTERING, Screen.CONSOLE_PROPERTIES, Screen.ORDER]:
		_rail.sink(StudioTokens.TR_RING_SINK_S if screen_to == Screen.ORDER else StudioTokens.TR_GAMES_RAIL_S)
	elif screen_to == Screen.CONSOLES and from != Screen.LEAVING:
		_rail.rise(StudioTokens.TR_GAMES_RAIL_BACK_S)
	_let_go()
	if screen_to in [Screen.ENTERING, Screen.CONSOLES, Screen.CONSOLE_PROPERTIES, Screen.ORDER]:
		_fade_title(1.0 if screen_to == Screen.CONSOLES else 0.0, 0.0,
			_RING_LEAVE_S if screen_to == Screen.ORDER else StudioTokens.TR_GAMES_FADE_S)
	# The games screen's hints come and go with it; its properties hide and show them themselves.
	if games or screen_to in [Screen.LEAVING, Screen.CONSOLES]:
		_games_hint_fade = Motion.restart(self, _games_hint_fade)
		_games_hint_fade.tween_property(_games_hints, ^"modulate:a",
			1.0 if screen_to == Screen.GAMES else 0.0, StudioTokens.TR_GAMES_HINTS_S)
	Diagnostics.trace("carousel", "screen %s" % Screen.keys()[screen_to])
	screen_changed.emit(screen_to)


func _launch() -> void:
	Sounds.play(SoundEffects.Cue.LAUNCH)
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
	# The selection saved is the game of the shelf stepped to.
	if _shelf_waiting:
		_shelf_waiting = false
		_show_shelf()
	if _shelves.is_empty() or not _row.has_games():
		return
	_positions[_shelves[_shelf].platform_id] = _search.shown_position()
	var result := await android.select_game(_row.selected_game())
	if not result.ok:
		Diagnostics.trace("carousel", "selection not saved (%s): %s" % [result.code, result.detail])


func _show_message(text: String) -> void:
	Sounds.play(SoundEffects.Cue.ERROR)
	_message.text = text
	_message.show()
	_art_progress.give_way(true)
	_message_timer.start(_MESSAGE_S)


func _on_art_changed(change: AndroidServices.ArtChange) -> void:
	var progress := change.progress
	_downloading = progress.done < progress.total and progress.stall.is_empty()
	if change.has_found:
		_art.add(change.found)
		_row.refresh_label(change.found.game_id)
	for game_id in change.absent:
		_art.mark_absent(game_id)
		_row.refresh_label(game_id)
	if not (_screens.visible or _properties.is_open() or _console_properties.is_open() or _order.is_open()):
		_art_progress.follow(progress)


func _on_art_progress(download: AndroidServices.LabelDownload) -> void:
	if download.running:
		_row.downloading(download.game_id, download.fraction)
	else:
		_row.downloaded(download.game_id)


func _on_row_selection_changed(_game: AndroidServices.Game) -> void:
	_art_focus.start()
	if _screen == Screen.GAMES:
		_show_title()


func _on_search_changed() -> void:
	# The row's positions are those of another list now: the pill does not slide by their difference.
	_title_position = _row.selected_position()
	if _screen in _GAME_SCREENS:
		_show_title()


func _on_search_opened(open: bool) -> void:
	_games_hints.visible = not open
	_lift = Motion.restart(self, _lift).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift.tween_property(_row, ^"position:y", _row_y + (_search_lift if open else 0.0), GameSearch.RISE_S)


func _on_consoles_selection_changed(index: int) -> void:
	_rail.go_to(_consoles.target())
	_shelf = index
	_use_platform()
	_shelf_waiting = true
	Diagnostics.trace("carousel", "platform %s" % _shelves[_shelf].platform_id)


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
		&"rehearsed", &"too_late":
			pass
		_:
			_show_message(tr("The game could not be launched."))


func _selected_gel() -> Color:
	return StudioTokens.NEUTRAL if _shelves.is_empty() else _appearance.gel(_shelves[_shelf].platform_id)


func _show_front(front: bool) -> void:
	for part: Node3D in [_row, _consoles]:
		part.visible = not front
	_console_title.visible = not front
	_search.visible = not front
	_games_logo.visible = not front and _screen in _GAME_SCREENS
	_pill.visible = not front and not _shelves.is_empty()
	_games_hints.visible = not front
	_show_rail()
	if front:
		_sequence.behind_amount = 0.0
		_art_progress.hide()
		_focus.gel = _selected_gel()


func _come_in() -> void:
	_resting.wake()
	_show_front(false)
	_arrive()


func _arrive(growing := true) -> void:
	_consoles.arrival = _ARRIVAL_POINT if growing else 1.0
	_console_title.modulate.a = 0.0
	_rail.ground_alpha = 0.0
	_pill.modulate.a = 0.0
	_arrival = create_tween().set_parallel()
	_arrival.tween_property(_consoles, ^"arrival", 1.0, _ARRIVAL_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# The pill names a game: it shows only over the games; the console's name only over the consoles.
	if _screen == Screen.GAMES:
		_arrival.tween_property(_pill, ^"modulate:a", 1.0, StudioTokens.TR_GAMES_FADE_S).set_delay(_PILL_ARRIVES_S)
	elif _screen == Screen.CONSOLES:
		_fade_title(1.0, _TITLE_ARRIVES_S)
		_rail.sunk = 1.0
		_rail.rise(StudioTokens.TR_GAMES_RAIL_BACK_S, _TITLE_ARRIVES_S)


func _show_rail() -> void:
	var shown := _console_title.visible and not _shelves.is_empty() and _screen not in _GAME_SCREENS
	_rail.visible = shown


## The console's name fades to [param alpha] after [param delay_s], instead of any fade under way:
## going into a console while it still comes in must not show it there.
func _fade_title(alpha: float, delay_s := 0.0, fade_s := StudioTokens.TR_GAMES_FADE_S) -> void:
	_title_fade = Motion.restart(self, _title_fade).set_parallel()
	_title_fade.tween_property(_console_title, ^"modulate:a", alpha, fade_s).set_delay(delay_s)
	# The frame and the pool leave with it; the tiles sink.
	_title_fade.tween_property(_rail, ^"ground_alpha", alpha, fade_s).set_delay(delay_s)


## The settings over the consoles screen or the games screen, until closed; the consoles come in
## again if a console had to be added meanwhile, the last one removed.
func _open_settings() -> void:
	Sounds.play(SoundEffects.Cue.SETTINGS)
	_cover()
	var settings: SettingsMenu = _screens.get_node("%Settings")
	settings.gel = _selected_gel()
	var transition := SettingsTransition.new(settings, _screen == Screen.GAMES, _row, _consoles,
		_console_title, _pill, _games_hints, _search, _sequence, _rail, _games_logo, [_arrival, _title_fade])
	var emptied := await _screens.open_settings()
	transition.restore(_screens.arrived)
	_row.games_float = settings.games_float
	Diagnostics.trace("settings", "games row games_float=%s" % str(settings.games_float))
	if emptied and not _screens.arrived:
		_come_in()
	else:
		_show_front(false)
	transition.resume([_arrival, _title_fade])
	_shown = true


## The selected console shown as the model in [param folder], the library's choice unchanged.
func _show_variant(folder: String) -> void:
	if folder == _consoles.selected().folder:
		return
	var shown := _console_variants.duplicate()
	shown[_shelves[_shelf].platform_id] = folder
	_show_variants(shown)


func _keep_variant(folder: String) -> void:
	var answer := await android.set_variant(_shelves[_shelf].platform_id, folder)
	if answer.ok:
		_console_variants = answer.library.console_variants
		_screens.library = answer.library
	else:
		Diagnostics.trace("console", "variant not kept (%s): %s" % [answer.code, answer.detail])
		_show_variants(_console_variants)


func _show_variants(variants: Dictionary[String, String]) -> void:
	_appearance.use_variants(variants)
	_consoles.replace_selected(_console_item(_shelves[_shelf]))
	# The selected console stands as its own model's launch animation has it.
	_sequence.use(_appearance.animation_of(_platforms[_shelves[_shelf].platform_id], _row.selected_game().medium))


func _open_console_properties() -> void:
	Sounds.play(SoundEffects.Cue.PROPERTIES)
	_focus.gel = _selected_gel()
	_leave_consoles(Screen.CONSOLE_PROPERTIES)
	_console_properties.open()


func _reopen_add_ball() -> void:
	if Input.is_action_pressed(&"ui_up"):
		_add_ball.open()


func _on_console_properties_closed() -> void:
	# Closed for the ring, the carousel is already there.
	if _screen == Screen.CONSOLE_PROPERTIES:
		_go(Screen.CONSOLES)
		_reopen_add_ball()


func _open_order() -> void:
	Sounds.play(SoundEffects.Cue.RING_OPEN)
	_leave_consoles(Screen.ORDER)
	_order.open(_platform_ids(), _shelf)


func _leave_consoles(screen_to: Screen) -> void:
	_hold_select.stop()
	_add_ball.close(false)
	_art_progress.hide()
	_go(screen_to)


func _platform_ids() -> Array[String]:
	var platform_ids: Array[String] = []
	for shelf in _shelves:
		platform_ids.append(shelf.platform_id)
	return platform_ids


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
	var folders: Array[String] = []
	for index in _shelves.size():
		folders.append(_consoles.console_at(index).folder)
	_rail.show_consoles(folders, _consoles.target())
	_show_rail()


## The ring starts closing: the rail rises and the consoles screen's frame, pool and title come back as the console
## pointed at glides to the middle (its title too when the ring came from a console's properties, which hid it).
func _on_order_closing(duration: float) -> void:
	var time_ratio := duration / _RING_CLOSE_S
	_console_title.show()
	_show_rail()
	_rail.rise(StudioTokens.TR_GAMES_RAIL_BACK_S * time_ratio, _RING_RISE_AFTER_S * time_ratio)
	_fade_title(1.0, _RING_BACK_AFTER_S * time_ratio, _RING_BACK_S * time_ratio)


func _on_order_closed() -> void:
	_go(Screen.CONSOLES)
	_reopen_add_ball()


func _open_properties() -> void:
	Sounds.play(SoundEffects.Cue.PROPERTIES)
	_hold_select.stop()
	_row.freeze()
	_art_progress.hide()
	_go(Screen.PROPERTIES)
	_focus.gel = _selected_gel()
	_properties.open()


func _add_console() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	_cover(true)
	if _form_entry == null:
		_form_entry = FormEntry.new()
		add_child(_form_entry)
	_form = Form.ASKED
	_rail.sink(StudioTokens.TR_RING_SINK_S)
	_fade_title(0.0, 0.0, _RING_LEAVE_S)
	_form_entry.open(_add_ball)
	await get_tree().create_timer(StudioTokens.TR_FORM_AT_S).timeout
	await _screens.add_console()
	_form = Form.NONE
	_add_ball.close(false)
	_show_front(false)
	_reopen_add_ball()
	_shown = true


func _on_screens_form_leaving() -> void:
	if _form == Form.NONE:
		return
	_form = Form.GIVEN_UP
	_show_front(false)
	_rail.rise(StudioTokens.TR_GAMES_RAIL_BACK_S, _FORM_BACK_RISE_AFTER_S)
	_fade_title(1.0, FormEntry.BALL_AT_S, StudioTokens.TR_FORM_BACK_S - FormEntry.BALL_AT_S)
	_form_entry.close(_add_ball)


## The screens cover the carousel: at once, but for the form, which comes in over the consoles and hides them once it is
## there.
func _on_screens_covering() -> void:
	if _form == Form.ASKED:
		_form = Form.COMING
		await get_tree().create_timer(StudioTokens.TR_FORM_OPEN_S - StudioTokens.TR_FORM_AT_S).timeout
		# Given up, or gone, while the consoles stayed in view: they are not covered any more.
		if _form != Form.COMING:
			return
		_form = Form.COVERING
		_add_ball.close(false)
	if _screens.visible:
		_show_front(true)


func _cover(keeping_ball := false) -> void:
	_show_waiting_shelf()
	_shown = false
	_hold_select.stop()
	_message_timer.stop()
	_on_message_timer_timeout()
	# A direction let go under the screens never reaches the row, nor the ribbon.
	_row.freeze()
	_search.let_go()
	_art_progress.hide()
	if not keeping_ball:
		_add_ball.close(false)


## The last console of the row placed on the ring of the others as the form's Add does, for the benchmarks: true once it
## is, and the consoles screen shows again.
func place_last_console() -> bool:
	_cover()
	_show_front(true)
	var last: String = _platform_ids().back()
	var placed := await _place_console(_screens.library, last)
	_show_front(false)
	_shown = true
	return placed


## The added console glides to the middle with up to two shelves or no other model; otherwise the ring places it.
## True once landed; false on cancellation, including a row removed during the flight.
func _place_console(library: AndroidServices.Library, platform_id: String) -> bool:
	_demo = false
	_show_library(library, platform_id)
	_remember()
	if _shelves.size() <= 2 or _order.ring_of(_platform_ids(), platform_id).is_empty():
		_screens.hide()
		_show_front(false)
		_console_title.modulate.a = 0.0
		_console_arrival = ConsoleArrival.new()
		add_child(_console_arrival)
		var arrived := await _console_arrival.play(_consoles)
		_console_arrival.queue_free()
		_console_arrival = null
		if not arrived:
			return false
		_arrive(false)
		return true
	_consoles.show()
	_console_title.modulate.a = 0.0
	_rail.ground_alpha = 0.0
	_rail.sunk = 1.0
	if not _order.form_wanted.is_connected(_screens.bring_back_form):
		_order.form_wanted.connect(_screens.bring_back_form)
	var placed := await _order.place(_platform_ids(), platform_id)
	if not placed:
		_show_front(true)
	return placed


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
	_art_progress.give_way(false)


func _on_art_focus_timeout() -> void:
	_show_waiting_shelf()
	if _row.has_games():
		android.art_focus(_row.games_around(CarouselLayout.REACH))


func _on_hold_select_timeout() -> void:
	# Awaited: its answer must not come back to a freed scene.
	await _remember()
	get_tree().change_scene_to_file(_DEVICE_CHECK)


func _play_logo(back: bool) -> void:
	var seconds := StudioTokens.TR_GAMES_LOGO_S
	if seconds <= 0.0 or _shelf < 0 or _shelf >= _rail.tiles().size():
		return
	var tile := _rail.tiles()[_shelf].logo()
	var flight := LogoFlight.new()
	add_child(flight)
	flight.play(_games_logo if back else tile, tile if back else _games_logo, seconds,
		maxf(0.0, _sequence.trip_s() - seconds) if back else 0.0)


func _start_moving() -> bool:
	if _screen == Screen.CONSOLES:
		return _consoles.is_settling()
	return _screen == Screen.GAMES and _row.is_settling()


func _needs_settle(event: InputEvent) -> bool:
	if StudioTokens.TR_SETTLE_S <= 0.0 or not _shown or _game_launch.is_busy() \
			or _screen not in [Screen.CONSOLES, Screen.GAMES] or event.is_echo() or not event.is_pressed():
		return false
	for action: StringName in [&"ui_accept", &"open_settings", &"open_properties", &"ui_up", &"ui_down", &"screen_back"]:
		if event.is_action_pressed(action):
			return _start_moving()
	return false


func _after_settle(event: InputEvent, moved: bool) -> void:
	_settle_waiting = true
	var before_screen := _screen
	var started := Time.get_ticks_msec()
	if _screen == Screen.GAMES:
		_row.freeze()
	while _start_moving() and Time.get_ticks_msec() - started < StudioTokens.TR_SETTLE_S * 1000.0:
		await get_tree().process_frame
	_settle_waiting = false
	if _screen == before_screen:
		_handle_input(event, moved)
