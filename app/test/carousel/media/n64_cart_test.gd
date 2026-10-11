# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Nintendo 64 Game Pak's own looks: its outline and its size, the band and the label's recess on
## the front between the grooves to the wings, the grooves going on over the top and down the back,
## the rails stepped down at its bottom corners, the indentations cut in its back, the slot its
## contacts sit in, the screws, the printed sticker and the moulded name on its back, and the
## dimensions it cannot be built from.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SCENE := "res://carousel/media/n64_cart/n64_cart.tscn"
const SHAPES := 120
const MODELS := 12
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
## How far inside a cut a box checked to be empty keeps from its walls.
const CLEAR := 0.05
## Farther than any cartridge reaches, in millimetres.
const FAR := 1000.0


func test_impossible_n64_cart_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(640)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: N64CartShape) -> void: cart.slot_depth = 0.0],
		[&"sizes_positive", func(cart: N64CartShape) -> void: cart.rail_slant = -1.0],
		[&"outline_holds_its_corners", func(cart: N64CartShape) -> void: cart.bevel = cart.bottom_corner],
		[&"outline_holds_its_corners", func(cart: N64CartShape) -> void:
			cart.top_corner = cart.width / N64CartGeometry.ARCS],
		[&"outline_holds_its_corners", func(cart: N64CartShape) -> void: cart.arch = cart.height],
		[&"outline_holds_its_corners", func(cart: N64CartShape) -> void: cart.shoulder = cart.top_corner],
		[&"layers_in_depth", func(cart: N64CartShape) -> void: cart.notch_depth = cart.depth / 2.0],
		[&"layers_in_depth", func(cart: N64CartShape) -> void: cart.rail_step = cart.depth / 2.0 - cart.band_raise],
		[&"indentations_fit", func(cart: N64CartShape) -> void: cart.notch_from = cart.bottom_corner],
		[&"indentations_fit", func(cart: N64CartShape) -> void: cart.notch_size.x = cart.width / 2.0],
		[&"rails_fit", func(cart: N64CartShape) -> void: cart.rail_size.y = cart.height],
		[&"band_on_the_face", func(cart: N64CartShape) -> void: cart.band_width = cart.width - cart.rail_size.x],
		[&"band_on_the_face", func(cart: N64CartShape) -> void:
			cart.groove = cart.width / 2.0 - cart.band_width / 2.0 - cart.rail_size.x],
		[&"grooves_fit", func(cart: N64CartShape) -> void: cart.groove = 2.0 * N64CartShape.LINING],
		[&"grooves_fit", func(cart: N64CartShape) -> void: cart.lip = cart.bevel],
		[&"grooves_fit", func(cart: N64CartShape) -> void: cart.groove_depth = cart.notch_depth],
		[&"grooves_fit", func(cart: N64CartShape) -> void: cart.screw_centre.x = cart.oval_size.x / 2.0],
		[&"grooves_fit", func(cart: N64CartShape) -> void:
			cart.screw_centre.x = cart.width / 2.0 - cart.notch_from - cart.notch_size.x],
		[&"grooves_fit", func(cart: N64CartShape) -> void: cart.band_width = cart.width / 4.0],
		[&"label_in_the_band", func(cart: N64CartShape) -> void: cart.label_size.x = cart.band_width],
		[&"label_in_the_band", func(cart: N64CartShape) -> void: cart.label_centre.y = cart.height / 2.0],
		[&"label_in_the_band", func(cart: N64CartShape) -> void: cart.band_raise = N64CartShape.LABEL_THICKNESS],
		[&"label_in_the_band", func(cart: N64CartShape) -> void: cart.label_centre.x = cart.label_size.x / 2.0],
		[&"slot_fits", func(cart: N64CartShape) -> void: cart.contacts_width = cart.slot_size.x],
		[&"slot_fits", func(cart: N64CartShape) -> void: cart.slot_size.y = N64CartShape.BOARD / 2.0],
		[&"marks_on_the_back", func(cart: N64CartShape) -> void: cart.sticker_centre.y = -cart.height / 2.0],
		[&"marks_on_the_back", func(cart: N64CartShape) -> void: cart.screw_centre.x = cart.width / 2.0],
		[&"marks_on_the_back", func(cart: N64CartShape) -> void: cart.screw_radius = N64CartShape.SMALLEST / 4.0],
		[&"marks_on_the_back", func(cart: N64CartShape) -> void: cart.oval_rim.x = cart.oval_size.y / 2.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_shipped_cartridge_stands_at_life_size_its_measured_outline_in_the_seat_s_frame() -> void:
	var shipped := _shipped()
	var box := Appearance.read("res://data/carousel/appearance.json").medium_box("n64_cart", "cartridge")
	var size := box.size / MM
	assert_vector(Vector2(size.x, size.y)).is_equal_approx(Vector2(116.0, 76.6), Vector2.ONE * EPSILON)
	# Its back's marks stand out of its thickness, the oval furthest.
	assert_float(size.z).is_equal_approx(shipped.depth + shipped.oval_rim.y, EPSILON)
	assert_vector(box.get_center() / MM).is_equal_approx(Vector3(0.0, 0.0, -shipped.oval_rim.y / 2.0),
		Vector3.ONE * EPSILON)


func test_its_top_is_an_arc_over_straight_sides_its_bottom_flat() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(641))):
		var points := Array(_points(shape, &"shell", 64))
		var half := shape.width / 2.0
		var top := shape.height / 2.0
		var highest: Vector3 = points.reduce(func(best: Vector3, point: Vector3) -> Vector3:
			return point if point.y > best.y else best)
		assert_float(highest.y).is_equal_approx(top, EPSILON)
		assert_float(absf(highest.x)).is_less(half / N64CartGeometry.ARCS)
		assert_float(points.map(func(point: Vector3) -> float: return point.y).min()).is_equal_approx(-top, EPSILON)
		for side: float in [-1.0, 1.0]:
			# Each side straight, upright, from its bottom corner up under its top corner.
			var heights := points.filter(func(point: Vector3) -> bool: return absf(point.x - side * half) < EPSILON) \
				.map(func(point: Vector3) -> float: return point.y)
			assert_float(heights.min()).is_less_equal(shape.bottom_corner - top + EPSILON)
			assert_float(heights.max()).is_between(top - shape.arch - shape.top_corner - EPSILON,
				top - shape.arch + EPSILON)


