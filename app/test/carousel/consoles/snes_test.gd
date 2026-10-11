# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The PAL Super Nintendo's own looks: its low front sloping back to the top, its tray out of sight
## under the front, its flaps, its cartridge's seat, its buttons, and the dimensions its rules refuse.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/snes/snes.tscn"
const MEASURED := "res://carousel/consoles/snes/snes_shape.tres"
const SHAPES := 40
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
## How near mesh points, stored in single precision, come to where they are meant to be, in millimetres.
const NEAR := 0.01
## The room each side of a cartridge in the slot, as the European one has in the real one, in millimetres.
const ROOM := 3.5


func test_the_front_face_stops_at_its_height_and_the_top_is_reached_only_behind_the_slope() -> void:
	for shape: SnesShape in _shapes(Fixtures.cases(64)):
		var front := -shape.depth / 2.0
		var lowest := INF
		var highest := -INF
		# In plan, X to the right, Y towards the back, Z up.
		for point in Fixtures.points(shape.mesh_arrays(&"shell", 32)):
			var at := ShapeGeometry.PLAN.inverse() * point / MM
			lowest = minf(lowest, at.z)
			highest = maxf(highest, at.z)
			if at.y < front + NEAR:
				assert_float(at.z).override_failure_message("the front face up at %s" % at) \
					.is_less_equal(shape.front_height + NEAR)
			if at.z > shape.height - NEAR:
				assert_float(at.y).override_failure_message("the top in front of the slope at %s" % at) \
					.is_greater_equal(front + shape.slope_run - NEAR)
		assert_float(lowest).is_equal_approx(shape.tray_height, NEAR)
		assert_float(highest).is_equal_approx(shape.height, NEAR)
		# The tray, under the shell, stays behind the front face and inside the sides and the back.
		for point in Fixtures.points(shape.mesh_arrays(&"base", 32)):
			var at := ShapeGeometry.PLAN.inverse() * point / MM
			assert_float(at.y).is_greater_equal(front + shape.tray_front - NEAR)
			assert_float(absf(at.x)).is_less_equal(shape.width / 2.0 - shape.tray_inset + NEAR)
			assert_float(at.z).is_between(-NEAR, shape.tray_height + SnesShape.TRAY_BEVEL + NEAR)


func test_closed_the_flaps_close_the_slot_below_the_panel_and_open_they_hang_clear_of_a_cartridge() -> void:
	for shape: SnesShape in _shapes(Fixtures.cases(60)):
		var console: SnesModel = Fixtures.built(self, SCENE, shape)
		var slot := shape.slot_box()
		var closed := _flaps(console)
		for flap in closed:
			for point in flap:
				var at := point / MM
				assert_float(at.y).is_between(shape.panel_top() - shape.flap_drop - shape.flap_length()
					- shape.flap_thickness, shape.panel_top())
				assert_bool(slot.has_point(Vector2(at.x, -at.z))).override_failure_message(
					"a flap out of the slot at %s" % at).is_true()
		# The back flap's edge stops short of the front one's, by their gap and a little more.
		var between := (_span(closed[1], Vector3.BACK).x - _span(closed[0], Vector3.BACK).y) / MM
		assert_float(between).is_between(0.0, shape.flap_gap + shape.flap_thickness)
		console.flaps_degrees = shape.flap_swing()
		var seat := shape.seat().origin / MM
		var cartridge := AABB(seat - shape.cartridge / 2.0, shape.cartridge).grow(-EPSILON)
		cartridge.size.y += shape.insertion
		for flap in _flaps(console):
			for point in flap:
				var at := point / MM
				assert_bool(cartridge.has_point(at)).override_failure_message(
					"a flap open in the cartridge's way at %s" % at).is_false()
				assert_bool(slot.grow(EPSILON).has_point(Vector2(at.x, -at.z))).is_true()
				assert_float(at.y).is_greater(shape.tray_height)


