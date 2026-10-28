# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleOrder
extends Control
## The screen putting the consoles in order. They leave the rail for an ellipse where all of them show
## ([RingFit]: each at its real size, none touching another), the ring having no end ([ConsoleWheel]). A cursor,
## a small arrow outside the pointed console, jumps from one console to the next with left and right, its logo
## in the middle. A takes that console: it peels off like a sticker ([ConsoleSticker]: a white border, a shadow,
## leaning a little) and goes with the cursor, taking at once the place of each console it passes, which slides
## into its own; the middle tells where it would go, in logos. A then puts it down, the order kept from then on;
## B lets go of it, the order as it was. B closes the ring, the consoles screen back on the console the cursor is
## on. By touch, dragging sideways moves the cursor, tapping a console takes it, and a tap puts it down. A
## platform without a model has no place on the ring and keeps its place in the order.
## The same ring places a console just added ([method place], [Placing]): it comes to the middle, an arrow moves between
## two consoles of the others, A flies it into that gap and the consoles screen opens on it, B flies it back.

## The ring starts closing: the consoles screen comes back as it does.
signal closing(duration: float)
## The ring is closed, the consoles back in their row.
signal closed
## The consoles are in [param order] (platform ids) from now on.
signal ordered(order: Array[String])
## The order could not be kept: it is back to what it was.
signal order_failed
## The console placed flies back: the form it came from is wanted back.
signal form_wanted
## The placing is over: placed (true), or given up for the form (false).
signal placing_over(placed: bool)

## The ring opens in this time, the console pointed at gliding from the hero's place; the others come from the
## rail a little after, in their own time; the arrow, the middle and the hints follow, each from its
## moment, in its time (seconds).
static var _OPEN_S: float:
	get: return StudioTokens.TR_RING_OPEN_S
static var _RISE_AFTER_S: float:
	get: return StudioTokens.TR_RING_RISE_AT_S
static var _RISE_S: float:
	get: return StudioTokens.TR_RING_RISE_S
static var _MARKS_AFTER_S: float:
	get: return StudioTokens.TR_RING_MARKS_AT_S
static var _MARKS_S: float:
	get: return StudioTokens.TR_RING_MARKS_S
static var _MIDDLE_AFTER_S: float:
	get: return StudioTokens.TR_RING_MIDDLE_AT_S
static var _MIDDLE_S: float:
	get: return StudioTokens.TR_RING_MIDDLE_S
const _HINTS_AFTER_S := 0.25
const _HINTS_S := 0.15
## It closes in this time, the others sinking towards the rail in theirs, the rest fading in theirs.
static var _CLOSE_S: float:
	get: return StudioTokens.TR_RING_CLOSE_S
const _SINK_S := 0.372
const _MARKS_OUT_S := 0.186
const _HINTS_OUT_S := 0.15
## The middle's top (px) and how far lower it starts when it comes in.
const _MIDDLE_Y := 419.2
const _MIDDLE_RISE_PX := 12.8
## Placing a console, the ring comes in as the form goes: the others one after another from this moment, each in this
## time (seconds), the arrow and the hints in theirs, the middle after it all.
const _COMING_AFTER_S := 0.06
const _COMING_EACH_S := 0.018
const _COMING_S := 0.3
const _PLACE_IN_S := 0.32
const _PLACE_MIDDLE_AFTER_S := 0.252
## Flying into the gap, the middle goes in this time; flying back the others go in the first, the marks in the second,
## the ring as a whole after this long in the third, and the form comes back as the ring leaves.
const _MIDDLE_OUT_S := 0.16
static var _OTHERS_OUT_S: float:
	get: return StudioTokens.TR_PLACE_OTHERS_S
static var _BACK_MARKS_S: float:
	get: return StudioTokens.TR_PLACE_MARKS_S
static var _BACK_FADE_AFTER_S: float:
	get: return StudioTokens.TR_PLACE_AT_S
const _BACK_FADE_S := 0.32
## A console peels off, and is put back down, in these times, springing a little.
const _PEEL_S := 0.24
const _PUT_DOWN_S := 0.26
## By touch: the cursor moves one console for each stretch this long dragged; a tap takes the
## console whose box is nearest it, this far from the box at most (in pixels of the design's frame).
const _DRAG_STEP := 160.0
const _TAP_REACH := 110.0
## The arrow stands this far (px) beyond the pointed console's box, further while it is held; a unit of its
## drawing in px (it is 28 × 36 units), its shadow's offset, the glow's centre and radii, and its colours.
const _ARROW_OUT_PX := 14.08
const _ARROW_HELD_PX := 20.48
const _ARROW_UNIT := 1.28
## How far the white edge reaches past the ink (the design's stroke of 3 units, half of it showing).
const _ARROW_EDGE_PX := 1.5 * _ARROW_UNIT
const _ARROW_SHADOW := Vector2(0.0, 3.2)
## The gel glow round the arrow (the design's drop-shadow of 0.9 cqw at 55 %): its layers' alphas, from the nearest
## to the farthest, each reaching 2 px further out than the one before; a Gaussian's edge laid in steps.
const _GLOW_ALPHAS: Array[float] = [0.0856, 0.0668, 0.0472, 0.0302, 0.0173, 0.0089, 0.0041, 0.0025]
const _GLOW_STEP_PX := 2.0
const _ARROW_STROKE := Color("#fffdf9")
const _ARROW_SHINE := Color(1.0, 1.0, 1.0, 0.22)
const _ARROW_DROP := Color(60.0 / 255.0, 40.0 / 255.0, 20.0 / 255.0, 0.35)

