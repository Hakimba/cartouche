# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsolePlacing
extends Node
## Places a console just added on the ring of the others ([ConsoleOrder] shows the ring and hands it the presses;
## [Placing] is the flow's rule, pure): the console comes from the form's plinth to the middle, an arrow
## ([RingMarks]) moves between two consoles of the others, A flies it into that gap, the plugin keeps the order and
## the consoles screen opens on it; B flies it back and the form is wanted back.

## The consoles screen comes back over this time: the ring starts closing on the console placed.
signal closing(duration: float)
## The consoles are in [param order] (platform ids) from now on.
signal ordered(order: Array[String])
## The console placed flies back: the form it came from is wanted back.
signal form_wanted
## The placing is over: placed (true), or given up for the form (false).
signal over(placed: bool)
## [method place] answers: as [signal over], or false as this node leaves the tree.
signal _finished(placed: bool)

## The ring comes in as the form goes: the others one after another from this moment, each in this
## time (seconds), the arrow and the hints in theirs, the middle after it all.
const _COMING_AFTER_S := 0.06
const _COMING_EACH_S := 0.018
const _COMING_S := 0.3
const _PLACE_IN_S := 0.32
const _PLACE_MIDDLE_AFTER_S := 0.252
## Flying into the gap, the middle goes in this time; flying back, the ring fades in this time.
const _MIDDLE_OUT_S := 0.16
const _BACK_FADE_S := 0.32

## Makes the tween the ring plays closing, given by [ConsoleOrder].
var ring_out: Callable
var consoles: ConsoleRow
var android: AndroidServices

var _state: Placing
## The platform ids in the order of the row: where each console of the row stands on the ring.
var _row: Array[String] = []
var _placed_id := ""
var _angle: Dictionary[String, float] = {}
var _angle_to: Dictionary[String, float] = {}
var _coming := 0.0
var _others_in := 1.0
var _move := 0.0
var _from := ConsoleRow.Stand.new()
var _arriving: Tween
## The arrow and the hints coming in, then the middle: A puts the middle out, B all of them.
var _marks_coming: Tween
var _middle_coming: Tween
var _tweens: Array[Tween] = []
@onready var _marks: RingMarks = %Frame
@onready var _hints: Control = %Moving


func _exit_tree() -> void:
	_kill_tweens()
	if _state:
		_finished.emit(false)


## Where the flow is, [constant Placing.State.FORM] when no console is placed.
func state() -> Placing.State:
	return _state.state if _state else Placing.State.FORM


## The gap chosen, 0 when no console is placed.
func gap() -> int:
	return _state.gap if _state else 0


## Places the console [param platform_id] of [param row], just added to the row of [param platform_ids], on the
## ring of the others, the order kept by [param services]: true once placed, false once flown back.
func place(row: ConsoleRow, services: AndroidServices, platform_ids: Array[String], platform_id: String) -> bool:
	consoles = row
	android = services
	var ring: Array[String] = []
	ring.assign(platform_ids.filter(func(other: String) -> bool: return other != platform_id))
	_row = platform_ids.duplicate()
	_placed_id = platform_id
	_state = Placing.new(ring)
	_marks.rim = ConsoleManifest.gel_of(_folder_of(platform_id))
	_write_slots()
	consoles.pointed = null
	consoles.held = null
	consoles.flier = _console_of(platform_id)
	consoles.wheel = 1.0
	consoles.others_wheel = 1.0
	_others_in = 1.0
	_coming = 0.0
	_marks.middle_y = RingMarks.MIDDLE_Y
	_angle.clear()
	_angle_to.clear()
	var opened := Placing.angles(ring.size(), _state.gap)
	for k in ring.size():
		_angle[ring[k]] = opened[k]
		_angle_to[ring[k]] = opened[k]
	_angle[platform_id] = 0.0
	_angle_to[platform_id] = 0.0
	aim()
	consoles.ring_scale = consoles.ring_target
	_marks.snap()
	_from = _plinth_stand()
	_move = 0.0
	_marks.arrow_in = 0.0
	_marks.middle_in = 0.0
	_write_ring()
	_state.start()
	Diagnostics.trace("order", "placing %s among %d" % [platform_id, ring.size()])
	_play_arrival()
	return await _finished


