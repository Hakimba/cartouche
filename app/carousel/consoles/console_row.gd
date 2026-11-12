# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleRow
extends Node3D
## The consoles screen's row: one console per platform with games, the selected one alone in the middle,
## posed by its launch animation's first step; the right stick turns it ([StickTurn]). Left and right
## step along a ring, whatever the count: its position shows console `posmod(position, count)`. A step
## swaps the consoles: the old one is gone at once, the new one comes in from the other side, opaque.
##
## The selected console stands as its launch animation has it: the animation drives the properties
## below, from where the console rests to where a game goes into it, and the console's own parts.
## The others rest as their own animations start, and show only on the ring.
##
## To be put in order ([ConsoleOrder]), the consoles leave the row for an ellipse where all of them
## show ([RingFit]): [member wheel] takes the one [member pointed] at there, [member others_wheel] the
## others, each console's [member Item.on_ring] says where it stands round it ([member OnRing.slot], -1 for a console
## that has no place: the others while one arrives alone from the form), and each one slides to a new place. Each
## stands at its real size on the shared [member ring_scale], as its picture stands in the consoles screen's frame.
## The one pointed at grows a little; the one [member held] peels off as [member peel] has it, drawn as a sticker
## only ([ConsoleSticker]) until it lies flat again.

signal selection_changed(index: int)

## How much the console pointed at grows, and how fast (a pop); the one peeled off, how much it grows,
## leans (radians, counter-clockwise on the screen) and rises (px).
const _POINTED_GROWTH := 0.06
const _POP_S := 0.26
const _PEEL_GROWTH := 0.08
const _PEEL_LEAN := deg_to_rad(4.0)
const _PEEL_LIFT_PX := 23.04
## Where the others come from when the ring opens and go to when it closes: this share of the way (per axis) from
## their ring place towards the rail of logos, in px of the reference frame, at this size.
const _RAIL_POINT := Vector2(640.0, 762.88)
const _RAIL_PULL := Vector2(0.45, 0.55)
const _RAIL_SIZE := 0.6
const _FLIER_NEARER := 0.9
const _COMING_SIZE := 0.7
## A swap: the console coming slides in from this far (px of the screen) and grows from this size in
## [constant _IN_S], opaque all along: a 3D model half faded shows as a pale ghost over the backdrop.
const _IN_S := 0.34
const _IN_PX := 76.8
const _IN_SCALE := 0.96
## How far the hero's whole frame stands above its fitted pose, in pixels of the screen.
const RAISE_PX := 83.2
## The render layer of the selected console when it has its own light rig on this screen: only that rig's
## lights are culled to it, the Sun leaves it alone.
const HERO := 1 << 3
## The picture's width in the consoles screen's frame, in [constant FormPaint.CQW] units.
const PICTURE_CQW := CarouselLayout.FRAME.x / FormPaint.CQW
## One pixel of the 1280 × 960 reference frame, in world units a unit of depth away (the camera's field of view
## being 32°).
const _WORLD_PER_PX := 0.000597386
## The room light the rig writes to: the carousel's own is set by the carousel, so no world uses this one.
static var _unseen_room := Environment.new()


## Where the selected console stands, turned (radians, about X then Y then Z) and sized.
var console_position := Vector3.ZERO
var console_rotation := Vector3.ZERO
var console_scale := 1.0
## How much of its pose, sway and float it has, from 0 (none) to 1.
var pose_amount := 1.0
var sway_degrees := CarouselLayout.SWAY_DEGREES
var bob_height := CarouselLayout.BOB_HEIGHT
## How fast the consoles float and sway, from 1 down to 0, still ([Resting]).
var pace := 1.0
## How far the row has come in on screen, from 0 (a point) to 1 (beyond, as it overshoots): every
## console grows out of its own centre with it, opaque all along (a fading model would draw with
## other shaders, compiled on the spot).
var arrival := 1.0
## How far the console pointed at has gone from the hero's place to the ring, from 0 to 1, and how far the
## others have come from the rail's, 0 to 1.
var wheel := 0.0
var others_wheel := 0.0
## The scale every console stands on ([method RingFit.scale]), and the one it is following.
var ring_scale := 0.0
var ring_target := 0.0
## The consoles pointed at and held on the ring, none null; the console flying free of the ring while it is
## placed, none null, standing as [member flier_stand] says.
var pointed: Item
var held: Item
var flier: Item
var flier_stand := Stand.new()
var peel := 0.0
var pose := ShelfRow.Pose.new()
## Whether the consoles are drawn apart, behind the games ([ConsoleLayer]): there, they move only in
## the frames [ConsoleSequence] arranges them in, and stand still in the others.
var behind := false


