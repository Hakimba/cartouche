# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleRow
extends Node3D
## The consoles screen's row: one console per platform with games, the selected one alone in the middle,
## posed by its launch animation's first step; the right stick turns it ([StickTurn]). Left and right
## step along a ring, whatever the count: its position shows console `posmod(position, count)`. A step
## swaps the consoles: the old one slides away and fades, the new one comes in from the other side.
##
## The selected console stands as its launch animation has it: the animation drives the properties
## below, from where the console rests to where a game goes into it, and the console's own parts.
## The others rest as their own animations start, and show only on the ring.
##
## To be put in order ([ConsoleOrder]), the consoles leave the row for an ellipse where all of them
## show ([RingFit]): [member wheel] takes the one [member pointed] at there, [member others_wheel] the
## others, [member wheel_slots] says where each one stands round it (-1 for a console that has no
## place, a platform without a model), and each one slides to a new place. Each stands at its real
## size on the shared [member ring_scale], as its picture stands in the consoles screen's frame. The one
## pointed at grows a little; the one [member held] peels off as [member peel] has it, drawn as a sticker
## only ([ConsoleSticker]) until it lies flat again.

signal selection_changed(index: int)

## How much of its pose a staged console keeps: enough to show its top and its front.
const _STAGED_POSE := 0.35
## Where the middle of the staged console's silhouette stands, in px of the design's frame, whatever its pose.
const STAGE_CENTRE := Vector2(640.0, 440.0)
## How much the console pointed at grows, and how fast (a pop); the one peeled off, how much it grows,
## leans (radians, counter-clockwise on the screen) and rises (px).
const _POINTED_GROWTH := 0.06
const _POP_S := 0.26
const _PEEL_GROWTH := 0.08
const _PEEL_LEAN := deg_to_rad(4.0)
const _PEEL_LIFT_PX := 23.04
## The 1280 × 960 frame the design is drawn in, and where the others come from when the ring opens and go to
## when it closes: the rail, as far towards its place as the design has them, at this size.
const _RAIL_POINT := Vector2(640.0, 762.88)
const _RAIL_PULL := Vector2(0.45, 0.55)
const _RAIL_SIZE := 0.6
## How much nearer the camera the console flying free of the ring is than the ones on it.
const _FLIER_NEARER := 0.9
## How small a console is as it comes onto the ring from nothing.
const _COMING_SIZE := 0.7
## A swap: the console leaving slides this far away (px of the screen), shrinks to this size and fades in
## [constant _OUT_S]; the one coming slides in from this far, grows from this size in [constant _IN_S].
const _OUT_S := 0.18
const _OUT_PX := 64.0
const _OUT_SCALE := 0.97
const _IN_S := 0.34
const _IN_PX := 76.8
const _IN_SCALE := 0.96
## How far the hero's whole frame stands above its fitted pose, in pixels of the screen.
const RAISE_PX := 83.2
## The render layer of the selected console when a light was designed for it on this screen: only that rig's
## lights are culled to it, the Sun leaves it alone.
const HERO := 1 << 3
## One pixel of the 1280 × 960 design frame, in world units a unit of depth away (the camera's field of view
## being 32°).
const _WORLD_PER_PX := 0.000597386


## Which folders have a light on the consoles screen, including an empty loaded set.
static var _with_rig: Dictionary[String, bool] = {}
static var _rigs_read := false

