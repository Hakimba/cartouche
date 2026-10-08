# SPDX-License-Identifier: GPL-3.0-or-later
@abstract
class_name PropertiesScreen
extends Control
## What the properties screens share (a game's, [DiscProperties]; a console's,
## [ConsoleProperties]): their model staged under the light of an operating table
## ([OperatingLight]), and each move from one of their screens to another played in three parts:
## what leaves goes, the 3D moves from one staging to the next, then what comes arrives ([Move]).
## No press counts meanwhile, nor while the plugin answers ([member _busy]). Both have a name that
## A opens a keyboard on ([NameEditor]): X erases, Y types a space, Start keeps the name, B leaves it.

## Back on the screen behind, the model in its row again.
signal closed
## The name typed could not be kept.
signal rename_failed

## How what leaves a screen goes: fading, or sliding down as it fades.
enum Leave { FADE, SLIDE }
## How what comes arrives: fading in, or rising as it does.
enum Arrive { FADE, RISE }

## How far, in pixels, what arrives rises and what leaves slides down.
const _RISE := 30.0
const _SLIDE := 40.0
## A name shows whole up to this width, in pixels, cut short beyond.
const _NAME_WIDEST := 1160.0

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first opening.
var light: OperatingLight
## What the screen behind shows over its row: it leaves while the properties show.
var behind: Array[CanvasItem] = []

# Used by the screens of the kind only.
@warning_ignore_start("unused_private_class_variable")
## The moves to a name's keyboard and back from it (or from another screen of the kind), in seconds.
static var _to_naming := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)
static var _from_editing := Move.new(Leave.FADE, 0.15, 0.42, Arrive.FADE, 0.22, 0.26)

@onready var _properties: Control = %Properties
@onready var _callout: FocusCallout = %Callout
@warning_ignore_restore("unused_private_class_variable")

var _staging: Staging
var _busy := false

@onready var _name: Button = %Name
@onready var _naming: NameEditor = %Naming
## What X, Y and Start do on the keyboard.
@onready var _naming_presses: Dictionary[StringName, Callable] = {
	&"open_properties": _naming.erase, &"open_settings": _naming.space, &"form_submit": _keep_name}


func _ready() -> void:
	hide()
	set_process(false)
	_name.pressed.connect(_open_naming)
	_naming.submitted.connect(_keep_name)


## Opens the keyboard of the name.
@abstract func _open_naming() -> void


## Keeps the name typed, asking the plugin.
@abstract func _keep_name() -> void


## Takes X, Y or Start on the keyboard, unless the plugin answers; whether [param event] was one.
func _naming_press(event: InputEvent) -> bool:
	if _busy:
		return false
	for action in _naming_presses:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_naming_presses[action].call()
			return true
	return false


## Asks the plugin to rename with [param request], no press counting meanwhile; when it cannot, the
## focus is back where it was and [signal rename_failed] tells it. Answers the plugin's answer.
func _renaming(request: Callable) -> AndroidServices.Result:
	_busy = true
	var focused := get_viewport().gui_get_focus_owner()
	_release_focus()
	var answer: AndroidServices.Result = await request.call()
	_busy = false
	if not answer.ok:
		Diagnostics.trace("properties", "name not kept (%s): %s" % [answer.code, answer.detail])
		if focused:
			focused.grab_focus()
		rename_failed.emit()
	return answer


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


## Shows [param title] on [param name_button], centred, as wide as it needs up to
## [constant _NAME_WIDEST].
func _show_name(name_button: Button, title: String) -> void:
	name_button.text = title
	var font_size := name_button.get_theme_font_size(&"font_size")
	var text := name_button.get_theme_font(&"font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var margins := name_button.get_theme_stylebox(&"normal").get_minimum_size().x
	var width := minf(text.x + margins + name_button.get_theme_constant(&"outline_size"), _NAME_WIDEST)
	name_button.offset_left = -width / 2.0
	name_button.offset_right = width / 2.0


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
	## of the 1280×960 design).
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