var _items: Array[Item] = []
## The console lit by its own rig, the rig's lights, and the middle of its box in its own space; none null.
var _lit: Item
var _lights: StudioLights
var _lit_centre := Vector3.ZERO
## The position shown, unbounded on an endless row (see [CarouselLayout]).
var _position := 0
var _scroll := 0.0
## How far the consoles' float and sway have gone, in seconds at full pace.
var _pose_s := 0.0
var _stick := Vector2.ZERO
var _turn := StickTurn.new(true)
var _ring_places := 0
## The console peeled off: the one held, or the one put down until it lies flat again; and the one
## drawn as a sticker. None null.
var _peeled: Item
var _stuck: Item
## Whether they were arranged since this node's last frame: then, behind the games too, they are
## arranged again as the clock moves on.
var _arranged := false
## The way the row went (-1 or 1) and the seconds since the selected console started coming in: the swap is over
## once it arrived.
var _way := 0
var _swap_s := _IN_S


## Whether the row is still between two positions or in a swap; [method settle] ends it at once.
func is_settling() -> bool:
	return not is_equal_approx(_scroll, float(_position)) or _swap_s < _IN_S


func settle() -> void:
	_scroll = float(_position)
	arrange()


func _ready() -> void:
	add_to_group(Resting.PACED)
	set_process(false)


func _process(delta: float) -> void:
	_pose_s += delta * pace
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_swap_s += delta
	_turn.follow(_stick, selected_index(), delta)
	_slide(delta)
	for item in _items:
		item.on_ring.pop = move_toward(item.on_ring.pop, 1.0 if item == pointed else 0.0, delta / _POP_S)
	# The one put down stays peeled off until it lies flat.
	if held != null or peel <= 0.0:
		_peeled = held
	_stick_on()
	if not behind or _arranged:
		arrange()
	_arranged = false


## Shows [param items], in their order, from [param from].
func show_consoles(items: Array[Item], from: int) -> void:
	_unlight()
	for item in _items:
		# Out at once: never drawn with the new consoles.
		remove_child(item.model)
		item.model.queue_free()
	_items = items
	for item in _items:
		_adopt(item)
	pointed = null
	held = null
	flier = null
	_peeled = null
	_stuck = null
	_stop_swap()
	behind = false
	_number_slots()
	for item in _items:
		item.on_ring.slid = float(item.on_ring.slot)
		item.on_ring.pop = 0.0
	_position = from
	_scroll = from
	_turn = StickTurn.new(true)
	set_process(true)
	arrange()


## The selected console shown by [param item] instead, where it stands: another model of it, in the same place on
## the ring and in the same roles.
func replace_selected(item: Item) -> void:
	var gone := selected()
	_unlight()
	remove_child(gone.model)
	gone.model.queue_free()
	_items[selected_index()] = item
	_adopt(item)
	item.on_ring = gone.on_ring
	pointed = item if pointed == gone else pointed
	held = item if held == gone else held
	flier = item if flier == gone else flier
	_peeled = item if _peeled == gone else _peeled
	_stuck = item if _stuck == gone else _stuck
	_lit = null
	arrange()


func selected_index() -> int:
	return posmod(_position, maxi(_items.size(), 1))


func selected() -> Item:
	return _items[selected_index()]


func console_at(index: int) -> Item:
	return _items[index]


## Each console's place round the ring, in the row's order, -1 for none.
func slots() -> Array[int]:
	var places: Array[int] = []
	for item in _items:
		places.append(item.on_ring.slot)
	return places