static var _sentence_slots := RegEx.create_from_string("\\{(before|after|name)\\}")

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first [method open].
var consoles: ConsoleRow

var _wheel: ConsoleWheel
## The platform ids in the order of the row: where each console of the row stands on the ring.
var _row: Array[String] = []
var _open := false
## No press counts while the ring comes or goes, nor while the plugin keeps an order.
var _busy := false
var _transition: Tween
var _opening_s := 0.0:
	set(value):
		_opening_s = value
		_place_opening()
var _peeling: Tween
var _finger := Finger.new()
## How many steps the finger's drag has made.
var _drag_steps := 0
## Where the arrow stands round the ring and how far beyond the console, and where it is going.
var _arrow_angle := 0.0
var _arrow_out := 0.0
var _arrow_to := 0.0
var _arrow_out_to := 0.0
## The gel of the console pointed at, which the arrow's glow takes.
var _rim := Color.WHITE
## How far the middle has risen, from 0 (gone, lower) to 1; how opaque the arrow is.
var _middle_in := 0.0:
	set(value):
		_middle_in = value
		_place_middle()
var _marks := 0.0:
	set(value):
		_marks = value
		_tint_marks()
## Where the middle's top stands (px): the ordering ring's, or under the console placed.
var _middle_y := _MIDDLE_Y
## Placing a console: the flow, the id of the console placed, the angle each console of the ring stands at and
## goes to, how long the ring has been coming in, how much the others are still there, how far the console's move has
## gone (0 to 1) and its bounce, where it started the move, and the move that waits for a press.
var _placing: Placing
var _placed_id := ""
var _angle: Dictionary[String, float] = {}
var _angle_to: Dictionary[String, float] = {}
var _coming := 0.0
var _others_in := 1.0
var _move := 0.0
var _bounce := 0.0
var _from := ConsoleRow.Stand.new()
var _arriving: Tween
var _tweens: Array[Tween] = []
@onready var _sticker: ConsoleSticker = %Sticker
@onready var _frame: Control = %Frame
@onready var _arrow: Control = %Arrow
@onready var _middle: Control = %Middle
@onready var _logo: LogoView = %Logo
@onready var _where: Control = %Where
@onready var _before: LogoView = %Before
@onready var _after: LogoView = %After
@onready var _choosing: Control = %Choosing
@onready var _moving: Control = %Moving


func _ready() -> void:
	hide()
	set_process(false)
	# Before the consoles, which stand where the placing says this frame.
	process_priority = -1
	_arrow.draw.connect(_draw_arrow)


func _process(delta: float) -> void:
	var follow := 1.0 - exp(-RingFit.FOLLOW * minf(delta, Motion.MAX_STEP_S))
	var gap := wrapf(_arrow_to - _arrow_angle, -PI, PI)
	_arrow_angle = _arrow_to if absf(gap) < 1e-4 else _arrow_angle + gap * follow
	_arrow_out = _arrow_out_to if absf(_arrow_out_to - _arrow_out) < 1e-4 else lerpf(_arrow_out, _arrow_out_to, follow)
	if _placing:
		_follow_placing(follow)
	_place_marks()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	var direction := int(event.is_action_pressed(&"carousel_right")) - int(event.is_action_pressed(&"carousel_left"))
	var accept := event.is_action_pressed(&"ui_accept")
	if not direction and not accept and not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _placing:
		_press_placing(direction, accept)
		return
	if _busy:
		if _transition and event.is_action_pressed(&"screen_back") and StudioTokens.TR_REVERSE:
			_close()
		return
	if direction:
		_step(direction)
	elif accept and _wheel.is_holding():
		_put_down()
	elif accept:
		_take()
	elif _wheel.is_holding():
		_let_go()
	else:
		_close()


## The first finger: a drag steps the cursor round, a tap takes or puts down; a drag made while
## the ring is busy moves nothing, even once it no longer is. Taken before the controls over the
## ring (the top bar, the hints), which would keep the touches on them.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	var was_down := _finger.is_down
	var now: int = clock.call()
	var gesture := _finger.read(event, now)
	if _finger.is_down and not was_down:
		_drag_steps = 0
	if gesture == Finger.Gesture.TAP and not _busy and not _placing:
		_tap(_finger.at)
	elif gesture == Finger.Gesture.DRAG:
		var steps := int((_finger.at.x - _finger.start.x) / _DRAG_STEP)
		while _drag_steps != steps:
			var direction := signi(steps - _drag_steps)
			if not _busy and not _placing:
				_step(direction)
			_drag_steps += direction