## A press of the ring while a console is placed: [param direction] (-1, 0 or 1), else A when [param accept], else B.
func press(direction: int, accept: bool) -> void:
	var pressed := Placing.Press.A if accept else Placing.Press.B
	if direction:
		pressed = Placing.Press.RIGHT if direction > 0 else Placing.Press.LEFT
	# Where the console stands now, before the press changes what the state makes of it.
	var stood := _flier_stand()
	match _state.press(pressed):
		Placing.Action.MOVE:
			Sounds.play(SoundEffects.Cue.CARRY)
			aim()
		Placing.Action.FLY:
			_fly_in(stood)
		Placing.Action.LEAVE:
			_fly_back(stood)


## Where every console of the ring, the arrow and the middle go for the gap chosen: the others on the ring with that
## gap open, the scale fitted again, the arrow in the middle of the gap.
func aim() -> void:
	var ring := _state.others
	var angles := Placing.angles(ring.size(), _state.gap)
	for k in ring.size():
		_angle_to[ring[k]] = angles[k]
	_fit(ring, angles)
	var before := ring[_state.gap]
	var after := ring[(_state.gap + 1) % ring.size()]
	_marks.arrow_to = Placing.arrow_angle(ring.size(), _state.gap)
	_marks.arrow_out_to = (_reach_of(before, angles[_state.gap]) + _reach_of(after, angles[(_state.gap + 1) % ring.size()])) \
		/ 2.0 + RingMarks.ARROW_OUT_PX
	_marks.redraw()
	_marks.show_logo(_folder_of(_placed_id))
	_marks.say_between(_folder_of(before), _folder_of(after), ring.size() == 1)
	_marks.middle_y = Placing.MIDDLE.y + _middle_height() / 2.0 + Placing.TEXT_GAP
	_marks.place_middle()


## The ring's angles follow where they go by [param share], written where the consoles read them.
func follow(share: float) -> void:
	for id in _angle:
		_angle[id] = RingFit.turn_toward(_angle[id], _angle_to[id], share)
	_write_ring()


## Each console of the row's place on the ring while a console is placed: the others', the one placed at the first.
func _write_slots() -> void:
	for k in _row.size():
		consoles.console_at(k).on_ring.slot = maxi(_state.others.find(_row[k]), 0)


## A tween of the placing, let go with it.
func _tween() -> Tween:
	var made := create_tween()
	_tweens.append(made)
	return made


func _kill_tweens() -> void:
	for made in _tweens:
		made.kill()
	_tweens.clear()


## What the ring plays as the form goes: the console flies from the plinth to the middle, the others come onto
## the ring one after another, the arrow and the hints fade in, then the middle.
func _play_arrival() -> void:
	_marks_coming = _tween().set_parallel()
	_marks_coming.tween_property(self, ^"_coming", 1.0, 1.0).from(0.0)
	var in_out := Motion.curve(Motion.Easing.EASE_OUT)
	_marks_coming.tween_property(_marks, ^"arrow_in", 1.0, _PLACE_IN_S).from(0.0).set_custom_interpolator(in_out)
	_marks_coming.tween_property(_hints, ^"modulate:a", 1.0, _PLACE_IN_S).from(0.0).set_custom_interpolator(in_out)
	_middle_coming = _tween()
	_middle_coming.tween_property(_marks, ^"middle_in", 1.0, StudioTokens.TR_RING_MIDDLE_S).from(0.0) \
		.set_delay(_PLACE_MIDDLE_AFTER_S).set_custom_interpolator(in_out)
	_arriving = _tween()
	_arriving.tween_property(self, ^"_move", 1.0, StudioTokens.ARRIVE_S).from(0.0)
	_arriving.tween_callback(_state.done)


