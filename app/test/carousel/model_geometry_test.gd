# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 50
## A cartridge shaped as a box, as one ships.
const _BOX_CART := preload("res://carousel/media/switch_card/switch_card_shape.tres")


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


func test_a_model_is_closed_its_faces_turned_outwards_and_built_for_each_of_its_parts_and_nothing_else() -> void:
	var random := Fixtures.cases(25)
	for i in SHAPES:
		for shape: ModelShape in [Fixtures.disc(random), Fixtures.drawn_around(_BOX_CART, random, Vector2(0.95, 1.05))]:
			var meshes := _meshes(shape, random.randi_range(8, 64))
			for arrays in meshes:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				assert_int(indices.size()).is_greater(0)
			assert_array(Fixtures.open_edges(meshes)).is_empty()
			for volume in Fixtures.volumes(meshes):
				assert_float(volume).is_greater(0.0)
			assert_array(shape.mesh_arrays(&"lable", 32)).is_empty()


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
		[&"gap_inside_data", func(disc: DiscShape) -> void: disc.data_gap = Vector2(disc.data_inner + 1.0, disc.data_outer)],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.thickness = 0.0],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.ring_height = -0.1],
		[&"sizes_positive", func(disc: DiscShape) -> void: disc.ring_width = 0.0],
		[&"mirror_inside_rim", func(disc: DiscShape) -> void: disc.mirror_outer = disc.radius],
	]
	var box_breaks: Array[Array] = [
		[&"sizes_positive", func(box: BoxCartShape) -> void: box.recess = 0.0],
		[&"sizes_positive", func(box: BoxCartShape) -> void: box.label_corner = -0.1],
		[&"bevel_fits", func(box: BoxCartShape) -> void: box.bevel = box.corner],
		[&"bevel_fits", func(box: BoxCartShape) -> void: box.depth = 2.0 * (box.bevel + box.recess)],
		[&"label_on_the_front", func(box: BoxCartShape) -> void: box.label = Rect2(0.0, box.label.position.y, box.label.size.x,
			box.label.size.y)],
		[&"label_on_the_front", func(box: BoxCartShape) -> void: box.label_corner = minf(box.label.size.x, box.label.size.y) / 2.0],
		[&"grip_fits", func(box: BoxCartShape) -> void: box.grip = Vector3(2.0, 0.5, 1.0)],
		[&"grip_fits", func(box: BoxCartShape) -> void: box.grip = Vector3(1.0, 2.0, box.height)],
	]
	for i in SHAPES:
		_assert_refused(Fixtures.disc(random), disc_breaks[i % disc_breaks.size()])
		_assert_refused(Fixtures.drawn_around(_BOX_CART, random, Vector2(0.95, 1.05)), box_breaks[i % box_breaks.size()])


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


## Every part of [param shape], built in [param detail] steps.
static func _meshes(shape: ModelShape, detail: int) -> Array[Array]:
	var found: Array[Array] = []
	for part in shape.parts():
		found.append(shape.mesh_arrays(part, detail))
	return found


## [param shape], accepted, then [param broken]: refused by the rule it names, and building nothing.
func _assert_refused(shape: ModelShape, broken: Array) -> void:
	assert_array(shape.problems()).is_empty()
	var breaking: Callable = broken[1]
	breaking.call(shape)
	assert_array(shape.problems()).contains([broken[0]])
	for part in shape.parts():
		assert_array(shape.mesh_arrays(part, 32)).is_empty()
