# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 200
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
const PS2 := preload("res://carousel/consoles/ps2_slim.tscn")


func test_INV_E5_07_a_console_is_closed_part_by_part_its_faces_turned_outwards() -> void:
	var random := Fixtures.cases(50)
	for i in SHAPES:
		var shape := Fixtures.console(random)
		assert_array(shape.problems()).is_empty()
		var detail := random.randi_range(16, 128)
		for part: StringName in [&"lower", &"upper", &"lid", &"ribs"]:
			var meshes: Array[Array] = [shape.mesh_arrays(part, detail)]
			assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s is open" % part).is_empty()
			var volumes := Fixtures.volumes(meshes)
			# A top too small for ribs has none.
			if part != &"ribs" or not shape.ribs().is_empty():
				assert_int(volumes.size()).is_greater(0)
			for volume in volumes:
				assert_float(volume).is_greater(0.0)


func test_INV_E5_07_closed_the_lid_fills_its_opening_but_its_gap_and_the_disc_sits_over_the_well() -> void:
	var random := Fixtures.cases(51)
	for i in SHAPES:
		var shape := Fixtures.console(random)
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
	var console: ConsoleModel = auto_free(PS2.instantiate())
	add_child(console)
	var shape := console.shape
	var well_part: MeshInstance3D = console.get_node("Well")
	var well := _box_of(console, well_part)
	var seat := console.global_transform.affine_inverse() * console.seat()
	assert_vector(Vector2(seat.origin.x, seat.origin.z)).is_equal_approx(
		Vector2(well.get_center().x, well.get_center().z), Vector2.ONE * EPSILON * MM)
	assert_float(seat.origin.y).is_between(shape.seam * MM, shape.height * MM)
	assert_vector(seat.basis.z.normalized()).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
	var cover: MeshInstance3D = console.get_node("%Lid/Cover")
	var closed := _box_of(console, cover)
	var lid := shape.lid_box()
	assert_vector(Vector2(closed.position.x, -closed.end.z) / MM).is_equal_approx(lid.position, Vector2.ONE * EPSILON)
	assert_vector(Vector2(closed.end.x, -closed.position.z) / MM).is_equal_approx(lid.end, Vector2.ONE * EPSILON)
	assert_float(closed.end.y / MM).is_equal_approx(shape.height, EPSILON)
	for degrees: float in [15.0, 45.0, 88.0, 120.0]:
		console.lid_degrees = degrees
		var open := _box_of(console, cover)
		var rise := lid.size.y * sin(deg_to_rad(degrees))
		# Its front rises, its back edge stays where it is hinged (up to upright, then the lid leans back).
		assert_float(open.end.y / MM).is_between(shape.height + rise * 0.95, shape.height + rise + shape.lid_thickness)
		if degrees <= 90.0:
			assert_float(-open.position.z / MM).is_between(lid.end.y - shape.lid_thickness, lid.end.y + shape.lid_thickness)


func test_INV_E5_07_impossible_console_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(52)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(console: ConsoleShape) -> void: console.lid_gap = 0.0],
		[&"corner_rounds_the_bevel", func(console: ConsoleShape) -> void: console.corner = console.bevel],
		[&"blocks_hold_their_bevels", func(console: ConsoleShape) -> void: console.seam = 2.0 * console.bevel],
		[&"lid_inside_the_top", func(console: ConsoleShape) -> void: console.lid_centre.x = console.body().end.x],
		[&"lid_inside_the_top", func(console: ConsoleShape) -> void:
			console.lid_centre = console.body().end - console.lid_size / 2.0],
		[&"lid_corner_fits", func(console: ConsoleShape) -> void: console.lid_corner = console.lid_size.x],
		[&"lid_thin_enough", func(console: ConsoleShape) -> void: console.lid_thickness = console.height],
		[&"disc_turns_in_the_well", func(console: ConsoleShape) -> void: console.disc_radius = console.lid_size.y],
		[&"seat_between_floor_and_lid", func(console: ConsoleShape) -> void: console.seat_height = console.seam],
		[&"seat_between_floor_and_lid", func(console: ConsoleShape) -> void: console.seat_height = console.height],
		[&"ribs_on_the_top_beside_the_lid", func(console: ConsoleShape) -> void:
			console.rib_count = maxi(1, console.rib_count)
			console.rib_start = console.lid_centre.x],
		[&"ribs_on_the_top_beside_the_lid", func(console: ConsoleShape) -> void: console.rib_width = console.rib_pitch],
	]
	for i in SHAPES:
		var shape := Fixtures.console(random)
		assert_array(shape.problems()).is_empty()
		var broken := breaks[i % breaks.size()]
		var breaking: Callable = broken[1]
		breaking.call(shape)
		assert_array(shape.problems()).contains([broken[0]])
		for part in shape.parts():
			assert_array(shape.mesh_arrays(part, 32)).is_empty()


func test_INV_E5_07_the_lid_s_opening_goes_through_the_top_down_to_the_well() -> void:
	var random := Fixtures.cases(53)
	for i in SHAPES:
		var shape := Fixtures.console(random)
		# Inside the opening's rounded outline, a hair in from it.
		var rounding := shape.lid_corner + shape.lid_gap
		var core := shape.opening().grow(-rounding)
		var upper := shape.mesh_arrays(&"upper", random.randi_range(16, 128))
		for point in Fixtures.points(upper):
			var at := point / MM
			var plan := Vector2(at.x, -at.z)
			var inside := plan.distance_to(plan.clamp(core.position, core.end)) < rounding - 0.01
			assert_bool(inside).override_failure_message("the upper block covers the opening at %s" % at).is_false()
		# Nor does any of its faces, seen from above.
		var through: Array[Vector2] = [core.get_center()]
		for k in 4:
			through.append(Vector2(random.randf_range(core.position.x, core.end.x), random.randf_range(core.position.y, core.end.y)))
		for triangle in Fixtures.triangles(upper):
			var plan := PackedVector2Array()
			for corner in triangle:
				plan.append(Vector2(corner.x, -corner.z) / MM)
			for spot in through:
				assert_bool(Geometry2D.point_is_inside_triangle(spot, plan[0], plan[1], plan[2])) \
					.override_failure_message("the upper block covers the opening at %s" % spot).is_false()



## The box, in plan (X right, Y back), of [param arrays]' points, moved by [param by] first.
static func _plan_box(arrays: Array, by: Vector3) -> Rect2:
	var points := Fixtures.points(arrays)
	var box := Rect2()
	for k in points.size():
		var point := (points[k] + by) / MM
		var plan := Vector2(point.x, -point.z)
		box = Rect2(plan, Vector2.ZERO) if k == 0 else box.expand(plan)
	return box


## Where [param part]'s mesh stands in [param console].
static func _box_of(console: Node3D, part: MeshInstance3D) -> AABB:
	return console.global_transform.affine_inverse() * part.global_transform * part.get_aabb()
