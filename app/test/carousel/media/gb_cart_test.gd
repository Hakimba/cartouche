# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy cartridge's own looks, the Game Boy Color's grey one being the same: as wide, high
## and thick as its dimensions, its corner notched, grooves cut into its sides, its lower front sides
## chamfered, its pill deep with the name on its floor, its sleeve lower than its back, its label in
## its recess, its screw sunk; and the dimensions it cannot be built from are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const GB := "res://carousel/media/gb_cart/gb_cart.tscn"
const SHAPES := 60
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_impossible_game_boy_cartridge_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(300)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: GbCartShape) -> void: cart.recess = 0.0],
		[&"sizes_positive", func(cart: GbCartShape) -> void: cart.pill_size.y = cart.pill_size.x],
		[&"bevels_fit", func(cart: GbCartShape) -> void: cart.bevel = GbCartShape.FILLET],
		[&"bevels_fit", func(cart: GbCartShape) -> void: cart.pill_depth = cart.depth / 2.0 - GbCartShape.SEAM],
		[&"bevels_fit", func(cart: GbCartShape) -> void: cart.chamfer.y = cart.depth / 2.0],
		[&"outline_fits", func(cart: GbCartShape) -> void:
			cart.notched = true
			cart.notch.x = cart.width - 2.0 * cart.corner],
		[&"outline_fits", func(cart: GbCartShape) -> void:
			cart.sleeve_height = cart.height - cart.step_drop - GbCartShape.TAPER],
		# Grooves running down past the chamfer's end, or up into the notch.
		[&"outline_fits", func(cart: GbCartShape) -> void:
			cart.grooves = maxi(1, cart.grooves)
			cart.groove_drop = cart.step_drop - GbCartShape.GROOVE],
		[&"outline_fits", func(cart: GbCartShape) -> void:
			cart.grooves = maxi(1, cart.grooves)
			cart.notched = true
			cart.groove_drop = cart.notch.y],
		[&"grooves_apart", func(cart: GbCartShape) -> void:
			cart.grooves = 2
			cart.groove_pitch = GbCartShape.GROOVE],
		[&"lines_cross_straight_edges", func(cart: GbCartShape) -> void:
			cart.stripe_offset = cart.width / 2.0 - cart.bottom_corner],
		[&"front_on_its_face", func(cart: GbCartShape) -> void: cart.label_drop = cart.pill_drop],
		[&"front_on_its_face", func(cart: GbCartShape) -> void: cart.arrow_drop = cart.height - cart.arrow.y],
		[&"front_on_its_face", func(cart: GbCartShape) -> void: cart.cove = cart.pill_size.y / 2.0],
		[&"front_on_its_face", func(cart: GbCartShape) -> void: cart.groove_length = cart.width / 2.0],
		[&"back_on_its_face", func(cart: GbCartShape) -> void: cart.marks_drop = cart.dimple_drop],
		[&"back_on_its_face", func(cart: GbCartShape) -> void: cart.stripe_span.y = cart.height - cart.sleeve_height],
		[&"connector_on_the_bottom", func(cart: GbCartShape) -> void: cart.connector.x = cart.width],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_game_boy_cartridge_is_as_big_as_its_dimensions_notched_grooved_at_its_sides_chamfered_below() -> void:
	var random := Fixtures.cases(301)
	for shape: GbCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var shell := _mm(shape.mesh_arrays(&"shell", random.randi_range(16, 64)))
		var box := Fixtures.bounds(shell)
		assert_vector(box.position).is_equal_approx(-Vector3(shape.width, shape.height, shape.depth) / 2.0,
			Vector3.ONE * EPSILON)
		assert_vector(box.end).is_equal_approx(Vector3(shape.width, shape.height, shape.depth) / 2.0,
			Vector3.ONE * EPSILON)
		var half := shape.width / 2.0
		var top := shape.height / 2.0
		var front := shape.depth / 2.0
		var cuts := 0
		for point in shell:
			var side := absf(point.x)
			# Nothing in a groove's cut nor in the notch.
			for span in shape.groove_spans():
				if point.y > span.x + EPSILON and point.y < span.y - EPSILON:
					assert_float(side).override_failure_message("%s in a groove" % point) \
						.is_less_equal(half - GbCartShape.TOOTH + EPSILON)
			if shape.notched:
				assert_bool(point.x > half - shape.notch.x + EPSILON and point.y > top - shape.notch.y + EPSILON) \
					.override_failure_message("%s in the notch" % point).is_false()
			# The lower part's front, set in by its chamfer above its taper.
			if point.y < top - shape.step_drop + EPSILON and point.y > GbCartShape.TAPER - top - EPSILON \
					and point.z > front - EPSILON:
				assert_float(side).is_less_equal(half - shape.chamfer.x + EPSILON)
				cuts += 1 if absf(side - half + shape.chamfer.x) < EPSILON else 0
			# The sleeve, below its top, a step lower than the back.
			if point.y < shape.sleeve_top() - EPSILON:
				assert_float(point.z).is_greater_equal(GbCartShape.SLEEVE_STEP - front - EPSILON)
			if is_failure():
				return
		assert_int(cuts).override_failure_message("no chamfer's edge").is_greater(0)
		# Each groove cut into both sides, its floor along its bottom and top.
		for span in shape.groove_spans():
			for side: float in [-1.0, 1.0]:
				for edge: float in [span.x, span.y]:
					var cut := Vector2(side * (half - GbCartShape.TOOTH), edge)
					assert_bool(Array(shell).any(func(point: Vector3) -> bool:
						return Vector2(point.x, point.y).distance_to(cut) < EPSILON)).override_failure_message(
							"no groove's floor at %s" % cut).is_true()
		# Without its notch, its corner fills where the notch would be.
		var whole: GbCartShape = shape.duplicate()
		whole.notched = false
		assert_bool(Array(_mm(whole.mesh_arrays(&"shell", 32))).any(func(point: Vector3) -> bool:
			return point.x > half - shape.notch.x + EPSILON and point.y > top - shape.notch.y + EPSILON)).is_true()


