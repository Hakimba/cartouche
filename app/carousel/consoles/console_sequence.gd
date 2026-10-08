# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleSequence
extends Node
## Plays the selected console's launch animation ([LaunchAnimation]): into the console
## ([method enter]), back out of it ([method leave]), and a game going into it
## ([method launch_at]). The animation drives the consoles, the games' row, the carousel's controls
## and the properties below; from them, this node puts the chosen disc between the row and the
## console's spindle, spins it, and draws the consoles apart, behind the games, while they blur.
##
## The player only samples the animation, at the times this node or [GameLaunch] give it, so that
## every move follows the time given to [method _process] and tests can step through it.

## [method enter] or [method leave] is over.
signal finished

const _ANIMATION := &"launch"

@export var player: AnimationPlayer
@export var row: ShelfRow
@export var consoles: ConsoleRow
@export var layer: ConsoleLayer

## How far the chosen disc has left the row for the spindle, from 0 to 1; how high it is above the
## spindle along its axis, moved across it (world units), and tilted (radians, about X then Y).
var disc_away := 0.0
var disc_lift := 0.0
var disc_offset := Vector2.ZERO
var disc_tilt := Vector2.ZERO
var disc_turns_per_s := 0.0
## How the consoles show behind the games: blurred over this many pixels of a 1280 pixel wide
## screen, at this opacity, their colours at this saturation.
var blur := 0.0
var layer_opacity := 1.0
var saturation := 1.0
## How much of the screen the black covers, from 0 to 1 (see [GameLaunch]).
var black := 0.0
## How much of the consoles behind the games shows, from 0 (none) to 1 (as the animation has them):
## the carousel takes them away once on the games screen, back for a launch or to go out.
var behind_amount := 1.0:
	set(amount):
		behind_amount = amount
		# Playing, the next frame shows it.
		if not is_processing():
			_look_behind(consoles.behind)

var _animation := Animation.new()
var _at_s := 0.0
var _to_s := 0.0
## Where the animation settles once there: its start, when it goes back out.
var _settle_s := 0.0
var _spin := 0.0
## The label's blur while it spins: the turn it makes during one frame.
var _spin_blur := 0.0
## Where the chosen disc stood in the row as it left it, while it is out.
var _left_from := Transform3D.IDENTITY
var _out := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_seek(move_toward(_at_s, _to_s, delta))
	# Exactly there, as moving towards it ends.
	if _at_s == _to_s:
		set_process(false)
		_seek(_settle_s)
		finished.emit()


## Plays [param animation] from now on, from its start; never while going in or out.
func use(animation: Animation) -> void:
	assert(not is_processing(), "ConsoleSequence: another animation while going in or out")
	_animation = animation
	var library := AnimationLibrary.new()
	library.add_animation(_ANIMATION, animation)
	if player.has_animation_library(&""):
		player.remove_animation_library(&"")
	player.add_animation_library(&"", library)
	player.assigned_animation = _ANIMATION
	# The consoles screen, still.
	set_process(false)
	_seek(0.0)


## The games screen, still.
func show_games() -> void:
	set_process(false)
	_seek(_moment(&"games"))


## Into the console, from the consoles screen to the games screen; [signal finished] once there.
func enter() -> void:
	_play(_moment(&"consoles"), _moment(&"games"), _moment(&"games"))


## Back out, from the games screen to the consoles screen; [signal finished] once there: as soon as
## the consoles stand as they rest, before the first step's hold.
func leave() -> void:
	_play(_moment(&"games"), _moment(&"consoles"), 0.0)


## Whether a game goes into the console, rather than by its medium's [Insertion].
func can_launch() -> bool:
	return _animation.length > _moment(&"launch") + 0.001


## How long a game takes from the games screen to the whole screen black.
func launch_duration() -> float:
	return _moment(&"black", _animation.length) - _moment(&"launch")


## When the disc reaches the spindle, from the start of the launch.
func seated_s() -> float:
	return _moment(&"seated", _animation.length) - _moment(&"launch")


## The launch [param time] seconds in, [param delta] after the previous frame of it.
func launch_at(time: float, delta: float) -> void:
	_spin += disc_turns_per_s * TAU * delta
	_spin_blur = minf(TAU, disc_turns_per_s * TAU * delta)
	_seek(_moment(&"launch") + time)


## Where the black starts from: the selected console's spindle, else the row.
func black_origin() -> Vector3:
	var console := consoles.selected().model
	if console is ConsoleModel:
		var model: ConsoleModel = console
		return model.seat().origin
	return row.global_position


func _play(from_s: float, to_s: float, settle_s: float) -> void:
	_seek(from_s)
	_to_s = to_s
	_settle_s = settle_s
	set_process(true)


func _moment(named: StringName, otherwise := 0.0) -> float:
	return LaunchAnimation.moment(_animation, named, otherwise)


func _seek(time: float) -> void:
	_at_s = time
	player.seek(time, true)
	var behind := blur > 0.3 or layer_opacity < 0.97 or saturation < 0.97
	if behind != consoles.behind:
		consoles.show_in_layers(ConsoleLayer.BEHIND if behind else ConsoleLayer.FRONT)
	_look_behind(behind)
	layer.draw_again()
	consoles.arrange()
	_place_disc()


## The consoles drawn behind the games when [param behind], as the animation and
## [member behind_amount] have them; not at all once gone.
func _look_behind(behind: bool) -> void:
	var opacity := layer_opacity * behind_amount
	layer.look(behind and opacity > 0.001, blur, opacity, saturation)


## The chosen disc, out of the row, between where it stood and the console's spindle; back in the
## row once it is not out any more.
func _place_disc() -> void:
	var console := consoles.selected().model
	if disc_away <= 0.0 or console is not ConsoleModel:
		if _out:
			_out = false
			_spin = 0.0
			_spin_blur = 0.0
			row.pose_selected()
			if console is ConsoleModel:
				var emptied: ConsoleModel = console
				emptied.spindle.turn(0.0)
		return
	if not _out:
		_out = true
		_left_from = row.selected_stand()
	var into: ConsoleModel = console
	var tilt := Basis(Vector3.RIGHT, disc_tilt.x) * Basis(Vector3.UP, disc_tilt.y)
	var above := Transform3D(tilt, Vector3(disc_offset.x, disc_offset.y, disc_lift))
	var on_spindle := row.global_transform.affine_inverse() * into.seat() * above
	row.stand_selected(_left_from.interpolate_with(on_spindle, disc_away), _spin, _spin_blur)
	into.spindle.turn(_spin if disc_away >= 1.0 else 0.0)
