# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleOrder
extends Control
## The screen putting the consoles in order. They leave their row for a ring further back, where
## all of them show; the ring has no end ([ConsoleWheel]). A cursor, a small arrow outside the
## ring, jumps from one console to the next with left and right, the name of the one it is on in
## the middle. A takes that console: it peels off like a sticker ([ConsoleSticker]: a white
## border, a shadow, leaning a little) and goes with the cursor, taking at once the place of each
## console it passes, which slides into its own; the middle tells where it would go. A then puts it
## down, the order kept from then on; B lets go of it, the order as it was. B closes the ring, the
## consoles screen back on the console the cursor is on. By touch, dragging sideways moves the
## cursor, tapping a console takes it, and a tap puts it down.

## The ring is closed, the consoles back in their row.
signal closed
## The consoles are in [param order] (platform ids) from now on.
signal ordered(order: Array[String])
## The order could not be kept: it is back to what it was.
signal order_failed

## The ring comes and goes in this time; what it shows arrives once the consoles are nearly there,
## and leaves first.
const _MOVE_S := 0.6
const _ARRIVE_S := 0.24
const _ARRIVE_AFTER_S := 0.38
const _LEAVE_S := 0.15
## A console peels off, and is put back down, in these times, springing a little.
const _PEEL_S := 0.24
const _PUT_DOWN_S := 0.26
## By touch: the cursor moves one console for each stretch this long dragged; a tap takes the
## console nearest it, this close at most (in pixels).
const _DRAG_STEP := 160.0
const _TAP_REACH := 110.0
## The ring's track: how many straight bits draw it, its dashes in pixels, and its colour; the
## arrow's tip and base, in world units outside the ring, its half width, length, notch and rim,
## in pixels, and ink.
const _TRACK_BITS := 120
const _DASH := 6.0
const _DASH_GAP := 9.0
const _TRACK := Color(0.13, 0.14, 0.17, 0.25)
const _ARROW_TIP := 0.65
const _ARROW_BASE := 1.0
const _ARROW_HALF := 8.0
const _ARROW_LONG := 16.0
const _ARROW_NOTCH := 5.0
const _ARROW_RIM := 3.0
const _INK := Color(0.13, 0.14, 0.17)

var android: AndroidServices = Android
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first [method open].
var consoles: ConsoleRow
## Takes a platform id, answers the name its console shows.
var name_of: Callable

var _wheel: ConsoleWheel
## The platform ids in the order of the row: where each console of the row stands on the ring.
var _row: Array[String] = []
var _open := false
## No press counts while the ring comes or goes, nor while the plugin keeps an order.
var _busy := false
var _peeling: Tween
var _finger := Finger.new()
## How many steps the finger's drag has made.
var _drag_steps := 0

@onready var _sticker: ConsoleSticker = %Sticker
## The ring's track, on a layer of the backdrop: the consoles stand in front of it.
@onready var _behind: CanvasLayer = %Behind
@onready var _ring: Control = %Ring
@onready var _middle: Control = %Middle
@onready var _name: Label = %Name
@onready var _place: Label = %Place
@onready var _choosing: Control = %Choosing
@onready var _moving: Control = %Moving


func _ready() -> void:
	hide()
	_ring.draw.connect(_draw_ring)
	visibility_changed.connect(func() -> void: _behind.visible = visible)


func _unhandled_input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	var direction := int(event.is_action_pressed(&"carousel_right")) - int(event.is_action_pressed(&"carousel_left"))
	var accept := event.is_action_pressed(&"ui_accept")
	if not direction and not accept and not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _busy:
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
	if gesture == Finger.Gesture.TAP and not _busy:
		_tap(_finger.at)
	elif gesture == Finger.Gesture.DRAG:
		var steps := int((_finger.at.x - _finger.start.x) / _DRAG_STEP)
		while _drag_steps != steps:
			var direction := signi(steps - _drag_steps)
			if not _busy:
				_step(direction)
			_drag_steps += direction


## Whether the ring shows, or is coming or going.
func is_open() -> bool:
	return _open or _busy


## Opens the ring on [param platform_ids], the consoles of the row in its order, the cursor on the
## one at [param at].
func open(platform_ids: Array[String], at: int) -> void:
	_row = platform_ids.duplicate()
	_wheel = ConsoleWheel.new(platform_ids, at)
	_open = true
	_finger = Finger.new()
	_sticker.consoles = consoles
	_sticker.watch(true)
	modulate.a = 0.0
	_ring.modulate.a = 0.0
	show()
	_show()
	Diagnostics.trace("order", "ring open on %s" % _wheel.selected())
	await _move(1.0, 1.0, _ARRIVE_S, _ARRIVE_AFTER_S)