func test_its_pill_is_sunk_to_its_floor_the_name_on_it_its_marks_on_its_back() -> void:
	var random := Fixtures.cases(303)
	for shape: GbCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var floor_z := shape.depth / 2.0 - shape.pill_depth
		var floor_box := shape.floor_box()
		var shell := Array(_mm(shape.mesh_arrays(&"shell", 32)))
		var floored := shell.any(func(point: Vector3) -> bool:
			return is_equal_approx(point.z, floor_z) and floor_box.grow(EPSILON).has_point(Vector2(point.x, point.y)))
		assert_bool(floored).override_failure_message("no pill floor at %s" % floor_z).is_true()
		for mark: Array in [[&"logo", floor_z, shape.logo_box()], [&"marks", -shape.depth / 2.0, shape.marks_box()]]:
			var part: StringName = mark[0]
			var face: float = mark[1]
			var area: Rect2 = mark[2]
			for point in _mm(shape.mesh_arrays(part, 32)):
				# Seen from behind, the back's marks lie mirrored across.
				var across := point.x if part == &"logo" else -point.x
				assert_float(absf(point.z - face)).is_less_equal(GbCartGeometry.MARK_OVER + EPSILON)
				assert_bool(area.grow(EPSILON).has_point(Vector2(across, point.y))).is_true()
		if is_failure():
			return


func test_its_label_lies_in_its_recess_its_image_upright_across_it_and_its_screw_is_sunk_in_its_hole() -> void:
	var random := Fixtures.cases(302)
	for shape: GbCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var label := shape.mesh_arrays(&"label", 32)
		var points := _mm(label)
		var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
		var box := shape.label_box()
		for i in points.size():
			assert_float(points[i].z).is_equal_approx(shape.depth / 2.0 - shape.recess, EPSILON)
			var expected := Vector2((points[i].x - box.position.x) / box.size.x, (box.end.y - points[i].y) / box.size.y)
			assert_vector(uvs[i]).is_equal_approx(expected, Vector2.ONE * EPSILON)
		var flat := Fixtures.bounds(points)
		assert_vector(Vector2(flat.position.x, flat.position.y)).is_equal_approx(box.position, Vector2.ONE * EPSILON)
		assert_vector(Vector2(flat.end.x, flat.end.y)).is_equal_approx(box.end, Vector2.ONE * EPSILON)
		# The screw's head, behind the back, stands in its hole below the back's face.
		var screw := shape.back_boxes()[3]
		for point in _mm(shape.mesh_arrays(&"screw", 32)):
			assert_float(Vector2(point.x, point.y).distance_to(screw.get_center())).is_less(GbCartShape.SCREW_HOLE / 2.0)
			assert_float(point.z).is_between(0.1 - shape.depth / 2.0, GbCartShape.SCREW_SINK - shape.depth / 2.0 + 0.1 + EPSILON)
		if is_failure():
			return


func test_the_game_boy_color_s_grey_cartridge_is_the_game_boy_s() -> void:
	var found := MediumManifest.found()
	assert_str(found["gbc_cart"].scene).is_equal(GB)
	assert_str(found["gb_cart"].scene).is_equal(GB)


static func _cart(random: RandomNumberGenerator) -> GbCartShape:
	var shape := Fixtures.drawn_around(GbCartShape.new(), random, Vector2(0.92, 1.08), 1) as GbCartShape
	# Its notch taken off only frees its top corner.
	shape.notched = random.randf() < 0.7
	return shape


static func _mm(arrays: Array) -> PackedVector3Array:
	return Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * Fixtures.points(arrays)