## Where the selected console stands, turned (radians, about X then Y then Z) and sized.
var console_position := Vector3.ZERO
var console_rotation := Vector3.ZERO
var console_scale := 1.0
## How much of its pose, sway and float it has, from 0 (none) to 1.
var pose_amount := 1.0
var sway_degrees := CarouselLayout.SWAY_DEGREES
var bob_height := CarouselLayout.BOB_HEIGHT
var others_opacity := 1.0
## How fast the consoles float and sway, from 1 down to 0, still ([Resting]).
var pace := 1.0
## How far the row has come in on screen, from 0 (a point) to 1 (beyond, as it overshoots): every
## console grows out of its own centre with it, opaque all along (a fading model would draw with
## other shaders, compiled on the spot).
var arrival := 1.0
## How far the selected console has left the row for its properties, from 0 to 1: it stops swaying
## and floating, keeps a little of its pose, takes [member staged_size] times its size and moves for the middle of
## its silhouette to stand at [constant STAGE_CENTRE], while the others fade out.
var stage := 0.0
var staged_size := 1.0
## How far the console pointed at has gone from the hero's place to the ring, from 0 to 1, and how far the
## others have come from the rail's, 0 to 1.
var wheel := 0.0
var others_wheel := 0.0
## The scale every console stands on, in cqw ([method RingFit.scale]), and the one it is following.
var ring_scale := 0.0
var ring_target := 0.0
## Each console's place round the ring, by its index in the row, -1 for none; the consoles pointed at and
## held there, by the same index, -1 for none.
var wheel_slots: Array[int] = []
## While a console is placed on the ring: each console's angle round it in radians (instead of its slot's), how far
## each has come in (0 gone, smaller, to 1 at rest; any number of them, none for all at rest), and the console flying
## free of the ring, none -1, standing as [member flier_stand] says.
var ring_angles := PackedFloat64Array()
var ring_arrival := PackedFloat64Array()
var flier := -1
var flier_stand := Stand.new()
var pointed := -1
var held := -1
var peel := 0.0
var pose := ShelfRow.Pose.new()
## Whether the consoles are drawn apart, behind the games ([ConsoleLayer]): there, they move only in
## the frames [ConsoleSequence] arranges them in, and stand still in the others.
var behind := false


var _items: Array[Item] = []
## The console lit by its own rig, the rig's lights, and the middle of its box in its own space; -1 for none.
var _lit := -1
var _lights: StudioLights
var _lit_centre := Vector3.ZERO
## The position shown, unbounded on an endless row (see [CarouselLayout]).
var _position := 0
var _scroll := 0.0
## How far the consoles' float and sway have gone, in seconds at full pace.
var _pose_s := 0.0
var _stick := Vector2.ZERO
var _turn := StickTurn.new(true)
## Where each console stands round the ring this frame, sliding towards its slot; how many places the ring has.
var _slid: Array[float] = []
var _ring_places := 0
## How far each console's pop has gone, from 0 (as placed) to 1 (grown).
var _pop: Array[float] = []
## The console peeled off: the one held, or the one put down until it lies flat again; and the one
## drawn as a sticker. -1 for none.
var _peeled := -1
var _stuck := -1
## Whether they were arranged since this node's last frame: then, behind the games too, they are
## arranged again as the clock moves on.
var _arranged := false
## The consoles leaving, each from where it stood when it was left; the way the row went (-1 or 1) and the seconds
## since the console now selected started coming in: the swap is over once it arrived.
var _leavers: Array[Leaver] = []
var _way := 0
var _in_from := Swap.new(0.0, 1.0, 1.0)
var _swap_s := _IN_S
var _screen_presence := 1.0


## Stops a row between steps at its selected position before another screen opens.
func is_settling() -> bool:
	return not is_equal_approx(_scroll, float(_position)) or _swap_s < _IN_S


func settle() -> void:
	_scroll = float(_position)
	arrange()


## Fades the row without interrupting its pose or arranging internals from outside.
func fade_to(presence: float) -> void:
	_screen_presence = presence
	arrange()


func _ready() -> void:
	add_to_group(Resting.PACED)
	set_process(false)


func _process(delta: float) -> void:
	_pose_s += delta * pace
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_swap_s += delta
	for leaver in _leavers:
		leaver.seconds += delta
	_leavers = _leavers.filter(func(leaver: Leaver) -> bool: return leaver.seconds < _OUT_S)
	_turn.follow(_stick, selected_index(), delta)
	_slide(delta)
	for i in _pop.size():
		_pop[i] = move_toward(_pop[i], 1.0 if i == pointed else 0.0, delta / _POP_S)
	# The one put down stays peeled off until it lies flat.
	if held >= 0 or peel <= 0.0:
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
	_peeled = -1
	_stuck = -1
	_stop_swap()
	# New models are drawn in front.
	behind = false
	wheel_slots.assign(range(_items.size()))
	_slid.assign(wheel_slots)
	_pop.resize(_items.size())
	_pop.fill(0.0)
	_position = from
	_scroll = from
	_turn = StickTurn.new(true)
	set_process(true)
	arrange()


