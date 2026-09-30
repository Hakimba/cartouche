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
## In debug builds, holding Select opens the device check, and command-line arguments set up
## measurements: `--demo-games=N` shows a made-up library of N games, `--bench=scroll`, `enter`,
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
var _direction := HeldDirection.new()
var _clock_ticks := 0
var _art_tween: Tween

@onready var _row: ShelfRow = %Row
@onready var _consoles: ConsoleRow = %Consoles
@onready var _sequence: ConsoleSequence = %Sequence
@onready var _clock: Label = %Clock
@onready var _platform_tab: Label = %Platform
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
@onready var _empty: Label = %Empty
@onready var _hold_select: Timer = %HoldSelect
@onready var _game_launch: GameLaunch = %GameLaunch


func _ready() -> void:
	var started := Time.get_ticks_msec()
	for platform in Android.catalog.platforms:
		_platforms[platform.id] = platform
	_appearance = Appearance.read(_APPEARANCE)
	_row.pose = _appearance.pose
	# The same pose, but for its sway, which each console's launch animation has.
	_consoles.pose.tilt = _appearance.pose.tilt
	_consoles.pose.turn = _appearance.pose.turn
	_consoles.pose.sway_period_s = _appearance.pose.sway_period_s
	_row.label_images = _art
	# Before the library is asked for: its art is looked for as soon as it is sent.
	Android.art_changed.connect(_on_art_changed)
	_row.prepare(_appearance.models.values())
	_row.turntable = Diagnostics.argument("turntable").to_float()
	_on_clock_timeout()
	var demo_games := Diagnostics.argument("demo-games").to_int()
	var answer: AndroidServices.LibraryAnswer
	_demo = demo_games > 0 or not Android.is_available()
	if _demo:
		answer = await Android.use_demo_library(demo_games)
	else:
		answer = await Android.library()
	if not answer.ok:
		Diagnostics.trace("carousel", "library not read (%s): %s" % [answer.code, answer.detail])
	for art in answer.art:
		_art.add(art)
	_show_library(answer.library)
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


func _process(_delta: float) -> void:
	var stick := Input.get_vector(&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down")
	_consoles.inspect(stick if _screen == Screen.CONSOLES else Vector2.ZERO)
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
	elif _screen == Screen.CONSOLES and moved and _direction.held:
		_consoles.step(_direction.direction)
	elif _screen == Screen.CONSOLES and event.is_action_pressed(&"ui_accept"):
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


func _show_library(library: AndroidServices.Library) -> void:
	var started := Time.get_ticks_usec()
	_shelves = library.shelves
	_shelf = library.selected_shelf
	var asked := Diagnostics.argument("shelf")
	for i in _shelves.size():
		if _shelves[i].platform_id == asked:
			_shelf = i
	var has_games := not _shelves.is_empty()
	_empty.visible = not has_games
	_pill.visible = has_games
	if not has_games:
		_empty.text = tr("No games yet.")
		if Diagnostics.enabled:
			_empty.text += "\n" + tr("Hold Select to open the device check, then choose a folder and scan it.")
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
	_platform_tab.text = platform.name
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
	if not _row.has_games():
		return
	_positions[_shelves[_shelf].platform_id] = _row.selected_index()
	var result := await Android.select_game(_row.selected_game())
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
		var battery := Android.battery()
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


func _on_message_timer_timeout() -> void:
	_message.hide()
	_art_content.show()


func _on_hold_select_timeout() -> void:
	# Awaited: its answer must not come back to a freed scene.
	await _remember()
	get_tree().change_scene_to_file(_DEVICE_CHECK)