func _close() -> void:
	_open = false
	Diagnostics.trace("order", "ring closed on %s" % _wheel.selected())
	consoles.pointed = -1
	# The row comes back round the console the cursor was on.
	consoles.select(_row.find(_wheel.selected()))
	await _move(0.0, 0.0, _LEAVE_S)
	_sticker.watch(false)
	hide()
	closed.emit()


## The consoles go to the ring ([param wheel] 1) or the row (0), what the screen shows fading to
## [param alpha] in [param fade_s] seconds once [param fade_after_s] have passed; no press counts
## meanwhile.
func _move(wheel: float, alpha: float, fade_s: float, fade_after_s := 0.0) -> void:
	_busy = true
	var moves := create_tween().set_parallel()
	moves.tween_property(consoles, ^"wheel", wheel, _MOVE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for faded: CanvasItem in [self, _ring]:
		moves.tween_property(faded, ^"modulate:a", alpha, fade_s).set_delay(fade_after_s)
	await moves.finished
	_busy = false


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
	var order := _wheel.order.duplicate()
	var answer := await android.order_consoles(PackedStringArray(order))
	_busy = false
	if answer.ok:
		ordered.emit(order)
		_row = order
	else:
		Diagnostics.trace("order", "order not kept (%s): %s" % [answer.code, answer.detail])
		_wheel = ConsoleWheel.new(_row, _row.find(_wheel.selected()))
		order_failed.emit()
	_show()


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
	var camera := get_viewport().get_camera_3d()
	var nearest := -1
	var reach := _TAP_REACH
	for slot in _wheel.order.size():
		var distance := camera.unproject_position(consoles.ring_point(slot)).distance_to(at)
		if distance < reach:
			nearest = slot
			reach = distance
	if nearest >= 0:
		_wheel.point(nearest)
		_take()


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
	_name.text = name_of.call(_wheel.selected())
	_place.visible = _wheel.is_holding()
	var around := _wheel.neighbours()
	if not _wheel.is_moved():
		_place.text = tr("in its place")
	elif around.size() == 2 and around[0] != around[1]:
		_place.text = tr("between {before} and {after}").format({"before": name_of.call(around[0]),
			"after": name_of.call(around[1])})
	else:
		_place.text = tr("next to {other}").format({"other": name_of.call(around[0])})
	_choosing.visible = not _wheel.is_holding()
	_moving.visible = _wheel.is_holding()
	var middle := get_viewport().get_camera_3d().unproject_position(consoles.ring_middle())
	_middle.position = middle - _middle.size / 2.0
	_ring.queue_redraw()


## The ring's dashed track, and the arrow outside it pointing at the console the cursor is on.
func _draw_ring() -> void:
	var camera := get_viewport().get_camera_3d()
	var count := _wheel.order.size()
	var track := PackedVector2Array()
	for k in _TRACK_BITS + 1:
		track.append(camera.unproject_position(consoles.ring_point(float(k) / _TRACK_BITS * count)))
	var drawn := 0.0
	for k in track.size() - 1:
		var from := track[k]
		var length := from.distance_to(track[k + 1])
		var along := 0.0
		while along < length:
			var phase := fmod(drawn + along, _DASH + _DASH_GAP)
			var stretch := minf((_DASH if phase < _DASH else _DASH + _DASH_GAP) - phase, length - along)
			if phase < _DASH:
				_ring.draw_line(from.lerp(track[k + 1], along / length), from.lerp(track[k + 1], (along + stretch) / length),
					_TRACK, 2.0, true)
			along += stretch
		drawn += length
	var tip := camera.unproject_position(consoles.ring_point(_wheel.cursor, _ARROW_TIP))
	var inward := (tip - camera.unproject_position(consoles.ring_point(_wheel.cursor, _ARROW_BASE))).normalized()
	var side := inward.orthogonal() * _ARROW_HALF
	var back := tip - inward * _ARROW_LONG
	var arrow := PackedVector2Array([tip, back + side, tip - inward * (_ARROW_LONG - _ARROW_NOTCH), back - side, tip])
	_ring.draw_polyline(arrow, Color.WHITE, 2.0 * _ARROW_RIM + 2.0, true)
	_ring.draw_colored_polygon(arrow.slice(0, 4), _INK)
	_ring.draw_polyline(arrow, _INK, 2.0, true)
