# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleOrder
extends Control
## The screen putting the consoles in order. They leave the rail for an ellipse where all of them show
## ([RingFit]: each at its real size, none touching another), the ring having no end ([ConsoleWheel]). A cursor,
## a small arrow outside the pointed console ([RingMarks]), jumps from one console to the next with left and right,
## its logo in the middle. A takes that console: it peels off like a sticker ([ConsoleSticker]: a white border, a
## shadow, leaning a little) and goes with the cursor, taking at once the place of each console it passes, which slides
## into its own; the middle tells where it would go, in logos. A then puts it down, the order kept from then on;
## B lets go of it, the order as it was. B closes the ring, the consoles screen back on the console the cursor is
## on. By touch, dragging sideways moves the cursor, tapping a console takes it, and a tap puts it down; the console
## placed goes the same way.
## The same ring places a console just added ([method place], [ConsolePlacing]).

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

## Where the ring is: not shown; coming in, taking no press; taking presses, a console held or not
## ([ConsoleWheel] says which); the plugin keeping an order; going; or placing a console ([ConsolePlacing] says where
## that is, and takes every press).
enum Flow { CLOSED, OPENING, CHOOSING, SAVING, CLOSING, PLACING }

## Opening the ring, the hints come in from this moment, in this time (seconds).
const _HINTS_AFTER_S := 0.25
const _HINTS_S := 0.15
## Closing the ring, the others sink towards the rail in this time, the marks and hints fade in theirs.
const _SINK_S := 0.372
const _MARKS_OUT_S := 0.186
const _HINTS_OUT_S := 0.15
## A console peels off, and is put back down, in these times, springing a little.
const _PEEL_S := 0.24
const _PUT_DOWN_S := 0.26
## By touch: the cursor moves one console for each stretch this long dragged; a tap takes the
## console whose box is nearest it, this far from the box at most (in pixels of the reference frame).
const _DRAG_STEP := 160.0
const _TAP_REACH := 110.0

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first [method open].
var consoles: ConsoleRow

var _wheel: ConsoleWheel
## The platform ids in the order of the row: where each console of the row stands on the ring.
var _row: Array[String] = []
var _flow := Flow.CLOSED
## The ring's way in.
var _opening := Motion.Timeline.new(_place_opening, self)
var _peeling: Tween
var _finger := Finger.new()
var _drag_steps := 0
@onready var _sticker: ConsoleSticker = %Sticker
@onready var _marks: RingMarks = %Frame
@onready var _placer: ConsolePlacing = %Placing
@onready var _choosing: Control = %Choosing
@onready var _moving: Control = %Moving


func _ready() -> void:
	hide()
	set_process(false)
	# Before the consoles, which stand where the placing says this frame.
	process_priority = -1
	get_viewport().size_changed.connect(_fit_view)
	_placer.ring_out = _tween_out
	_placer.closing.connect(closing.emit)
	_placer.ordered.connect(ordered.emit)
	_placer.form_wanted.connect(form_wanted.emit)
	_placer.over.connect(_on_placing_over)


func _process(delta: float) -> void:
	var follow := RingFit.share(delta)
	if _flow == Flow.PLACING:
		_placer.follow(follow)
	_marks.follow(follow)


func _unhandled_input(event: InputEvent) -> void:
	if _flow in [Flow.CLOSED, Flow.CLOSING] or event.is_echo():
		return
	var direction := int(event.is_action_pressed(&"carousel_right")) - int(event.is_action_pressed(&"carousel_left"))
	var accept := event.is_action_pressed(&"ui_accept")
	if not direction and not accept and not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	match _flow:
		Flow.PLACING:
			_placer.press(direction, accept)
		Flow.CHOOSING:
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