## Where [param item] is in the row, -1 for none.
func index_of(item: Item) -> int:
	return _items.find(item)


## Every console at its slot's angle again, fully come in: the placing's angles are let go.
func forget_angles() -> void:
	for item in _items:
		item.on_ring.angle = NAN
		item.on_ring.arrival = 1.0


## The console at [param index] selected at once, in the middle of the row.
func select(index: int) -> void:
	if index == selected_index():
		return
	_position = CarouselLayout.nearest(_position, index, _items.size())
	_scroll = _position
	_stop_swap()
	_turn.release()
	selection_changed.emit(index)


## The consoles in a new order: the one at [param order]'s first index first, and so on. Each one
## stays as it is (selected, turned, pointed at, held, flying, at its angle on the ring) wherever it goes. One the
## order leaves out (a placing's answer, its games gone meanwhile) is out at once, never drawn again.
func reorder(order: Array[int]) -> void:
	var items: Array[Item] = []
	for index in order:
		items.append(_items[index])
	for item in _items:
		if item not in items:
			if item == _lit:
				_unlight()
			pointed = null if pointed == item else pointed
			held = null if held == item else held
			remove_child(item.model)
			item.model.queue_free()
	_position = order.find(selected_index())
	_scroll = _position
	_turn.index = order.find(_turn.index)
	_items = items
	_number_slots()
	_stop_swap()


## [param places] steps towards [param direction] (-1 or 1) round the ring: from the last console, the first, and
## back. The console reached replaces the one left; a step during a swap starts the swap again.
func step(direction: int, places := 1) -> void:
	if _items.size() < 2:
		return
	_way = direction
	_swap_s = 0.0
	_position += direction * places
	_turn.release()
	Sounds.play(SoundEffects.Cue.CONSOLE)
	selection_changed.emit(selected_index())


## Starts a direct arrival from the form; the returned stand is the flight's pose.
func begin_arrival(centre: Vector2, width: float) -> Stand:
	arrival = 1.0
	face_front()
	flier = selected()
	pointed = flier
	for item in _items:
		item.on_ring.slot = -1
	flier.on_ring.slot = 0
	wheel = 1.0
	flier_stand = Stand.new(centre, width)
	arrange()
	return flier_stand


## Restores the selected hero and the row's normal slots after a direct arrival.
func end_arrival() -> void:
	flier = null
	pointed = null
	wheel = 0.0
	_number_slots()
	flier_stand = Stand.new()
	arrange()


## Where the ring stands: the position the selected console shows at, unbounded (the rail follows it).
func target() -> int:
	return _position


## Turns the selected console while [param stick] (each axis from -1 to 1) is pushed (see
## [StickTurn]).
func inspect(stick: Vector2) -> void:
	_stick = stick


## The selected console turns back to the front, in the middle of the row.
func face_front() -> void:
	_stick = Vector2.ZERO
	_turn.release()
	_scroll = _position


func let_go() -> void:
	_turn.let_go()


## Draws the consoles apart, behind the games ([ConsoleLayer]), when [param on]; in front otherwise.
func draw_behind(on: bool) -> void:
	behind = on
	for item in _items:
		_draw_in(item)


## Stands every console as the properties above have it; each frame does (behind the games, only
## the frames they were arranged in), and so does whoever needs where they stand at once.
func arrange() -> void:
	_arranged = true
	var on_ring := wheel > 0.0 or others_wheel > 0.0
	_light_selected()
	var arrived := Motion.eased(Motion.Easing.ARRIVE, clampf(_swap_s / _IN_S, 0.0, 1.0))
	var layout: ScreenLayout = ScreenLayout.at(get_viewport()) if on_ring else null
	for i in _items.size():
		var item := _items[i]
		var chosen := i == selected_index()
		var shown := chosen or on_ring and item.on_ring.slot >= 0
		var ringed: Stand = _stand(item) if on_ring and shown else null
		# A console coming to or leaving the ring grows from a point, opaque: none is drawn at no size.
		item.model.visible = shown and (ringed == null or ringed.size > 0.0)
		if not item.model.visible:
			continue
		var in_row := _selected_in_row(i, arrived) if chosen else Transform3D.IDENTITY
		var moved := _on_ring(item, ringed, layout) if on_ring else in_row
		if chosen and _lights and on_ring:
			_lights.place(moved * _lit_centre)
		# Set again, even unchanged, it would be sent to every part of the console.
		if item.model.transform != moved:
			item.model.transform = moved


