# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The GameCube's own looks: its lid notched round the buttons' collars over a shallow well, opening
## past upright, its buttons pushed into their collars.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded by each test, not preloaded: no console may be loaded before a library asks for it.
const SCENE := "res://carousel/consoles/gc/gc.tscn"
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 120
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_gamecube_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(80)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(gc: GcShape) -> void: gc.lid_gap = 0.0],
		[&"corner_rounds_the_bevel", func(gc: GcShape) -> void: gc.corner = gc.bevel],
		[&"blocks_hold_their_bevels", func(gc: GcShape) -> void: gc.seam = 2.0 * gc.bevel],
		[&"lid_corner_fits", func(gc: GcShape) -> void: gc.lid_corner = gc.lid_box().size.x],
		[&"collars_wider_than_their_gaps", func(gc: GcShape) -> void: gc.button_collar = GcShape.BUTTON_CLEARANCE],
		[&"lid_in_one_piece_round_the_collars", func(gc: GcShape) -> void: gc.button_radius = gc.lid_box().size.x],
		[&"collars_straddle_the_lid_s_edges", func(gc: GcShape) -> void:
			gc.power_inset = -gc.notch_radius() - gc.lid_gap - 1.0],
		[&"lid_and_collars_inside_the_top", func(gc: GcShape) -> void: gc.lid_sides.y = 0.0],
		[&"lid_and_collars_inside_the_top", func(gc: GcShape) -> void: gc.lid_ends.y = gc.bevel],
		[&"collars_apart_beside_the_well", func(gc: GcShape) -> void:
			gc.power_inset = gc.lid_box().size.y - gc.button_inset - gc.notch_radius()],
		[&"collars_apart_beside_the_well", func(gc: GcShape) -> void:
			gc.seat_centre.x = gc.buttons()[&"open"].x - gc.notch_radius()],
		[&"lid_clears_the_disc", func(gc: GcShape) -> void: gc.lid_thickness = gc.seat_depth],
		# A lid so thick it would swing back through the top behind it.
		[&"lid_clears_the_top_behind_it", func(gc: GcShape) -> void: gc.lid_thickness = 2.0 * gc.lid_gap + 2.1],
		[&"floor_above_the_base", func(gc: GcShape) -> void: gc.seat_depth = gc.height - gc.seam],
		[&"disc_under_the_ledge", func(gc: GcShape) -> void:
			gc.seat_depth = GcShape.BUTTON_DEPTH + GcShape.LEDGE.y + 1.0],
		[&"disc_and_drive_in_the_well", func(gc: GcShape) -> void: gc.disc_radius = gc.lid_box().size.x / 2.0],
		# The recess fits before the lid's front edge, the ledge round it does not.
		[&"disc_and_drive_in_the_well", func(gc: GcShape) -> void:
			gc.seat_centre.y = gc.lid_box().position.y + gc.disc_radius + GcShape.DRIVE_MARGIN + 1.0],
		[&"lid_opens_behind_the_disc", func(gc: GcShape) -> void:
			gc.seat_centre.y = gc.lid_box().end.y - gc.lid_thickness - gc.disc_radius],
		[&"dimple_on_the_lid", func(gc: GcShape) -> void: gc.dimple_radius = gc.lid_box().size.x / 2.0 + 1.0],
		[&"dimple_on_the_lid", func(gc: GcShape) -> void: gc.dimple_centre.y = gc.lid_box().size.y / 2.0],
		[&"lamp_before_the_lid", func(gc: GcShape) -> void: gc.lid_ends.x = gc.bevel],
		[&"panel_on_the_front", func(gc: GcShape) -> void: gc.panel_lift = 0.0],
		[&"panel_on_the_front", func(gc: GcShape) -> void: gc.panel_size.y = gc.height],
		[&"panel_on_the_front", func(gc: GcShape) -> void: gc.panel_size.x = gc.width],
		[&"vents_on_the_sides", func(gc: GcShape) -> void: gc.vent_centre.x = gc.depth / 2.0],
		[&"handle_behind_the_back", func(gc: GcShape) -> void: gc.handle_reach = GcShape.HANDLE_THICKNESS],
		[&"handle_behind_the_back", func(gc: GcShape) -> void: gc.handle_reach = gc.handle_span() / 2.0],
		[&"handle_behind_the_back", func(gc: GcShape) -> void: gc.handle_band.x = 0.0],
		[&"handle_behind_the_back", func(gc: GcShape) -> void: gc.handle_band.y = gc.height],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _gc.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_wide_or_broadly_bevelled_gamecubes_found_open_once_are_closed() -> void:
	# A body cut in two across its well, its crossing a hair off the cut on so wide a console; a block
	# whose face stood a hair beside its bevel's last outline.
	var found: Array[Dictionary] = [
		{&"width": 396.19109630584717, &"corner": 8.304169, &"lid_sides": Vector2(16.112717, 14.847775),
			&"lid_gap": 0.7254889488220215, &"lid_corner": 3.3571590185165405, &"seat_centre": Vector2(0, -8.189602),
			&"handle_band": Vector2(11.682035, 27.25861)},
		{&"width": 489.54176902770996, &"height": 103.12081694602966, &"corner": 3.6864517,
			&"seam": 21.908543676137924, &"lid_sides": Vector2(16.073338, 24.627815),
			&"lid_ends": Vector2(10.22398, 4.9128394), &"lid_gap": 0.8446582794189453,
			&"panel_size": Vector2(116.08836, 56.978134), &"panel_lift": 2.879207968711853,
			&"vent_centre": Vector2(4.3035192, 58.29061), &"handle_band": Vector2(12.074468, 25.19032)},
		{&"bevel": 2.7038535475730896, &"lid_ends": Vector2(16.966394, 4.891133),
			&"lid_thickness": 2.823132812976837, &"disc_radius": 36.012135, &"dimple_radius": 44.94289457798004,
			&"panel_lift": 1.76864093542099, &"handle_reach": 31.378272771835327},
	]
	var console: GcModel = auto_free(Fixtures.new_console(SCENE))
	for dimensions in found:
		var shape: GcShape = console.shape.duplicate()
		for dimension: StringName in dimensions:
			shape.set(dimension, dimensions[dimension])
		assert_array(shape.problems()).is_empty()
		for part in shape.parts():
			if part in shape.surfaces():
				continue
			for detail: int in [16, 64]:
				var meshes: Array[Array] = [shape.mesh_arrays(part, detail)]
				assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s at %d" % [part, detail]) \
					.is_empty()


