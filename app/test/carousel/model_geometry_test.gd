# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 50
const EPSILON := 0.001


func test_a_disc_has_no_gap_its_parts_join_into_one_closed_outline() -> void:
	var random := Fixtures.cases(20)
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		var ends: Array[PackedVector2Array] = []
		for part in shape.parts():
			for profile in DiscGeometry.profiles(shape, part):
				ends.append(PackedVector2Array([profile[0], profile[-1]]))
		# Following each profile to the one that starts where it ends goes through all of them,
		# then back to the first.
		var at := 0
		var visited: Array[int] = []
		for step in ends.size():
			var end := ends[at][1]
			# The same point, computed the same way.
			at = ends.find_custom(func(other: PackedVector2Array) -> bool: return other[0].is_equal_approx(end))
			if at == -1 or at in visited:
				break
			visited.append(at)
		assert_int(visited.size()).override_failure_message("a gap in %s" % [ends]).is_equal(ends.size())
		assert_int(at).is_equal(0)


func test_a_disc_is_closed_its_faces_turned_outwards() -> void:
	var random := Fixtures.cases(25)
	for i in SHAPES:
		var meshes := _meshes(Fixtures.disc(random), random.randi_range(8, 64))
		assert_array(Fixtures.open_edges(meshes)).is_empty()
		for volume in Fixtures.volumes(meshes):
			assert_float(volume).is_greater(0.0)


func test_impossible_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(40)
	var disc_breaks: Array[Array] = [
		[&"label_inside_rim", func(disc: DiscShape) -> void: disc.label_outer = disc.radius],
		[&"label_inside_rim", func(disc: DiscShape) -> void: disc.label_inner = disc.label_outer],
		[&"ring_outside_hole", func(disc: DiscShape) -> void: disc.ring = disc.hole],
		[&"ring_outside_hole", func(disc: DiscShape) -> void: disc.hole = 0.0],
		[&"ring_inside_label_and_mirror", func(disc: DiscShape) -> void: disc.label_inner = disc.ring],
		[&"ring_inside_label_and_mirror", func(disc: DiscShape) -> void: disc.mirror_inner = disc.ring],
		[&"data_on_mirror", func(disc: DiscShape) -> void: disc.data_inner = disc.mirror_inner],
		[&"data_on_mirror", func(disc: DiscShape) -> void: disc.data_outer = disc.mirror_outer],
		[&"data_on_mirror", func(disc: DiscShape) -> void: disc.data_outer = disc.data_inner],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.thickness = 0.0],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.ring_height = -0.1],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.ring_width = 0.0],
		[&"mirror_inside_rim", func(disc: DiscShape) -> void: disc.mirror_outer = disc.radius],
	]
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		assert_array(shape.problems()).is_empty()
		var broken := disc_breaks[i % disc_breaks.size()]
		var breaking: Callable = broken[1]
		breaking.call(shape)
		assert_array(shape.problems()).contains([broken[0]])
		for part in shape.parts():
			assert_array(shape.mesh_arrays(part, 32)).is_empty()


func test_a_model_builds_faces_for_each_of_its_parts_and_nothing_else() -> void:
	var random := Fixtures.cases(41)
	for i in SHAPES:
		var console := Fixtures.ps2_slim(random)
		for shape: ModelShape in [Fixtures.disc(random), Fixtures.drawn_around(GbaCartShape.new(), random, Vector2(0.92, 1.08)), console]:
			for part in shape.parts():
				var indices: PackedInt32Array = shape.mesh_arrays(part, 32)[Mesh.ARRAY_INDEX]
				assert_int(indices.size()).is_greater(0)
			assert_array(shape.mesh_arrays(&"lable", 32)).is_empty()


func test_a_pill_or_a_circle_is_a_closed_solid_however_its_bevel_shrinks_it() -> void:
	var random := Fixtures.cases(43)
	for i in SHAPES:
		var size := Vector2(random.randf_range(0.5, 80.0), random.randf_range(0.5, 80.0))
		if i % 3 == 0:
			size.y = size.x
		var box := Rect2(Vector2(random.randf_range(-50.0, 50.0), random.randf_range(-50.0, 50.0)), size)
		var corner := minf(size.x, size.y) / 2.0
		var bevel := random.randf_range(0.05, 0.9) * corner
		var steps := random.randi_range(3, 12)
		var mesh := MeshBuilder.new()
		ShapeGeometry.block(mesh, box, Vector2.ONE * corner, steps, 0.0, random.randf_range(2.0, 10.0) * bevel,
			bevel, box)
		var meshes: Array[Array] = [mesh.arrays()]
		assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s, %s round" % [box, corner]).is_empty()
		assert_float(Fixtures.volumes(meshes)[0]).is_greater(0.0)
		# No two of its points are one, the closing point included.
		var outline := ShapeGeometry.rounded(box, corner, corner, steps)
		for k in outline.size():
			assert_float(outline[k].distance_to(outline[k - 1])).is_greater(0.0001)