## The first finger: a drag steps the cursor round, a tap takes or puts down; placing a console, held from the start,
## a drag moves the gap and a tap flies it there, as ← → and A. A drag made while the ring is busy moves nothing, even
## once it no longer is. Taken before the controls over the ring (the top bar, the hints), which would keep the touches
## on them.
func _input(event: InputEvent) -> void:
	if _flow in [Flow.CLOSED, Flow.CLOSING] or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	get_viewport().set_input_as_handled()
	var was_down := _finger.is_down
	var now: int = clock.call()
	var gesture := _finger.read(event, now)
	if _finger.is_down and not was_down:
		_drag_steps = 0
	if gesture == Finger.Gesture.TAP and _flow == Flow.CHOOSING:
		_tap(_finger.at)
	elif gesture == Finger.Gesture.TAP and _flow == Flow.PLACING:
		_placer.press(0, true)
	elif gesture == Finger.Gesture.DRAG:
		var steps := int((_finger.at.x - _finger.start.x) / _DRAG_STEP)
		while _drag_steps != steps:
			var direction := signi(steps - _drag_steps)
			if _flow == Flow.CHOOSING:
				_step(direction)
			elif _flow == Flow.PLACING:
				_placer.press(direction, false)
			_drag_steps += direction


## Whether the ring shows, or is coming or going.
func is_open() -> bool:
	return _flow != Flow.CLOSED


## Whether the ring is coming, going or keeping an order: no press counts.
func is_busy() -> bool:
	return _flow in [Flow.OPENING, Flow.SAVING, Flow.CLOSING]


## Whether a console just added is being placed among the others.
func is_placing() -> bool:
	return _flow == Flow.PLACING


## Where the placing stands; [constant Placing.State.FORM] when none is under way.
func placing_state() -> Placing.State:
	return _placer.state()


## The gap chosen in the placing, 0 when none is under way.
func placing_gap() -> int:
	return _placer.gap()


## Opens the ring on the consoles of [param platform_ids] (those of the row, in its order), the cursor on the one at
## [param at].
func open(platform_ids: Array[String], at: int) -> void:
	_row = platform_ids.duplicate()
	_wheel = ConsoleWheel.new(_row, at)
	_flow = Flow.OPENING
	_finger = Finger.new()
	_sticker.consoles = consoles
	_sticker.watch(true)
	_show()
	consoles.snap_ring()
	_marks.snap()
	consoles.ring_scale = consoles.ring_target
	_hints().modulate.a = 0.0
	# A placing leaves them faded out; they show at once when a console is taken.
	_moving.modulate.a = 1.0
	_marks.arrow_in = 0.0
	_marks.middle_in = 0.0
	show()
	set_process(true)
	Diagnostics.trace("order", "ring open on %s" % _wheel.selected())
	# The console pointed at glides from the hero's place, the others rise from the rail, the arrow, the middle and the
	# hints come in after them.
	_opening.stand(0.0)
	_opening.play(_opening_length())
	await _opening.arrived
	# Rewound by B, the ring is closing.
	if _flow == Flow.OPENING:
		_flow = Flow.CHOOSING


## Places the console [param platform_id], just added to the row of [param platform_ids] (the platforms shown, in
## their order), on the ring of the others: it comes to the middle, ← → move the arrow between two of them, A flies it
## there and the consoles screen opens on it (true), B flies it back (false, [signal form_wanted] as it goes).
func place(platform_ids: Array[String], platform_id: String) -> bool:
	assert(platform_ids.has(platform_id), "ConsoleOrder: a console placed that is not in the row")
	var ring: Array[String] = []
	ring.assign(platform_ids.filter(func(other: String) -> bool: return other != platform_id))
	_row = platform_ids.duplicate()
	_wheel = ConsoleWheel.new(ring, 0)
	_flow = Flow.PLACING
	_finger = Finger.new()
	_sticker.consoles = consoles
	_choosing.hide()
	_moving.show()
	_moving.modulate.a = 0.0
	_fit_view()
	show()
	set_process(true)
	return await _placer.place(consoles, android, platform_ids, platform_id)


func _on_placing_over(_placed: bool) -> void:
	set_process(false)
	hide()
	_flow = Flow.CLOSED


