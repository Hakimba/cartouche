# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 200
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E5_07_a_console_is_closed_part_by_part_its_faces_turned_outwards() -> void:
	var random := Fixtures.cases(50)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		var detail := random.randi_range(16, 128)
		for part: StringName in [&"slabs", &"dark", &"lid", &"lid_ribs", &"well", &"sled", &"lens", &"flex", &"label_plate"]:
			var meshes: Array[Array] = [shape.mesh_arrays(part, detail)]
			assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s is open" % part).is_empty()
			var volumes := Fixtures.volumes(meshes)
			assert_int(volumes.size()).is_greater(0)
			for volume in volumes:
				assert_float(volume).is_greater(0.0)


func test_INV_E5_07_closed_the_lid_fills_its_opening_but_its_gap_and_the_disc_sits_over_the_well() -> void:
	var random := Fixtures.cases(51)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, Fixtures.ps2_slim.bind(random)):
		var detail := random.randi_range(16, 128)
		# The lid is given about its hinge: put back where it closes.
		var lid := _plan_box(shape.mesh_arrays(&"lid", detail), shape.hinge())
		assert_vector(lid.position).is_equal_approx(shape.lid_box().position, Vector2.ONE * EPSILON)
		assert_vector(lid.end).is_equal_approx(shape.lid_box().end, Vector2.ONE * EPSILON)
		var well := _plan_box(shape.mesh_arrays(&"well", detail), Vector3.ZERO)
		assert_vector(well.position).is_equal_approx(shape.opening().position, Vector2.ONE * EPSILON)
		assert_vector(well.end).is_equal_approx(shape.opening().end, Vector2.ONE * EPSILON)
		var seat := shape.seat()
		assert_vector(seat.origin / MM).is_equal_approx(
			Vector3(shape.lid_centre.x, shape.seat_height, -shape.lid_centre.y), Vector3.ONE * EPSILON)
		assert_vector(seat.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		var hinge := shape.hinge() / MM
		assert_float(hinge.y).is_equal_approx(shape.height - shape.lid_thickness / 2.0, EPSILON)
		assert_float(hinge.z).is_equal_approx(-shape.lid_box().end.y, EPSILON)


func test_INV_E5_07_the_ps2_s_lid_opens_upwards_about_its_back_edge_over_the_well_its_disc_sits_in() -> void:
	var console: Ps2SlimModel = auto_free(Fixtures.new_console(Fixtures.PS2_SLIM))
	add_child(console)
	var shape: Ps2SlimShape = console.shape
	var well_part: MeshInstance3D = console.get_node("Well")
	var well := Fixtures.box_of(console, well_part)
	var seat := console.seat()
	var spindle: Spindle = console.get_node("%Spindle")
	assert_bool(spindle.transform.is_equal_approx(seat)).is_true()
	assert_vector(Vector2(seat.origin.x, seat.origin.z)).is_equal_approx(
		Vector2(well.get_center().x, well.get_center().z), Vector2.ONE * EPSILON * MM)
	assert_float(seat.origin.y).is_between(shape.seam * MM, shape.height * MM)
	assert_vector(seat.basis.z.normalized()).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
	var cover: MeshInstance3D = console.get_node("%Lid/Cover")
	var closed := Fixtures.box_of(console, cover)
	var lid := shape.lid_box()
	assert_vector(Vector2(closed.position.x, -closed.end.z) / MM).is_equal_approx(lid.position, Vector2.ONE * EPSILON)
	assert_vector(Vector2(closed.end.x, -closed.position.z) / MM).is_equal_approx(lid.end, Vector2.ONE * EPSILON)
	assert_float(closed.end.y / MM).is_equal_approx(shape.height, EPSILON)
	for degrees: float in [15.0, 45.0, 88.0, 120.0]:
		console.lid_degrees = degrees
		var open := Fixtures.box_of(console, cover)
		var rise := lid.size.y * sin(deg_to_rad(degrees))
		# Its front rises, its back edge stays where it is hinged (up to upright, then the lid leans back).
		assert_float(open.end.y / MM).is_between(shape.height + rise * 0.95, shape.height + rise + shape.lid_thickness)
		if degrees <= 90.0:
			assert_float(-open.position.z / MM).is_between(lid.end.y - shape.lid_thickness, lid.end.y + shape.lid_thickness)


func test_INV_E5_07_impossible_console_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(52)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(console: Ps2SlimShape) -> void: console.lid_gap = 0.0],
		[&"corner_rounds_the_bevel", func(console: Ps2SlimShape) -> void: console.corner = console.bevel],
		[&"blocks_hold_their_bevels", func(console: Ps2SlimShape) -> void: console.seam = 2.0 * console.bevel],
		[&"lid_inside_the_top", func(console: Ps2SlimShape) -> void: console.lid_centre.x = console.body().end.x],
		[&"lid_inside_the_top", func(console: Ps2SlimShape) -> void:
			console.lid_centre = console.body().end - console.lid_size / 2.0],
		# Corners so round that the opening's reach past their centres: the top's face would fold.
		[&"lid_inside_the_top", func(console: Ps2SlimShape) -> void:
			console.corner = minf(console.width, console.depth) / 2.0 - 0.05],
		[&"lid_corner_fits", func(console: Ps2SlimShape) -> void: console.lid_corner = console.lid_size.x],
		[&"lid_thin_enough", func(console: Ps2SlimShape) -> void: console.lid_thickness = console.height],
		[&"disc_turns_in_the_well", func(console: Ps2SlimShape) -> void: console.disc_radius = console.lid_size.y],
		[&"seat_between_floor_and_lid", func(console: Ps2SlimShape) -> void: console.seat_height = console.seam],
		[&"seat_between_floor_and_lid", func(console: Ps2SlimShape) -> void: console.seat_height = console.height],
		[&"strip_on_the_top_beside_the_lid", func(console: Ps2SlimShape) -> void: console.strip_x = console.lid_centre.x],
		[&"strip_on_the_top_beside_the_lid", func(console: Ps2SlimShape) -> void: console.strip_raise = 0.0],
		[&"strip_on_the_top_beside_the_lid", func(console: Ps2SlimShape) -> void: console.strip_length = console.depth],
		[&"base_under_the_lid_s_side", func(console: Ps2SlimShape) -> void: console.base_inset.y = console.width],
		[&"base_under_the_lid_s_side", func(console: Ps2SlimShape) -> void: console.base_inset.x = 0.0],
		[&"grooves_sizes_positive", func(console: Ps2SlimShape) -> void:
			console.groove_pitch = console.groove_height],
		[&"grooves_sizes_positive", func(console: Ps2SlimShape) -> void: console.groove_depth = 0.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, Fixtures.ps2_slim.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_INV_E5_07_the_lid_s_opening_goes_through_the_top_down_to_the_well() -> void:
	var random := Fixtures.cases(53)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		# Inside the opening's rounded outline, a hair in from it.
		var rounding := shape.lid_corner + shape.lid_gap
		var core := shape.opening().grow(-rounding)
		var detail := random.randi_range(16, 128)
		# The slabs, and the grooves' backs above the well's floor.
		var above_the_floor := func(triangle: PackedVector3Array) -> bool:
			return Array(triangle).all(func(corner: Vector3) -> bool: return corner.y / MM > shape.seam + 0.01)
		var covering: Array[PackedVector3Array] = Fixtures.triangles(shape.mesh_arrays(&"slabs", detail))
		covering.append_array(Fixtures.triangles(shape.mesh_arrays(&"dark", detail)).filter(above_the_floor))
		for triangle in covering:
			for corner in triangle:
				var at := corner / MM
				var plan := Vector2(at.x, -at.z)
				var inside := plan.distance_to(plan.clamp(core.position, core.end)) < rounding - 0.01
				assert_bool(inside).override_failure_message("the top covers the opening at %s" % at).is_false()
		# Nor does any of their faces, seen from above.
		var through: Array[Vector2] = [core.get_center()]
		for k in 4:
			through.append(Vector2(random.randf_range(core.position.x, core.end.x), random.randf_range(core.position.y, core.end.y)))
		for triangle in covering:
			var plan := PackedVector2Array()
			for corner in triangle:
				plan.append(Vector2(corner.x, -corner.z) / MM)
			for spot in through:
				assert_bool(Geometry2D.point_is_inside_triangle(spot, plan[0], plan[1], plan[2])) \
					.override_failure_message("the top covers the opening at %s" % spot).is_false()


func test_the_drive_lies_under_a_seated_disc_and_the_closed_lid_s_ribs_over_it() -> void:
	var random := Fixtures.cases(57)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		var detail := random.randi_range(16, 64)
		var underside := shape.seat_height - Ps2SlimGeometry._DISC_HALF_THICKNESS
		var over := func(point: Vector3) -> bool:
			return Vector2(point.x, -point.z).distance_to(shape.lid_centre) < shape.disc_radius
		for part: StringName in [&"well", &"sled", &"lens", &"flex", &"label_plate"]:
			var under := Array(Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * Fixtures.points(
				shape.mesh_arrays(part, detail))).filter(over)
			# The cable, back under the bridge, may lie beyond a small disc.
			if part != &"flex":
				assert_array(under).override_failure_message("no %s under the disc" % part).is_not_empty()
			var highest: float = under.reduce(func(top: float, point: Vector3) -> float: return maxf(top, point.y), -INF)
			assert_float(highest).override_failure_message("%s reaches the disc" % part).is_less(underside)
		# The lid's ribs, closed: about its hinge, put back where it closes.
		var ribs := Array(Transform3D(Basis.from_scale(Vector3.ONE / MM), shape.hinge() / MM) * Fixtures.points(
			shape.mesh_arrays(&"lid_ribs", detail))).filter(over)
		assert_array(ribs).is_not_empty()
		var heights := ribs.map(func(point: Vector3) -> float: return point.y)
		var lowest: float = heights.min()
		var highest: float = heights.max()
		assert_float(lowest).is_greater(underside + 2.0 * Ps2SlimGeometry._DISC_HALF_THICKNESS)
		assert_float(highest).is_less(shape.height)


func test_the_grooves_run_around_the_slabs_from_under_the_top_leaving_each_slab_its_bevels() -> void:
	var random := Fixtures.cases(54)
	var grooved := 0
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		var grooves := shape.grooves()
		var holds := 2.0 * shape.bevel + 0.1
		assert_int(grooves.size()).is_less_equal(shape.groove_count)
		for k in grooves.size():
			# From the top down: under the lid's thickness, then a pitch further down each time.
			var groove := grooves[grooves.size() - 1 - k]
			assert_float(groove.y).is_equal_approx(shape.height - shape.lid_thickness - k * shape.groove_pitch, EPSILON)
			assert_float(groove.y - groove.x).is_equal_approx(shape.groove_height, EPSILON)
		var low := shape.seam
		for groove in grooves:
			assert_float(groove.x - low).is_greater_equal(holds)
			low = groove.y
		assert_float(shape.height - low).is_greater_equal(holds)
		# One more would leave a slab too thin, unless they stopped short of the opening.
		if not grooves.is_empty() and grooves.size() < shape.groove_count:
			var top := shape.height - shape.lid_thickness - grooves.size() * shape.groove_pitch
			var below := top - shape.groove_height - shape.seam
			assert_bool(below < holds or shape.groove_pitch - shape.groove_height < holds).is_true()
		var detail := random.randi_range(16, 64)
		var slabs := Fixtures.points(shape.mesh_arrays(&"slabs", detail))
		var dark := Fixtures.points(shape.mesh_arrays(&"dark", detail))
		for groove in grooves:
			var within := func(point: Vector3) -> bool:
				return point.y / MM > groove.x + 0.01 and point.y / MM < groove.y - 0.01
			assert_bool(Array(slabs).any(within)).override_failure_message("a slab across a groove").is_false()
			# The groove's back, as far in as its depth, all around.
			var back := Array(dark).filter(within)
			var reach := 0.0
			for point: Vector3 in back:
				reach = maxf(reach, point.x / MM)
			assert_float(reach).is_equal_approx(shape.body().end.x - shape.groove_depth, EPSILON)
		grooved += 1 if not grooves.is_empty() else 0
	assert_int(grooved).is_between(40, SHAPES - 10)


func test_grooves_that_would_reach_the_lid_s_opening_are_all_left_out() -> void:
	var random := Fixtures.cases(55)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		var body := shape.body()
		var opening := shape.opening()
		var rim := minf(minf(opening.position.x - body.position.x, body.end.x - opening.end.x),
			minf(opening.position.y - body.position.y, body.end.y - opening.end.y))
		shape.groove_depth = random.randf_range(rim, rim + 5.0)
		assert_array(shape.problems()).is_empty()
		assert_array(shape.grooves()).is_empty()


func test_the_base_is_set_back_under_the_lid_s_side_and_reaches_the_edges_on_the_other() -> void:
	var random := Fixtures.cases(56)
	for shape: Ps2SlimShape in Fixtures.accepted(self, SHAPES, _drawn.bind(random)):
		var body := shape.body()
		var inset := shape.base_inset
		var side := shape.opening().position.x
		var base := Array(Fixtures.points(shape.mesh_arrays(&"dark", 32))).filter(
			func(point: Vector3) -> bool: return point.y / MM < shape.seam + EPSILON)
		var plan := Rect2()
		for k in base.size():
			var at: Vector3 = base[k] / MM
			var spot := Vector2(at.x, -at.z)
			plan = Rect2(spot, Vector2.ZERO) if k == 0 else plan.expand(spot)
			if spot.x > side + EPSILON:
				assert_float(spot.y).is_between(body.position.y + inset.x - EPSILON, body.end.y - inset.z + EPSILON)
		assert_vector(plan.position).is_equal_approx(body.position, Vector2.ONE * EPSILON)
		assert_vector(plan.end).is_equal_approx(Vector2(body.end.x - inset.y, body.end.y), Vector2.ONE * EPSILON)


func test_the_disc_marks_stay_on_a_lid_too_narrow_for_them_smaller() -> void:
	var shape := Ps2SlimShape.new()
	shape.disc_radius = 30.0
	shape.lid_size.x = 64.0
	assert_array(shape.problems()).is_empty()
	var marks := _plan_box(shape.mesh_arrays(&"disc_marks", 32), shape.hinge())
	assert_bool(shape.lid_box().encloses(marks)).is_true()
	assert_float(marks.size.x).is_less(Ps2SlimGeometry.LOGOS[&"disc_marks"].x)


## A PS2 slim [param random] draws that its rules accept, its grooves and its base drawn too: from
## none to five grooves, thin to thick, shallow to deep; the base barely or far set back.
static func _drawn(random: RandomNumberGenerator) -> Ps2SlimShape:
	var shape := Fixtures.ps2_slim(random)
	shape.groove_count = random.randi_range(0, 5)
	shape.groove_height = random.randf_range(0.2, 2.0)
	shape.groove_pitch = shape.groove_height + random.randf_range(0.1, 6.0)
	shape.groove_depth = random.randf_range(0.05, 1.5)
	var across := (shape.depth - 1.2) / 2.0
	var beside := shape.body().end.x - shape.opening().position.x - 1.1
	shape.base_inset = Vector3(random.randf_range(0.11, across), random.randf_range(0.11, beside),
		random.randf_range(0.11, across))
	return shape


## The box, in plan (X right, Y back), of [param arrays]' points, moved by [param by] first.
static func _plan_box(arrays: Array, by: Vector3) -> Rect2:
	var box := Fixtures.bounds(Transform3D(Basis.from_scale(Vector3.ONE / MM), by / MM) * Fixtures.points(arrays))
	return Rect2(box.position.x, -box.end.z, box.size.x, box.size.z)