## The selected console shown by [param item] instead, where it stands: another model of it.
func replace_selected(item: Item) -> void:
	var gone := selected()
	_unlight()
	remove_child(gone.model)
	gone.model.queue_free()
	_items[selected_index()] = item
	_adopt(item)
	_lit = -1
	arrange()


func selected_index() -> int:
	return posmod(_position, maxi(_items.size(), 1))


func selected() -> Item:
	return _items[selected_index()]


## The console at [param index] of the row.
func console_at(index: int) -> Item:
	return _items[index]


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
## stays as it is (selected, turned, pointed at, held, on the ring) wherever it goes. ConsoleOrder._landed
## rewrites flier and the ring angles immediately afterwards.
func reorder(order: Array[int]) -> void:
	var items: Array[Item] = []
	var slid: Array[float] = []
	var popped: Array[float] = []
	for index in order:
		items.append(_items[index])
		slid.append(_slid[index])
		popped.append(_pop[index])
	_items = items
	_slid = slid
	_pop = popped
	wheel_slots.assign(range(_items.size()))
	_position = order.find(selected_index())
	_scroll = _position
	_turn.index = order.find(_turn.index)
	pointed = order.find(pointed)
	held = order.find(held)
	_peeled = order.find(_peeled)
	_stuck = order.find(_stuck)
	_lit = order.find(_lit)
	_stop_swap()


## [param places] steps towards [param direction] (-1 or 1) round the ring: from the last console, the first, and
## back. The console left swaps with the one reached; a step during a swap starts the swap again.
func step(direction: int, places := 1) -> void:
	if _items.size() < 2:
		return
	var leaver := Leaver.new()
	leaver.index = selected_index()
	leaver.way = direction
	leaver.from = _swap_in() if _swap_s < _IN_S else Swap.new(0.0, 1.0, 1.0)
	_way = direction
	_swap_s = 0.0
	_position += direction * places
	var returning := _leaver_of(selected_index())
	_in_from = returning.look() if returning else Swap.new(_way * _IN_PX, _IN_SCALE, 0.0)
	_leavers.append(leaver)
	_leavers = _leavers.filter(func(other: Leaver) -> bool: return other.index != selected_index())
	_turn.release()
	Sounds.play(SoundEffects.Cue.CONSOLE)
	selection_changed.emit(selected_index())


## Starts a direct arrival from the form; the returned stand is the flight's pose.
func begin_arrival(centre: Vector2, width: float) -> Stand:
	arrival = 1.0
	face_front()
	flier = selected_index()
	pointed = flier
	wheel_slots.fill(-1)
	wheel_slots[flier] = 0
	wheel = 1.0
	flier_stand = Stand.new()
	flier_stand.centre = centre
	flier_stand.size = width
	arrange()
	return flier_stand


## Restores the selected hero and the row's normal slots after a direct arrival.
func end_arrival() -> void:
	flier = -1
	pointed = -1
	wheel = 0.0
	wheel_slots.assign(range(_items.size()))
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


## Turns the selected console with a finger dragged [param pixels] over it; it comes back to the
## front once [method let_go] (see [StickTurn]).
func touch_turn(pixels: Vector2) -> void:
	_turn.touch(pixels)


func let_go() -> void:
	_turn.let_go()


## Draws every console in the render layers of [param mask].
func show_in_layers(mask: int) -> void:
	behind = mask == ConsoleLayer.BEHIND
	for i in _items.size():
		for geometry in _items[i].geometry:
			geometry.layers = HERO if mask == ConsoleLayer.FRONT and i == _lit else mask