func test_the_label_lies_in_its_recess_in_the_band_standing_over_the_wings() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(642))):
		var front := shape.depth / 2.0
		var band := Rect2(-shape.band_width / 2.0, -shape.height / 2.0, shape.band_width, shape.height)
		var over_wings := Array(_points(shape, &"shell", 48)).filter(func(point: Vector3) -> bool:
			return point.z > shape.face() + EPSILON)
		assert_array(over_wings).is_not_empty()
		for point: Vector3 in over_wings:
			assert_bool(band.grow(EPSILON).has_point(Vector2(point.x, point.y))).override_failure_message(
				"%s stands over the wings" % point).is_true()
			assert_float(point.z).is_less_equal(front + EPSILON)
		var label := _points(shape, &"label", 48)
		var recess := shape.label_box().grow(N64CartShape.LABEL_GAP)
		for point in label:
			assert_bool(recess.has_point(Vector2(point.x, point.y))).is_true()
			assert_float(point.z).is_between(shape.face() - N64CartShape.OVERLAP - EPSILON,
				shape.face() + N64CartShape.LABEL_THICKNESS + EPSILON)
		# The label's front faces out of the recess, below the band's front.
		assert_float(Fixtures.bounds(label).end.z).is_less(front)


func test_the_rails_indentations_and_slot_are_cut_where_measured() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(643))):
		var shell := _corners(shape.mesh_arrays(&"shell", 48))
		var low := shape.whole().position
		var back := -shape.depth / 2.0
		for side: float in [-1.0, 1.0]:
			var rail := _mirrored(AABB(Vector3(low.x, low.y, shape.rails()),
				Vector3(shape.rail_size.x, shape.rail_size.y - N64CartShape.RAIL_CORNER, shape.rail_step)), side)
			var notch := _mirrored(AABB(Vector3(low.x + shape.notch_from, low.y, back),
				Vector3(shape.notch_size.x, shape.notch_size.y, shape.notch_depth)), side)
			for cut: AABB in [rail, notch]:
				assert_bool(Fixtures.meets(shell, cut.grow(-CLEAR))).override_failure_message(
					"%s not cut" % cut).is_false()
				# Beside it, towards the middle, the face it is cut in is whole.
				var beside := cut.grow(CLEAR)
				beside.position.x -= cut.size.x * side
				assert_bool(Fixtures.meets(shell, beside)).override_failure_message("%s cut" % beside).is_true()
		var slot := AABB(Vector3(-shape.slot_size.x / 2.0, low.y, -shape.slot_size.y / 2.0),
			Vector3(shape.slot_size.x, shape.slot_depth, shape.slot_size.y))
		assert_bool(Fixtures.meets(shell, slot.grow(-CLEAR))).is_false()
		# The contacts in the slot, but for their top, sunk into the shell above it.
		var contacts := Fixtures.bounds(_points(shape, &"contacts", 48))
		contacts.size.y -= N64CartShape.OVERLAP
		assert_bool(slot.grow(EPSILON).encloses(contacts)).is_true()


