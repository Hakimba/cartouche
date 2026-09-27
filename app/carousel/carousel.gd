# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## The main screen: one shelf of games per platform, the selected game in the middle. Left and
## right move along the shelf (held, faster and faster), L1 and R1 change platform, A launches the
## selected game, the right stick turns it. Where the user was is remembered across restarts.
##
## In debug builds, holding Select opens the device check, and command-line arguments set up
## measurements: `--demo-games=N` shows a made-up library of N games, `--bench=scroll`, `switch` or
## `turn` runs [CarouselBench], `--turntable=T` turns the selected game T times a second to show
## all its sides, `--shelf=gba` opens on that platform's shelf. Without the Android plugin (the
## editor, a desktop run), the demo library is shown.

const _APPEARANCE := "res://data/carousel/appearance.json"
const _DEVICE_CHECK := "res://dev/device_check/device_check.tscn"
const _BATTERY_EVERY_S := 60
const _MESSAGE_S := 4.0
const _SWITCH_OUT_S := 0.12
const _SWITCH_IN_S := 0.2

var _shelves: Array[AndroidServices.Shelf] = []
var _shelf := 0
## Index of the game each platform showed last in this session, by platform id.
var _positions: Dictionary[String, int] = {}
var _platforms: Dictionary[String, AndroidServices.Platform] = {}
var _models: Dictionary[String, PackedScene] = {}
var _colors: Dictionary[String, Color] = {}
var _default_color: Color
## Whether the library shown is made up: its labels get made-up artwork.
var _demo := false
## Set once the library is shown: until then there is nothing to move, launch or remember.
var _shown := false
var _switching := false
var _launching := false
var _direction := HeldDirection.new()
var _clock_ticks := 0

@onready var _row: ShelfRow = %Row
@onready var _clock: Label = %Clock
@onready var _tabs: HBoxContainer = %Tabs
@onready var _tab_bar: Control = %TabBar
@onready var _battery: Label = %Battery
@onready var _pill: Control = %Pill
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _message_timer: Timer = %MessageTimer
@onready var _empty: Label = %Empty
@onready var _hold_select: Timer = %HoldSelect


func _ready() -> void:
	var started := Time.get_ticks_msec()
	for platform in Android.catalog.platforms:
		_platforms[platform.id] = platform
	_load_appearance()
	_row.prepare(_models.values())
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
	_show_library(answer.library)
	_shown = true
	if Diagnostics.enabled:
		await get_tree().process_frame
		Diagnostics.trace("carousel", "shown: %d games on %d shelves, %d ms after the scene started" % [
			answer.library.games.size(), _shelves.size(), Time.get_ticks_msec() - started])
		var frames := PackedStringArray()
		for frame in 3:
			var frame_started := Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append("%.1f" % ((Time.get_ticks_usec() - frame_started) / 1000.0))
		Diagnostics.trace("carousel", "first frames: %s ms" % ", ".join(frames))
		var bench := Diagnostics.argument("bench")
		if bench:
			add_child(CarouselBench.new(bench, _row))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_remember()


func _process(_delta: float) -> void:
	_row.inspect(Input.get_vector(&"inspect_left", &"inspect_right", &"inspect_up", &"inspect_down"))


func _unhandled_input(event: InputEvent) -> void:
	var moved := _direction.update(event)
	if event.is_echo() or not _shown:
		return
	if event.is_action_pressed(&"app_back") and Diagnostics.enabled:
		_hold_select.start()
	elif event.is_action_released(&"app_back"):
		_hold_select.stop()
	elif _switching or not _row.has_games():
		return
	elif moved and _direction.held:
		_row.hold(_direction.direction)
	elif moved:
		_row.release(_direction.direction)
	elif event.is_action_pressed(&"tab_previous"):
		_switch_shelf(-1)
	elif event.is_action_pressed(&"tab_next"):
		_switch_shelf(1)
	elif event.is_action_pressed(&"ui_accept"):
		_launch()
	else:
		return
	get_viewport().set_input_as_handled()


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
	_tab_bar.visible = has_games
	if not has_games:
		_empty.text = tr("No games yet.")
		if Diagnostics.enabled:
			_empty.text += "\n" + tr("Hold Select to open the device check, then choose a folder and scan it.")
		return
	for shelf in _shelves:
		_positions[shelf.platform_id] = shelf.selected
	_show_shelf()
	if Diagnostics.enabled:
		var game := _row.selected_game()
		Diagnostics.trace("carousel", "restored %s on %s in %.1f ms" % [
			game.title, game.platform_id, (Time.get_ticks_usec() - started) / 1000.0])


