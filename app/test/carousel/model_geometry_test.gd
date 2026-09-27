# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 200
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E2_5_02_a_disc_has_no_gap_its_parts_join_into_one_closed_outline() -> void:
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


func test_INV_E2_5_02_a_disc_is_closed_its_faces_turned_outwards() -> void:
	var random := Fixtures.cases(25)
	for i in SHAPES:
		var meshes := _meshes(Fixtures.disc(random), random.randi_range(8, 64))
		assert_array(_open_edges(meshes)).is_empty()
		for volume in _volumes(meshes):
			assert_float(volume).is_greater(0.0)


func test_INV_E2_5_02_a_disc_fills_its_size_and_nothing_covers_its_hole() -> void:
	var random := Fixtures.cases(21)
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		var segments := random.randi_range(8, 64)
		var radii := PackedFloat32Array()
		var heights := PackedFloat32Array()
		# The hole's edge is a polygon in the circle: no face comes further in than its sides.
		var nearest := shape.hole * cos(PI / segments)
		for triangle in _triangles(_meshes(shape, segments)):
			var centre := (triangle[0] + triangle[1] + triangle[2]) / 3.0 / MM
			assert_float(Vector2(centre.x, centre.y).length()).is_greater_equal(nearest - EPSILON)
			for corner in triangle:
				radii.append(Vector2(corner.x, corner.y).length() / MM)
				heights.append(corner.z / MM)
		assert_float(Array(radii).min()).is_equal_approx(shape.hole, EPSILON)
		assert_float(Array(radii).max()).is_equal_approx(shape.radius, EPSILON)
		var top := shape.thickness / 2.0
		assert_float(Array(heights).max()).is_equal_approx(top + shape.ring_height, EPSILON)
		assert_float(Array(heights).min()).is_equal_approx(-top - shape.ring_height, EPSILON)


func test_INV_E2_5_02_the_label_covers_the_top_from_its_inner_to_its_outer_radius_and_the_mirror_the_bottom() -> void:
	var random := Fixtures.cases(22)
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		var segments := random.randi_range(8, 64)
		for part: StringName in [&"label", &"mirror"]:
			var arrays := DiscGeometry.arrays(shape, part, segments)
			var side := 1.0 if part == &"label" else -1.0
			var radii := PackedFloat32Array()
			for point in _points(arrays):
				radii.append(Vector2(point.x, point.y).length() / MM)
				assert_float(point.z / MM).is_equal_approx(side * shape.thickness / 2.0, EPSILON)
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				assert_float(normal.z).is_equal_approx(side, EPSILON)
			var inner := shape.label_inner if part == &"label" else shape.mirror_inner
			var outer := shape.label_outer if part == &"label" else shape.mirror_outer
			assert_float(Array(radii).min()).is_equal_approx(inner, EPSILON)
			assert_float(Array(radii).max()).is_equal_approx(outer, EPSILON)


func test_INV_E2_5_02_a_label_image_covers_the_disc_face_its_top_upwards() -> void:
	var random := Fixtures.cases(23)
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		var arrays := DiscGeometry.arrays(shape, &"label", random.randi_range(8, 64))
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var points := _points(arrays)
		for v in points.size():
			# The image's square is the disc's: its top-left corner at the top left of the disc.
			var point := points[v] / MM
			var expected := Vector2(point.x + shape.radius, shape.radius - point.y) / (2.0 * shape.radius)
			assert_vector(uvs[v]).is_equal_approx(expected, Vector2.ONE * EPSILON)


func test_INV_E2_5_02_only_the_mirror_between_the_data_radii_is_marked_recorded() -> void:
	var random := Fixtures.cases(24)
	for i in SHAPES:
		var shape := Fixtures.disc(random)
		var arrays := DiscGeometry.arrays(shape, &"mirror", random.randi_range(8, 64))
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices := _points(arrays)
		for t in range(0, indices.size(), 3):
			var radii := PackedFloat32Array()
			for k in 3:
				var point := vertices[indices[t + k]] / MM
				radii.append(Vector2(point.x, point.y).length())
			var recorded: bool = Array(radii).min() > shape.data_inner - EPSILON and Array(radii).max() < shape.data_outer + EPSILON
			for k in 3:
				assert_float(colours[indices[t + k]].r).is_equal(1.0 if recorded else 0.0)
				assert_float(colours[indices[t + k]].g).is_equal(0.0)


