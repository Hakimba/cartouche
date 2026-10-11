# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The North American Super Nintendo's cartridge's own looks: its outline and its tab, its raised
## body and its grip's channel, its grooves and the notches in its back.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SHAPES := 100
const MODELS := 12
const DETAIL := 32
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_impossible_snes_us_cart_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: SnesUsCartShape) -> void: cart.tab = 0.0],
		[&"sizes_positive", func(cart: SnesUsCartShape) -> void: cart.groove_width = 0.0],
		[&"halves_hold_their_rolls", func(cart: SnesUsCartShape) -> void:
			cart.front_round = cart.wings() - cart.slot_size.y / 2.0],
		[&"halves_hold_their_rolls", func(cart: SnesUsCartShape) -> void:
			cart.back_round = cart.thickness / 2.0 - cart.slot_size.y / 2.0],
		[&"slot_in_the_end", func(cart: SnesUsCartShape) -> void: cart.slot_size.x = cart.width],
		[&"board_in_the_slot", func(cart: SnesUsCartShape) -> void: cart.side_contacts = 12],
		[&"body_on_the_face", func(cart: SnesUsCartShape) -> void: cart.body_width = cart.width],
		[&"body_on_the_face", func(cart: SnesUsCartShape) -> void: cart.rail_width = 2.0 * cart.body_round],
		[&"body_on_the_face", func(cart: SnesUsCartShape) -> void: cart.channel_width = cart.body_width],
		[&"body_on_the_face", func(cart: SnesUsCartShape) -> void: cart.channel_depth.y = cart.body_raise],
		[&"body_on_the_face", func(cart: SnesUsCartShape) -> void: cart.grip_top = -cart.height / 2.0],
		[&"label_on_the_body", func(cart: SnesUsCartShape) -> void: cart.label_centre.y = cart.grip_top],
		[&"label_on_the_body", func(cart: SnesUsCartShape) -> void: cart.recess = cart.body_raise],
		[&"grooves_on_the_wings", func(cart: SnesUsCartShape) -> void: cart.groove_from_top = 0.0],
		[&"grooves_on_the_wings", func(cart: SnesUsCartShape) -> void: cart.groove_pitch = cart.groove_width],
		[&"screws_on_the_wings", func(cart: SnesUsCartShape) -> void: cart.screw_inset.x = cart.width / 2.0],
		[&"back_holds_the_sticker_and_the_notches", func(cart: SnesUsCartShape) -> void:
			cart.notch_inset = cart.width / 2.0],
		[&"back_holds_the_sticker_and_the_notches", func(cart: SnesUsCartShape) -> void:
			cart.notch_size.z = cart.thickness],
	]
	var random := Fixtures.cases(1311)
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_snes_us_cart_fills_its_outline_its_raised_body_alone_reaching_up_its_tab() -> void:
	for shape: SnesUsCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1312))):
		var points := PackedVector3Array()
		for part in shape.parts():
			points.append_array(Fixtures.points(shape.mesh_arrays(part, DETAIL)))
		var off := SnesUsCartShape.DARK_OFF
		var expected := AABB(Vector3(-shape.width / 2.0 - off, -shape.height / 2.0 - off, -shape.thickness / 2.0 - off),
			Vector3(shape.width + 2.0 * off, shape.height + off, shape.thickness + off))
		var found := Fixtures.bounds(points)
		assert_vector(found.position / MM).is_equal_approx(expected.position, Vector3.ONE * EPSILON)
		assert_vector(found.end / MM).is_equal_approx(expected.end, Vector3.ONE * EPSILON)
		var in_tab := 0
		for at in Fixtures.points(shape.mesh_arrays(&"shell", DETAIL)):
			var mm := at / MM
			if mm.y > shape.outline().end.y + EPSILON:
				assert_float(absf(mm.x)).is_less_equal(shape.body_width / 2.0 + EPSILON)
				assert_float(mm.z).is_greater_equal(shape.body_back() - EPSILON)
				in_tab += 1
		assert_int(in_tab).is_greater(0)