## Where the selected console stands in the row, posed and floating, and its lights with it. Off the ring it is
## the only console shown.
func _selected_in_row(index: int, arrived: float) -> Transform3D:
	pose.sway = sway_degrees
	var size := console_scale * lerpf(_IN_SCALE, 1.0, arrived) * maxf(arrival, 0.001)
	var stand := pose.at(_pose_s, pose_amount) * _turn.of(index) * _three_euler(console_rotation).scaled(Vector3.ONE * size)
	var lift := Vector3.UP * CarouselLayout.float_height(_pose_s, bob_height, pose_amount)
	var slid := Vector3.RIGHT * lerpf(_way * _IN_PX, 0.0, arrived) * _WORLD_PER_PX * (3.7 - console_position.z - global_position.z)
	if _lights:
		_lights.place(Transform3D(stand, console_position + lift) * _lit_centre)
	return Transform3D(stand, console_position + lift + slid)


## The lights of the selected console, for the debug bridge to tune live.
func lights() -> StudioLights:
	return _lights


## The selected console lit again from the light file as it now reads (the debug bridge reloaded it).
func relight() -> void:
	_unlight()
	_lit = null
	_light_selected()


func _adopt(item: Item) -> void:
	add_child(item.model)
	item.geometry.assign(item.model.find_children("*", "VisualInstance3D", true, false))
	if item.model is VisualInstance3D:
		item.geometry.append(item.model)


## The lights of the selected console's own rig stand about it, the console alone drawn in their layer; a
## console without a rig keeps the Sun and the room as they are.
func _light_selected() -> void:
	var wanted: Item = selected() if not _items.is_empty() and StudioLights.has_rig(selected().folder, &"consoles") else null
	if wanted == _lit and (wanted == null or _lights):
		return
	var was := _lit
	_unlight()
	_lit = wanted
	if wanted:
		var model := wanted.model
		_lit_centre = Plinth.bounds(model, model).get_center()
		_lights = StudioLights.new(self, StudioLights.rig_of(wanted.folder, &"consoles"), Vector3.ZERO,
			_unseen_room)
		for light in _lights.lights():
			light.light_cull_mask = HERO
	for item: Item in [was, wanted]:
		if item:
			_draw_in(item)


func _unlight() -> void:
	if _lights:
		_lights.dispose()
	_lights = null
	_lit = null


## [param item] drawn in its render layer: the sticker's while it is the one stuck, else behind the games when the
## consoles are, else the hero's when its own rig lights it, else the front.
func _draw_in(item: Item) -> void:
	var layer := HERO if item == _lit else ConsoleLayer.FRONT
	if item == _stuck:
		layer = ConsoleLayer.STICKER
	elif behind:
		layer = ConsoleLayer.BEHIND
	for geometry in item.geometry:
		geometry.layers = layer


func _stop_swap() -> void:
	_swap_s = _IN_S