func test_a_polygon_s_corners_rounded_join_its_sides_and_make_a_closed_slab() -> void:
	var random := Fixtures.cases(45)
	for i in SHAPES:
		# A box with a notch out of its top: four convex corners and two reflex ones.
		var box := Rect2(0.0, 0.0, random.randf_range(20.0, 60.0), random.randf_range(20.0, 60.0))
		var notch := Vector2(random.randf_range(0.3, 0.5) * box.size.x, random.randf_range(0.2, 0.5) * box.size.y)
		var left := random.randf_range(0.2, 0.3) * box.size.x
		var polygon := PackedVector2Array([Vector2.ZERO, Vector2(box.size.x, 0.0), box.size,
			Vector2(left + notch.x, box.size.y), Vector2(left + notch.x, box.size.y - notch.y),
			Vector2(left, box.size.y - notch.y), Vector2(left, box.size.y), Vector2(0.0, box.size.y)])
		# No side shorter than its two corners' arcs.
		var radius := random.randf_range(0.5, 0.2 * minf(minf(notch.x, notch.y), minf(left, box.size.x - left - notch.x)))
		var radii := PackedFloat32Array()
		radii.resize(polygon.size())
		radii.fill(radius)
		var steps := random.randi_range(2, 8)
		var outline := ShapeGeometry.filleted(polygon, radii, steps)
		assert_int(outline.size()).is_equal(polygon.size() * (steps + 1))
		for k in polygon.size():
			var coming := polygon[k - 1]
			var going := polygon[(k + 1) % polygon.size()]
			# Each arc starts on the side coming into its corner and ends on the one leaving it, a
			# radius from where they meet.
			var start := outline[k * (steps + 1)]
			var end := outline[k * (steps + 1) + steps]
			assert_float(Geometry2D.get_closest_point_to_segment(start, coming, polygon[k]).distance_to(start)) \
				.is_less(EPSILON)
			assert_float(Geometry2D.get_closest_point_to_segment(end, polygon[k], going).distance_to(end)) \
				.is_less(EPSILON)
			assert_float(start.distance_to(polygon[k])).is_equal_approx(radius, EPSILON)
		var mesh := MeshBuilder.new()
		var bevel := random.randf_range(0.05, 0.9) * radius
		ShapeGeometry.slab(mesh, outline, 0.0, random.randf_range(3.0, 10.0) * bevel, Vector2(bevel, 0.0), box)
		var meshes: Array[Array] = [mesh.arrays()]
		assert_array(Fixtures.open_edges(meshes)).is_empty()
		assert_float(Fixtures.volumes(meshes)[0]).is_greater(0.0)


func test_a_corner_of_no_radius_or_in_line_stays_one_point_and_its_slab_closed() -> void:
	# A square with a point half way along its bottom, its top right corner left square.
	var polygon := PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0), Vector2(20.0, 0.0), Vector2(20.0, 20.0),
		Vector2(0.0, 20.0)])
	var outline := ShapeGeometry.filleted(polygon, PackedFloat32Array([3.0, 3.0, 3.0, 0.0, 3.0]), 4)
	assert_int(outline.size()).is_equal(3 * 5 + 2)
	assert_bool(Vector2(10.0, 0.0) in outline and Vector2(20.0, 20.0) in outline).is_true()
	for i in outline.size():
		assert_float(outline[i].distance_to(outline[i - 1])).is_greater(EPSILON)
	var mesh := MeshBuilder.new()
	ShapeGeometry.slab(mesh, outline, 0.0, 5.0, Vector2.ONE, Rect2(0.0, 0.0, 20.0, 20.0))
	var meshes: Array[Array] = [mesh.arrays()]
	assert_array(Fixtures.open_edges(meshes)).is_empty()
	assert_float(Fixtures.volumes(meshes)[0]).is_greater(0.0)
	var normals: PackedVector3Array = meshes[0][Mesh.ARRAY_NORMAL]
	assert_bool(Array(normals).all(func(normal: Vector3) -> bool: return normal.is_finite())).is_true()


## Every part of [param shape], built in [param detail] steps.
static func _meshes(shape: ModelShape, detail: int) -> Array[Array]:
	var found: Array[Array] = []
	for part in shape.parts():
		found.append(shape.mesh_arrays(part, detail))
	return found