## Whether the ring shows, or is coming or going.
func is_open() -> bool:
	return _open or _busy


## Opens the ring on the consoles of [param platform_ids] (those of the row, in its order) that have a model, the
## cursor on the one at [param at], or on the first when that one has none.
func open(platform_ids: Array[String], at: int) -> void:
	_row = platform_ids.duplicate()
	var ringed := _ring_ids(_row)
	if ringed.is_empty():
		closed.emit()
		return
	_wheel = ConsoleWheel.new(ringed, maxi(ringed.find(_row[at]), 0))
	_open = true
	_finger = Finger.new()
	_sticker.consoles = consoles
	_sticker.watch(true)
	_show()
	consoles.snap_ring()
	_arrow_angle = _arrow_to
	_arrow_out = _arrow_out_to
	consoles.ring_scale = consoles.ring_target
	_hints().modulate.a = 0.0
	_marks = 0.0
	_middle_in = 0.0
	show()
	set_process(true)
	Diagnostics.trace("order", "ring open on %s" % _wheel.selected())
	_busy = true
	var opening := _tween_in()
	_transition = opening
	await opening.finished
	if _transition == opening:
		_transition = null
		_busy = false


## The consoles of [param platform_ids] that have a model: the ones the ring holds.
func _ring_ids(platform_ids: Array[String]) -> Array[String]:
	var ringed: Array[String] = []
	for k in platform_ids.size():
		if consoles.console_at(k).modelled:
			ringed.append(platform_ids[k])
	return ringed


func _close() -> void:
	var rewind := _transition != null
	if _transition:
		var interrupted := _transition
		_transition = null
		interrupted.kill()
		interrupted.finished.emit()
	_open = false
	_busy = true
	Diagnostics.trace("order", "ring closed on %s" % _wheel.selected())
	# The row comes back round the console the cursor was on.
	consoles.select(_row.find(_wheel.selected()))
	var duration := maxf(_opening_s, 0.001) if rewind else _CLOSE_S
	closing.emit(duration)
	var leaving := create_tween() if rewind else _tween_out()
	if rewind:
		leaving.tween_property(self, ^"_opening_s", 0.0, duration)
	await leaving.finished
	consoles.pointed = -1
	consoles.held = -1
	_sticker.watch(false)
	set_process(false)
	hide()
	_busy = false
	closed.emit()


## What the ring plays opening: the console pointed at glides from the hero's place, the others rise from the rail,
## the arrow, the middle and the hints come in after them.
func _tween_in() -> Tween:
	var moves := create_tween()
	_opening_s = 0.0
	moves.tween_property(self, ^"_opening_s", _opening_length(), _opening_length())
	return moves


func _opening_length() -> float:
	return [ _OPEN_S, _RISE_AFTER_S + _RISE_S, _MARKS_AFTER_S + _MARKS_S,
		_MIDDLE_AFTER_S + _MIDDLE_S, _HINTS_AFTER_S + _HINTS_S ].max()


func _place_opening() -> void:
	consoles.wheel = Motion.phase(_opening_s, 0.0, _OPEN_S, StudioTokens.TR_RING_OPEN_S_CURVE)
	consoles.others_wheel = Motion.phase(_opening_s, _RISE_AFTER_S, _RISE_S, StudioTokens.TR_RING_RISE_S_CURVE)
	_marks = Motion.phase(_opening_s, _MARKS_AFTER_S, _MARKS_S)
	_middle_in = Motion.phase(_opening_s, _MIDDLE_AFTER_S, _MIDDLE_S, StudioTokens.TR_RING_MIDDLE_S_CURVE)
	_hints().modulate.a = Motion.phase(_opening_s, _HINTS_AFTER_S, _HINTS_S)


## What it plays closing: the console pointed at glides back to the hero’s place, the others sink towards the
## rail, the arrow, the middle and the hints leave.
func _tween_out() -> Tween:
	var moves := create_tween().set_parallel()
	moves.tween_property(consoles, ^"wheel", 0.0, _CLOSE_S).set_custom_interpolator(Motion.curve(StudioTokens.TR_RING_CLOSE_S_CURVE))
	moves.tween_property(consoles, ^"others_wheel", 0.0, _SINK_S).set_custom_interpolator(Motion.curve(Motion.Easing.SINK))
	moves.tween_property(self, ^"_marks", 0.0, _MARKS_OUT_S)
	moves.tween_property(self, ^"_middle_in", 0.0, _HINTS_OUT_S)
	moves.tween_property(_hints(), ^"modulate:a", 0.0, _HINTS_OUT_S)
	return moves


## The consoles of [param platform_ids] on the ring a console of [param platform_id] would be placed among: those of the
## others that have a model, in their order.
func ring_of(platform_ids: Array[String], platform_id: String) -> Array[String]:
	var others: Array[String] = []
	others.assign(_ring_ids(platform_ids).filter(func(other: String) -> bool: return other != platform_id))
	return others