## How tall the console placed stands in the middle, in px.
func _middle_height() -> float:
	var width := RingFit.width(RingFit.weight_of(_folder_of(_placed_id)), consoles.ring_target, 0.0) * Placing.MIDDLE_GROWTH
	return width * 0.75 * consoles.silhouette(_row.find(_placed_id)).size.y * FormPaint.CQW


func _fit(ids: Array[String], angles: PackedFloat64Array) -> void:
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	for id in ids:
		boxes.append(consoles.silhouette(_row.find(id)))
		weights.append(RingFit.weight_of(_folder_of(id)))
	consoles.ring_target = RingFit.scale(boxes, weights, angles, RingFit.CAP)
	Diagnostics.trace("order", "placing fit scale=%.2f gap=%d" % [consoles.ring_target, _state.gap])


## How far (px) from console [param id]'s place at [param angle] its box reaches along the radial.
func _reach_of(id: String, angle: float) -> float:
	return RingFit.ext(consoles.silhouette(_row.find(id)), RingFit.weight_of(_folder_of(id)), consoles.ring_target, angle)


## The console of [param platform_id] in the row, null when the row has none.
func _console_of(platform_id: String) -> ConsoleRow.Item:
	var index := _row.find(platform_id)
	return consoles.console_at(index) if index >= 0 else null


func _folder_of(platform_id: String) -> String:
	return consoles.console_at(_row.find(platform_id)).folder


## The console on its way from the plinth: standing there as big as the form's model.
func _plinth_stand() -> ConsoleRow.Stand:
	return ConsoleRow.Stand.new(Placing.PLINTH, Placing.PLINTH_WIDTH / ConsoleRow.PICTURE_CQW)


## The console placed standing at [param angle] of the ring, [param growth] times its size there, its silhouette's
## centre at [param centre].
func _stand_of_placed(centre: Vector2, angle: float, growth: float) -> ConsoleRow.Stand:
	return ConsoleRow.Stand.new(centre,
		RingFit.width(RingFit.weight_of(_folder_of(_placed_id)), consoles.ring_scale, angle) * growth / ConsoleRow.PICTURE_CQW)


## The ring's angles and arrivals, and the console placed, written where the consoles read them.
func _write_ring() -> void:
	for k in _row.size():
		var on := consoles.console_at(k).on_ring
		on.angle = _angle[_row[k]] if _row[k] in _angle else 0.0
		var after := _COMING_AFTER_S + _COMING_EACH_S * k
		on.arrival = _others_in * Motion.eased(Motion.Easing.APPEAR, clampf((_coming - after) / _COMING_S, 0.0, 1.0))
	if consoles.flier:
		consoles.flier_stand = _flier_stand()


## Where the console placed stands this frame for the state the flow is in.
func _flier_stand() -> ConsoleRow.Stand:
	var angle := _angle_to[_placed_id]
	var landed := _stand_of_placed(RingFit.place(angle), angle, 1.0)
	var to := _stand_of_placed(Placing.MIDDLE, 0.0, Placing.MIDDLE_GROWTH)
	var easing := Motion.Easing.IN_OUT
	var lift := StudioTokens.TR_PLACE_ARC_PX
	match _state.state:
		Placing.State.ARRIVING, Placing.State.CHOOSING:
			easing = Motion.Easing.EASE_OUT
		Placing.State.FLYING:
			to = landed
			lift = Placing.FLY_LIFT
		Placing.State.LANDING:
			return landed
		Placing.State.BACK:
			to = _plinth_stand()
	return ConsoleRow.Stand.new(Placing.flight(_from.centre, to.centre, _move, lift),
		lerpf(_from.size, to.size, Motion.eased(easing, _move)))


