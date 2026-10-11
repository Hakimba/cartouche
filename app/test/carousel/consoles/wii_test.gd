# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Wii's own looks: a seated disc stands behind the slot's gap, edge on to it, its label to the
## right, and comes out through it; the SD door closes its opening flush and swings open clear of the
## front's other parts; the buttons press in, the slot glows; it is shown standing, its front and its
## right side towards the camera; the dimensions it cannot be built from are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SCENE := "res://carousel/consoles/wii/wii.tscn"
const MEASURED := "res://carousel/consoles/wii/wii_shape.tres"
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 150
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_a_seated_disc_stands_upright_behind_the_gap_its_label_to_the_right_and_comes_out_through_it() -> void:
	var random := Fixtures.cases(110)
	var console: WiiModel = auto_free(Fixtures.new_console(SCENE))
	for shape: WiiShape in Fixtures.accepted(self, SHAPES, _wii.bind(random)):
		var detail := random.randi_range(16, 128)
		var gap := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"gap", detail)))
		var front := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"front", detail)))
		var body := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"body", detail)))
		console.shape = shape
		var seat := console.seat()
		assert_vector(seat.basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * EPSILON)
		assert_vector(seat.basis * console.approach()).is_equal_approx(Vector3.BACK, Vector3.ONE * EPSILON)
		# Edge on to the gap, the whole disc within its height, and behind the front panel.
		var radius := shape.disc_radius * MM
		assert_float(seat.origin.x).is_between(gap.position.x, gap.end.x)
		assert_float(seat.origin.y - radius).is_greater(gap.position.y)
		assert_float(seat.origin.y + radius).is_less(gap.end.y)
		assert_float(seat.origin.z + radius).is_less(front.position.z + shape.front_bevel * MM)
		assert_float(seat.origin.z - radius).is_greater(body.position.z)
		# The gap opens on the front, below the rim's top.
		var rim := Fixtures.bounds(Fixtures.points(shape.mesh_arrays(&"rim", detail)))
		assert_float(gap.end.z).is_between(front.end.z, rim.end.z)


func test_the_sd_door_closes_its_opening_flush_and_swings_open_clear_of_the_front_s_other_parts() -> void:
	var random := Fixtures.cases(111)
	for i in 12:
		var console: WiiModel = Fixtures.built(self, SCENE, _wii(random))
		var shape: WiiShape = console.shape
		var door: MeshInstance3D = console.get_node("%Door/Panel")
		var closed := Fixtures.box_of(console, door)
		var opening := shape.door_opening().grow(-WiiShape.DOOR_GAP)
		assert_vector(Vector2(closed.position.x, closed.position.y) / MM).is_equal_approx(opening.position,
			Vector2.ONE * EPSILON)
		assert_vector(Vector2(closed.end.x, closed.end.y) / MM).is_equal_approx(opening.end, Vector2.ONE * EPSILON)
		assert_float(closed.end.z / MM).is_equal_approx(shape.depth / 2.0, EPSILON)
		console.door_degrees = WiiShape.DOOR_SWING
		var opened := Fixtures.box_of(console, door)
		assert_float(opened.end.z / MM).is_greater(shape.depth / 2.0 + shape.door().size.x * 0.9)
		assert_float(opened.end.x).is_less_equal(closed.position.x + WiiShape.DOOR_THICKNESS * MM)
		for other: String in ["Rim", "Reset", "%Power/Cap", "%Eject/Cap"]:
			var part: MeshInstance3D = console.get_node(other)
			assert_bool(opened.intersects(Fixtures.box_of(console, part))).override_failure_message(
				"the open door meets %s" % other).is_false()


func test_the_buttons_press_in() -> void:
	var console: WiiModel = Fixtures.built(self, SCENE, load(MEASURED) as ModelShape)
	var power: Node3D = console.get_node("%Power")
	var eject: Node3D = console.get_node("%Eject")
	var power_rest := power.position
	var eject_rest := eject.position
	var pressed := Vector2(Fixtures.open_of(console, &"power_mm"), Fixtures.open_of(console, &"eject_mm"))
	console.power_mm = pressed.x
	console.eject_mm = pressed.y
	var near := Vector3.ONE * EPSILON * MM
	assert_vector(power.position).is_equal_approx(power_rest + Vector3.FORWARD * pressed.x * MM, near)
	assert_vector(eject.position).is_equal_approx(eject_rest + Vector3.FORWARD * pressed.y * MM, near)