func _close() -> void:
	Sounds.play(SoundEffects.Cue.RING_CLOSE)
	_flow = Flow.CLOSING
	Diagnostics.trace("order", "ring closed on %s" % _wheel.selected())
	consoles.select(_row.find(_wheel.selected()))
	closing.emit(StudioTokens.TR_RING_CLOSE_S)
	await _tween_out().finished
	consoles.pointed = null
	consoles.held = null
	_sticker.watch(false)
	set_process(false)
	hide()
	_flow = Flow.CLOSED
	closed.emit()


func _opening_length() -> float:
	return [
		StudioTokens.TR_RING_OPEN_S,
		StudioTokens.TR_RING_RISE_AT_S + StudioTokens.TR_RING_RISE_S,
		StudioTokens.TR_RING_MARKS_AT_S + StudioTokens.TR_RING_MARKS_S,
		StudioTokens.TR_RING_MIDDLE_AT_S + StudioTokens.TR_RING_MIDDLE_S,
		_HINTS_AFTER_S + _HINTS_S,
	].max()


func _place_opening() -> void:
	var t := _opening.seconds
	consoles.wheel = Motion.phase(t, 0.0, StudioTokens.TR_RING_OPEN_S, StudioTokens.TR_RING_OPEN_S_CURVE)
	consoles.others_wheel = Motion.phase(t, StudioTokens.TR_RING_RISE_AT_S, StudioTokens.TR_RING_RISE_S,
		StudioTokens.TR_RING_RISE_S_CURVE)
	_marks.arrow_in = Motion.phase(t, StudioTokens.TR_RING_MARKS_AT_S, StudioTokens.TR_RING_MARKS_S)
	_marks.middle_in = Motion.phase(t, StudioTokens.TR_RING_MIDDLE_AT_S, StudioTokens.TR_RING_MIDDLE_S, StudioTokens.TR_RING_MIDDLE_S_CURVE)
	_hints().modulate.a = Motion.phase(t, _HINTS_AFTER_S, _HINTS_S)


## What it plays closing: the console pointed at glides back to the hero’s place, the others sink towards the
## rail, the arrow, the middle and the hints leave.
func _tween_out() -> Tween:
	var moves := create_tween().set_parallel()
	moves.tween_property(consoles, ^"wheel", 0.0,
		StudioTokens.TR_RING_CLOSE_S).set_custom_interpolator(Motion.curve(StudioTokens.TR_RING_CLOSE_S_CURVE))
	moves.tween_property(consoles, ^"others_wheel", 0.0, _SINK_S).set_custom_interpolator(Motion.curve(Motion.Easing.SINK))
	moves.tween_property(_marks, ^"arrow_in", 0.0, _MARKS_OUT_S)
	moves.tween_property(_marks, ^"middle_in", 0.0, _HINTS_OUT_S)
	moves.tween_property(_hints(), ^"modulate:a", 0.0, _HINTS_OUT_S)
	return moves


## The console of [param platform_id] in the row, null when the row has none.
func _console_of(platform_id: String) -> ConsoleRow.Item:
	var index := _row.find(platform_id)
	return consoles.console_at(index) if index >= 0 else null


func _folder_of(platform_id: String) -> String:
	return consoles.console_at(_row.find(platform_id)).folder


func _hints() -> Control:
	return _moving if _flow == Flow.PLACING or _wheel.is_holding() else _choosing


## One step round the ring towards [param direction] (-1 or 1), the console held with the cursor.
func _step(direction: int) -> void:
	Sounds.play(SoundEffects.Cue.CARRY if _wheel.is_holding() else SoundEffects.Cue.CONSOLE)
	_wheel.step(direction)
	_show()


func _take() -> void:
	Sounds.play(SoundEffects.Cue.PEEL)
	_wheel.take()
	Diagnostics.trace("order", "took %s" % _wheel.selected())
	_peel(1.0, _PEEL_S)
	_show()