func test_a_groove_runs_down_each_side_of_the_band_to_the_core_narrow_and_lined_a_shade_darker() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(645))):
		var shell := shape.mesh_arrays(&"shell", 48)
		var lining := shape.mesh_arrays(&"grooves", 48)
		var front := shape.depth / 2.0
		var band := shape.band_width / 2.0
		for side: float in [-1.0, 1.0]:
			for y: float in [-0.3 * shape.height, 0.0, 0.25 * shape.height]:
				var middle := side * shape.front_line()
				assert_float(Fixtures.hit(shell, Vector3(middle, y, FAR), Vector3.FORWARD).z) \
					.is_equal_approx(shape.rails(), EPSILON)
				assert_float(Fixtures.hit(lining, Vector3(middle, y, FAR), Vector3.FORWARD).z) \
					.is_equal_approx(shape.rails() + N64CartShape.LINING, EPSILON)
				# Either side, the band's front and the wing's, flat past the groove's lips, its own
				# rolled edges far from it.
				var on_band := side * (band - shape.lip - CLEAR)
				var on_wing := side * (band + shape.groove + shape.lip + CLEAR)
				assert_float(Fixtures.hit(shell, Vector3(on_band, y, FAR), Vector3.FORWARD).z) \
					.is_equal_approx(front, EPSILON)
				assert_float(Fixtures.hit(shell, Vector3(on_wing, y, FAR), Vector3.FORWARD).z) \
					.is_equal_approx(shape.face(), EPSILON)
				# Its walls upright from its floor up to its lips, each lined a hair inside.
				for z: float in [shape.rails() + CLEAR, shape.face() - shape.lip - CLEAR]:
					var at := Vector3(middle, y, z)
					assert_float(absf(Fixtures.hit(shell, at, Vector3(-side, 0.0, 0.0)).x)) \
						.is_equal_approx(band, EPSILON)
					assert_float(absf(Fixtures.hit(shell, at, Vector3(side, 0.0, 0.0)).x)) \
						.is_equal_approx(band + shape.groove, EPSILON)
					assert_float(absf(Fixtures.hit(lining, at, Vector3(-side, 0.0, 0.0)).x)) \
						.is_equal_approx(band + N64CartShape.LINING, EPSILON)