func test_a_cartridge_stands_its_insertion_down_the_slot_its_label_to_the_front() -> void:
	for shape: SnesShape in _shapes(Fixtures.cases(61)):
		var console: SnesModel = Fixtures.built(self, SCENE, shape)
		var seat := console.seat()
		assert_bool(seat.basis.is_equal_approx(Basis())).is_true()
		assert_vector(seat.origin / MM).is_equal_approx(Vector3(shape.slot_centre.x,
			shape.panel_top() - shape.insertion + shape.cartridge.y / 2.0, -shape.slot_centre.y),
			Vector3.ONE * EPSILON)
		assert_vector(console.approach()).is_equal(Vector3.UP)
		# Each corner of the cartridge's outline lies within the slot's rounded outline.
		var core := shape.slot_box().grow(-shape.slot_corner)
		for side: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			var corner := shape.slot_centre + side * Vector2(shape.cartridge.x, shape.cartridge.z) / 2.0
			assert_float(corner.distance_to(corner.clamp(core.position, core.end))).is_less_equal(shape.slot_corner)


func test_the_slot_takes_every_cartridge_of_the_platform_with_room_each_side() -> void:
	var snes: SnesShape = load(MEASURED)
	for medium in Fixtures.media("snes"):
		var width: float = Fixtures.medium_shape(medium).get(&"width")
		assert_float(snes.slot_size.x - 2.0 * ROOM).override_failure_message(medium).is_greater_equal(width)
		assert_float(snes.cartridge.x).override_failure_message(medium).is_greater_equal(width)


func test_pressed_the_eject_lever_comes_level_with_the_panel_the_reset_button_still_stands_out_and_the_knob_slides_on() -> void:
	for shape: SnesShape in _shapes(Fixtures.cases(62)):
		var console: SnesModel = Fixtures.built(self, SCENE, shape)
		var parts: Dictionary[StringName, MovingPart] = {}
		for part in console.moving_parts():
			parts[part.property] = part
		var top := shape.panel_top()
		assert_float(_span(_where(console, ^"%Eject/Lever", &"eject"), Vector3.UP).y / MM).is_equal_approx(
			top + shape.eject_raise, EPSILON)
		# The middle of its top's front edge comes down to the panel.
		var front_edge := PackedVector3Array([Vector3(0.0, 0.0, shape.eject_size.y) * MM])
		var lever: MeshInstance3D = console.get_node(^"%Eject/Lever")
		console.eject_degrees = parts[&"eject_degrees"].open
		assert_float(_placed(lever, front_edge)[0].y / MM).is_equal_approx(top, EPSILON)
		console.reset_mm = parts[&"reset_mm"].open
		assert_float(_span(_where(console, ^"%Reset/Button", &"reset"), Vector3.UP).y / MM).is_equal_approx(
			top + SnesGeometry.OFF + ConsoleModel.PRESSED_SHOWS_MM, EPSILON)
		var off := _where(console, ^"%Knob/Grip", &"knob")
		console.power_mm = parts[&"power_mm"].open
		var on := _where(console, ^"%Knob/Grip", &"knob")
		for i in off.size():
			assert_vector((on[i] - off[i]) / MM).is_equal_approx(Vector3(0.0, 0.0, -shape.power_travel),
				Vector3.ONE * EPSILON)


