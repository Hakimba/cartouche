# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Xbox 360's own looks: its top and bottom curve in towards the middle, its tray slides out of
## the slot through its front with the disc on it, its buttons press in, its ring of lights lights
## up, and the dimensions it cannot be built from are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded by each test, not preloaded: no console may be loaded before a library asks for it.
const SCENE := "res://carousel/consoles/xbox360/xbox360.tscn"
const MEASURED := "res://carousel/consoles/xbox360/xbox360_shape.tres"
## Building a mesh takes a while: fewer cases than the carousel's properties, and fewer still for
## the whole body.
const SHAPES := 120
const BODIES := 30
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_closed_the_tray_fills_its_slot_its_plate_in_the_pocket_its_disc_on_the_hub_s_clamp_ring() -> void:
	var random := Fixtures.cases(100)
	for shape: Xbox360Shape in Fixtures.accepted(self, SHAPES, _xbox360.bind(random)):
		var detail := random.randi_range(16, 128)
		var front := shape.depth / 2.0
		var bezel := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"bezel", detail)))
		var slot := shape.slot()
		assert_float(bezel.position.x / MM).is_equal_approx(slot.position.x + Xbox360Shape.TRAY_GAP, EPSILON)
		assert_float(bezel.end.x / MM).is_equal_approx(slot.end.x - Xbox360Shape.TRAY_GAP, EPSILON)
		assert_float(bezel.position.y / MM).is_equal_approx(slot.position.y + Xbox360Shape.TRAY_GAP, EPSILON)
		assert_float(bezel.end.y / MM).is_equal_approx(slot.end.y - Xbox360Shape.TRAY_GAP, EPSILON)
		assert_float(bezel.end.z / MM).is_equal_approx(front, EPSILON)
		# The plate within the bezel's outline, its back short of the pocket's bottom.
		var plate := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"tray", detail)))
		assert_float(plate.position.x).is_greater(bezel.position.x)
		assert_float(plate.end.x).is_less(bezel.end.x)
		assert_float(plate.position.y).is_greater(bezel.position.y)
		assert_float(plate.position.z / MM).is_greater(front - shape.pocket_depth())
		var ring := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"clamp_ring", detail)))
		var seat := shape.seat(0.0)
		assert_vector(Vector2(seat.origin.x, seat.origin.z)).is_equal_approx(
			Vector2(ring.get_center().x, ring.get_center().z), Vector2.ONE * EPSILON * MM)
		# On the ring, at the recess's floor under the plate's top.
		assert_float(seat.origin.y - ring.end.y).is_equal_approx(Xbox360Shape.DISC_HALF_THICKNESS * MM, EPSILON * MM)
		assert_float(ring.end.y / MM).is_equal_approx(shape.plate().end.y - DiscTray.RECESS_DEPTH, EPSILON)
		assert_vector(seat.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)


func test_open_the_tray_has_brought_its_disc_out_in_front_of_the_console_still_held_in_its_slot() -> void:
	var random := Fixtures.cases(101)
	for shape: Xbox360Shape in Fixtures.accepted(self, SHAPES, _xbox360.bind(random)):
		var travel := shape.tray_travel()
		var moved := random.randf_range(0.0, travel)
		assert_bool(shape.seat(moved).is_equal_approx(shape.seat(0.0).translated(Vector3.BACK * moved * MM))).is_true()
		var front := shape.depth / 2.0
		assert_float(shape.seat(travel).origin.z / MM - shape.disc_radius).is_between(front, front + 5.0)
		# The plate's back, slid out, is still behind the front.
		var plate := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"tray", 32)))
		assert_float(plate.position.z / MM + travel).is_less(front)


