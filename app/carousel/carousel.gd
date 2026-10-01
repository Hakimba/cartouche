# SPDX-License-Identifier: GPL-3.0-or-later
class_name Carousel
extends Control
## The main screens. The consoles screen shows one console per platform with games ([ConsoleRow]);
## A goes into the selected one, as its launch animation has it ([ConsoleSequence]), to the games
## screen: the platform's shelf of games, the selected game in the middle. There, left and right
## move along the shelf (held, faster and faster), A launches the selected game into its console
## ([GameLaunch]), B goes back out to the consoles. The right stick turns the selected console on
## the consoles screen, the selected game on the games screen, nothing in between. Where the user
## was is remembered across restarts. The games' disc scans arrive as the plugin finds them
## ([GameArt]), a bar under the title telling how it goes.
##
## In front of it, [ScreenFlow] shows the welcome at each start while the library loads, the first
## launch's screens, and the screens adding a console while none has games; Y on the consoles
## screen opens the settings over it. On the consoles screen, holding up turns the "+" ball above
## the console into a button ([AddBall]), until up is let go: A then adds one more console, the
## consoles coming in again on it. The carousel waits for the screens in front to close.
##
## In debug builds, holding Select opens the device check, and command-line arguments set up
## measurements: `--welcome=skip` goes past the welcome without a press, `--demo-games=N` shows a made-up library of N games, `--bench=scroll`, `enter`,
## `turn` or `launch` runs [CarouselBench], `--turntable=T` turns the selected game T times a second to show
## all its sides, `--shelf=gba` opens on that platform. Without the Android plugin (the editor, a
## desktop run), the demo library is shown.

## The screen changed; in between, the animation into or out of the console plays.
signal screen_changed(screen: Screen)

enum Screen { CONSOLES, ENTERING, GAMES, LEAVING }

const _APPEARANCE := "res://data/carousel/appearance.json"
const _DEVICE_CHECK := "res://dev/device_check/device_check.tscn"
const _BATTERY_EVERY_S := 60
const _MESSAGE_S := 4.0
## The art bar moves to each new count in this time; once full, it stays a moment, then fades.
const _ART_STEP_S := 0.3
const _ART_FULL_S := 1.0
const _ART_FADE_S := 0.4
const _MOVING: Array[Screen] = [Screen.ENTERING, Screen.LEAVING]
## The console's name above it fades out as the animation into it starts, back in once out.
const _TITLE_FADE_S := 0.2
## The carousel comes in once the screens in front of it are gone: the consoles grow out of
## their centres, overshooting a little, then the console's name and the pill fade in.
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

var android: AndroidServices = Android

var _shelves: Array[AndroidServices.Shelf] = []
var _shelf := 0
var _screen := Screen.CONSOLES
## Index of the game each platform showed last in this session, by platform id.
var _positions: Dictionary[String, int] = {}
var _platforms: Dictionary[String, AndroidServices.Platform] = {}
var _appearance: Appearance
## Whether the library shown is made up: its labels get made-up artwork.
var _demo := false
## Set once the library is shown: until then there is nothing to move, launch or remember.
var _shown := false
## Whether the consoles wait to come in, at the start or once the last was removed: the screens in
## front hide them until then.
var _arriving := true
var _direction := HeldDirection.new()
var _clock_ticks := 0
var _art_tween: Tween
var _arrival: Tween