func test_it_is_shown_standing_its_front_and_its_right_side_towards_the_camera() -> void:
	var console: WiiModel = auto_free(Fixtures.new_console(SCENE))
	var facing := console.presented()
	assert_vector(facing * Vector3.UP).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
	assert_float((facing * Vector3.BACK).z).is_greater(0.5)
	assert_float((facing * Vector3.RIGHT).z).is_greater(0.3)


func test_INV_E10_02_impossible_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(112)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(wii: WiiShape) -> void: wii.plate_thickness = 0.0],
		# Buttons narrower than their corners; a door narrower than its sync button; a slot turned inside
		# out.
		[&"sizes_positive", func(wii: WiiShape) -> void: wii.button_size.x = 2.0 * WiiShape.BUTTON_CORNER],
		[&"front_parts_apart", func(wii: WiiShape) -> void: wii.door_x.y = wii.door_x.x + 3.5],
		[&"front_parts_apart", func(wii: WiiShape) -> void: wii.slot_span = Vector2(wii.slot_span.y, wii.slot_span.x)],
		[&"edges_round", func(wii: WiiShape) -> void: wii.front_bevel = wii.corner],
		[&"blocks_hold_their_bevels", func(wii: WiiShape) -> void: wii.front_depth = WiiShape.DOOR_WELL],
		[&"panels_on_the_flat_sides", func(wii: WiiShape) -> void: wii.panel_inset = wii.corner],
		[&"slot_on_the_front", func(wii: WiiShape) -> void: wii.slot_gap = wii.slot_rim - 2.0 * WiiShape.RIM_BEVEL],
		[&"disc_through_the_slot", func(wii: WiiShape) -> void: wii.disc_radius = wii.slot().size.y / 2.0],
		[&"disc_through_the_slot", func(wii: WiiShape) -> void: wii.disc_depth = wii.depth - wii.back_depth],
		[&"front_parts_apart", func(wii: WiiShape) -> void: wii.slot_x = wii.door().get_center().x],
		[&"front_parts_apart", func(wii: WiiShape) -> void:
			wii.buttons_from_top.y = (wii.door_span.x + wii.door_span.y) / 2.0],
		[&"front_parts_apart", func(wii: WiiShape) -> void: wii.slot_span.y = wii.height],
		[&"flaps_on_the_top", func(wii: WiiShape) -> void: wii.controller_flap.x = wii.memory_flap.y],
		# A flap shorter than its rounded corners.
		[&"flaps_on_the_top", func(wii: WiiShape) -> void: wii.memory_flap.y = wii.memory_flap.x + 2.1],
		[&"stand_wraps_the_foot", func(wii: WiiShape) -> void:
			wii.stand_wall = WiiShape.STAND_BEVEL + WiiShape.STAND_GAP],
		[&"stand_wraps_the_foot", func(wii: WiiShape) -> void:
			wii.stand_sink = wii.height - wii.buttons_from_top.z],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _wii.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])
	# Found by INV-E10-02's draws: the console's name sunk behind the stand.
	Fixtures.assert_found_refused(self, load(MEASURED) as ModelShape, &"stand_wraps_the_foot", [
		{&"corner": 3.4737122, &"depth": 230.56606477499008, &"door_span": Vector2(47.231945, 106.269844),
			&"height": 152.8785057067871, &"memory_flap": Vector2(12.538035, 75.817505),
			&"panel_inset": 4.2972255, &"slot_rim": 7.1213007, &"stand_height": 33.798447012901306},
		{&"buttons_from_top": Vector3(16.757513, 30.515541, 144.08965), &"buttons_x": -10.759145617485046,
			&"door_span": Vector2(47.60142, 105.5103), &"panel_inset": 3.5200036764144897,
			&"width": 46.11699116230011},
	])


## A shape drawn by [param random] around the measured one, each dimension from 0.8 to 1.2 times
## it, drawn again until its rules accept it.
static func _wii(random: RandomNumberGenerator) -> WiiShape:
	return Fixtures.drawn_around(load(MEASURED) as ModelShape, random, Vector2(0.8, 1.2)) as WiiShape
