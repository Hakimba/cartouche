# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameLaunch
extends Node
## Launches the selected game: checks that it can start, puts it into its console (the console's
## [ConsoleSequence]) or plays its medium's [Insertion], with its sounds, starts it once the screen
## is black, and shows the carousel again, as it was, when the user comes back. Nothing is played
## for a game that cannot start. While [method is_busy], the carousel ignores every input.
##
## Everything moves with the time [method _process] is given, so tests can step through a launch.
## Android pauses the app as the emulator shows and resumes it as the user comes back, before or
## after the start is answered: the stages keep track of both.

## The launch failed, before the insertion or at its end; [param code] is the plugin's error code,
## or `timeout` when it never answered.
signal failed(code: StringName)
## The screen is black: the game can start.
signal _inserted

enum Stage {
	READY,
	CHECKING,
	INSERTING,
	## Started, not answered yet; then left for the emulator, then back from it.
	STARTING,
	STARTING_LEFT,
	STARTING_BACK,
	## Started and answered; then left for the emulator.
	AWAY,
	AWAY_LEFT,
	SHOWING,
}

## Waiting this long for an answer, or for Android to leave for the emulator, gives up: the carousel
## shows again.
const WAIT_TIMEOUT_S := 5.0
const SHOW_S := 0.2

@export var row: ShelfRow
@export var spindle: Spindle
@export var sequence: ConsoleSequence
@export var blackout: ColorRect
## What fades out as the game turns: the title pill, the top bar.
@export var controls: Array[CanvasItem] = []

## The Android services, replaced by a fake in tests.
var android: AndroidServices = Android
## Where the insertions' sounds come from.
var sounds := DevSounds.new()

var _stage := Stage.READY
var _stage_s := 0.0
## Increases with every launch and every launch given up, so that a late answer is ignored.
var _launch_id := 0
var _insertion := Insertion.new()
## Whether the game goes into its console ([member sequence]) rather than by its insertion.
var _into_console := false
var _start := Transform3D.IDENTITY
var _clock_s := 0.0
var _cues_played := 0
var _players: Dictionary[Insertion.Cue, AudioStreamPlayer] = {}
## Frame times of the insertion, traced once it is done, in debug builds.
var _frames_ms := PackedFloat32Array()

@onready var _black: ShaderMaterial = blackout.material


func _ready() -> void:
	_enter(Stage.READY)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		match _stage:
			Stage.STARTING:
				_enter(Stage.STARTING_LEFT)
			Stage.AWAY:
				_enter(Stage.AWAY_LEFT)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		match _stage:
			Stage.STARTING_LEFT:
				_enter(Stage.STARTING_BACK)
			Stage.AWAY_LEFT:
				_show_carousel()


func _process(delta: float) -> void:
	_clock_s += delta
	_stage_s += delta
	match _stage:
		Stage.CHECKING:
			if _stage_s > WAIT_TIMEOUT_S:
				_give_up(&"timeout")
		Stage.INSERTING:
			if Diagnostics.enabled:
				_frames_ms.append(delta * 1000.0)
			_insert(delta)
			if _clock_s >= (sequence.launch_duration() if _into_console else _insertion.duration_s()):
				_inserted.emit()
		Stage.STARTING, Stage.STARTING_BACK, Stage.AWAY:
			_insert(delta)
			if _stage_s > WAIT_TIMEOUT_S:
				Diagnostics.trace("launch", "no answer or the emulator never showed: back to the carousel")
				_show_carousel()
		Stage.SHOWING:
			var shown := minf(_stage_s / SHOW_S, 1.0)
			_black.set_shader_parameter(&"opacity", 1.0 - shown)
			if shown >= 1.0:
				blackout.visible = false
				_enter(Stage.READY)


func is_busy() -> bool:
	return _stage != Stage.READY


## Makes the players of [param insertions]' sounds, once, rather than as a launch starts.
func prepare(insertions: Array[Insertion]) -> void:
	for insertion in insertions:
		for cue in insertion.sounds:
			if sounds.has_sound(cue.name):
				var player := AudioStreamPlayer.new()
				player.stream = sounds.sound(cue.name)
				player.volume_db = cue.volume_db
				add_child(player)
				_players[cue] = player