func test_INV_E2_5_03_a_cartridge_is_closed_except_under_the_plate_its_faces_turned_outwards() -> void:
	var random := Fixtures.cases(30)
	for i in SHAPES:
		var shape := Fixtures.cartridge(random)
		var meshes := _meshes(shape, random.randi_range(16, 128))
		var plate := shape.plate_box().grow(EPSILON)
		var upper_front := shape.depth / 2.0 + shape.ledge
		for edge in _open_edges(meshes):
			for end in edge:
				var point := end / MM
				assert_bool(plate.has_point(Vector2(point.x, point.y)) and absf(point.z - upper_front) < EPSILON) \
					.override_failure_message("an open edge away from the plate: %s" % [edge]).is_true()
		for volume in _volumes(meshes):
			assert_float(volume).is_greater(0.0)


func test_INV_E2_5_03_a_cartridge_fills_its_size_its_label_upright_at_the_bottom_of_its_recess() -> void:
	var random := Fixtures.cases(31)
	for i in SHAPES:
		var shape := Fixtures.cartridge(random)
		var detail := random.randi_range(16, 128)
		var points := _points(shape.mesh_arrays(&"shell", detail))
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		var nearest := shape.depth / 2.0 + shape.ledge + maxf(shape.ridge_raise, shape.plate_raise)
		var expected := AABB(Vector3(-shape.width / 2.0, -shape.height / 2.0, -shape.depth / 2.0),
			Vector3(shape.width, shape.height, shape.depth / 2.0 + nearest))
		assert_vector(box.position / MM).is_equal_approx(expected.position, Vector3.ONE * EPSILON)
		assert_vector(box.end / MM).is_equal_approx(expected.end, Vector3.ONE * EPSILON)
		var label := shape.mesh_arrays(&"label", detail)
		var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
		var label_box := shape.label_box()
		var corners := _points(label)
		for v in corners.size():
			var point := corners[v] / MM
			assert_bool(label_box.grow(EPSILON).has_point(Vector2(point.x, point.y))).is_true()
			assert_float(point.z).is_equal_approx(shape.depth / 2.0 - shape.recess, EPSILON)
			# The image's corners at the label's: its top left at the top left.
			var expected_uv := Vector2(point.x - label_box.position.x, label_box.end.y - point.y) / label_box.size
			assert_vector(uvs[v]).is_equal_approx(expected_uv, Vector2.ONE * EPSILON)
		for normal: Vector3 in label[Mesh.ARRAY_NORMAL]:
			assert_vector(normal).is_equal_approx(Vector3.BACK, Vector3.ONE * EPSILON)


func test_INV_E2_5_04_impossible_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
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
	var cartridge_breaks: Array[Array] = [
		[&"sizes_positive", func(cartridge: CartridgeShape) -> void: cartridge.ledge = -0.1],
		[&"sizes_positive", func(cartridge: CartridgeShape) -> void: cartridge.notch = -0.1],
		[&"sizes_positive", func(cartridge: CartridgeShape) -> void: cartridge.recess_slope = -0.1],
		[&"sizes_positive", func(cartridge: CartridgeShape) -> void: cartridge.ridge_raise = -0.1],
		[&"sizes_positive", func(cartridge: CartridgeShape) -> void: cartridge.plate_raise = -0.1],
		[&"bevel_fits", func(cartridge: CartridgeShape) -> void: cartridge.bevel = cartridge.depth],
		[&"bevel_fits", func(cartridge: CartridgeShape) -> void: cartridge.bevel = cartridge.bottom_corner],
		[&"bevel_fits", func(cartridge: CartridgeShape) -> void: cartridge.bevel = cartridge.top_corner],
		[&"upper_part_fits", func(cartridge: CartridgeShape) -> void: cartridge.upper_height = cartridge.top_corner],
		[&"upper_part_fits", func(cartridge: CartridgeShape) -> void: cartridge.upper_height = cartridge.height],
		[&"ridge_fits", func(cartridge: CartridgeShape) -> void: cartridge.ridge_height = cartridge.upper_height],
		[&"ridge_fits", func(cartridge: CartridgeShape) -> void: cartridge.ridge_height = cartridge.bevel],
		[&"ridge_fits", func(cartridge: CartridgeShape) -> void:
			cartridge.ledge = 0.0
			cartridge.depth = cartridge.ridge_height],
		[&"label_on_body", func(cartridge: CartridgeShape) -> void: cartridge.label_size.x = cartridge.width],
		[&"label_on_body", func(cartridge: CartridgeShape) -> void: cartridge.label_corner = 0.0],
		[&"label_on_body", func(cartridge: CartridgeShape) -> void:
			cartridge.label_centre.y = -cartridge.height / 2.0 + cartridge.label_size.y / 2.0],
		[&"label_over_straight_edge", func(cartridge: CartridgeShape) -> void:
			cartridge.label_centre.x = cartridge.body().end.x - cartridge.bottom_corner / 2.0],
		[&"plate_on_upper_part", func(cartridge: CartridgeShape) -> void: cartridge.plate_centre = cartridge.label_centre],
		[&"plate_on_upper_part", func(cartridge: CartridgeShape) -> void:
			cartridge.plate_centre.y = cartridge.height / 2.0 - cartridge.plate_size.y / 2.0],
		[&"recess_fits", func(cartridge: CartridgeShape) -> void: cartridge.recess = cartridge.depth],
	]
	for i in SHAPES:
		var shapes: Array[ModelShape] = [Fixtures.disc(random), Fixtures.cartridge(random)]
		for k in 2:
			var shape := shapes[k]
			var breaks := disc_breaks if k == 0 else cartridge_breaks
			assert_array(shape.problems()).is_empty()
			var broken := breaks[i % breaks.size()]
			var breaking: Callable = broken[1]
			breaking.call(shape)
			assert_array(shape.problems()).contains([broken[0]])
			for part in shape.parts():
				assert_array(shape.mesh_arrays(part, 32)).is_empty()