## Places the console [param platform_id], just added to the row of [param platform_ids] (the platforms shown, in
## their order), on the ring of the others: it comes to the middle, ← → move the arrow between two of them, A flies it
## there and the consoles screen opens on it (true), B flies it back (false, [signal form_wanted] as it goes).
## Returns at once, true, when no other console has a model to stand beside.
func place(platform_ids: Array[String], platform_id: String) -> bool:
	var ring := ring_of(platform_ids, platform_id)
	if ring.is_empty():
		return true
	_row = platform_ids.duplicate()
	_placed_id = platform_id
	_placing = Placing.new(ring)
	_wheel = ConsoleWheel.new(ring, 0)
	_open = true
	_busy = false
	_finger = Finger.new()
	_sticker.consoles = consoles
	_rim = StudioTokens.GEL.get(StringName(_folder_of(platform_id)), StudioTokens.NEUTRAL)
	consoles.wheel_slots = _ring_slots()
	consoles.pointed = -1
	consoles.held = -1
	consoles.flier = _row.find(platform_id)
	consoles.wheel = 1.0
	consoles.others_wheel = 1.0
	_others_in = 1.0
	_coming = 0.0
	_middle_y = _MIDDLE_Y
	_angle.clear()
	_angle_to.clear()
	var opened := Placing.angles(ring.size(), _placing.gap)
	for k in ring.size():
		_angle[ring[k]] = opened[k]
		_angle_to[ring[k]] = opened[k]
	_angle[platform_id] = 0.0
	_angle_to[platform_id] = 0.0
	_aim_placing()
	consoles.ring_scale = consoles.ring_target
	_arrow_angle = _arrow_to
	_arrow_out = _arrow_out_to
	_from = _plinth_stand()
	_move = 0.0
	_marks = 0.0
	_middle_in = 0.0
	_choosing.hide()
	_moving.show()
	_moving.modulate.a = 0.0
	_fit_view()
	_write_ring()
	show()
	set_process(true)
	_placing.start()
	Diagnostics.trace("order", "placing %s among %d" % [platform_id, ring.size()])
	_play_arrival()
	return await placing_over


## Each console of the row's place on the ring while a console is placed: the others with a model and the one placed
## have one, the rest none.
func _ring_slots() -> Array[int]:
	var slots: Array[int] = []
	for id in _row:
		slots.append(maxi(_placing.others.find(id), 0) if id in _placing.others or id == _placed_id else -1)
	return slots


## A tween of the placing, let go with it.
func _tween() -> Tween:
	var made := create_tween()
	_tweens.append(made)
	return made


func _exit_tree() -> void:
	_kill_tweens()
	if _placing:
		placing_over.emit(false)


func _kill_tweens() -> void:
	for made in _tweens:
		made.kill()
	_tweens.clear()


## What the ring plays as the form goes: the console flies from the plinth to the middle, the others come onto
## the ring one after another, the arrow and the hints fade in, then the middle.
func _play_arrival() -> void:
	var motion := _tween().set_parallel()
	motion.tween_property(self, ^"_coming", 1.0, 1.0).from(0.0)
	var in_out := Motion.curve(Motion.Easing.EASE_OUT)
	motion.tween_property(self, ^"_marks", 1.0, _PLACE_IN_S).from(0.0).set_custom_interpolator(in_out)
	motion.tween_property(_moving, ^"modulate:a", 1.0, _PLACE_IN_S).from(0.0).set_custom_interpolator(in_out)
	motion.tween_property(self, ^"_middle_in", 1.0, _MIDDLE_S).from(0.0).set_delay(_PLACE_MIDDLE_AFTER_S) \
		.set_custom_interpolator(in_out)
	_arriving = _tween()
	_arriving.tween_property(self, ^"_move", 1.0, StudioTokens.ARRIVE_S).from(0.0)
	_arriving.tween_callback(_placing.done)


## A press while a console is placed: what its state makes of it.
func _press_placing(direction: int, accept: bool) -> void:
	var pressed := Placing.Press.A if accept else Placing.Press.B
	if direction:
		pressed = Placing.Press.RIGHT if direction > 0 else Placing.Press.LEFT
	# Where the console stands now, before the press changes what the state makes of it.
	var stood := _flier_stand()
	match _placing.press(pressed):
		Placing.Action.MOVE:
			_aim_placing()
		Placing.Action.FLY:
			_fly_in(stood)
		Placing.Action.LEAVE:
			_fly_back(stood)


