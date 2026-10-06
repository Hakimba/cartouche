# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleRow
extends Node3D
## The consoles screen's row: one console per platform with games, the selected one in the middle,
## laid out, faded and posed as the games are ([CarouselLayout], [ShelfRow.Pose]); the right stick
## turns it ([StickTurn]). Left and right step along the row, from end to end.
##
## The selected console stands as its launch animation has it: the animation drives the properties
## below, from where the console rests to where a game goes into it. The others rest as their own
## animations start, and fade out with [member others_opacity].
##
## To be put in order ([ConsoleOrder]), the consoles leave the row for a ring, further back, where
## all of them show: [member wheel] takes them there, [member wheel_slots] says where each one
## stands round it, and each one slides to a new place. The one [member pointed] at grows a little;
## the one [member held] peels off as [member peel] has it, drawn as a sticker only
## ([ConsoleSticker]) until it lies flat again.

signal selection_changed(index: int)

## How much of its pose a staged console keeps: enough to show its top and its front.
const _STAGED_POSE := 0.35
## The ring's radius, in world units, how far it leans back (radians), and how much further from
## the camera than the row it stands: the camera seems to step back 3.1 times as far.
const _RING_RADIUS := 2.1
const _RING_TILT := 0.244
const _RING_BACK := 7.77
## How much the console pointed at grows; the one peeled off, how much it grows and leans (radians).
const _POINTED_GROWTH := 0.06
const _PEEL_GROWTH := 0.05
const _PEEL_LEAN := 0.07
## How fast a console slides to its new place round the ring, per second.
const _SLIDE_RATE := 18.0
## How many consoles the ring holds at their size; more, and all of them shrink to fit.
const _RING_ROOM := 9.0


## Where the selected console stands, turned (radians, about X then Y then Z) and sized.
var console_position := Vector3.ZERO
var console_rotation := Vector3.ZERO
var console_scale := 1.0
## How much of its pose, sway and float it has, from 0 (none) to 1.
var pose_amount := 1.0
var sway_degrees := CarouselLayout.SWAY_DEGREES
var bob_height := CarouselLayout.BOB_HEIGHT
var others_opacity := 1.0
## How far the row has come in on screen, from 0 (a point) to 1 (beyond, as it overshoots): every
## console grows out of its own centre with it, opaque all along (a fading model would draw with
## other shaders, compiled on the spot).
var arrival := 1.0
## How far the selected console's lid is open, when it has one.
var lid_degrees := 0.0
## How far the selected console has left the row for its properties, from 0 to 1: it stops swaying
## and floating, keeps a little of its pose, rises [member staged_lift] world units and takes
## [member staged_size] times its size, while the others fade out.
var stage := 0.0
var staged_lift := 0.0
var staged_size := 1.0
## How far the consoles have gone from the row to the ring, from 0 to 1; where the ring's centre
## stands, in the row's space.
var wheel := 0.0
var ring_centre := Vector3.ZERO
## Each console's place round the ring, by its index in the row; the consoles pointed at and held
## there, by the same index, -1 for none.
var wheel_slots: Array[int] = []
var pointed := -1
var held := -1
var peel := 0.0
var pose := ShelfRow.Pose.new()

var _items: Array[Item] = []
var _position := 0
var _scroll := 0.0
var _clock_s := 0.0
var _stick := Vector2.ZERO
var _turn := StickTurn.new()
## Where each console stands round the ring this frame, sliding towards its slot.
var _slid: Array[float] = []
## The console peeled off: the one held, or the one put down until it lies flat again; and the one
## drawn as a sticker. -1 for none.
var _peeled := -1
var _stuck := -1


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_clock_s += delta
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_turn.follow(_stick, _position, delta)
	_slide(delta)
	# The one put down stays peeled off until it lies flat.
	if held >= 0 or peel <= 0.0:
		_peeled = held
	_stick_on()
	arrange()


## Shows [param items], in their order, from [param from].
func show_consoles(items: Array[Item], from: int) -> void:
	for item in _items:
		# Out at once: never drawn with the new consoles.
		remove_child(item.model)
		item.model.queue_free()
	_items = items
	for item in _items:
		add_child(item.model)
		item.geometry.assign(item.model.find_children("*", "VisualInstance3D", true, false))
		if item.model is VisualInstance3D:
			item.geometry.append(item.model)
	_peeled = -1
	_stuck = -1
	wheel_slots.assign(range(_items.size()))
	_slid.assign(wheel_slots)
	_position = from
	_scroll = from
	_turn = StickTurn.new()
	set_process(true)
	arrange()


