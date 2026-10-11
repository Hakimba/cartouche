# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy Advance cartridge's own looks: as wide, high and thick as its dimensions, its head
## wider than its body, its hump standing out only above its arch, highest in its middle, the body's
## front sides chamfered, its sleeve narrower and lower, its label in its recess, its marks on its
## panel; and the dimensions it cannot be built from are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SHAPES := 60
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_impossible_game_boy_advance_cartridge_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(310)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: GbaCartShape) -> void: cart.sleeve_inset = 0.0],
		[&"layers_fit", func(cart: GbaCartShape) -> void: cart.plate_depth = GbaCartShape.SCREW_SINK],
		[&"layers_fit", func(cart: GbaCartShape) -> void: cart.depth = 2.0 * cart.body_depth - cart.depth],
		[&"outline_fits", func(cart: GbaCartShape) -> void: cart.head_drop = cart.corner + GbaCartShape.ROLL],
		[&"outline_fits", func(cart: GbaCartShape) -> void: cart.sleeve_height = cart.height - cart.head_drop],
		[&"hump_fits", func(cart: GbaCartShape) -> void: cart.hump.y = cart.width / 2.0],
		[&"hump_fits", func(cart: GbaCartShape) -> void: cart.arch_drop = GbaCartShape.ROLL],
		[&"front_on_its_face", func(cart: GbaCartShape) -> void: cart.label_drop = cart.arch_drop],
		[&"front_on_its_face", func(cart: GbaCartShape) -> void: cart.arrow.y = cart.height - cart.label_drop],
		[&"logo_on_the_band", func(cart: GbaCartShape) -> void:
			cart.label_drop = cart.arch(GbaCartShape.LOGO.x / 2.0) + GbaCartShape.LOGO.y],
		[&"back_on_its_face", func(cart: GbaCartShape) -> void: cart.panel_size.y = cart.height],
		[&"back_on_its_face", func(cart: GbaCartShape) -> void: cart.panel_size.x = GbaCartShape.MARKS.x],
		[&"lines_cross_straight_edges", func(cart: GbaCartShape) -> void: cart.stripe_offset = cart.body_width() / 2.0],
		[&"connector_on_the_bottom", func(cart: GbaCartShape) -> void:
			cart.shoulder = (cart.width - GbaCartShape.CONNECTOR.x) / 2.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_game_boy_advance_cartridge_is_as_big_as_its_dimensions_its_hump_above_its_arch_its_body_narrower() -> void:
	var random := Fixtures.cases(311)
	for shape: GbaCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var shell := _mm(shape.mesh_arrays(&"shell", random.randi_range(16, 64)))
		var box := Fixtures.bounds(shell)
		assert_vector(box.position).is_equal_approx(Vector3(-shape.width / 2.0, -shape.height / 2.0, shape.back()),
			Vector3.ONE * EPSILON)
		assert_vector(box.end).is_equal_approx(Vector3(shape.width / 2.0, shape.height / 2.0, shape.peak()),
			Vector3.ONE * EPSILON)
		var body := shape.body_width() / 2.0
		var under := shape.at(shape.head_drop)
		var peak := false
		for point in shell:
			# Below the head only the body; its front set in by its chamfer above its taper.
			if point.y < under - EPSILON:
				assert_float(absf(point.x)).override_failure_message("%s beside the body" % point) \
					.is_less_equal(body + EPSILON)
				if point.z > shape.face() - EPSILON and point.y > GbaCartShape.TAPER - shape.height / 2.0:
					assert_float(absf(point.x)).is_less_equal(body - shape.chamfer.x + EPSILON)
			# Over the head's ends, only the hump, above its arch; at its top only over its middle.
			if point.z > shape.head_front() + EPSILON:
				assert_float(absf(point.x)).is_less(shape.hump.y)
				assert_float(point.y).is_greater_equal(shape.at(shape.arch(point.x)) - EPSILON)
			if point.z > shape.peak() - EPSILON:
				assert_float(absf(point.x)).is_less_equal(shape.hump.x + EPSILON)
				peak = true
			# The sleeve, below its top, narrower and a step lower than the back.
			if point.y < shape.sleeve_top() - EPSILON and point.z < shape.joint() - EPSILON:
				assert_float(absf(point.x)).is_less_equal(body - shape.sleeve_inset + EPSILON)
				assert_float(point.z).is_greater_equal(shape.back() + GbaCartShape.SLEEVE_STEP - EPSILON)
			if is_failure():
				return
		assert_bool(peak).override_failure_message("no hump's top").is_true()


func test_its_label_lies_in_its_recess_its_name_on_its_band_its_marks_on_its_panel() -> void:
	var random := Fixtures.cases(312)
	for shape: GbaCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var label := shape.mesh_arrays(&"label", 32)
		var points := _mm(label)
		var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
		var box := shape.label_box()
		for i in points.size():
			assert_float(points[i].z).is_equal_approx(shape.face() - GbaCartShape.RECESS, EPSILON)
			var expected := Vector2((points[i].x - box.position.x) / box.size.x, (box.end.y - points[i].y) / box.size.y)
			assert_vector(uvs[i]).is_equal_approx(expected, Vector2.ONE * EPSILON)
		var flat := Fixtures.bounds(points)
		assert_vector(Vector2(flat.position.x, flat.position.y)).is_equal_approx(box.position, Vector2.ONE * EPSILON)
		assert_vector(Vector2(flat.end.x, flat.end.y)).is_equal_approx(box.end, Vector2.ONE * EPSILON)
		var panel_face := shape.back() + GbaCartShape.PANEL_DEPTH
		for mark: Array in [[&"logo", shape.face(), shape.logo_box(), 1.0], [&"marks", panel_face, shape.marks_box(), -1.0]]:
			var part: StringName = mark[0]
			var face: float = mark[1]
			var area: Rect2 = mark[2]
			var across: float = mark[3]
			for point in _mm(shape.mesh_arrays(part, 32)):
				assert_float(absf(point.z - face)).is_less_equal(GbCartGeometry.MARK_OVER + EPSILON)
				assert_bool(area.grow(EPSILON).has_point(Vector2(point.x * across, point.y))).is_true()
		if is_failure():
			return


static func _cart(random: RandomNumberGenerator) -> GbaCartShape:
	return Fixtures.drawn_around(GbaCartShape.new(), random, Vector2(0.92, 1.08)) as GbaCartShape


static func _mm(arrays: Array) -> PackedVector3Array:
	return Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * Fixtures.points(arrays)