@onready var _row: ShelfRow = %Row
@onready var _consoles: ConsoleRow = %Consoles
@onready var _sequence: ConsoleSequence = %Sequence
@onready var _clock: Label = %Clock
@onready var _console_title: Control = %ConsoleTitle
@onready var _console_name: Label = %ConsoleName
@onready var _console_model: Label = %ConsoleModel
@onready var _add_ball: AddBall = %AddBall
@onready var _camera: Camera3D = $Camera
@onready var _battery: Label = %Battery
## Shown while a run looks for art; its content, apart, hides for a message and fades once done.
@onready var _art_progress: Control = %ArtProgress
@onready var _art_content: Control = %Content
@onready var _art_bar: ProgressBar = %Bar
@onready var _art_text: Label = %ArtText
@onready var _art: GameArt = %Art
@onready var _pill: Control = %Pill
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _message_timer: Timer = %MessageTimer
@onready var _screens: ScreenFlow = %Screens
@onready var _top_bar: Control = %TopBar
@onready var _hold_select: Timer = %HoldSelect
@onready var _game_launch: GameLaunch = %GameLaunch


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_screens.android = android
	if Diagnostics.argument("welcome") == "skip":
		_screens.welcome_waits = false
	# The welcome shows first, without the bar.
	_top_bar.hide()
	_show_front(true)
	for platform in android.catalog.platforms:
		_platforms[platform.id] = platform
	_appearance = Appearance.read(_APPEARANCE)
	# At the consoles' depth, the screen's height spans 2·d·tan(fov / 2).
	var depth := _camera.global_position.z - _consoles.global_position.z
	var shown := get_viewport_rect().size
	_consoles.position.y -= _CONSOLES_LOWER_PX / shown.y * 2.0 * depth * tan(deg_to_rad(_camera.fov / 2.0))
	_screens.console_point = Vector2(shown.x / 2.0, _CONSOLE_Y + _CONSOLES_LOWER_PX)
	_screens.appearance = _appearance
	_screens.console_of = func(platform_id: String) -> Node3D: return _console_item(platform_id).model
	_row.pose = _appearance.pose
	# The same pose, but for its sway, which each console's launch animation has.
	_consoles.pose.tilt = _appearance.pose.tilt
	_consoles.pose.turn = _appearance.pose.turn
	_consoles.pose.sway_period_s = _appearance.pose.sway_period_s
	_row.label_images = _art
	# Before the library is asked for: its art is looked for as soon as it is sent.
	android.art_changed.connect(_on_art_changed)
	_row.prepare(_appearance.models.values())
	_row.turntable = Diagnostics.argument("turntable").to_float()
	_on_clock_timeout()
	var demo_games := Diagnostics.argument("demo-games").to_int()
	var answer: AndroidServices.LibraryAnswer
	_demo = demo_games > 0 or not android.is_available()
	if _demo:
		answer = await android.use_demo_library(demo_games)
	else:
		answer = await android.library()
	if not answer.ok:
		Diagnostics.trace("carousel", "library not read (%s): %s" % [answer.code, answer.detail])
	var settings := await android.settings()
	if settings.has_button_style:
		Controls.style = settings.button_style
	for art in answer.art:
		_art.add(art)
	_show_library(answer.library)
	_screens.library = answer.library
	await _screens.run(settings)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_remember()
		# Up let go meanwhile never reaches the app.
		_add_ball.close(false)