func test_closed_the_lid_fills_its_opening_but_its_gap_and_clears_each_collar_by_it() -> void:
	var random := Fixtures.cases(81)
	for shape: GcShape in Fixtures.accepted(self, SHAPES, _gc.bind(random)):
		var detail := random.randi_range(16, 128)
		var lid := Fixtures.points(shape.mesh_arrays(&"lid", detail))
		var box := AABB()
		var nearest := INF
		for k in lid.size():
			var at := (lid[k] + shape.hinge()) / MM
			box = AABB(at, Vector3.ZERO) if k == 0 else box.expand(at)
			for centre: Vector2 in shape.buttons().values():
				nearest = minf(nearest, Vector2(at.x, -at.z).distance_to(centre))
		assert_float(nearest).is_greater_equal(shape.notch_radius() + shape.lid_gap - EPSILON)
		var plan := Rect2(box.position.x, -box.end.z, box.size.x, box.size.z)
		assert_vector(plan.position).is_equal_approx(shape.lid_box().position, Vector2.ONE * EPSILON)
		assert_vector(plan.end).is_equal_approx(shape.lid_box().end, Vector2.ONE * EPSILON)
		assert_vector(Vector2(box.position.y, box.end.y)).is_equal_approx(
			Vector2(shape.height - shape.lid_thickness, shape.height), Vector2.ONE * EPSILON)
		# Each button stands in its collar's hole, which the collar's ring surrounds.
		var reach := 0.0
		for part: StringName in shape.buttons():
			var centre: Vector2 = shape.buttons()[part]
			for point in Fixtures.points(shape.mesh_arrays(part, detail)):
				reach = maxf(reach, Vector2(point.x, -point.z).distance_to(centre * MM) / MM)
		assert_float(reach).is_less_equal(shape.button_radius + EPSILON)
		var ring := Vector2(INF, 0.0)
		for point in Fixtures.points(shape.mesh_arrays(&"collars", detail)):
			var from := Vector2(point.x, -point.z) / MM
			var nearest_centre: float = shape.buttons().values().map(func(at: Vector2) -> float:
				return from.distance_to(at)).min()
			ring = Vector2(minf(ring.x, nearest_centre), maxf(ring.y, nearest_centre))
		assert_float(ring.x).is_greater_equal(shape.button_radius + GcShape.BUTTON_CLEARANCE - EPSILON)
		assert_float(ring.y).is_less_equal(shape.notch_radius() + EPSILON)