## Puts the console held down where it is; when that changes the order, keeps it, or goes back to
## the order before when it cannot be kept.
func _put_down() -> void:
	Sounds.play(SoundEffects.Cue.PLACE)
	var moved := _wheel.put_down()
	Diagnostics.trace("order", "put %s down, %s" % [_wheel.selected(), "moved" if moved else "in its place"])
	_peel(0.0, _PUT_DOWN_S)
	_show()
	if not moved:
		return
	_flow = Flow.SAVING
	var order: Array[String] = _wheel.order.duplicate()
	var answer := await android.order_consoles(PackedStringArray(order))
	_flow = Flow.CHOOSING
	if answer.ok:
		ordered.emit(order)
		_row = order
	else:
		Diagnostics.trace("order", "order not kept (%s): %s" % [answer.code, answer.detail])
		_wheel = ConsoleWheel.new(_row, _row.find(_wheel.selected()))
		order_failed.emit()
	_show()


func _let_go() -> void:
	Sounds.play(SoundEffects.Cue.PLACE)
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
	var reach := _TAP_REACH
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
	var half := consoles.silhouette(index).size * CarouselLayout.FRAME * stand.size / 2.0
	var away := (at - consoles.to_view(stand.centre)).abs() - half
	return Vector2(maxf(away.x, 0.0), maxf(away.y, 0.0)).length()


## The console held peels off to [param amount] (0, down) in [param seconds], springing a little.
func _peel(amount: float, seconds: float) -> void:
	_peeling = Motion.restart(self, _peeling)
	_peeling.tween_property(consoles, ^"peel", amount, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows where the consoles are on the ring, what the cursor is on and what the buttons do.
func _show() -> void:
	for k in _row.size():
		consoles.console_at(k).on_ring.slot = _wheel.order.find(_row[k])
	consoles.pointed = _console_of(_wheel.selected())
	consoles.held = consoles.pointed if _wheel.is_holding() else null
	_refit()
	_aim()
	_describe()
	_choosing.visible = not _wheel.is_holding()
	_moving.visible = _wheel.is_holding()
	_fit_view()


## The ring's parts stand in the reference frame, on the stage.
func _fit_view() -> void:
	_marks.position = consoles.view_origin()


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
	consoles.ring_target = RingFit.scale(boxes, weights, angles, RingFit.CAP)
	Diagnostics.trace("order", "fit scale=%.2f room=%.2f in %.2f ms" % [consoles.ring_target,
		minf(RingFit.least_room(boxes, weights, angles, consoles.ring_target), RingFit.ROOM * FormPaint.CQW),
		(Time.get_ticks_usec() - started) / 1000.0])


## Where the arrow stands: at once onto the console the cursor is on, further out (coming there on the follow)
## while it is held; its logo in the middle.
func _aim() -> void:
	var angle := float(_wheel.cursor) / _wheel.order.size() * TAU
	var item := consoles.console_at(_row.find(_wheel.selected()))
	var reach := RingFit.ext(consoles.silhouette(_row.find(_wheel.selected())), RingFit.weight_of(item.folder),
		consoles.ring_target, angle)
	_marks.arrow_to = angle
	_marks.arrow_angle = angle
	_marks.arrow_out_to = reach + (RingMarks.ARROW_HELD_PX if _wheel.is_holding() else RingMarks.ARROW_OUT_PX)
	_marks.rim = ConsoleManifest.gel_of(item.folder)
	_marks.redraw()
	_marks.show_logo(item.folder)


## What the line under the logo says: nothing at rest; while a console is held, that it stands in its place, or
## between the logos of the two next to it (next to the one, when there are two consoles).
func _describe() -> void:
	if not _wheel.is_holding():
		_marks.say("")
	elif not _wheel.is_moved():
		_marks.say(tr("in its place", "ring"))
	else:
		var around := _wheel.neighbours()
		_marks.say_between(_folder_of(around[0]), _folder_of(around[1]), around.size() != 2 or around[0] == around[1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if _flow == Flow.PLACING:
			_placer.aim()
		elif _wheel:
			_describe()