## Stands every console as the properties above have it; each frame does (behind the games, only
## the frames they were arranged in), and so does whoever needs where they stand at once.
func arrange() -> void:
	_arranged = true
	var on_ring := wheel > 0.0 or others_wheel > 0.0
	_light_selected()
	var settled := Swap.new(0.0, 1.0, 1.0)
	var swap := _swap_in() if _swap_s < _IN_S else settled
	for i in _items.size():
		var item := _items[i]
		var chosen := i == selected_index()
		var leaver := _leaver_of(i)
		var going := leaver != null and not chosen and leaver.seconds < _OUT_S
		item.model.visible = (chosen or going) and item.modelled or on_ring and wheel_slots[i] >= 0
		if not item.model.visible:
			continue
		var offset := 0.0 if chosen or going else CarouselLayout.nearest(_position, i, _items.size()) - _scroll
		var staged := stage if chosen else 0.0
		var unstaged := 1.0 - staged
		var rest := item.rest
		var at_position := console_position if chosen else rest.console_position
		var amount := pose_amount if chosen else rest.pose_amount
		var centred := CarouselLayout.centred(offset) * amount
		var place := CarouselLayout.place(offset)
		pose.sway = (sway_degrees if chosen else rest.sway_degrees) * unstaged
		var bob := CarouselLayout.float_height(_pose_s, bob_height if chosen else rest.bob_height, centred * unstaged)
		var turned := _three_euler(console_rotation if chosen else rest.console_rotation)
		var swapping := swap if chosen else leaver.look() if going else settled
		var size := (console_scale if chosen else rest.console_scale) * maxf(arrival, 0.001) \
			* lerpf(1.0, staged_size, staged) * swapping.size
		var posed := place.basis * pose.at(_pose_s, centred * lerpf(1.0, _STAGED_POSE, staged)) * _turn.of(i)
		var stand := posed * turned.scaled(Vector3.ONE * size)
		var lift := Vector3.UP * bob
		if staged > 0.0 and item.modelled:
			lift += _stage_shift(item, at_position + place.origin) * staged
		var slid := Vector3.RIGHT * swapping.shift_px * _WORLD_PER_PX * (3.7 - at_position.z - global_position.z)
		var in_row := Transform3D(stand, at_position + place.origin + lift + slid)
		if chosen and _lights:
			_lights.place(Transform3D(stand, at_position + place.origin + lift) * _lit_centre)
		var ringed: Stand = _stand(i) if on_ring else null
		var moved := _on_ring(i, ringed) if on_ring else in_row
		if chosen and _lights and on_ring:
			_lights.place(moved * _lit_centre)
		# Set again, even unchanged, it would be sent to every part of the console.
		if item.model.transform != moved:
			item.model.transform = moved
		var presence := (1.0 if chosen else others_opacity * (1.0 - stage)) * swapping.opacity
		item.fade.call(1.0 - ringed.opacity if on_ring else CarouselLayout.faded(offset, presence * _screen_presence))


## The lights of the selected console, for the debug bridge to tune live.
func lights() -> StudioLights:
	return _lights


## The selected console lit again from the light file as it now reads (the debug bridge reloaded it).
func relight() -> void:
	_unlight()
	_lit = -1
	_light_selected()


## Drops what was read of the light file, so that the next read sees a file the debug bridge reloaded.
static func forget() -> void:
	_rigs_read = false
	_with_rig.clear()


## Whether the console in [param folder] has a light designed for it on this screen (`consoles`).
static func has_rig(folder: String) -> bool:
	if not _rigs_read:
		_with_rig = _rigs_from(FileAccess.get_file_as_string(StudioLights.FILE))
		_rigs_read = true
	return _with_rig.get(folder, false)


static func _rigs_from(text: String) -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		return found
	var data: Dictionary = parsed
	var models: Dictionary = data.get("lights", {})
	for model: String in models:
		var screens: Dictionary = models[model]
		found[model] = screens.has("consoles")
	return found



func _adopt(item: Item) -> void:
	add_child(item.model)
	item.geometry.assign(item.model.find_children("*", "VisualInstance3D", true, false))
	if item.model is VisualInstance3D:
		item.geometry.append(item.model)