func test_under_the_lid_the_well_steps_down_from_the_shelf_to_a_ledge_then_the_recess_of_the_disc() -> void:
	var random := Fixtures.cases(82)
	var steps_seen: Dictionary[int, bool] = {}
	for i in SHAPES >> 2:
		var shape := _gc(random)
		var detail := random.randi_range(16, 128)
		var body := Fixtures.triangles(shape.mesh_arrays(&"body", detail))
		var lid := shape.lid_outline(ShapeGeometry.corner_steps(detail))
		var recess := shape.disc_radius + GcShape.DRIVE_MARGIN
		var ledge := recess + GcShape.LEDGE.x
		# The shelf, the ledge round the recess, and in it the well's floor, the drive's plate.
		var shelf := shape.height - GcShape.BUTTON_DEPTH
		var steps: Array[float] = [shelf, shelf - GcShape.LEDGE.y,
			shape.height - shape.seat_depth - GcShape.TURNTABLE_DEPTH]
		var step_at := func(spot: Vector2) -> int:
			var from_seat := spot.distance_to(shape.seat_centre)
			return 2 if from_seat < recess else 1 if from_seat < ledge else 0
		var spots: Array[Vector2] = [shape.seat_centre]
		var room := shape.lid_box()
		while spots.size() < 12:
			var spot := Vector2(random.randf_range(room.position.x, room.end.x),
				random.randf_range(room.position.y, room.end.y))
			var from_seat := spot.distance_to(shape.seat_centre)
			# Clear of the steps' edges, which their outlines' sides cut across.
			if Geometry2D.is_point_in_polygon(spot, lid) and absf(from_seat - recess) > 0.5 \
					and absf(from_seat - ledge) > 0.5:
				spots.append(spot)
		for spot in spots:
			var covering := body.filter(func(triangle: PackedVector3Array) -> bool:
				var plan := PackedVector2Array()
				for corner in triangle:
					plan.append(Vector2(corner.x, -corner.z) / MM)
				return Geometry2D.point_is_inside_triangle(spot, plan[0], plan[1], plan[2]))
			var heights := covering.map(func(triangle: PackedVector3Array) -> float: return triangle[0].y / MM)
			# Under the lid, the body has the base's floor below and the well's step there, nothing above it.
			assert_float(heights.max()).override_failure_message("covered at %s" % spot) \
				.is_equal_approx(steps[step_at.call(spot)], EPSILON)
			steps_seen[step_at.call(spot)] = true
		var seat := shape.seat()
		assert_vector(seat.origin / MM).is_equal_approx(
			Vector3(shape.seat_centre.x, shape.height - shape.seat_depth, -shape.seat_centre.y), Vector3.ONE * EPSILON)
		assert_vector(seat.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
	assert_array(steps_seen.keys()).contains_exactly_in_any_order([0, 1, 2])
	var console: GcModel = auto_free(Fixtures.new_console(SCENE))
	add_child(console)
	var spindle: Spindle = console.get_node("%Spindle")
	assert_bool(spindle.transform.is_equal_approx(console.seat())).is_true()
	# The spindle's turntable stands on the drive's plate, its motor under it.
	var plate: MeshInstance3D = console.get_node("Well")
	var turntable: MeshInstance3D = spindle.get_node("Rotor/Turntable")
	var motor: MeshInstance3D = spindle.get_node("Motor")
	var floor_height := Fixtures.box_of(console, plate).position.y
	assert_float(Fixtures.box_of(console, turntable).position.y).is_equal_approx(floor_height, 0.1 * MM)
	assert_float(Fixtures.box_of(console, motor).end.y).is_less(floor_height)


func test_the_lid_opens_upwards_about_its_back_edge_past_upright_never_over_the_well() -> void:
	var console: GcModel = auto_free(Fixtures.new_console(SCENE))
	add_child(console)
	var shape: GcShape = console.shape
	var cover: MeshInstance3D = console.get_node("%Lid/Cover")
	var lid := shape.lid_box()
	var hinge := shape.hinge() / MM
	for degrees: float in [20.0, 60.0, 90.0, GcShape.OPEN_DEGREES]:
		console.lid_degrees = degrees
		var open := Fixtures.box_of(console, cover)
		var rise := lid.size.y * sin(deg_to_rad(degrees))
		assert_float(open.end.y / MM).is_between(shape.height + rise - shape.lid_thickness,
			shape.height + rise + shape.lid_thickness)
		# Its back edge stays where it is hinged; the rest of it never comes forward of it once upright.
		assert_float(-open.position.z / MM).is_between(lid.end.y - shape.lid_thickness, lid.end.y + lid.size.y)
		if degrees >= 90.0:
			assert_float(open.end.z / MM).is_less_equal(hinge.z + shape.lid_thickness)
	assert_float(GcShape.OPEN_DEGREES).is_greater(90.0)


func test_the_power_and_open_buttons_go_into_their_collars_the_reset_stays() -> void:
	var console: GcModel = auto_free(Fixtures.new_console(SCENE))
	add_child(console)
	var shape: GcShape = console.shape
	var buttons: Dictionary[StringName, MeshInstance3D] = {}
	var resting: Dictionary[StringName, AABB] = {}
	for part: StringName in shape.buttons():
		buttons[part] = console.get_node(String(part).capitalize())
		resting[part] = Fixtures.box_of(console, buttons[part])
	var pressed := {&"power": Fixtures.open_of(console, &"power_mm"), &"open": Fixtures.open_of(console, &"open_mm"),
		&"reset": 0.0}
	console.power_mm = pressed[&"power"]
	console.open_mm = pressed[&"open"]
	for part in buttons:
		var pushed := Fixtures.box_of(console, buttons[part])
		var was := resting[part]
		var sunk: float = pressed[part]
		assert_vector(pushed.position - was.position).is_equal_approx(Vector3.DOWN * sunk * MM, Vector3.ONE * EPSILON * MM)
		assert_float(was.end.y / MM).is_equal_approx(shape.height + GcShape.BUTTON_RAISE, EPSILON)


## A GameCube [param random] draws that [method GcShape.problems] accepts: the shipped one from small
## to large, its gaps, collars, corners and bevel anywhere from thin to wide, its seat moved about;
## the last drawn after a hundred draws.
static func _gc(random: RandomNumberGenerator) -> GcShape:
	var shape := GcShape.new()
	for attempt in 100:
		shape = GcShape.new()
		var scale := random.randf_range(0.8, 1.4)
		for dimension in shape.dimensions():
			var value: Variant = shape.get(dimension)
			shape.set(dimension, value * scale)
		shape.lid_gap = random.randf_range(0.05, 2.0)
		shape.button_collar = random.randf_range(GcShape.BUTTON_CLEARANCE + 0.21, 4.0)
		shape.lid_corner = random.randf_range(0.11, 12.0)
		shape.bevel = random.randf_range(0.2, 3.0)
		shape.lid_thickness = random.randf_range(0.5, 5.0)
		shape.seat_depth = random.randf_range(GcShape.BUTTON_DEPTH + GcShape.LEDGE.y + 1.1, 14.0)
		shape.seat_centre += Vector2(random.randf_range(-4.0, 4.0), random.randf_range(-4.0, 4.0))
		if shape.problems().is_empty():
			break
	return shape
