# SPDX-License-Identifier: GPL-3.0-or-later
@abstract
class_name PropertiesScreen
extends Control
## What the properties screens share (a game's, [DiscProperties]; a console's,
## [ConsoleProperties]): their model staged under the light of an operating table
## ([OperatingLight]), and each move from one of their screens to another played in three parts:
## what leaves goes, the 3D moves from one staging to the next, then what comes arrives ([Move]).
## No press counts while a staging moves or the plugin answers ([member _busy]).

## Back on the screen behind, the model in its row again.
signal closed

## How what leaves a screen goes: fading, or sliding down as it fades.
enum Leave { FADE, SLIDE }
## How what comes arrives: fading in, or rising as it does.
enum Arrive { FADE, RISE }

## How far, in pixels, what arrives rises and what leaves slides down.
const _RISE := 30.0
const _SLIDE := 40.0

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first opening.
var light: OperatingLight
## What the screen behind shows over its row: it leaves while the properties show.
var behind: Array[CanvasItem] = []

var _staging: Staging
var _busy := false

# Used by the derived screens.
@warning_ignore("unused_private_class_variable")
@onready var _properties: Control = %Properties


func _ready() -> void:
	hide()
	set_process(false)


## Puts the model back in its row as [param staging] and [param move] have it, [param leaving] going
## and [param arriving] (what was behind, unless another screen comes) coming back, then closes.
func _put_back(leaving: Array[CanvasItem], arriving: Array[CanvasItem], staging: Staging, move: Move) -> void:
	await _move(leaving, arriving, staging, move)
	set_process(false)
	light.look(Vector2.ZERO, 0.0, 0.0)
	hide()
	closed.emit()


## Moves from one screen to the next as [param move] has it: [param leaving] goes, the 3D moves to
## [param staging], then [param arriving] comes; no focus meanwhile.
func _move(leaving: Array[CanvasItem], arriving: Array[CanvasItem], staging: Staging,
		move: Move) -> void:
	_busy = true
	_release_focus()
	var moves := create_tween().set_parallel()
	for item in leaving:
		moves.tween_property(item, ^"modulate:a", 0.0, move.leave_s)
		if move.leave == Leave.SLIDE and item is Control:
			var down := (item as Control).position.y + _SLIDE
			moves.tween_property(item, ^"position:y", down, move.leave_s)
	moves.tween_method(_stage.bind(_staging, staging), 0.0, 1.0, move.staging_s).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	for item in arriving:
		item.modulate.a = 0.0
		item.show()
		moves.tween_property(item, ^"modulate:a", 1.0, move.arrive_s).set_delay(move.arrive_after_s)
		if move.arrive == Arrive.RISE and item is Control:
			var y := (item as Control).position.y
			moves.tween_property(item, ^"position:y", y, move.arrive_s).from(y + _RISE) \
				.set_delay(move.arrive_after_s)
	await moves.finished
	for item in leaving:
		if item not in arriving:
			item.hide()
			item.modulate.a = 1.0
		if move.leave == Leave.SLIDE and item is Control:
			(item as Control).position.y -= _SLIDE
	_busy = false


## The 3D [param amount] of the way from [param from] to [param to].
func _stage(amount: float, from: Staging, to: Staging) -> void:
	_staging = to if amount >= 1.0 else from.towards(to, amount)
	_place()


## Stands the model as [member _staging] has it.
@abstract func _place() -> void


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


## Where the model stands on a screen, and how the light falls on it.
class Staging:
	## How far the model is out of its row, from 0 (in it) to 1.
	var amount: float
	## The height of the model's centre, in world units, and its size, as a part of its size in
	## the middle of the row.
	var height: float
	var size: float
	## How dark the room is round it, from 0 to 1, and how far its pool of light reaches (in pixels
	## of the 1280×960 layout frame).
	var darkness: float
	var radius: float

	func _init(out_of_row: float, at: float, sized: float, dark: float, reach: float) -> void:
		amount = out_of_row
		height = at
		size = sized
		darkness = dark
		radius = reach

	## The staging [param part] of the way to [param other].
	func towards(other: Staging, part: float) -> Staging:
		return Staging.new(lerpf(amount, other.amount, part), lerpf(height, other.height, part),
			lerpf(size, other.size, part), lerpf(darkness, other.darkness, part),
			lerpf(radius, other.radius, part))


## How a move from one screen to the next plays: what leaves goes in [member leave_s] seconds,
## the 3D moves in [member staging_s] (easing in and out), what comes arrives in [member arrive_s]
## once [member arrive_after_s] have passed; all from the same start.
class Move:
	var leave: Leave
	var leave_s: float
	var staging_s: float
	var arrive: Arrive
	var arrive_s: float
	var arrive_after_s: float

	func _init(how_leaving: Leave, leaving_s: float, moving_s: float, how_arriving: Arrive,
			arriving_s: float, after_s: float) -> void:
		leave = how_leaving
		leave_s = leaving_s
		staging_s = moving_s
		arrive = how_arriving
		arrive_s = arriving_s
		arrive_after_s = after_s