func test_INV_E10_02_impossible_snes_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var breaks: Array[Array] = [
		[&"sizes_positive", func(console: SnesShape) -> void: console.panel_gap = 0.0],
		[&"corner_rounds_the_edges", func(console: SnesShape) -> void: console.corner = console.side_round],
		[&"shell_holds_its_profile", func(console: SnesShape) -> void: console.front_height = console.height],
		[&"shell_holds_its_profile", func(console: SnesShape) -> void: console.tray_front = console.tray_inset - 0.5],
		[&"crease_on_the_faces", func(console: SnesShape) -> void: console.crease_height = console.front_height],
		[&"panel_inside_the_top", func(console: SnesShape) -> void: console.panel_size.x = console.top().size.x],
		[&"panel_inside_the_top", func(console: SnesShape) -> void: console.panel_corner = SnesShape.PANEL_BEVEL],
		[&"panel_below_the_top", func(console: SnesShape) -> void: console.panel_drop = console.height],
		[&"slot_in_the_panel", func(console: SnesShape) -> void: console.slot_centre.y = console.panel_box().end.y],
		[&"flaps_fit_the_slot", func(console: SnesShape) -> void: console.flap_drop = console.flap_thickness / 2.0],
		[&"flaps_fit_the_slot", func(console: SnesShape) -> void: console.flap_tilt = 45.0],
		[&"cartridge_passes_the_open_flaps", func(console: SnesShape) -> void:
			console.cartridge.z = console.slot_size.y - 2.0 * console.flap_inset() - console.flap_thickness],
		[&"cartridge_passes_the_open_flaps", func(console: SnesShape) -> void: console.cartridge.x = console.slot_size.x + 1.0],
		[&"cartridge_stands_in_the_slot", func(console: SnesShape) -> void: console.insertion = console.cartridge.y],
		[&"cartridge_stands_in_the_slot", func(console: SnesShape) -> void:
			console.insertion = console.flap_drop + console.flap_length()],
		[&"buttons_round_their_corners", func(console: SnesShape) -> void:
			console.button_corner = console.knob_size.y / 2.0],
		[&"buttons_apart_on_the_panel", func(console: SnesShape) -> void: console.reset_centre = console.eject_centre],
		[&"buttons_apart_on_the_panel", func(console: SnesShape) -> void:
			console.power_travel = console.slot_box().position.y - console.knob_box().end.y],
		[&"buttons_stand_a_little_out", func(console: SnesShape) -> void:
			console.eject_raise = console.panel_drop + ConsoleModel.PROUD_MM + 0.1],
		[&"bay_on_the_front", func(console: SnesShape) -> void: console.bay_bottom = console.height],
		[&"vents_on_the_back", func(console: SnesShape) -> void: console.vent_pitch = console.vent_size.x],
		[&"vents_on_the_back", func(console: SnesShape) -> void: console.vent_bottom = console.crease_height],
		[&"vents_on_the_back", func(console: SnesShape) -> void: console.vent_count = 0],
	]
	var shapes := _shapes(Fixtures.cases(63))
	for i in breaks.size():
		Fixtures.assert_refused(self, shapes[i % shapes.size()].duplicate() as ModelShape, breaks[i])


## [constant SHAPES] dimensions its rules accept, drawn by [param random] around the shipped ones:
## each one, half of the times, up to a seventh larger or smaller; a count a few more or fewer.
func _shapes(random: RandomNumberGenerator) -> Array[ModelShape]:
	return Fixtures.accepted(self, SHAPES, Fixtures.drawn_around.bind(load(MEASURED) as ModelShape, random,
		Vector2(0.87, 1.15), 3, 0.5))


## The back flap's points, then the front one's, in the model's space.
static func _flaps(console: SnesModel) -> Array[PackedVector3Array]:
	return [_where(console, ^"%BackFlap/Plate", &"flap"), _where(console, ^"%FrontFlap/Plate", &"flap")]


## The points of [param console]'s [param part], built from its shape, where its node at [param path]
## puts them, in the model's space.
static func _where(console: SnesModel, path: NodePath, part: StringName) -> PackedVector3Array:
	var geometry: MeshInstance3D = console.get_node(path)
	return _placed(geometry, Fixtures.points(console.shape.mesh_arrays(part, 32)))


## [param points] of [param geometry]'s mesh where it puts them, in its console's space.
static func _placed(geometry: MeshInstance3D, points: PackedVector3Array) -> PackedVector3Array:
	var console := geometry.get_parent().get_parent() as Node3D
	return console.global_transform.affine_inverse() * geometry.global_transform * points


## How far [param points] go along [param axis], least and most.
static func _span(points: PackedVector3Array, axis: Vector3) -> Vector2:
	var along := Vector2(INF, -INF)
	for point in points:
		along = Vector2(minf(along.x, point.dot(axis)), maxf(along.y, point.dot(axis)))
	return along