func test_the_tray_goes_through_the_front_into_a_pocket_deeper_than_it() -> void:
	var random := Fixtures.cases(102)
	for shape: Xbox360Shape in Fixtures.accepted(self, BODIES, _xbox360.bind(random)):
		var detail := random.randi_range(16, 128)
		var front := shape.depth / 2.0
		var bottom := front - shape.pocket_depth()
		# The tray seen from the front: its bezel's outline, the plate within it.
		var tray := PackedVector2Array()
		for point in Fixtures.points(shape.mesh_arrays(&"bezel", detail)):
			tray.append(Vector2(point.x, point.y) / MM)
		var floored := false
		for triangle in Fixtures.triangles(shape.mesh_arrays(&"shell", detail)):
			var plan := PackedVector2Array()
			for corner in triangle:
				plan.append(Vector2(corner.x, corner.y) / MM)
			if Array(triangle).all(func(corner: Vector3) -> bool: return is_equal_approx(corner.z / MM, front)):
				for point in tray:
					assert_bool(Geometry2D.point_is_inside_triangle(point, plan[0], plan[1], plan[2])) \
						.override_failure_message("the front covers the tray at %s" % point).is_false()
			floored = floored or (is_equal_approx(triangle[0].z / MM, bottom)
				and Geometry2D.is_point_in_polygon(shape.slot().get_center(), plan))
		assert_bool(floored).override_failure_message("no pocket's bottom at %f" % bottom).is_true()
		assert_float(bottom).is_less(front - Xbox360Shape.BEZEL_THICKNESS - shape.plate_length())


func test_the_eject_button_is_round_in_its_own_round_hole_a_gap_all_round_it() -> void:
	var random := Fixtures.cases(105)
	for shape: Xbox360Shape in Fixtures.accepted(self, BODIES, _xbox360.bind(random)):
		var detail := random.randi_range(16, 128)
		var front := shape.depth / 2.0
		var centre := shape.eject_centre()
		# Round: no point beyond its radius, and many on it, all round.
		var rim := {}
		for point in Fixtures.points(shape.mesh_arrays(&"eject", detail)):
			var off := Vector2(point.x, point.y) / MM - centre
			assert_float(off.length()).is_less_equal(shape.eject_radius + EPSILON)
			if off.length() > shape.eject_radius - EPSILON:
				rim[roundi(rad_to_deg(off.angle()))] = true
		assert_int(rim.size()).is_greater_equal(32)
		# The front stops short of it by the gap, all round; the hole has a floor, behind the front.
		var gap := PackedVector2Array([centre])
		for k in 16:
			gap.append(centre + Vector2.from_angle(TAU * k / 16) * (shape.eject_radius + Xbox360Shape.EJECT_HOLE_GAP / 2.0))
		var floored := false
		for triangle in Fixtures.triangles(shape.mesh_arrays(&"shell", detail)):
			var plan := PackedVector2Array()
			for corner in triangle:
				plan.append(Vector2(corner.x, corner.y) / MM)
			if Array(triangle).all(func(corner: Vector3) -> bool: return is_equal_approx(corner.z / MM, front)):
				for point in gap:
					assert_bool(Geometry2D.point_is_inside_triangle(point, plan[0], plan[1], plan[2])) \
						.override_failure_message("the front covers the eject's gap at %s" % point).is_false()
			floored = floored or (is_equal_approx(triangle[0].z / MM, front - Xbox360Shape.EJECT_DEPTH)
				and Geometry2D.is_point_in_polygon(centre, plan))
		assert_bool(floored).override_failure_message("no floor to the eject's hole").is_true()


func test_the_top_and_the_bottom_curve_in_towards_the_middle() -> void:
	var random := Fixtures.cases(103)
	for shape: Xbox360Shape in Fixtures.accepted(self, BODIES, _xbox360.bind(random)):
		var straight := shape.width / 2.0 - shape.corner
		var middle_top := 0.0
		for point in Fixtures.points(shape.mesh_arrays(&"shell", random.randi_range(16, 128))):
			var at := point / MM
			if absf(at.x) > straight:
				continue
			assert_float(at.y).is_less_equal(shape.height - shape.sag(at.x) + EPSILON)
			assert_float(at.y).is_greater_equal(shape.foot_height + shape.sag(at.x) - EPSILON)
			if absf(at.x) < shape.width / 20.0:
				middle_top = maxf(middle_top, at.y + shape.sag(at.x))
		assert_float(middle_top).is_equal_approx(shape.height, EPSILON)
		assert_float(shape.sag(0.0)).is_equal(shape.dip)
		assert_float(shape.sag(shape.width / 2.0)).is_equal_approx(0.0, EPSILON)