func test_the_grooves_go_over_the_top_and_down_the_back_broken_by_the_sticker() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(647))):
		var shell := shape.mesh_arrays(&"shell", 48)
		var lining := shape.mesh_arrays(&"grooves", 48)
		var back := -shape.depth / 2.0
		var sticker := shape.sticker_box()
		# Over the top: through the front half at the front's grooves, through the back half at the
		# back's, as deep as they go.
		var front_half := (shape.slot_size.y / 2.0 + shape.rails()) / 2.0
		var back_half := back + shape.notch_depth + 1.0
		for side: float in [-1.0, 1.0]:
			for over: Array in [[shape.front_line(), front_half, shape.back_line()],
					[shape.back_line(), back_half, shape.front_line()]]:
				var x: float = side * over[0]
				var z: float = over[1]
				var top := shape.height / 2.0 - shape.arch_within(0.0, absf(x))
				assert_float(Fixtures.hit(shell, Vector3(x, FAR, z), Vector3.DOWN).y) \
					.is_equal_approx(top - shape.groove_depth, EPSILON)
				assert_float(Fixtures.hit(lining, Vector3(x, FAR, z), Vector3.DOWN).y) \
					.is_equal_approx(top - shape.groove_depth + N64CartShape.LINING, EPSILON)
				# Where the other half's groove runs, this half's top is whole.
				var other: float = side * over[2]
				var level := shape.height / 2.0 - shape.arch_within(0.0, absf(other))
				assert_float(Fixtures.hit(shell, Vector3(other, FAR, z), Vector3.DOWN).y).is_greater(level - shape.lip)
			# Down the back: from the top to the sticker, through the screw, and from the sticker to
			# the bottom, lined at its depth; none under the sticker.
			var line := side * shape.back_line()
			var above := (sticker.end.y + shape.screw_centre.y - shape.screw_radius) / 2.0
			var below := (sticker.position.y - shape.height / 2.0) / 2.0
			for y: float in [above, below]:
				assert_float(Fixtures.hit(shell, Vector3(line, y, -FAR), Vector3.BACK).z) \
					.is_equal_approx(back + shape.notch_depth, EPSILON)
				assert_float(Fixtures.hit(lining, Vector3(line, y, -FAR), Vector3.BACK).z) \
					.is_equal_approx(back + shape.groove_depth - N64CartShape.LINING, EPSILON)
				var beside := line + side * (shape.groove / 2.0 + shape.lip + CLEAR)
				assert_float(Fixtures.hit(shell, Vector3(beside, y, -FAR), Vector3.BACK).z) \
					.is_equal_approx(back, EPSILON)
			var under := Vector3(line, sticker.get_center().y, -FAR)
			assert_float(Fixtures.hit(shell, under, Vector3.BACK).z).is_equal_approx(back, EPSILON)
			assert_bool(Fixtures.hit(lining, under, Vector3.BACK).is_finite()).is_false()


func test_the_screws_and_the_oval_s_rim_stand_on_the_back_above_its_indentations() -> void:
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(644))):
		var back := -shape.depth / 2.0
		var screws := _points(shape, &"screws", 48)
		for point in screws:
			assert_float(point.z).is_between(back - N64CartShape.SCREW_PROUD - EPSILON,
				back + N64CartShape.OVERLAP + EPSILON)
			assert_float(point.y).is_greater(shape.notch_size.y - shape.height / 2.0)
		# Two screws, either side of the middle.
		for side: float in [-1.0, 1.0]:
			var centre := shape.screw_centre * Vector2(side, 1.0)
			assert_bool(Array(screws).any(func(point: Vector3) -> bool:
				return is_equal_approx(Vector2(point.x, point.y).distance_to(centre), shape.screw_radius))).is_true()
		# The rim stands out round the oval; inside it, the back's face.
		var shell := shape.mesh_arrays(&"shell", 48)
		var oval := shape.oval_box()
		var on_rim := Vector3(oval.get_center().x, oval.end.y - shape.oval_rim.x / 2.0, -FAR)
		assert_float(Fixtures.hit(shell, on_rim, Vector3.BACK).z).is_equal_approx(back - shape.oval_rim.y, EPSILON)
		var inside := Vector3(oval.get_center().x, oval.end.y - shape.oval_rim.x - CLEAR, -FAR)
		assert_float(Fixtures.hit(shell, inside, Vector3.BACK).z).is_equal_approx(back, EPSILON)
		var outside := Vector3(oval.get_center().x, oval.end.y + CLEAR, -FAR)
		assert_float(Fixtures.hit(shell, outside, Vector3.BACK).z).is_equal_approx(back, EPSILON)