func _show_shelf() -> void:
	# Shelves are made of the catalog's platforms, and every media has a model (INV-E2-06).
	var shelf := _shelves[_shelf]
	var platform := _platforms[shelf.platform_id]
	var look := ShelfRow.LabelLook.new()
	look.color = _colors.get(shelf.platform_id, _default_color)
	look.platform_name = platform.name
	look.demo_art = _demo
	_row.show_shelf(shelf.games, _positions[shelf.platform_id], _models[platform.media], look)
	_show_tabs()
	_on_row_selection_changed(_row.selected_game())


## The current platform between the ones L1 and R1 lead to: the bar fits however many there are.
func _show_tabs() -> void:
	var shown: Array[int] = []
	for step in range(-1, 2):
		var shelf := posmod(_shelf + step, _shelves.size())
		if shelf not in shown:
			shown.append(shelf)
	for i in _tabs.get_child_count():
		var tab: Label = _tabs.get_child(i)
		tab.visible = i < shown.size()
		if tab.visible:
			tab.text = _platforms[_shelves[shown[i]].platform_id].name
			tab.theme_type_variation = &"CurrentTab" if shown[i] == _shelf else &"OtherTab"


func _switch_shelf(direction: int) -> void:
	if _shelves.size() < 2:
		return
	_switching = true
	# The game left on this shelf, for the next start; the requests are answered in order.
	_remember()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_row, ^"scale", Vector3.ONE * 0.01, _SWITCH_OUT_S).set_ease(Tween.EASE_IN)
	await tween.finished
	_shelf = posmod(_shelf + direction, _shelves.size())
	_show_shelf()
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "platform %s" % _shelves[_shelf].platform_id)
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_row, ^"scale", Vector3.ONE, _SWITCH_IN_S)
	await tween.finished
	_switching = false
	_remember()


func _launch() -> void:
	if _launching:
		return
	_launching = true
	var game := _row.selected_game()
	_remember()
	var result := await Android.launch_game(game, game.last_disc)
	_launching = false
	if not result.ok:
		Diagnostics.trace("carousel", "launch failed (%s): %s" % [result.code, result.detail])
		match result.code:
			&"not_installed", &"no_player":
				_show_message(tr("No emulator for this game is installed."))
			_:
				_show_message(tr("The game could not be launched."))


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
	_message_timer.start(_MESSAGE_S)


func _load_appearance() -> void:
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_APPEARANCE))
	var models: Dictionary = appearance["models"]
	for media: String in models:
		var path: String = models[media]
		_models[media] = load(path)
	var colors: Dictionary = appearance["colors"]
	for platform_id: String in colors:
		var color: String = colors[platform_id]
		_colors[platform_id] = Color(color)
	var default_color: String = appearance["default_color"]
	_default_color = Color(default_color)
	var pose: Dictionary = appearance["pose"]
	_row.pose.tilt = pose["tilt_degrees"]
	_row.pose.turn = pose["turn_degrees"]
	_row.pose.sway = pose["sway_degrees"]
	var period: float = pose["sway_period_s"]
	# A sway never takes no time.
	_row.pose.sway_period_s = maxf(period, 0.5)


func _on_row_selection_changed(game: AndroidServices.Game) -> void:
	_title.text = game.title


func _on_clock_timeout() -> void:
	_clock.text = Time.get_time_string_from_system().left(5)
	if _clock_ticks % _BATTERY_EVERY_S == 0:
		var battery := Android.battery()
		_battery.text = ("%d %%" % battery.level_percent if battery.has_level else "") + (" ⚡" if battery.charging else "")
	_clock_ticks += 1


func _on_message_timer_timeout() -> void:
	_message.hide()


func _on_hold_select_timeout() -> void:
	# Awaited: its answer must not come back to a freed scene.
	await _remember()
	get_tree().change_scene_to_file(_DEVICE_CHECK)