func test_INV_E10_02_impossible_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(104)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(xbox: Xbox360Shape) -> void: xbox.eject_radius = 0.0],
		[&"corner_rounds_the_bevel", func(xbox: Xbox360Shape) -> void: xbox.corner = xbox.bevel],
		[&"curved_in_gently", func(xbox: Xbox360Shape) -> void: xbox.dip = 0.05 * xbox.width],
		[&"slot_level_on_the_ends", func(xbox: Xbox360Shape) -> void:
			xbox.slot_levels = Vector2(xbox.height - xbox.corner, xbox.height - xbox.corner + 2.0)],
		[&"front_details_on_the_face_and_apart", func(xbox: Xbox360Shape) -> void:
			xbox.power_centre.x = xbox.slot_span.y],
		[&"front_details_on_the_face_and_apart", func(xbox: Xbox360Shape) -> void:
			xbox.slot_span.x = -xbox.width / 2.0 + xbox.corner],
		[&"ring_on_the_boss", func(xbox: Xbox360Shape) -> void: xbox.ring_radii.y = xbox.boss_radius],
		[&"tray_in_its_slot", func(xbox: Xbox360Shape) -> void: xbox.slot_levels.y = xbox.slot_levels.x + 6.0],
		[&"tray_in_its_slot", func(xbox: Xbox360Shape) -> void: xbox.depth = xbox.pocket_depth() + xbox.bevel],
		[&"disc_fits_the_tray", func(xbox: Xbox360Shape) -> void:
			xbox.disc_radius = (xbox.slot_span.y - xbox.slot_span.x) / 2.0],
		# Its recess a quarter of a millimetre into the walls each side.
		[&"disc_fits_the_tray", func(xbox: Xbox360Shape) -> void:
			xbox.disc_radius = xbox.plate().size.x / 2.0 - DiscTray.RAIL.x - DiscTray.WALL - DiscTray.RECESS_ROOM + 0.25],
		[&"faceplate_seam_behind_the_bevel", func(xbox: Xbox360Shape) -> void: xbox.faceplate_depth = xbox.bevel],
		[&"vents_on_the_top", func(xbox: Xbox360Shape) -> void: xbox.corner = Xbox360Shape.VENT_INSET],
		[&"drive_on_the_left_end", func(xbox: Xbox360Shape) -> void: xbox.faceplate_depth = xbox.depth / 2.0 + 30.0],
		# Corners so round that the end curves away from under the drive's edges.
		[&"drive_on_the_left_end", func(xbox: Xbox360Shape) -> void: xbox.corner = 16.0],
		[&"back_details_on_the_back_and_apart", func(xbox: Xbox360Shape) -> void: xbox.width = 280.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _xbox360.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_tray_slides_its_disc_out_and_the_buttons_press_in() -> void:
	var console: Xbox360Model = auto_free(Fixtures.new_console(SCENE))
	add_child(console)
	var shape: Xbox360Shape = console.shape
	var tray: Node3D = console.get_node("%Tray")
	var power: Node3D = console.get_node("%Power")
	var eject: Node3D = console.get_node("%Eject")
	for travel: float in [30.0, shape.tray_travel()]:
		console.tray_mm = travel
		assert_vector(tray.position).is_equal_approx(Vector3.BACK * travel * MM, Vector3.ONE * EPSILON * MM)
		assert_bool(console.seat().is_equal_approx(shape.seat(travel))).is_true()
	var pressed := Vector2(Fixtures.open_of(console, &"power_mm"), Fixtures.open_of(console, &"eject_mm"))
	console.power_mm = pressed.x
	console.eject_mm = pressed.y
	assert_vector(power.position).is_equal_approx(Vector3.FORWARD * pressed.x * MM, Vector3.ONE * EPSILON * MM)
	assert_vector(eject.position).is_equal_approx(Vector3.FORWARD * pressed.y * MM, Vector3.ONE * EPSILON * MM)


## A shape drawn by [param random] around the measured one, each dimension from 0.85 to 1.15 times
## it, drawn again until its rules accept it.
static func _xbox360(random: RandomNumberGenerator) -> Xbox360Shape:
	return Fixtures.drawn_around(load(MEASURED) as ModelShape, random, Vector2(0.85, 1.15)) as Xbox360Shape