func _process(_delta: float) -> void:
	var stick := Input.get_vector(&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down")
	_consoles.inspect(stick if _screen == Screen.CONSOLES and _shown else Vector2.ZERO)
	if not _game_launch.is_busy():
		_row.inspect(stick if _screen == Screen.GAMES else Vector2.ZERO)
	if _screen in _MOVING:
		_show_title()


func _unhandled_input(event: InputEvent) -> void:
	var moved := _direction.update(event)
	# Nothing acts from A until the carousel shows again after the game, nor while the animation
	# into or out of the console plays.
	if event.is_echo() or not _shown or _game_launch.is_busy() or _screen in _MOVING:
		return
	if event.is_action_pressed(&"app_back") and Diagnostics.enabled:
		_hold_select.start()
	elif event.is_action_released(&"app_back"):
		_hold_select.stop()
	elif not _row.has_games():
		return
	elif _screen == Screen.CONSOLES and event.is_action_pressed(&"open_settings"):
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
	elif _screen == Screen.GAMES and event.is_action_pressed(&"screen_back"):
		_leave()
	else:
		return
	get_viewport().set_input_as_handled()


## The screen shown, or the one the animation goes to.
func screen() -> Screen:
	return _screen


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
	if _screens.visible:
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
	var asked := shown if shown else Diagnostics.argument("shelf")
	for i in _shelves.size():
		if _shelves[i].platform_id == asked:
			_shelf = i
	if _shelves.is_empty():
		return
	var items: Array[ConsoleRow.Item] = []
	for shelf in _shelves:
		_positions[shelf.platform_id] = shelf.selected
		items.append(_console_item(shelf.platform_id))
	_consoles.show_consoles(items, _shelf)
	_show_platform()
	if Diagnostics.enabled:
		var game := _row.selected_game()
		Diagnostics.trace("carousel", "restored %s on %s in %.1f ms" % [
			game.title, game.platform_id, (Time.get_ticks_usec() - started) / 1000.0])


## The console of [param platform_id] as the consoles screen shows it: its model, or else its
## medium, labelled with the platform's name.
func _console_item(platform_id: String) -> ConsoleRow.Item:
	var platform := _platforms[platform_id]
	var rest := ConsoleRow.Rest.of(_appearance.animation_of(platform_id))
	if platform_id in _appearance.consoles:
		var console: ConsoleModel = _appearance.consoles[platform_id].instantiate()
		return ConsoleRow.Item.new(console, rest)
	var medium := ShelfRow.LabelledModel.new(_appearance.models[platform.media])
	medium.draw_label(platform.name, _look(platform_id))
	return ConsoleRow.Item.new(medium, rest)


## The platform selected on the consoles screen: its shelf behind, ready for the games screen, and
## its launch animation.
func _show_platform() -> void:
	var shelf := _shelves[_shelf]
	var platform := _platforms[shelf.platform_id]
	_row.show_shelf(shelf.games, _positions[shelf.platform_id], _appearance.models[platform.media],
		_look(shelf.platform_id))
	_sequence.use(_appearance.animation_of(shelf.platform_id))
	_console_name.text = _appearance.console_names.get(shelf.platform_id, platform.name)
	_console_model.text = _appearance.console_models.get(shelf.platform_id, "")
	_title.text = platform.name


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


## The pill names the selected game once its disc shows at least half, the console otherwise.
func _show_title() -> void:
	_title.text = (_row.selected_game().title if _row.selected_presence >= 0.5
		else _platforms[_shelves[_shelf].platform_id].name)


func _go(screen_to: Screen) -> void:
	_screen = screen_to
	if screen_to in [Screen.ENTERING, Screen.CONSOLES]:
		_console_title.create_tween().tween_property(_console_title, ^"modulate:a",
			1.0 if screen_to == Screen.CONSOLES else 0.0, _TITLE_FADE_S)
	Diagnostics.trace("carousel", "screen %s" % Screen.keys()[screen_to])
	screen_changed.emit(screen_to)


func _launch() -> void:
	var game := _row.selected_game()
	# A press begun before A must not act once it is let go.
	_hold_select.stop()
	_remember()
	var insertion := _appearance.insertions[_platforms[game.platform_id].media]
	_game_launch.launch(game, game.last_disc, insertion)


## Stores the selected game and its platform, for the next start.
func _remember() -> void:
	if _shelves.is_empty() or not _row.has_games():
		return
	_positions[_shelves[_shelf].platform_id] = _row.selected_index()
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
	if change.has_found:
		_art.add(change.found)
		_row.refresh_label(change.found.game_id)
	_show_art_progress(change.progress)


func _on_row_selection_changed(game: AndroidServices.Game) -> void:
	if _screen == Screen.GAMES:
		_title.text = game.title


func _on_consoles_selection_changed(index: int) -> void:
	_shelf = index
	_show_platform()
	Diagnostics.trace("carousel", "platform %s" % _shelves[_shelf].platform_id)
	_remember()


func _on_clock_timeout() -> void:
	_clock.text = Time.get_time_string_from_system().left(5)
	if _clock_ticks % _BATTERY_EVERY_S == 0:
		var battery := android.battery()
		_battery.text = ("%d %%" % battery.level_percent if battery.has_level else "") + (" ⚡" if battery.charging else "")
	_clock_ticks += 1


func _on_game_launch_failed(code: StringName) -> void:
	Diagnostics.trace("carousel", "launch failed: %s" % code)
	var platform := _platforms[_shelves[_shelf].platform_id].name
	match code:
		&"not_installed", &"no_player":
			_show_message(tr("No {platform} emulator is installed.").format({"platform": platform}))
		&"game_missing":
			_show_message(tr("This game's file cannot be found: is its SD card or folder still there?"))
		_:
			_show_message(tr("The game could not be launched."))


## Shows the screens in front of the carousel, which then shows nothing of its own but its
## background, or the carousel itself.
func _show_front(front: bool) -> void:
	for part: Node3D in [_row, _consoles]:
		part.visible = not front
	_console_title.visible = not front
	_pill.visible = not front and not _shelves.is_empty()
	if front:
		_art_progress.hide()


## The consoles come in, no longer hidden by the screens in front.
func _come_in() -> void:
	_arriving = false
	_show_front(false)
	_arrive()


## The consoles fade in and grow to their size, then their name and the pill come in.
func _arrive() -> void:
	_consoles.arrival = _ARRIVAL_POINT
	_console_title.modulate.a = 0.0
	_pill.modulate.a = 0.0
	_arrival = create_tween().set_parallel()
	_arrival.tween_property(_consoles, ^"arrival", 1.0, _ARRIVAL_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_arrival.tween_property(_console_title, ^"modulate:a", 1.0, _TITLE_FADE_S).set_delay(_TITLE_ARRIVES_S)
	_arrival.tween_property(_pill, ^"modulate:a", 1.0, _TITLE_FADE_S).set_delay(_PILL_ARRIVES_S)


func _on_screens_library_changed(library: AndroidServices.Library) -> void:
	_demo = false
	# Drawn as a point under the screens in front, the consoles have their shaders ready when
	# they come out of it. A point before they are placed: placed full size, they would show so
	# for a frame.
	_consoles.arrival = _ARRIVAL_POINT
	_show_library(library)
	_consoles.show()


## The settings over the consoles screen, until closed; the consoles come in again if a console
## had to be added meanwhile, the last one removed.
func _open_settings() -> void:
	_cover()
	if await _screens.open_settings():
		_come_in()
	_shown = true


## The form adding one more console, over the consoles; the consoles come in again on the one
## added.
func _add_console() -> void:
	_cover()
	await _screens.add_console()
	# Still held up, the button is still there.
	if Input.is_action_pressed(&"ui_up"):
		_add_ball.open()
	_shown = true


## Before screens open over the consoles: the carousel takes no press, and the art's progress is
## not followed under them.
func _cover() -> void:
	_shown = false
	_hold_select.stop()
	_art_progress.hide()
	_add_ball.close(false)


func _on_screens_console_added(library: AndroidServices.Library, platform_id: String) -> void:
	_show_library(library, platform_id)
	_remember()
	_arrive()


func _on_screens_library_edited(library: AndroidServices.Library) -> void:
	_art.keep_only(library.games)
	_show_library(library)
	# Back once the settings close, coming in as after a first console.
	if _shelves.is_empty():
		_arriving = true
		_show_front(true)


func _on_screens_covering(covers: bool) -> void:
	_show_front(covers or _arriving)


func _on_screens_welcome_closed() -> void:
	_top_bar.show()


func _on_message_timer_timeout() -> void:
	_message.hide()
	_art_content.show()


func _on_hold_select_timeout() -> void:
	# Awaited: its answer must not come back to a freed scene.
	await _remember()
	get_tree().change_scene_to_file(_DEVICE_CHECK)
