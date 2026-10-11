# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Xbox's own looks: its tray slides out of its slot in the strip with the disc on it, its
## buttons press in, its power ring lights up, and the dimensions it cannot be built from are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SCENE := "res://carousel/consoles/xbox/xbox.tscn"
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 150
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_closed_the_tray_fills_its_slot_but_its_gap_its_disc_on_the_hub_s_clamp_ring() -> void:
	var random := Fixtures.cases(90)
	for shape: XboxShape in Fixtures.accepted(self, SHAPES, _xbox.bind(random)):
		var detail := random.randi_range(16, 128)
		var tray := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"tray", detail)))
		var slot := shape.slot()
		assert_float(tray.position.x / MM).is_equal_approx(slot.position.x + XboxShape.TRAY_GAP, EPSILON)
		assert_float(tray.end.x / MM).is_equal_approx(slot.end.x - XboxShape.TRAY_GAP, EPSILON)
		# Flush with the strip's front, and still in the slot behind it.
		assert_float(tray.end.z / MM).is_equal_approx(-shape.strip().position.y, EPSILON)
		assert_float(-tray.position.z / MM).is_equal_approx(slot.end.y - XboxShape.TRAY_GAP, EPSILON)
		assert_float(tray.position.y / MM).is_equal_approx(shape.strip_bottom + XboxShape.TRAY_GAP, EPSILON)
		assert_float(tray.end.y / MM).is_equal_approx(shape.strip_top - XboxShape.TRAY_GAP, EPSILON)
		var ring := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"clamp_ring", detail)))
		var seat := shape.seat(0.0)
		assert_vector(Vector2(seat.origin.x, seat.origin.z)).is_equal_approx(
			Vector2(ring.get_center().x, ring.get_center().z), Vector2.ONE * EPSILON * MM)
		# On the ring, at the recess's floor under the plate's top.
		assert_float(seat.origin.y - ring.end.y).is_equal_approx(XboxShape.DISC_HALF_THICKNESS * MM, EPSILON * MM)
		assert_float(ring.end.y / MM).is_equal_approx(shape.plate_levels().y - DiscTray.RECESS_DEPTH, EPSILON)
		assert_vector(seat.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)


func test_open_the_tray_has_brought_its_disc_out_in_front_of_the_console_still_held_in_its_slot() -> void:
	var random := Fixtures.cases(91)
	for shape: XboxShape in Fixtures.accepted(self, SHAPES, _xbox.bind(random)):
		var travel := shape.tray_travel()
		var moved := random.randf_range(0.0, travel)
		var rest := shape.seat(0.0)
		assert_bool(shape.seat(moved).is_equal_approx(rest.translated(Vector3.BACK * moved * MM))).is_true()
		var front := shape.depth / 2.0
		assert_float(shape.seat(travel).origin.z / MM - shape.disc_radius).is_between(front, front + 5.0)
		# The plate's back, slid out, is still behind the strip's front.
		assert_float(shape.plate().end.y - travel).is_greater(shape.strip().position.y)


func test_the_slot_goes_through_the_strip_and_the_vents_lie_between_the_fins() -> void:
	var random := Fixtures.cases(92)
	for shape: XboxShape in Fixtures.accepted(self, SHAPES, _xbox.bind(random)):
		var detail := random.randi_range(16, 128)
		var slot := shape.slot().grow(-0.01)
		for triangle in Fixtures.triangles(shape.mesh_arrays(&"strip", detail)):
			var plan := PackedVector2Array()
			for corner in triangle:
				plan.append(Vector2(corner.x, -corner.z) / MM)
			assert_bool(Geometry2D.intersect_polygons(plan, ShapeGeometry.square(slot)).is_empty()) \
				.override_failure_message("the strip covers the slot at %s" % plan).is_true()
		var vents := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"vents", detail)))
		var fins := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"fins", detail)))
		assert_float(vents.position.y / MM).is_between(shape.lip_top, fins.end.y / MM)
		for fin in shape.fins():
			assert_bool(shape.wedges().any(func(wedge: PackedVector2Array) -> bool:
				return Geometry2D.clip_polygons(ShapeGeometry.square(fin.grow(-0.01)), wedge).is_empty())) \
				.override_failure_message("a fin sticks out of its wedge: %s" % fin).is_true()