func test_the_grip_s_sides_slope_down_to_its_channel_at_its_top_the_channel_at_the_wings_face() -> void:
	for shape: SnesUsCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1313))):
		var triangles := Fixtures.triangles(shape.mesh_arrays(&"shell", DETAIL))
		var bottom := -shape.height / 2.0 + shape.seam + SnesUsCartShape.END_SET
		var top := shape.grip_top + SnesUsCartShape.BODY_CORNER
		var side := (shape.channel_width / 2.0 + shape.body_width / 2.0 - shape.rail_width) / 2.0
		# From where the wings' face stops rolling over the end, to under the upper part.
		for y: float in [shape.face().position.y + 0.1, (bottom + shape.grip_top) / 2.0, shape.grip_top - 0.5]:
			var rise := lerpf(shape.channel_depth.y, shape.channel_depth.x, (y - bottom) / (top - bottom))
			for x: float in [-side, side]:
				assert_float(_top(triangles, Vector2(x, y))).is_equal_approx(shape.wings() + rise, EPSILON)
			assert_float(_top(triangles, Vector2(0.0, y))).is_equal_approx(shape.wings(), EPSILON)


func test_the_grooves_go_round_the_wings_and_the_back_clear_of_the_raised_body_and_the_sticker() -> void:
	for shape: SnesUsCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1314))):
		var dark := shape.mesh_arrays(&"dark", DETAIL)
		var corners := PackedVector3Array()
		for triangle in Fixtures.triangles(dark):
			corners.append_array(triangle)
		var back := -shape.thickness / 2.0
		var front := shape.thickness / 2.0
		var sticker := shape.sticker_box().grow(SnesPalCartShape.RIM - 0.01)
		var body := shape.body_width / 2.0 - 0.51
		for clear: AABB in [AABB(Vector3(sticker.position.x, sticker.position.y, back - 0.1),
				Vector3(sticker.size.x, sticker.size.y, 0.1 + shape.sticker_recess)),
				AABB(Vector3(-body, -shape.height, shape.wings() + 0.05), Vector3(2.0 * body, 2.0 * shape.height, front))]:
			assert_bool(Fixtures.meets(corners, AABB(clear.position * MM, clear.size * MM))).is_false()
		for at in Fixtures.points(dark):
			var mm := at / MM
			var in_notch := shape.notches().any(func(notch: Rect2) -> bool:
				return notch.grow(SnesUsCartShape.DARK_OFF + EPSILON).has_point(Vector2(mm.x, mm.y)))
			assert_bool(in_notch or Array(shape.grooves()).any(func(y: float) -> bool:
				return absf(mm.y - y) <= shape.groove_width / 2.0 + EPSILON)).is_true()
		# Round the back, both sides and both wings' faces.
		var found := Fixtures.bounds(Fixtures.points(dark))
		assert_float(found.size.x / MM).is_equal_approx(shape.width + 2.0 * SnesUsCartShape.DARK_OFF, EPSILON)
		assert_bool(shape.groove_count == 0 or found.end.z / MM > shape.wings()).is_true()


func test_the_notches_open_on_the_back_and_the_end_beside_the_slot() -> void:
	for shape: SnesUsCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1315))):
		var off := SnesUsCartShape.DARK_OFF
		for notch in shape.notches():
			var box := AABB(Vector3(notch.position.x, notch.position.y - off, -shape.thickness / 2.0 - off),
				Vector3(notch.size.x, notch.size.y + off, shape.notch_size.z + off))
			var found := PackedVector3Array()
			for at in Fixtures.points(shape.mesh_arrays(&"dark", DETAIL)):
				if box.grow(EPSILON).has_point(at / MM):
					found.append(at / MM)
			assert_vector(Fixtures.bounds(found).position).is_equal_approx(box.position, Vector3.ONE * EPSILON)
			assert_vector(Fixtures.bounds(found).end).is_equal_approx(box.end, Vector3.ONE * EPSILON)
			assert_float(absf(notch.get_center().x)).is_greater(shape.slot_size.x / 2.0)


## The height, in millimetres, of the highest of [param triangles] over [param at].
static func _top(triangles: Array[PackedVector3Array], at: Vector2) -> float:
	var highest := -INF
	for corners in triangles:
		var a := Vector2(corners[0].x, corners[0].y) / MM
		var b := Vector2(corners[1].x, corners[1].y) / MM
		var c := Vector2(corners[2].x, corners[2].y) / MM
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-9:
			continue
		var u := (b - at).cross(c - at) / area
		var v := (c - at).cross(a - at) / area
		if u >= -1e-6 and v >= -1e-6 and 1.0 - u - v >= -1e-6:
			highest = maxf(highest, (u * corners[0].z + v * corners[1].z + (1.0 - u - v) * corners[2].z) / MM)
	return highest


## A cartridge drawn around the shipped one, which its rules accept.
static func _cart(random: RandomNumberGenerator) -> SnesUsCartShape:
	return Fixtures.drawn_around(SnesUsCartShape.new(), random, Vector2(0.94, 1.06), 2, 0.4) as SnesUsCartShape