## Where every console of the ring, the arrow and the middle go for the gap chosen: the others on the ring with that
## gap open, the scale fitted again, the arrow in the middle of the gap.
func _aim_placing() -> void:
	var ring := _placing.others
	var angles := Placing.angles(ring.size(), _placing.gap)
	for k in ring.size():
		_angle_to[ring[k]] = angles[k]
	_fit_placing(ring, angles)
	var before := ring[_placing.gap]
	var after := ring[(_placing.gap + 1) % ring.size()]
	_arrow_to = Placing.arrow_angle(ring.size(), _placing.gap)
	_arrow_out_to = (_reach_of(before, angles[_placing.gap]) + _reach_of(after, angles[(_placing.gap + 1) % ring.size()])) \
		/ 2.0 + _ARROW_OUT_PX
	_tint_marks()
	_arrow.queue_redraw()
	var folder := _folder_of(_placed_id)
	_logo.show_logo(LogoView.Slot.RING_MIDDLE, folder)
	var alone := ring.size() == 1
	_sentence(tr("next to {name}", "ring") if alone else tr("between {before} and {after}", "ring"),
		_folder_of(before), _folder_of(after))
	_middle_y = Placing.MIDDLE.y + _middle_height() / 2.0 + Placing.TEXT_GAP
	_place_middle()


## How tall the console placed stands in the middle, in px.
func _middle_height() -> float:
	var width := RingFit.width(RingFit.weight_of(_folder_of(_placed_id)), consoles.ring_target, 0.0) * Placing.MIDDLE_GROWTH
	return width * 0.75 * consoles.silhouette(_row.find(_placed_id)).size.y * RingFit.CQW


## The scale the [param ids] stand on at [param angles].
func _fit_placing(ids: Array[String], angles: PackedFloat64Array) -> void:
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	for id in ids:
		boxes.append(consoles.silhouette(_row.find(id)))
		weights.append(RingFit.weight_of(_folder_of(id)))
	consoles.ring_target = RingFit.scale(boxes, weights, angles, RingFit.WIDEST / RingFit.PS2_BOX.size.x)
	Diagnostics.trace("order", "placing fit scale=%.2f gap=%d" % [consoles.ring_target, _placing.gap])


## How far (px) from console [param id]'s place at [param angle] its box reaches along the radial.
func _reach_of(id: String, angle: float) -> float:
	return RingFit.ext(consoles.silhouette(_row.find(id)), RingFit.weight_of(_folder_of(id)), consoles.ring_target, angle)


func _folder_of(platform_id: String) -> String:
	return consoles.console_at(_row.find(platform_id)).folder


## The console on its way from the plinth: standing there as big as the form's model.
func _plinth_stand() -> ConsoleRow.Stand:
	var stand := ConsoleRow.Stand.new()
	stand.centre = Placing.PLINTH
	stand.size = Placing.PLINTH_WIDTH / (CarouselLayout.FRAME.x / RingFit.CQW)
	return stand


## The console placed standing at [param angle] of the ring, [param growth] times its size there, its silhouette's
## centre at [param centre].
func _stand_of_placed(centre: Vector2, angle: float, growth: float) -> ConsoleRow.Stand:
	var stand := ConsoleRow.Stand.new()
	stand.centre = centre
	stand.size = RingFit.width(RingFit.weight_of(_folder_of(_placed_id)), consoles.ring_scale, angle) * growth \
		/ (CarouselLayout.FRAME.x / RingFit.CQW)
	return stand


## The ring's angles and arrivals, and the console placed, written where the consoles read them.
func _write_ring() -> void:
	var angles := PackedFloat64Array()
	var arrivals := PackedFloat64Array()
	for k in _row.size():
		angles.append(_angle[_row[k]] if _row[k] in _angle else 0.0)
		var after := _COMING_AFTER_S + _COMING_EACH_S * k
		arrivals.append(_others_in * Motion.eased(Motion.Easing.APPEAR, clampf((_coming - after) / _COMING_S, 0.0, 1.0)))
	consoles.ring_angles = angles
	consoles.ring_arrival = arrivals
	if consoles.flier >= 0:
		consoles.flier_stand = _flier_stand()


## Every console of the ring follows its angle, as the arrow does.
func _follow_placing(follow: float) -> void:
	for id in _angle:
		var gap := wrapf(_angle_to[id] - _angle[id], -PI, PI)
		_angle[id] = _angle_to[id] if absf(gap) < 1e-4 else _angle[id] + gap * follow
	_write_ring()


## Where the console placed stands this frame for the state the flow is in.
func _flier_stand() -> ConsoleRow.Stand:
	var angle := _angle_to[_placed_id]
	var landed := _stand_of_placed(RingFit.place(angle), angle, 1.0)
	var to := _stand_of_placed(Placing.MIDDLE, 0.0, Placing.MIDDLE_GROWTH)
	var easing := Motion.Easing.IN_OUT
	var lift := Placing.ARRIVE_LIFT
	match _placing.state:
		Placing.State.ARRIVING, Placing.State.CHOOSING:
			easing = Motion.Easing.OUT_BACK
		Placing.State.FLYING:
			to = landed
			lift = Placing.FLY_LIFT
		Placing.State.LANDING:
			landed.size *= Placing.bounce(_bounce)
			return landed
		Placing.State.BACK:
			to = _plinth_stand()
	var stand := ConsoleRow.Stand.new()
	stand.centre = Placing.flight(_from.centre, to.centre, _move, lift)
	stand.size = lerpf(_from.size, to.size, Motion.eased(easing, _move))
	return stand