## The lights of the selected console's own rig stand about it, the console alone drawn in their layer; a
## console without a rig keeps the Sun and the room as they are (today's light).
func _light_selected() -> void:
	var wanted := selected_index() if not _items.is_empty() and has_rig(selected().folder) else -1
	if wanted == _lit and (wanted < 0 or _lights):
		return
	var was := _lit
	_unlight()
	_lit = wanted
	if wanted >= 0:
		var model := _items[wanted].model
		_lit_centre = Plinth.bounds(model, model).get_center()
		_lights = StudioLights.new(self, StudioLights.rig_of(_items[wanted].folder, &"consoles"), Vector3.ZERO,
			StudioLights.environment_of(self))
		for light in _lights.lights():
			light.light_cull_mask = HERO
	for i: int in [was, wanted]:
		if i >= 0 and i < _items.size():
			for geometry in _items[i].geometry:
				geometry.layers = _front_layer(i) if not behind else ConsoleLayer.BEHIND


## The lights taken down.
func _unlight() -> void:
	if _lights:
		for light in _lights.lights():
			light.queue_free()
	_lights = null
	_lit = -1


## The layer console [param index] is drawn in in front of the games.
func _front_layer(index: int) -> int:
	return HERO if index == _lit else ConsoleLayer.FRONT


## How the console coming in stands this far into a swap.
func _swap_in() -> Swap:
	var arrived := Motion.eased(Motion.Easing.ARRIVE, clampf(_swap_s / _IN_S, 0.0, 1.0))
	return Swap.new(lerpf(_in_from.shift_px, 0.0, arrived), lerpf(_in_from.size, 1.0, arrived),
		lerpf(_in_from.opacity, 1.0, clampf(arrived, 0.0, 1.0)))


## The leaver of console [param index], none when it is not leaving.
func _leaver_of(index: int) -> Leaver:
	for leaver in _leavers:
		if leaver.index == index:
			return leaver
	return null


## No swap under way: the console selected stands, the ones that were leaving are gone.
func _stop_swap() -> void:
	_leavers.clear()
	_swap_s = _IN_S


## Where console [param index] stands on the ring: its silhouette's centre ([member Stand.centre]) at its place,
## [member Stand.size] times its size in the consoles screen's frame, as opaque as [member Stand.opacity]. The one
## pointed at glides from the hero's place as [member wheel] has it; the others come from the rail as
## [member others_wheel] has it.
func _stand(index: int) -> Stand:
	if index == flier:
		return flier_stand
	var item := _items[index]
	var angle := ring_angles[index] if index < ring_angles.size() else _slid[index] / _ring_places * TAU
	var peeled := peel if index == _peeled else 0.0
	var growth := Motion.eased(Motion.Easing.POP, _pop[index]) * lerpf(_POINTED_GROWTH, _PEEL_GROWTH, peeled)
	var size := RingFit.width(RingFit.weight_of(item.folder), ring_scale, angle) * (1.0 + growth) / (CarouselLayout.FRAME.x / RingFit.CQW)
	var place := RingFit.place(angle) - Vector2(0.0, _PEEL_LIFT_PX * peeled)
	var stand := Stand.new()
	if index == pointed:
		stand.centre = _hero_of(item).centre.lerp(place, wheel)
		stand.size = lerpf(1.0, size, wheel)
		stand.opacity = 1.0
		return stand
	var from := Vector2(lerpf(place.x, _RAIL_POINT.x, _RAIL_PULL.x), lerpf(place.y, _RAIL_POINT.y, _RAIL_PULL.y))
	var arrived := ring_arrival[index] if index < ring_arrival.size() else 1.0
	stand.centre = from.lerp(place, others_wheel)
	stand.size = size * lerpf(_RAIL_SIZE, 1.0, others_wheel) * lerpf(_COMING_SIZE, 1.0, arrived)
	stand.opacity = others_wheel * clampf(arrived, 0.0, 1.0)
	return stand


## How console [param index] stands in the model's frame for [param stand]: as in the consoles screen but sized and
## moved, leaning when held; its place is found from where its silhouette's centre stands in the hero's frame.
func _on_ring(index: int, stand: Stand) -> Transform3D:
	var rest := _items[index].rest
	var hero := _hero_of(_items[index])
	var peeled := peel if index == _peeled else 0.0
	var leaning := Basis(Vector3.BACK, _PEEL_LEAN * peeled)
	var origin := to_view(stand.centre - stand.size * (hero.centre - hero.origin))
	# The console flying free of the ring is nearer the camera, and as much smaller, so that it is drawn over the others.
	var nearer := _FLIER_NEARER if index == flier else 1.0
	var at := to_local(get_viewport().get_camera_3d().project_position(origin, hero.depth * nearer))
	return Transform3D(leaning * _three_euler(rest.console_rotation).scaled(Vector3.ONE * rest.console_scale * stand.size * nearer), at)