func test_the_sticker_and_the_moulded_name_are_printed_on_the_back_reading_the_right_way_from_behind() -> void:
	var checked := 0
	for shape: N64CartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(646))):
		# Off the middle, so that a mirrored print shows.
		shape.sticker_centre.x += 1.5
		shape.oval_centre.x -= 1.5
		if not shape.problems().is_empty():
			continue
		checked += 1
		var back := -shape.depth / 2.0
		var shell := shape.mesh_arrays(&"shell", 48)
		for printed: Array in [[&"sticker", shape.sticker_box(), back - N64CartShape.STICKER_THICKNESS],
				[&"lettering", shape.lettering_box(), back - N64CartShape.LETTERING_PROUD]]:
			var part: StringName = printed[0]
			var box: Rect2 = printed[1]
			var level: float = printed[2]
			var arrays := shape.mesh_arrays(part, 48)
			var inside := box.get_center() + box.size * Vector2(0.21, -0.13)
			var face := Fixtures.hit(arrays, Vector3(inside.x, inside.y, -FAR), Vector3.BACK)
			assert_float(face.z).is_equal_approx(level, EPSILON)
			assert_float(Fixtures.hit(shell, Vector3(inside.x, inside.y, -FAR), Vector3.BACK).z).is_greater(face.z)
			assert_bool(Fixtures.hit(arrays, Vector3(box.end.x + EPSILON, inside.y, -FAR), Vector3.BACK).is_finite()) \
				.is_false()
			# Seen from behind, the image's top left corner is at the box's top right seen from the front.
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in points.size():
				if normals[i].z < -0.5:
					var seen := Vector2(box.end.x - points[i].x / MM, box.end.y - points[i].y / MM) / box.size
					assert_vector(uvs[i]).is_equal_approx(seen, Vector2.ONE * EPSILON)
	assert_int(checked).is_greater(0)


## A cartridge its rules accept, drawn around the shipped one by [param random].
func _cart(random: RandomNumberGenerator) -> N64CartShape:
	return Fixtures.drawn_around(_shipped(), random, Vector2(0.85, 1.15), 0, 0.3)


func _shipped() -> N64CartShape:
	var model: Node3D = auto_free((load(SCENE) as PackedScene).instantiate())
	return ((model.get_node(^"Label") as MeshInstance3D).mesh as ShapedMesh).shape


## The points of [param part] of [param shape], in millimetres.
func _points(shape: N64CartShape, part: StringName, detail: int) -> PackedVector3Array:
	return Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * Fixtures.points(shape.mesh_arrays(part, detail))


## The corners of the triangles of [param arrays], three by three, in millimetres.
func _corners(arrays: Array) -> PackedVector3Array:
	var corners := PackedVector3Array()
	for triangle in Fixtures.triangles(arrays):
		corners.append_array(Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * triangle)
	return corners


## [param box], laid out from the left side, on the side [param side] (-1 the left, 1 the right).
func _mirrored(box: AABB, side: float) -> AABB:
	if side < 0.0:
		return box
	return AABB(Vector3(-box.end.x, box.position.y, box.position.z), box.size)