## A: the console flies from where it is into the gap, bounces, rests a moment, then the consoles screen opens on it.
func _fly_in(stood: ConsoleRow.Stand) -> void:
	_arriving.kill()
	_from = stood
	var ring := _placing.others
	var shown: Array[String] = []
	shown.assign(_row.filter(func(id: String) -> bool: return id != _placed_id))
	var gap := _placing.shown_gap(shown)
	Diagnostics.trace("order", "placing gap=%d" % gap)
	var landed := Placing.landed(ring.size(), _placing.gap)
	var slot := 0
	var ids: Array[String] = []
	for k in landed.size():
		var id := _placed_id if k == _placing.gap + 1 else ring[slot]
		slot += int(id != _placed_id)
		_angle_to[id] = landed[k]
		ids.append(id)
	_fit_placing(ids, landed)
	_arrow_to = _angle_to[_placed_id]
	_move = 0.0
	_bounce = 0.0
	var flight := _tween()
	flight.tween_property(self, ^"_move", 1.0, StudioTokens.FLY_S)
	flight.tween_callback(_placing.done)
	flight.tween_property(self, ^"_bounce", 1.0, StudioTokens.BOUNCE_S)
	flight.tween_callback(_landed.bind(gap))
	var out := _tween()
	out.tween_property(self, ^"_middle_in", 0.0, _MIDDLE_OUT_S)


## The console is in its gap: the order is saved with it, then, after the pause, the morph onto the consoles screen.
func _landed(gap: int) -> void:
	var pause := get_tree().create_timer(StudioTokens.PAUSE_S)
	var answer := await android.place_console(_placed_id, gap)
	if not answer.ok:
		# The ring stays as it was: the console flies back to the form, as on B.
		Diagnostics.trace("order", "not placed (%s): %s" % [answer.code, answer.detail])
		var stood := _flier_stand()
		_placing.refuse()
		_fly_back(stood)
		return
	Diagnostics.trace("order", "placed %s at %d" % [_placed_id, gap])
	var order: Array[String] = []
	order.assign(Array(answer.order))
	ordered.emit(order)
	_row = order
	# The consoles are in their new order: the console placed and the places on the ring follow it.
	consoles.flier = _row.find(_placed_id)
	consoles.wheel_slots = _ring_slots()
	if pause.time_left > 0.0:
		await pause.timeout
	_placing.done()
	_morph()


## The consoles screen comes: the console placed glides to the hero's place as the ring does closing, the others sink
## into the rail, the rail and the consoles screen's parts come in.
func _morph() -> void:
	consoles.wheel_slots = _ring_slots()
	consoles.flier = -1
	consoles.pointed = _row.find(_placed_id)
	_write_ring()
	closing.emit(_CLOSE_S)
	await _tween_out().finished
	_placing.done()
	_end_placing(true)


