# SPDX-License-Identifier: GPL-3.0-or-later
class_name SoundEffects
extends Node
## Plays the app's sound effects on the `UI` bus, registered as the `Sounds` autoload: one player per
## [enum Cue], so that a cue played again cuts its previous play rather than piling up. Cues are the
## app's gestures; each plays one sound or none, as [constant CUES] has it (made by `dev/audio/sfx.py`
## from `dev/audio/sounds.json`, the table of every screen's gestures and their sounds). A held
## direction repeats its cue up to 20 times a second: the [constant REPEATED] cues play once per
## [constant REPEAT_GAP_S] at most, each a little higher or lower, so that a fast scroll does not
## rattle.
##
## A screen in the [constant MOVES] group has its focus moves played here: the focus moved by a
## direction plays [constant Cue.MOVE], or the cue the nearest of its parents has as its
## [constant MOVE_SOUND] meta, the focus given by the code nothing: Godot moves the focus
## while it handles the direction, in the frame of the press.

enum Cue {
	MOVE,
	GAME,
	CONSOLE,
	LETTER,
	SELECT,
	BACK,
	OPEN,
	ADD_BALL,
	PROPERTIES,
	SETTINGS,
	TYPE,
	ERASE,
	TOGGLE,
	UNTOGGLE,
	PEEL,
	CARRY,
	PLACE,
	SUCCESS,
	ERROR,
	WELCOME,
	MODEL,
	VOLUME,
	LAUNCH,
	REMOVE,
	RETURN,
	ART_DONE,
	REGIONS,
	LETTERS,
	RING_OPEN,
	RING_CLOSE,
}

const BUS := &"UI"
## The steps of [member level], from silenced to full.
const LEVELS := 10
const CUES := "res://audio/cues.json"
const REPEAT_GAP_S := 0.06
## How far a repeated cue strays from its pitch, either way.
const PITCH_SPREAD := 0.03
const REPEATED: Array[Cue] = [Cue.MOVE, Cue.GAME, Cue.CONSOLE, Cue.LETTER, Cue.CARRY]
## The group of the screens whose focus moves play [constant Cue.MOVE].
const MOVES := &"sound_moves"
## The meta of a control whose focus moves play another cue than [constant Cue.MOVE].
const MOVE_SOUND := &"move_sound"
## How far a search climbs, in semitones, from the whole shelf to one game left.
const NARROWING_SEMITONES := 7.0
## A search's key glides from the last key's height to its own, this long for each semitone between them,
## within these bounds: few keys apart by much glide long and join, many close ones stay short.
const GLIDE_S_PER_SEMITONE := 0.025
const GLIDE_MIN_S := 0.03
const GLIDE_MAX_S := 0.14

const _DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

## The file of the sound of each cue, by cue name, read once.
static var _files: Dictionary = {}

## How loud the sounds play, from 0 (silenced) to [constant LEVELS], on an even scale to the ear.
var level := LEVELS:
	set(steps):
		level = steps
		var bus := AudioServer.get_bus_index(BUS)
		AudioServer.set_bus_mute(bus, steps == 0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(float(maxi(steps, 1)) / LEVELS))
var clock := Callable(Time, &"get_ticks_msec")
var random := RandomNumberGenerator.new()

var _players: Dictionary[Cue, AudioStreamPlayer] = {}
var _played_ms: Dictionary[Cue, int] = {}
var _directed_frame := -1
var _glide: Tween


func _ready() -> void:
	for cue: Cue in Cue.values():
		var player := AudioStreamPlayer.new()
		if path_of(cue):
			player.stream = load(path_of(cue))
		player.bus = BUS
		add_child(player)
		_players[cue] = player
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	if _DIRECTIONS.any(func(action: StringName) -> bool: return event.is_action_pressed(action, true)):
		_directed_frame = Engine.get_process_frames()


## The file of the sound [param cue] plays; empty for a cue kept silent.
static func path_of(cue: Cue) -> String:
	if _files.is_empty():
		_files = JSON.parse_string(FileAccess.get_file_as_string(CUES))
	return str(_files[str(Cue.keys()[cue]).to_lower()])


## Plays [param cue], unless it is silent, or one of the [constant REPEATED] played less than
## [constant REPEAT_GAP_S] ago.
func play(cue: Cue) -> void:
	var player := _players[cue]
	if not player.stream:
		return
	var pitch := 1.0
	if cue in REPEATED:
		var now: int = clock.call()
		if cue in _played_ms and now - _played_ms[cue] < REPEAT_GAP_S * 1000.0:
			return
		_played_ms[cue] = now
		pitch = random.randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)
	player.pitch_scale = pitch
	player.play()
	Diagnostics.trace("sound", str(Cue.keys()[cue]).to_lower())


## Plays [param cue] for a search going from [param before] games found to [param found], of [param total]: its
## note glides from the height of [param before] to that of [param found] (see [method narrowing_pitch]), the
## longer the farther apart.
func play_narrowing(cue: Cue, before: int, found: int, total: int) -> void:
	var player := _players[cue]
	if not player.stream:
		return
	var from := narrowing_pitch(before, total)
	var to := narrowing_pitch(found, total)
	if _glide:
		_glide.kill()
	player.pitch_scale = from
	player.play()
	_glide = create_tween()
	_glide.tween_property(player, ^"pitch_scale", to, glide_s(from, to))
	Diagnostics.trace("sound", "%s %.2f → %.2f" % [str(Cue.keys()[cue]).to_lower(), from, to])


## How long a key glides from pitch [param from] to [param to].
static func glide_s(from: float, to: float) -> float:
	return clampf(GLIDE_S_PER_SEMITONE * absf(12.0 * log(to / from) / log(2.0)), GLIDE_MIN_S, GLIDE_MAX_S)


## The pitch of a search with [param found] games of [param total] left: the share left on a logarithmic scale, the
## whole shelf at 1, one game alone [constant NARROWING_SEMITONES] higher, without steps between.
static func narrowing_pitch(found: int, total: int) -> float:
	var share := 1.0 if found <= 1 or total < 2 else log(float(total) / found) / log(float(total))
	return pow(2.0, NARROWING_SEMITONES * share / 12.0)


func _on_focus_changed(focused: Control) -> void:
	if Engine.get_process_frames() != _directed_frame:
		return
	var node: Node = focused
	while node and not node.is_in_group(MOVES):
		if node.has_meta(MOVE_SOUND):
			var cue: Cue = node.get_meta(MOVE_SOUND)
			play(cue)
			return
		node = node.get_parent()
	if node:
		play(Cue.MOVE)