## Where [param item] stands on the ring: its silhouette's centre ([member Stand.centre]) at its place,
## [member Stand.size] times its size in the consoles screen's frame. The one pointed at glides from the hero's place
## as [member wheel] has it; the others come from the rail as [member others_wheel] has it, growing from a point,
## opaque all along: a 3D model faded shows its insides.
func _stand(item: Item) -> Stand:
	if item == flier:
		return flier_stand
	var on := item.on_ring
	var angle := on.slid / _ring_places * TAU if is_nan(on.angle) else on.angle
	var peeled := peel if item == _peeled else 0.0
	var growth := Motion.eased(Motion.Easing.POP, on.pop) * lerpf(_POINTED_GROWTH, _PEEL_GROWTH, peeled)
	var size := RingFit.width(RingFit.weight_of(item.folder), ring_scale, angle) * (1.0 + growth) / PICTURE_CQW
	var place := RingFit.place(angle) - Vector2(0.0, _PEEL_LIFT_PX * peeled)
	if item == pointed:
		return Stand.new(_hero_of(item).centre.lerp(place, wheel), lerpf(1.0, size, wheel))
	var from := Vector2(lerpf(place.x, _RAIL_POINT.x, _RAIL_PULL.x), lerpf(place.y, _RAIL_POINT.y, _RAIL_PULL.y))
	var come := maxf(others_wheel, 0.0) * clampf(on.arrival, 0.0, 1.0)
	return Stand.new(from.lerp(place, others_wheel),
		size * lerpf(_RAIL_SIZE, 1.0, others_wheel) * lerpf(_COMING_SIZE, 1.0, on.arrival) * come)


## How [param item] stands in the model's frame for [param stand]: as in the consoles screen but sized and
## moved, leaning when held; its place is found from where its silhouette's centre stands in the hero's frame.
func _on_ring(item: Item, stand: Stand, layout: ScreenLayout) -> Transform3D:
	var rest := item.rest
	var hero := _hero_of(item)
	var peeled := peel if item == _peeled else 0.0
	var leaning := Basis(Vector3.BACK, _PEEL_LEAN * peeled)
	var origin := layout.on_stage(stand.centre - stand.size * (hero.centre - hero.origin))
	# The console flying free of the ring is nearer the camera, and as much smaller, so that it is drawn over the others.
	var nearer := _FLIER_NEARER if item == flier else 1.0
	var at := to_local(get_viewport().get_camera_3d().project_position(origin, hero.depth * nearer))
	return Transform3D(leaning * _three_euler(rest.console_rotation).scaled(Vector3.ONE * rest.console_scale * stand.size * nearer), at)


func ring_stand(index: int) -> Stand:
	return _stand(_items[index])


## The silhouette box of console [param index] in its picture's frame, as fractions of it: the box of what it
## draws, seen as in the consoles screen, before the frame is raised to the hero's place.
func silhouette(index: int) -> Rect2:
	return _hero_of(_items[index]).box


## Where [param slot] is round the ring, in px of the viewport.
func ring_point(slot: float) -> Vector2:
	return to_view(RingFit.place(slot / _ring_places * TAU))


## Where the corner of the reference frame stands, in px of the viewport.
func view_origin() -> Vector2:
	return to_view(Vector2.ZERO)


## The point [param design] of the reference frame, in px of the viewport.
func to_view(design: Vector2) -> Vector2:
	return ScreenLayout.at(get_viewport()).on_stage(design)


## The console's look in the hero's place, measured once, the first time it is wanted: the boxes of its visible parts
## in its rest basis (the lid and the trays move in the launch, whose steps start from this very rest) drawn through
## the camera.
func _hero_of(item: Item) -> Hero:
	if item.hero == null:
		var started := Time.get_ticks_usec()
		item.hero = Hero.of(self, item, ScreenLayout.at(get_viewport()))
		Diagnostics.trace("order", "silhouette of %s measured in %.2f ms" % [item.folder, (Time.get_ticks_usec() - started) / 1000.0])
	return item.hero


## What draws the console peeled off, none when no console is.
func peeled_geometry() -> Array[VisualInstance3D]:
	var geometry: Array[VisualInstance3D] = []
	if _peeled:
		geometry = _peeled.geometry
	return geometry


## Every console stands in its slot at once, the ring's places counted again.
func snap_ring() -> void:
	_count_places()
	for item in _items:
		item.on_ring.slid = float(maxi(item.on_ring.slot, 0))


func _count_places() -> void:
	var places := 0
	for item in _items:
		places += int(item.on_ring.slot >= 0)
	_ring_places = maxi(places, 1)


## The consoles' slots as the row has them: the first at the first place, and so on.
func _number_slots() -> void:
	for i in _items.size():
		_items[i].on_ring.slot = i