## A: the console flies from where it is into the gap, lands with no bounce, rests a moment, then the consoles screen opens on it.
func _fly_in(stood: ConsoleRow.Stand) -> void:
	_arriving.kill()
	_middle_coming.kill()
	_from = stood
	var ring := _state.others
	# Library.withConsoleAt counts its gap from before the first console of the ring.
	var chosen := _state.gap + 1
	Diagnostics.trace("order", "placing gap=%d" % chosen)
	var landed := Placing.landed(ring.size(), _state.gap)
	var slot := 0
	var ids: Array[String] = []
	for k in landed.size():
		var id := _placed_id if k == _state.gap + 1 else ring[slot]
		slot += int(id != _placed_id)
		_angle_to[id] = landed[k]
		ids.append(id)
	_fit(ids, landed)
	_marks.arrow_to = _angle_to[_placed_id]
	_move = 0.0
	var flight := _tween()
	flight.tween_property(self, ^"_move", 1.0, StudioTokens.FLY_S)
	flight.tween_callback(_state.done)
	flight.tween_callback(_landed.bind(chosen))
	var out := _tween()
	out.tween_property(_marks, ^"middle_in", 0.0, _MIDDLE_OUT_S)


## The console is in its gap: the order is saved with it, then, after the pause, the morph onto the consoles screen.
func _landed(chosen: int) -> void:
	Sounds.play(SoundEffects.Cue.PLACE)
	var pause := get_tree().create_timer(StudioTokens.PAUSE_S)
	var answer := await android.place_console(_placed_id, chosen)
	if not answer.ok:
		# The ring stays as it was: the console flies back to the form, as on B.
		Diagnostics.trace("order", "not placed (%s): %s" % [answer.code, answer.detail])
		var stood := _flier_stand()
		_state.refuse()
		_fly_back(stood)
		return
	Diagnostics.trace("order", "placed %s at %d" % [_placed_id, chosen])
	var order: Array[String] = []
	# A console whose folder gained games meanwhile is in the order but not on the ring yet.
	order.assign(Array(answer.order).filter(func(id: String) -> bool: return id in _row))
	ordered.emit(order)
	_row = order
	_write_slots()
	if pause.time_left > 0.0:
		await pause.timeout
	_state.done()
	_morph()


## The consoles screen comes: the console placed glides to the hero's place as the ring does closing, the others sink
## into the rail, the rail and the consoles screen's parts come in.
func _morph() -> void:
	_write_slots()
	consoles.flier = null
	consoles.pointed = _console_of(_placed_id)
	_write_ring()
	closing.emit(StudioTokens.TR_RING_CLOSE_S)
	var out: Tween = ring_out.call()
	await out.finished
	_state.done()
	_end(true)


## B: the console flies back to the plinth, the ring goes, the form is wanted back.
func _fly_back(stood: ConsoleRow.Stand) -> void:
	_arriving.kill()
	_marks_coming.kill()
	_middle_coming.kill()
	_from = stood
	_move = 0.0
	var motion := _tween().set_parallel()
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(self, ^"_move", 1.0, StudioTokens.TR_PLACE_BACK_S)
	motion.tween_property(self, ^"_others_in", 0.0, StudioTokens.TR_PLACE_OTHERS_S).set_custom_interpolator(ease_in)
	motion.tween_property(_marks, ^"arrow_in", 0.0, StudioTokens.TR_PLACE_MARKS_S)
	motion.tween_property(_marks, ^"middle_in", 0.0, StudioTokens.TR_PLACE_MARKS_S)
	motion.tween_property(_hints, ^"modulate:a", 0.0, _BACK_FADE_S).set_delay(StudioTokens.TR_PLACE_AT_S).set_custom_interpolator(ease_in)
	get_tree().create_timer(StudioTokens.TR_PLACE_AT_S).timeout.connect(form_wanted.emit)
	await motion.finished
	_state.done()
	_end(false)


## The placing is over: the ring is let go, whichever way it ended.
func _end(placed: bool) -> void:
	consoles.pointed = null
	consoles.flier = null
	consoles.forget_angles()
	if not placed:
		consoles.wheel = 0.0
		consoles.others_wheel = 0.0
	_kill_tweens()
	_marks.middle_y = RingMarks.MIDDLE_Y
	_state = null
	over.emit(placed)
	_finished.emit(placed)