func selected_index() -> int:
	return _position


func selected() -> Item:
	return _items[_position]


## The console at [param index] selected at once, in the middle of the row.
func select(index: int) -> void:
	if index == _position:
		return
	_position = index
	_scroll = index
	_turn.release()
	selection_changed.emit(_position)


## The consoles in a new order: the one at [param order]'s first index first, and so on. Each one
## stays as it is (selected, turned, pointed at, held, on the ring) wherever it goes.
func reorder(order: Array[int]) -> void:
	var items: Array[Item] = []
	var slid: Array[float] = []
	for index in order:
		items.append(_items[index])
		slid.append(_slid[index])
	_items = items
	_slid = slid
	wheel_slots.assign(range(_items.size()))
	_position = order.find(_position)
	_scroll = _position
	_turn.index = order.find(_turn.index)
	pointed = order.find(pointed)
	held = order.find(held)
	_peeled = order.find(_peeled)
	_stuck = order.find(_stuck)


## One step towards [param direction] (-1 or 1), stopping at the ends.
func step(direction: int) -> void:
	var next := clampi(_position + direction, 0, _items.size() - 1)
	if next == _position:
		return
	_position = next
	_turn.release()
	selection_changed.emit(_position)


## Turns the selected console while [param stick] (each axis from -1 to 1) is pushed (see
## [StickTurn]).
func inspect(stick: Vector2) -> void:
	_stick = stick


## The selected console turns back to the front, in the middle of the row.
func face_front() -> void:
	_stick = Vector2.ZERO
	_turn.release()
	_scroll = _position


## Turns the selected console with a finger dragged [param pixels] over it; it comes back to the
## front once [method let_go] (see [StickTurn]).
func touch_turn(pixels: Vector2) -> void:
	_turn.touch(pixels)


func let_go() -> void:
	_turn.let_go()


## Draws every console in the render layers of [param mask].
func show_in_layers(mask: int) -> void:
	for item in _items:
		for geometry in item.geometry:
			geometry.layers = mask


## Stands every console as the properties above have it; each frame does, and so does whoever
## needs where they stand at once.
func arrange() -> void:
	var shown := CarouselLayout.offsets(_items.size(), _scroll)
	for i in _items.size():
		var item := _items[i]
		item.model.visible = i in shown or wheel > 0.0
		if not item.model.visible:
			continue
		var offset: float = shown.get(i, i - _scroll)
		var chosen := i == _position
		var staged := stage if chosen else 0.0
		var unstaged := 1.0 - staged
		var rest := item.rest
		var at_position := console_position if chosen else rest.console_position
		var amount := pose_amount if chosen else rest.pose_amount
		var centred := CarouselLayout.centred(offset) * amount
		var place := CarouselLayout.place(offset)
		pose.sway = (sway_degrees if chosen else rest.sway_degrees) * unstaged
		var bob := CarouselLayout.float_height(_clock_s, bob_height if chosen else rest.bob_height, centred * unstaged)
		var turned := _three_euler(console_rotation if chosen else rest.console_rotation)
		var size := (console_scale if chosen else rest.console_scale) * maxf(arrival, 0.001) * lerpf(1.0, staged_size, staged)
		var posed := place.basis * pose.at(_clock_s, centred * lerpf(1.0, _STAGED_POSE, staged)) * _turn.of(i)
		var stand := posed * turned.scaled(Vector3.ONE * size)
		var lift := Vector3.UP * (bob + staged_lift * staged)
		var in_row := Transform3D(stand, at_position + place.origin + lift)
		item.model.transform = in_row.interpolate_with(_on_ring(i), wheel) if wheel > 0.0 else in_row
		var presence := 1.0 if chosen else others_opacity * (1.0 - stage)
		item.fade.call(lerpf(CarouselLayout.faded(offset, presence), 0.0, wheel))
		if chosen and item.model is ConsoleModel:
			var console: ConsoleModel = item.model
			console.lid_degrees = lid_degrees