## Each console slides towards its slot round the ring, the shorter way.
func _slide(delta: float) -> void:
	_count_places()
	var follow := RingFit.share(delta)
	ring_scale = RingFit.toward(ring_scale, ring_target, follow)
	for item in _items:
		var on := item.on_ring
		if on.slot < 0:
			continue
		var gap := wrapf(on.slot - on.slid, -_ring_places / 2.0, _ring_places / 2.0)
		var slid := on.slid + gap * follow
		on.slid = float(on.slot) if absf(gap) < 0.001 else fposmod(slid, _ring_places)


## The console peeled off drawn as a sticker only, the others as usual.
func _stick_on() -> void:
	if _peeled == _stuck:
		return
	var was := _stuck
	_stuck = _peeled
	for item: Item in [was, _stuck]:
		if item:
			_draw_in(item)


## Turned about X, then Y, then Z, each about the axes the previous turns left, as the steps of a
## launch animation give it.
static func _three_euler(angles: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y) \
		* Basis(Vector3.BACK, angles.z)


## One console of the row: its model, where it rests and where it stands on the ring.
class Item:
	var model: Node3D
	## Its folder under res://carousel/consoles.
	var folder: String
	var rest: Rest
	## What draws it, once in the row.
	var geometry: Array[VisualInstance3D] = []
	## How it looks in the hero's place, once known (see [method ConsoleRow._hero_of]).
	var hero: Hero
	var on_ring := OnRing.new()

	func _init(shown: Node3D, resting: Rest, from := "") -> void:
		model = shown
		rest = resting
		folder = from


## Where a console stands on the ring ([ConsoleOrder] writes [member slot], [member angle] and [member arrival]).
class OnRing:
	## Its place round the ring, -1 for none.
	var slot := -1
	## Where it has slid to, on its way to its slot.
	var slid := 0.0
	## How far its pop has gone, from 0 (as placed) to 1 (grown).
	var pop := 0.0
	## While a console is placed: its angle round the ring in radians; NAN for its slot's.
	var angle := NAN
	## While a console is placed: how far it has come in, from 0 (gone, smaller) to 1 (at rest).
	var arrival := 1.0


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


## Where a console's silhouette stands on the ring: its centre in px of the reference frame, its size against
## the picture in the consoles screen (1 there).
class Stand:
	var centre: Vector2
	var size: float

	func _init(at := Vector2.ZERO, wide := 1.0) -> void:
		centre = at
		size = wide


## How a console looks in the hero's place, drawn through the camera: where its origin and the centre of its
## silhouette stand in px of the reference frame, how far from the camera its origin is, and its silhouette's box
## as fractions of the picture (the frame is raised by [constant RAISE_PX] over the screen).
class Hero:
	var origin := Vector2.ZERO
	var centre := Vector2.ZERO
	var depth := 1.0
	var box := Rect2()

	static func of(row: ConsoleRow, item: Item, layout: ScreenLayout) -> Hero:
		var camera := row.get_viewport().get_camera_3d()
		var rest := item.rest
		var posed := row.global_transform * Transform3D(
			ConsoleRow._three_euler(rest.console_rotation).scaled(Vector3.ONE * rest.console_scale), rest.console_position)
		var inverse := item.model.global_transform.affine_inverse()
		var low := Vector2.INF
		var high := -Vector2.INF
		for part in item.geometry:
			if not part.visible:
				continue
			var to_world := posed * (inverse * part.global_transform)
			var aabb := part.get_aabb()
			for corner in 8:
				var seen := layout.from_stage(camera.unproject_position(to_world * aabb.get_endpoint(corner)))
				low = low.min(seen)
				high = high.max(seen)
		var hero := Hero.new()
		hero.origin = layout.from_stage(camera.unproject_position(posed.origin))
		hero.centre = (low + high) / 2.0
		hero.depth = -(camera.global_transform.affine_inverse() * posed.origin).z
		hero.box = Rect2((low + Vector2(0.0, RAISE_PX)) / CarouselLayout.FRAME, (high - low) / CarouselLayout.FRAME)
		return hero