## B: the console flies back to the plinth, the ring goes, the form is wanted back.
func _fly_back(stood: ConsoleRow.Stand) -> void:
	_arriving.kill()
	_from = stood
	_move = 0.0
	var motion := _tween().set_parallel()
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(self, ^"_move", 1.0, Placing.BACK_S)
	motion.tween_property(self, ^"_others_in", 0.0, _OTHERS_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(self, ^"_marks", 0.0, _BACK_MARKS_S)
	motion.tween_property(self, ^"_middle_in", 0.0, _BACK_MARKS_S)
	motion.tween_property(_moving, ^"modulate:a", 0.0, _BACK_FADE_S).set_delay(_BACK_FADE_AFTER_S).set_custom_interpolator(ease_in)
	get_tree().create_timer(_BACK_FADE_AFTER_S).timeout.connect(form_wanted.emit)
	await motion.finished
	_placing.done()
	_end_placing(false)


## The placing is over: the ring is let go, whichever way it ended.
func _end_placing(placed: bool) -> void:
	consoles.pointed = -1
	consoles.flier = -1
	consoles.ring_angles = PackedFloat64Array()
	consoles.ring_arrival = PackedFloat64Array()
	if not placed:
		consoles.wheel = 0.0
		consoles.others_wheel = 0.0
	_kill_tweens()
	_middle_y = _MIDDLE_Y
	set_process(false)
	hide()
	_open = false
	_placing = null
	placing_over.emit(placed)


## The hint row the buttons show now.
func _hints() -> Control:
	return _moving if _placing or _wheel.is_holding() else _choosing


## One step round the ring towards [param direction] (-1 or 1), the console held with the cursor.
func _step(direction: int) -> void:
	_wheel.step(direction)
	_show()


func _take() -> void:
	_wheel.take()
	Diagnostics.trace("order", "took %s" % _wheel.selected())
	_peel(1.0, _PEEL_S)
	_show()


## Puts the console held down where it is; when that changes the order, keeps it, or goes back to
## the order before when it cannot be kept.
func _put_down() -> void:
	var moved := _wheel.put_down()
	Diagnostics.trace("order", "put %s down, %s" % [_wheel.selected(), "moved" if moved else "in its place"])
	_peel(0.0, _PUT_DOWN_S)
	_show()
	if not moved:
		return
	_busy = true
	var order := _with_unmodelled(_wheel.order)
	var answer := await android.order_consoles(PackedStringArray(order))
	_busy = false
	if answer.ok:
		ordered.emit(order)
		_row = order
	else:
		Diagnostics.trace("order", "order not kept (%s): %s" % [answer.code, answer.detail])
		var ringed := _ring_ids(_row)
		_wheel = ConsoleWheel.new(ringed, ringed.find(_wheel.selected()))
		order_failed.emit()
	_show()


## The row's order with [param ringed] (a permutation of the consoles the ring holds) in the places they take, and
## every console without a model where it was.
func _with_unmodelled(ringed: Array[String]) -> Array[String]:
	var order: Array[String] = []
	var next := 0
	for platform_id in _row:
		if platform_id in ringed:
			order.append(ringed[next])
			next += 1
		else:
			order.append(platform_id)
	return order


func _let_go() -> void:
	_wheel.let_go()
	Diagnostics.trace("order", "let go of %s, the order as it was" % _wheel.selected())
	_peel(0.0, _PUT_DOWN_S)
	_show()


## A tap puts the console held down, or takes the one nearest it.
func _tap(at: Vector2) -> void:
	if _wheel.is_holding():
		_put_down()
		return
	var nearest := -1
	var reach := _TAP_REACH * consoles.view_scale()
	for slot in _wheel.order.size():
		var distance := _distance_to_box(_row.find(_wheel.order[slot]), at)
		if distance < reach:
			nearest = slot
			reach = distance
	if nearest >= 0:
		_wheel.point(nearest)
		_take()


## How far [param at] (px of the viewport) is from the box of the console at [param index] of the row: 0 inside it.
func _distance_to_box(index: int, at: Vector2) -> float:
	var stand := consoles.ring_stand(index)
	var half := consoles.silhouette(index).size * CarouselLayout.FRAME * stand.size * consoles.view_scale() / 2.0
	var away := (at - consoles.to_view(stand.centre)).abs() - half
	return Vector2(maxf(away.x, 0.0), maxf(away.y, 0.0)).length()


## The console held peels off to [param amount] (0, down) in [param seconds], springing a little.
func _peel(amount: float, seconds: float) -> void:
	if _peeling:
		_peeling.kill()
	_peeling = create_tween()
	_peeling.tween_property(consoles, ^"peel", amount, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows where the consoles are on the ring, what the cursor is on and what the buttons do.
func _show() -> void:
	var slots: Array[int] = []
	for platform_id in _row:
		slots.append(_wheel.order.find(platform_id))
	consoles.wheel_slots = slots
	consoles.pointed = _row.find(_wheel.selected())
	consoles.held = consoles.pointed if _wheel.is_holding() else -1
	_refit()
	_aim()
	_describe()
	_choosing.visible = not _wheel.is_holding()
	_moving.visible = _wheel.is_holding()
	_fit_view()


## The ring's parts stand in the design's frame as the viewport shows it.
func _fit_view() -> void:
	_frame.position = consoles.view_origin()
	_frame.scale = Vector2.ONE * consoles.view_scale()


## The scale every console stands on, for the order the ring is in.
func _refit() -> void:
	var started := Time.get_ticks_usec()
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	var angles := PackedFloat64Array()
	var count := _wheel.order.size()
	for slot in count:
		var index := _row.find(_wheel.order[slot])
		boxes.append(consoles.silhouette(index))
		weights.append(RingFit.weight_of(consoles.console_at(index).folder))
		angles.append(float(slot) / count * TAU)
	consoles.ring_target = RingFit.scale(boxes, weights, angles, RingFit.WIDEST / RingFit.PS2_BOX.size.x)
	Diagnostics.trace("order", "fit scale=%.2f room=%.2f in %.2f ms" % [consoles.ring_target,
		minf(RingFit.least_room(boxes, weights, angles, consoles.ring_target), RingFit.ROOM * RingFit.CQW),
		(Time.get_ticks_usec() - started) / 1000.0])


## Where the arrow stands: at once onto the console the cursor is on, further out (coming there on the follow)
## while it is held; its logo in the middle.
func _aim() -> void:
	var angle := float(_wheel.cursor) / _wheel.order.size() * TAU
	var item := consoles.console_at(_row.find(_wheel.selected()))
	var reach := RingFit.ext(consoles.silhouette(_row.find(_wheel.selected())), RingFit.weight_of(item.folder),
		consoles.ring_target, angle)
	_arrow_to = angle
	_arrow_angle = angle
	_arrow_out_to = reach + (_ARROW_HELD_PX if _wheel.is_holding() else _ARROW_OUT_PX)
	_rim = StudioTokens.GEL.get(StringName(item.folder), StudioTokens.NEUTRAL)
	_tint_marks()
	_arrow.queue_redraw()
	_logo.show_logo(LogoView.Slot.RING_MIDDLE, item.folder)


## What the line under the logo says: nothing at rest; while a console is held, that it stands in its place, or
## between the logos of the two next to it (next to the one, when there are two consoles).
func _describe() -> void:
	if not _wheel.is_holding():
		_sentence("")
	elif not _wheel.is_moved():
		_sentence(tr("in its place", "ring"))
	else:
		var around := _wheel.neighbours()
		var between := around.size() == 2 and around[0] != around[1]
		_sentence(tr("between {before} and {after}", "ring") if between else tr("next to {name}", "ring"),
			_folder_of(around[0]), _folder_of(around[1]))


## Logo placeholders follow the complete translated sentence, including languages with a different order.
func _sentence(text: String, before_folder := "", after_folder := "") -> void:
	for child in _where.get_children():
		_where.remove_child(child)
		if child is not LogoView:
			child.queue_free()
	_before.hide()
	_after.hide()
	_before.show_logo(LogoView.Slot.BETWEEN_MINI, before_folder)
	_after.show_logo(LogoView.Slot.BETWEEN_MINI, after_folder)
	var logos: Dictionary[String, LogoView] = {"before": _before, "after": _after, "name": _before}
	var at := 0
	for slot in _sentence_slots.search_all(text):
		_word(text.substr(at, slot.get_start() - at))
		var logo := logos[slot.get_string(1)]
		_where.add_child(logo)
		logo.show()
		at = slot.get_end()
	_word(text.substr(at))
	for logo: LogoView in [_before, _after]:
		if not logo.get_parent():
			_where.add_child(logo)


func _word(text: String) -> void:
	var words := text.strip_edges()
	if not words.is_empty():
		_where.add_child(Word.new(words))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if _placing:
			_aim_placing()
		elif _wheel:
			_describe()



## The middle as opaque and as high as it has come in.
func _place_middle() -> void:
	_middle.modulate.a = _middle_in
	_middle.position.y = _middle_y + (1.0 - _middle_in) * _MIDDLE_RISE_PX


func _tint_marks() -> void:
	_arrow.modulate.a = _marks


## The arrow where the ring's marks stand this frame.
func _place_marks() -> void:
	var radial := Vector2(RingFit.RADII.x * sin(_arrow_angle), RingFit.RADII.y * cos(_arrow_angle)).normalized()
	_arrow.position = RingFit.place(_arrow_angle) + radial * _arrow_out - Vector2(_arrow.pivot_offset.x, 0.0)
	_arrow.rotation = atan2(-radial.x, radial.y)


## The arrow, as the design draws it: an ink head with a white edge and a shine, a shadow and a glow of the pointed
## console's gel.
func _draw_arrow() -> void:
	var head := _arrow_shape([Vector2(0, 0), Vector2(12, 28), Vector2(0, 21), Vector2(-12, 28)])
	var shine := _arrow_shape([Vector2(0, 4), Vector2(7, 22), Vector2(0, 18)])
	for k in range(_GLOW_ALPHAS.size(), 0, -1):
		_stroke_arrow(head, _ARROW_EDGE_PX + k * _GLOW_STEP_PX, Color(_rim, _GLOW_ALPHAS[k - 1]), true)
	_arrow.draw_colored_polygon(_shifted(head, _ARROW_SHADOW), _ARROW_DROP)
	_stroke_arrow(head, _ARROW_EDGE_PX, _ARROW_STROKE, false)
	_arrow.draw_colored_polygon(head, StudioTokens.INK)
	_arrow.draw_colored_polygon(shine, _ARROW_SHINE)


## The head's outline [param reach] px out, as the design strokes it: edge by edge with a disc on each corner (the
## polyline's own corners are mitred, the design's are round), the inside filled when [param filled].
func _stroke_arrow(head: PackedVector2Array, reach: float, colour: Color, filled: bool) -> void:
	if filled:
		_arrow.draw_colored_polygon(head, colour)
	for k in head.size():
		_arrow.draw_line(head[k], head[(k + 1) % head.size()], colour, 2.0 * reach, true)
		_arrow.draw_circle(head[k], reach, colour)


## The points [param units] (the design's, tip at the origin) in the arrow control's pixels.
func _arrow_shape(units: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for unit in units:
		points.append(Vector2(_arrow.pivot_offset.x + unit.x * _ARROW_UNIT, (unit.y + 3.0) * _ARROW_UNIT))
	return points


func _shifted(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + by)
	return moved


## A word of the line under the logo, in the design's mono face and its muted ink.
class Word:
	extends Control

	const _PX := 20.48

	var _text: String
	var _line: StudioText

	func _init(text: String) -> void:
		_text = text
		mouse_filter = MOUSE_FILTER_IGNORE
		_line = StudioText.new(text, StudioTokens.Face.PLEX_500, _PX, 0.0, false)

	func shown() -> String:
		return _text

	func _get_minimum_size() -> Vector2:
		return Vector2(_line.width, _line.height)

	func _draw() -> void:
		_line.draw(self, Vector2(0.0, (size.y - _line.height) / 2.0), StudioTokens.MUTE)