## Launches disc [param disc] of [param game], the selected game, into its console when the
## sequence has a launch (see [method ConsoleSequence.can_launch]), else with [param insertion],
## whose sounds play either way; does nothing while [method is_busy].
func launch(game: AndroidServices.Game, disc: int, insertion: Insertion) -> void:
	if is_busy():
		return
	_launch_id += 1
	var launch_id := _launch_id
	row.freeze()
	_enter(Stage.CHECKING)
	var pressed := Time.get_ticks_msec()
	var check := await android.check_launch(game, disc)
	if launch_id != _launch_id:
		return
	var checked_ms := Time.get_ticks_msec() - pressed
	Diagnostics.trace("launch", "checked in %d ms: %s" % [checked_ms, check.code if not check.ok else &"ok"])
	if not check.ok:
		_give_up(check.code)
		return
	_insertion = insertion
	_into_console = sequence.can_launch()
	_start = row.selected_stand()
	_clock_s = 0.0
	_cues_played = 0
	_frames_ms.clear()
	spindle.transform = insertion.spindle_stand()
	spindle.visible = insertion.spindle and not _into_console
	_black.set_shader_parameter(&"opacity", 1.0)
	_black.set_shader_parameter(&"radius", 0.0)
	blackout.visible = true
	_enter(Stage.INSERTING)
	await _inserted
	var inserted_s := _clock_s
	_enter(Stage.STARTING)
	var result := await android.launch_game(game, disc)
	if launch_id != _launch_id:
		return
	if Diagnostics.enabled:
		Diagnostics.trace("bench", "launch: %s check_ms=%d start_ms=%d" % [
			Diagnostics.frame_statistics(_frames_ms, inserted_s), checked_ms, Time.get_ticks_msec() - pressed])
	if not result.ok:
		_show_carousel()
		failed.emit(result.code)
		return
	match _stage:
		Stage.STARTING:
			_enter(Stage.AWAY)
		Stage.STARTING_LEFT:
			_enter(Stage.AWAY_LEFT)
		Stage.STARTING_BACK:
			_show_carousel()


func _enter(stage: Stage) -> void:
	_stage = stage
	_stage_s = 0.0
	set_process(stage != Stage.READY)


## Back to ready before the insertion, the launch failed with [param code]; a late answer is ignored.
func _give_up(code: StringName) -> void:
	_launch_id += 1
	_enter(Stage.READY)
	failed.emit(code)


## Applies the launch at the current time, [param delta] after the previous frame: the game, its
## spindle, the black, the controls, the sounds.
func _insert(delta: float) -> void:
	var t := _clock_s
	var black := 0.0
	var origin := Vector3.ZERO
	if _into_console:
		sequence.launch_at(t, delta)
		black = sequence.black
		origin = sequence.black_origin()
	else:
		var stand := _insertion.stand_at(t, _start)
		var spin := _insertion.spin_at(t)
		# The label blurs over the turn it makes while a frame shows.
		row.stand_selected(stand, spin, minf(TAU, _insertion.spin_speed_at(t) * delta))
		spindle.turn(spin)
		spindle.fade(1.0 - _insertion.spindle_at(t))
		for control in controls:
			control.modulate.a = _insertion.controls_at(t)
		black = _insertion.black_at(t)
		origin = row.to_global(stand.origin)
	var size := blackout.size
	var centre := get_viewport().get_camera_3d().unproject_position(origin)
	# The distance to the farthest corner of the screen.
	var farthest := Vector2(maxf(centre.x, size.x - centre.x), maxf(centre.y, size.y - centre.y)).length()
	_black.set_shader_parameter(&"centre", centre / size)
	_black.set_shader_parameter(&"size", size)
	_black.set_shader_parameter(&"radius", black * farthest)
	var cues := _insertion.sounds
	var seated_s := sequence.seated_s() if _into_console else _insertion.seated_s()
	while _cues_played < cues.size() and t >= seated_s + cues[_cues_played].delay_s:
		var player: AudioStreamPlayer = _players.get(cues[_cues_played])
		if player:
			player.play(cues[_cues_played].from_s)
		_cues_played += 1


## The carousel as it was before the launch, shown again as the black fades.
func _show_carousel() -> void:
	_launch_id += 1
	if _into_console:
		sequence.show_games()
	row.pose_selected()
	spindle.visible = false
	for control in controls:
		control.modulate.a = 1.0
	for player: AudioStreamPlayer in _players.values():
		player.stop()
	_black.set_shader_parameter(&"radius", blackout.size.length() * 2.0)
	_enter(Stage.SHOWING)