## How console [param index] stands on the ring this frame.
func ring_stand(index: int) -> Stand:
	return _stand(index)


## The selected console's silhouette on the stage, in px of the design's frame.
func staged_box() -> Rect2:
	var size := _hero_of(selected()).box.size * CarouselLayout.FRAME * staged_size
	return Rect2(STAGE_CENTRE - size / 2.0, size)


## How far the console of [param item], standing at [param origin], moves on the stage for the middle of its
## silhouette to stand at [constant STAGE_CENTRE]: measured on its rest pose, grown as it grows there.
func _stage_shift(item: Item, origin: Vector3) -> Vector3:
	var hero := _hero_of(item)
	var camera := get_viewport().get_camera_3d()
	var depth := -(camera.global_transform.affine_inverse() * to_global(origin)).z
	var wanted := STAGE_CENTRE - (hero.centre - hero.origin) * staged_size
	return to_local(camera.project_position(to_view(wanted), depth)) - origin


## The silhouette box of console [param index] in its picture's frame, as fractions of it: the box of what it
## draws, seen as in the consoles screen, before the frame is raised to the hero's place.
func silhouette(index: int) -> Rect2:
	return _hero_of(_items[index]).box


## Where [param slot] is round the ring, in px of the viewport.
func ring_point(slot: float) -> Vector2:
	return to_view(RingFit.place(slot / _ring_places * TAU))


## How many px of the viewport a px of the design's frame is: the camera keeps the view's height, so a screen taller
## than the frame's 4:3 shows it larger.
func view_scale() -> float:
	return get_viewport().get_visible_rect().size.y / CarouselLayout.FRAME.y


## The design's frame in the middle of the viewport: where its corner stands, in px of the viewport.
func view_origin() -> Vector2:
	return to_view(Vector2.ZERO)


## The point [param design] of the design's frame, in px of the viewport.
func to_view(design: Vector2) -> Vector2:
	return get_viewport().get_visible_rect().size / 2.0 + (design - CarouselLayout.FRAME / 2.0) * view_scale()


## The point [param view] of the viewport, in px of the design's frame.
func to_design(view: Vector2) -> Vector2:
	return (view - get_viewport().get_visible_rect().size / 2.0) / view_scale() + CarouselLayout.FRAME / 2.0


## The console's look in the hero's place, measured once, the first time it is wanted: the boxes of its visible parts
## in its rest basis (the lid and the trays move in the launch, whose steps start from this very rest) drawn through
## the camera.
func _hero_of(item: Item) -> Hero:
	if item.hero == null:
		var started := Time.get_ticks_usec()
		item.hero = Hero.of(self, item)
		Diagnostics.trace("order", "silhouette of %s measured in %.2f ms" % [item.folder, (Time.get_ticks_usec() - started) / 1000.0])
	return item.hero


## What draws the console peeled off, none when no console is.
func peeled_geometry() -> Array[VisualInstance3D]:
	var geometry: Array[VisualInstance3D] = []
	if _peeled >= 0:
		geometry = _items[_peeled].geometry
	return geometry


## Every console stands in its slot at once, the ring's places counted again.
func snap_ring() -> void:
	_count_places()
	for i in mini(_items.size(), wheel_slots.size()):
		_slid[i] = float(maxi(wheel_slots[i], 0))


func _count_places() -> void:
	_ring_places = maxi(wheel_slots.filter(func(slot: int) -> bool: return slot >= 0).size(), 1)