func test_INV_E10_02_impossible_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(93)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(xbox: XboxShape) -> void: xbox.bezel_thickness = 0.0],
		[&"corner_rounds_the_bevel", func(xbox: XboxShape) -> void: xbox.corner = xbox.bevel],
		[&"layers_rise_holding_their_bevels", func(xbox: XboxShape) -> void:
			xbox.lip_top = xbox.strip_top + xbox.bevel],
		[&"layers_rise_holding_their_bevels", func(xbox: XboxShape) -> void: xbox.strip_bottom = XboxShape.FRONT_TOP],
		[&"strip_recessed", func(xbox: XboxShape) -> void: xbox.strip_recess = xbox.corner],
		[&"wedges_on_the_straight_sides", func(xbox: XboxShape) -> void: xbox.side_wedge.y = xbox.depth / 2.0],
		[&"wedges_on_the_straight_sides", func(xbox: XboxShape) -> void: xbox.side_wedge_apex.x = xbox.width],
		[&"wedges_apart", func(xbox: XboxShape) -> void: xbox.end_wedges.y = xbox.depth],
		[&"jewel_on_the_crossing", func(xbox: XboxShape) -> void: xbox.jewel_radius = xbox.ring_radius],
		[&"jewel_on_the_crossing", func(xbox: XboxShape) -> void: xbox.ring_radius = xbox.side_wedge_apex.x],
		[&"tray_in_its_slot", func(xbox: XboxShape) -> void: xbox.tray_span.x = -xbox.width / 2.0],
		[&"tray_in_its_slot", func(xbox: XboxShape) -> void: xbox.strip_top = xbox.strip_bottom + 4.0],
		[&"disc_fits_the_tray", func(xbox: XboxShape) -> void:
			xbox.disc_radius = (xbox.tray_span.y - xbox.tray_span.x) / 2.0],
		# Its recess a quarter of a millimetre into the walls each side.
		[&"disc_fits_the_tray", func(xbox: XboxShape) -> void:
			xbox.disc_radius = xbox.plate().size.x / 2.0 - DiscTray.RAIL.x - DiscTray.WALL - DiscTray.RECESS_ROOM + 0.25],
		[&"grilles_on_the_sides", func(xbox: XboxShape) -> void: xbox.grille_levels.y = xbox.lip_top],
		[&"grilles_on_the_sides", func(xbox: XboxShape) -> void: xbox.grille_length = xbox.depth],
		# No fin between the X's arms; a strip too low for the bezel's logo.
		[&"fins_in_the_side_wedges", func(xbox: XboxShape) -> void:
			xbox.fin_pitch = xbox.side_wedge.y - xbox.side_wedge.x + 1.0],
		[&"logo_on_the_bezel", func(xbox: XboxShape) -> void:
			xbox.strip_top = xbox.strip_bottom + XboxGeometry.LOGOS[&"bezel_logo"].y + 1.5],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _xbox.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])
	# Found by INV-E10-02's draws: a deep recess and a low strip, the bezel's logo coming out through the
	# shells above and below it.
	Fixtures.assert_found_refused(self, load("res://carousel/consoles/xbox/xbox_shape.tres") as ModelShape,
		&"logo_on_the_bezel", [{&"bevel": 1.8366411, &"bezel_thickness": 4.8394617438316345,
			&"cross_top": 86.97342577576637, &"foot_height": 3.2171011567115784, &"grille_pitch": 10.675070881843567,
			&"side_wedge_apex": Vector2(64.71398, 0.37447202), &"strip_recess": 10.211179465055466,
			&"strip_top": 59.333604514598846, &"width": 754.5154619216919}])


func test_the_tray_slides_its_disc_out_and_the_buttons_press_in() -> void:
	var console: XboxModel = auto_free(Fixtures.new_console(SCENE))
	add_child(console)
	var shape: XboxShape = console.shape
	var tray: Node3D = console.get_node("%Tray")
	var power: Node3D = console.get_node("%Power")
	var eject: Node3D = console.get_node("%Eject")
	var power_rest := power.position
	var eject_rest := eject.position
	for travel: float in [30.0, shape.tray_travel()]:
		console.tray_mm = travel
		assert_vector(tray.position).is_equal_approx(Vector3.BACK * travel * MM, Vector3.ONE * EPSILON * MM)
		assert_bool(console.seat().is_equal_approx(shape.seat(travel))).is_true()
	var pressed := Vector2(Fixtures.open_of(console, &"power_mm"), Fixtures.open_of(console, &"eject_mm"))
	console.power_mm = pressed.x
	console.eject_mm = pressed.y
	var near := Vector3.ONE * EPSILON * MM
	assert_vector(power.position).is_equal_approx(power_rest + Vector3.FORWARD * pressed.x * MM, near)
	assert_vector(eject.position).is_equal_approx(eject_rest + Vector3.FORWARD * pressed.y * MM, near)


## A shape drawn by [param random] around the measured one, each dimension from 0.8 to 1.2 times
## it, drawn again until its rules accept it.
static func _xbox(random: RandomNumberGenerator) -> XboxShape:
	return Fixtures.drawn_around(load("res://carousel/consoles/xbox/xbox_shape.tres") as ModelShape, random,
		Vector2(0.8, 1.2)) as XboxShape