## Where console [param index] stands on the ring: in its place round it, the bottom one nearest,
## standing as it rests (smaller when the ring is crowded), grown when pointed at, peeled off when
## held.
func _on_ring(index: int) -> Transform3D:
	var rest := _items[index].rest
	var peeled := peel if index == _peeled else 0.0
	var growth := (1.0 + (lerpf(_POINTED_GROWTH, _PEEL_GROWTH, peeled) if index in [pointed, _peeled] else 0.0)) \
		* minf(1.0, _RING_ROOM / _items.size())
	var leaning := Basis(Vector3.BACK, -_PEEL_LEAN * peeled)
	return Transform3D(leaning * _three_euler(rest.console_rotation).scaled(Vector3.ONE * rest.console_scale * growth),
		_ring_at(_slid[index]))


## Where [param slot] is round the ring, [param beyond] world units outside it, in the world.
func ring_point(slot: float, beyond := 0.0) -> Vector3:
	return to_global(_ring_at(slot, beyond))


## The ring's centre, in the world.
func ring_middle() -> Vector3:
	return to_global(ring_centre + Vector3(0.0, 0.0, -_RING_BACK))


## What draws the console peeled off, none when no console is.
func peeled_geometry() -> Array[VisualInstance3D]:
	var geometry: Array[VisualInstance3D] = []
	if _peeled >= 0:
		geometry = _items[_peeled].geometry
	return geometry


## [param slot] round the ring, [param beyond] world units outside it, in the row's space: slot 0
## at the bottom, nearest, the next ones to the right then up.
func _ring_at(slot: float, beyond := 0.0) -> Vector3:
	var angle := slot / _items.size() * TAU
	var radius := _RING_RADIUS + beyond
	var height := -radius * cos(angle)
	return ring_centre + Vector3(radius * sin(angle), height * cos(_RING_TILT), -height * sin(_RING_TILT) - _RING_BACK)


## Each console slides towards its slot round the ring, the shorter way.
func _slide(delta: float) -> void:
	var places := _items.size()
	for i in mini(places, wheel_slots.size()):
		var gap := wrapf(wheel_slots[i] - _slid[i], -places / 2.0, places / 2.0)
		var slid := _slid[i] + gap * (1.0 - exp(-_SLIDE_RATE * delta))
		_slid[i] = float(wheel_slots[i]) if absf(gap) < 0.001 else fposmod(slid, places)


## The console peeled off drawn as a sticker only, the others as usual.
func _stick_on() -> void:
	if _peeled == _stuck:
		return
	for i: int in [_stuck, _peeled]:
		if i >= 0:
			for geometry in _items[i].geometry:
				geometry.layers = ConsoleLayer.STICKER if i == _peeled else ConsoleLayer.FRONT
	_stuck = _peeled


## Turned about X, then Y, then Z, each about the axes the previous turns left, as the steps of a
## launch animation give it.
static func _three_euler(angles: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y) \
		* Basis(Vector3.BACK, angles.z)


## One console of the row: its model, how to fade it, and where it rests.
class Item:
	var model: Node3D
	## Takes how transparent the model is, from 0 (opaque) to 1 (gone).
	var fade: Callable
	var rest: Rest
	## What draws it, once in the row.
	var geometry: Array[VisualInstance3D] = []

	## [param shown] has a `fade(amount)` method.
	func _init(shown: Node3D, resting: Rest) -> void:
		model = shown
		fade = Callable(shown, &"fade")
		rest = resting


## Where a console rests: its launch animation's first values.
class Rest:
	var console_position := Vector3.ZERO
	var console_rotation := Vector3.ZERO
	var console_scale := 1.0
	var pose_amount := 1.0
	var sway_degrees := CarouselLayout.SWAY_DEGREES
	var bob_height := CarouselLayout.BOB_HEIGHT

	## The rest [param animation] starts from.
	static func of(animation: Animation) -> Rest:
		var rest := Rest.new()
		for property: StringName in [&"console_position", &"console_rotation", &"console_scale",
				&"pose_amount", &"sway_degrees", &"bob_height"]:
			var track := animation.find_track(NodePath("Consoles:" + property), Animation.TYPE_VALUE)
			if track >= 0:
				rest.set(property, animation.value_track_interpolate(track, 0.0))
		return rest