## Each console slides towards its slot round the ring, the shorter way.
func _slide(delta: float) -> void:
	_count_places()
	var follow := 1.0 - exp(-RingFit.FOLLOW * minf(delta, Motion.MAX_STEP_S))
	ring_scale = ring_target if absf(ring_target - ring_scale) < 1e-4 else lerpf(ring_scale, ring_target, follow)
	for i in mini(_items.size(), wheel_slots.size()):
		if wheel_slots[i] < 0:
			continue
		var gap := wrapf(wheel_slots[i] - _slid[i], -_ring_places / 2.0, _ring_places / 2.0)
		var slid := _slid[i] + gap * follow
		_slid[i] = float(wheel_slots[i]) if absf(gap) < 0.001 else fposmod(slid, _ring_places)


## The console peeled off drawn as a sticker only, the others as usual.
func _stick_on() -> void:
	if _peeled == _stuck:
		return
	for i: int in [_stuck, _peeled]:
		if i >= 0:
			for geometry in _items[i].geometry:
				geometry.layers = ConsoleLayer.STICKER if i == _peeled else _front_layer(i)
	_stuck = _peeled


## Turned about X, then Y, then Z, each about the axes the previous turns left, as the steps of a
## launch animation give it.
static func _three_euler(angles: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y) \
		* Basis(Vector3.BACK, angles.z)


## How a console stands in a swap: slid by [member shift_px] pixels, [member size] times its size and
## [member opacity] opaque.
class Swap:
	var shift_px: float
	var size: float
	var opacity: float

	func _init(shift: float, scaled: float, opaque: float) -> void:
		shift_px = shift
		size = scaled
		opacity = opaque


## A console leaving the row: from [member from], where it stood when it was left, it slides away, shrinks and
## fades as the swap has it, [member seconds] into it.
class Leaver:
	var index: int
	var way: int
	var from: Swap
	var seconds := 0.0

	func look() -> Swap:
		var gone := Motion.eased(Motion.Easing.EASE_IN, clampf(seconds / ConsoleRow._OUT_S, 0.0, 1.0))
		return Swap.new(lerpf(from.shift_px, -way * ConsoleRow._OUT_PX, gone),
			lerpf(from.size, ConsoleRow._OUT_SCALE, gone), from.opacity * (1.0 - gone))


## One console of the row: its model, how to fade it, and where it rests.
class Item:
	var model: Node3D
	## Its folder under res://carousel/consoles.
	var folder: String
	## Whether it is a console of ours, with a model: a platform shown by its medium is shown nowhere here.
	var modelled := true
	## Takes how transparent the model is, from 0 (opaque) to 1 (gone).
	var fade: Callable
	var rest: Rest
	## What draws it, once in the row.
	var geometry: Array[VisualInstance3D] = []
	## How it looks in the hero's place, once known (see [method ConsoleRow._hero_of]).
	var hero: Hero

	## [param shown] has a `fade(amount)` method.
	func _init(shown: Node3D, resting: Rest, from := "", has_model := true) -> void:
		model = shown
		fade = Callable(shown, &"fade")
		rest = resting
		folder = from
		modelled = has_model


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


## Where a console's silhouette stands on the ring: its centre in px of the design's frame, its size against
## the picture in the consoles screen (1 there), its opacity.
class Stand:
	var centre := Vector2.ZERO
	var size := 1.0
	var opacity := 1.0


## How a console looks in the hero's place, drawn through the camera: where its origin and the centre of its
## silhouette stand in px of the design's frame, how far from the camera its origin is, and its silhouette's box
## as fractions of the picture (the frame is raised by [constant RAISE_PX] over the screen).
class Hero:
	var origin := Vector2.ZERO
	var centre := Vector2.ZERO
	var depth := 1.0
	var box := Rect2()

	static func of(row: ConsoleRow, item: Item) -> Hero:
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
				var seen := row.to_design(camera.unproject_position(to_world * aabb.get_endpoint(corner)))
				low = low.min(seen)
				high = high.max(seen)
		var hero := Hero.new()
		hero.origin = row.to_design(camera.unproject_position(posed.origin))
		hero.centre = (low + high) / 2.0
		hero.depth = -(camera.global_transform.affine_inverse() * posed.origin).z
		hero.box = Rect2((low + Vector2(0.0, RAISE_PX)) / CarouselLayout.FRAME, (high - low) / CarouselLayout.FRAME)
		return hero