func test_INV_E2_5_04_a_model_builds_faces_for_each_of_its_parts_and_nothing_else() -> void:
	var random := Fixtures.cases(41)
	for i in SHAPES:
		for shape: ModelShape in [Fixtures.disc(random), Fixtures.cartridge(random)]:
			for part in shape.parts():
				var indices: PackedInt32Array = shape.mesh_arrays(part, 32)[Mesh.ARRAY_INDEX]
				assert_int(indices.size()).is_greater(0)
			assert_array(shape.mesh_arrays(&"lable", 32)).is_empty()


func test_every_vertex_has_a_tangent_square_to_its_normal_as_normal_maps_need() -> void:
	var random := Fixtures.cases(42)
	for i in 50:
		for shape: ModelShape in [Fixtures.disc(random), Fixtures.cartridge(random)]:
			for part in shape.parts():
				var arrays := shape.mesh_arrays(part, 32)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for v in normals.size():
					var tangent := Vector3(tangents[4 * v], tangents[4 * v + 1], tangents[4 * v + 2])
					assert_float(tangent.length()).is_equal_approx(1.0, EPSILON)
					assert_float(tangent.dot(normals[v])).is_equal_approx(0.0, EPSILON)


## Every part of [param shape], built in [param detail] steps.
static func _meshes(shape: ModelShape, detail: int) -> Array[Array]:
	var found: Array[Array] = []
	for part in shape.parts():
		found.append(shape.mesh_arrays(part, detail))
	return found


static func _triangles(meshes: Array[Array]) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	for arrays in meshes:
		found.append_array(Fixtures.triangles(arrays))
	return found


static func _points(arrays: Array) -> PackedVector3Array:
	return arrays[Mesh.ARRAY_VERTEX]


## The edges of [param meshes]' faces, as their two ends, that no face goes back along: none on a
## closed surface whose faces are all turned the same way. Points are joined to the micrometre.
static func _open_edges(meshes: Array[Array]) -> Array[PackedVector3Array]:
	var counts: Dictionary[String, int] = {}
	var ends: Dictionary[String, PackedVector3Array] = {}
	for triangle in _triangles(meshes):
		for k in 3:
			var from := _micrometres(triangle[k])
			var to := _micrometres(triangle[(k + 1) % 3])
			if from == to:
				continue
			counts[from + ">" + to] = counts.get(from + ">" + to, 0) + 1
			counts[to + ">" + from] = counts.get(to + ">" + from, 0) - 1
			ends[from + ">" + to] = PackedVector3Array([triangle[k], triangle[(k + 1) % 3]])
	var found: Array[PackedVector3Array] = []
	for edge in counts:
		if counts[edge] > 0:
			found.append(ends[edge])
	return found


## The volume each separate piece of [param meshes] encloses (pieces share no point): positive
## when its faces are turned outwards.
static func _volumes(meshes: Array[Array]) -> PackedFloat32Array:
	var triangles := _triangles(meshes)
	# Each point's piece, pieces merged as faces join them.
	var piece: Dictionary[String, String] = {}
	var root := func(at: String) -> String:
		while piece[at] != at:
			at = piece[at]
		return at
	for triangle in triangles:
		var keys: Array[String] = []
		for corner in triangle:
			var key := _micrometres(corner)
			if key not in piece:
				piece[key] = key
			keys.append(key)
		for key: String in keys.slice(1):
			piece[root.call(key)] = root.call(keys[0])
	var sums: Dictionary[String, float] = {}
	for triangle in triangles:
		var at: String = root.call(_micrometres(triangle[0]))
		# Godot's front faces are clockwise seen from the side they face.
		sums[at] = sums.get(at, 0.0) - triangle[0].dot(triangle[1].cross(triangle[2])) / 6.0
	return PackedFloat32Array(sums.values())


static func _micrometres(point: Vector3) -> String:
	var at := Vector3i((point / MM * 1000.0).round())
	return "%d %d %d" % [at.x, at.y, at.z]
