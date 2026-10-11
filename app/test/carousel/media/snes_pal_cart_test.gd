# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The European Super Nintendo's cartridge's own looks, the Super Famicom's too: its outline, its
## label's recess, its grip, its slits, its holes and its board's contacts.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SCENE := "res://carousel/media/snes_pal_cart/snes_pal_cart.tscn"
const SHAPES := 120
const MODELS := 12
const DETAIL := 32
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_impossible_snes_pal_cart_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: SnesPalCartShape) -> void: cart.recess = 0.0],
		[&"sizes_positive", func(cart: SnesPalCartShape) -> void: cart.plate_lip = 0.0],
		[&"sizes_positive", func(cart: SnesPalCartShape) -> void: cart.centre_contacts = 0],
		[&"halves_hold_their_rolls", func(cart: SnesPalCartShape) -> void:
			cart.side_round = cart.wings() - cart.slot_size.y / 2.0],
		[&"halves_hold_their_rolls", func(cart: SnesPalCartShape) -> void:
			cart.back_round = cart.thickness / 2.0 - cart.slot_size.y / 2.0],
		[&"slot_in_the_end", func(cart: SnesPalCartShape) -> void: cart.slot_size.x = cart.width],
		[&"slot_in_the_end", func(cart: SnesPalCartShape) -> void: cart.slot_depth = cart.height / 2.0],
		[&"board_in_the_slot", func(cart: SnesPalCartShape) -> void: cart.side_contacts = 12],
		[&"plates_on_the_face", func(cart: SnesPalCartShape) -> void: cart.plate_width = cart.width],
		[&"plates_on_the_face", func(cart: SnesPalCartShape) -> void:
			cart.plate_raise = cart.thickness / 2.0 - cart.plate_back()],
		[&"label_on_the_face", func(cart: SnesPalCartShape) -> void: cart.label_size.x = cart.width],
		[&"label_on_the_face", func(cart: SnesPalCartShape) -> void: cart.label_centre.y = cart.height / 2.0],
		[&"grip_in_the_plate", func(cart: SnesPalCartShape) -> void: cart.grip_size.x = cart.plate_width],
		[&"grip_in_the_plate", func(cart: SnesPalCartShape) -> void:
			cart.grip_depth = cart.thickness / 2.0 - cart.plate_back()],
		[&"grip_in_the_plate", func(cart: SnesPalCartShape) -> void: cart.grip_slope = cart.grip_size.y / 2.0],
		[&"grip_in_the_plate", func(cart: SnesPalCartShape) -> void: cart.grip_depth = cart.plate_raise],
		[&"slits_on_the_sides", func(cart: SnesPalCartShape) -> void: cart.slit_from_top = 0.0],
		[&"slits_on_the_sides", func(cart: SnesPalCartShape) -> void: cart.slit_pitch = cart.slit_height],
		[&"screws_on_the_wings", func(cart: SnesPalCartShape) -> void: cart.screw_inset.x = cart.width / 2.0],
		[&"screws_on_the_wings", func(cart: SnesPalCartShape) -> void: cart.screw_inset.y = cart.height / 2.0],
		[&"back_holds_the_sticker_and_the_holes", func(cart: SnesPalCartShape) -> void:
			cart.sticker_size.x = cart.width],
		[&"back_holds_the_sticker_and_the_holes", func(cart: SnesPalCartShape) -> void:
			cart.hole_inset = Vector2(cart.width / 2.0, cart.height / 2.0) + cart.sticker_centre],
	]
	var random := Fixtures.cases(1301)
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_snes_pal_cart_fills_its_outline_its_plates_standing_past_its_end_and_its_top() -> void:
	for shape: SnesPalCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1302))):
		var points := PackedVector3Array()
		for part in shape.parts():
			points.append_array(Fixtures.points(shape.mesh_arrays(part, DETAIL)))
		var reach := maxf(shape.height / 2.0, shape.height / 2.0 - shape.seam + shape.plate_lip)
		var expected := AABB(Vector3(-shape.width / 2.0, -reach, -shape.thickness / 2.0 - 0.04),
			Vector3(shape.width, 2.0 * reach, shape.thickness + 0.04))
		var found := Fixtures.bounds(points)
		assert_vector(found.position / MM).is_equal_approx(expected.position, Vector3.ONE * EPSILON)
		assert_vector(found.end / MM).is_equal_approx(expected.end, Vector3.ONE * EPSILON)


func test_the_label_lies_at_the_bottom_of_its_recess_upright_its_image_filling_it() -> void:
	for shape: SnesPalCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1303))):
		var label := shape.mesh_arrays(&"label", DETAIL)
		var points := Fixtures.points(label)
		var uvs: PackedVector2Array = label[Mesh.ARRAY_TEX_UV]
		var box := shape.label_box()
		for i in points.size():
			var at := points[i] / MM
			assert_float(at.z).is_equal_approx(shape.wings() - shape.recess, EPSILON)
			assert_vector(uvs[i]).is_equal_approx(Vector2((at.x - box.position.x) / box.size.x,
				(box.end.y - at.y) / box.size.y), Vector2.ONE * EPSILON)
		var found := Fixtures.bounds(points)
		assert_vector(Vector2(found.size.x, found.size.y) / MM).is_equal_approx(box.size, Vector2.ONE * EPSILON)


func test_nothing_fills_the_grip_but_its_raised_middle_and_its_ridges() -> void:
	for shape: SnesPalCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1304))):
		var corners := PackedVector3Array()
		for triangle in Fixtures.triangles(shape.mesh_arrays(&"shell", DETAIL)):
			corners.append_array(triangle)
		# The floor's straight part, short of its round ends.
		var floor_box := shape.grip_floor().grow_individual(-shape.grip_corner() + shape.grip_slope, 0.0,
			-shape.grip_corner() + shape.grip_slope, 0.0).grow(-0.01)
		var front := shape.thickness / 2.0
		var bottom := front - shape.grip_depth
		var highest := bottom + maxf(shape.grip_rise, SnesPalCartShape.RIDGE.y) + 0.01
		var above := AABB(Vector3(floor_box.position.x, floor_box.position.y, highest),
			Vector3(floor_box.size.x, floor_box.size.y, front + 1.0 - highest))
		var at_floor := AABB(Vector3(floor_box.position.x, floor_box.position.y, bottom - 0.01),
			Vector3(floor_box.size.x, floor_box.size.y, 0.02))
		assert_bool(Fixtures.meets(corners, AABB(above.position * MM, above.size * MM))).is_false()
		assert_bool(Fixtures.meets(corners, AABB(at_floor.position * MM, at_floor.size * MM))).is_true()


func test_the_slits_lie_up_both_sides_rolls_and_the_holes_in_the_back() -> void:
	for shape: SnesPalCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1305))):
		var sides: Dictionary[float, int] = {-1.0: 0, 1.0: 0}
		var reach := shape.slits()[-1] - shape.slit_height / 2.0 if shape.slit_count > 0 else INF
		for at in Fixtures.points(shape.mesh_arrays(&"dark", DETAIL)):
			var mm := at / MM
			if mm.z < -shape.thickness / 2.0 + 0.2:
				continue
			assert_float(absf(mm.x)).is_greater(shape.face().end.x - 0.6)
			assert_float(mm.y).is_greater_equal(reach - EPSILON)
			sides[signf(mm.x)] += 1
		assert_bool(shape.slit_count == 0 or sides[-1.0] == sides[1.0] and sides[1.0] > 0).is_true()


func test_the_contacts_lie_in_the_slot_on_both_faces_of_the_board() -> void:
	for shape: SnesPalCartShape in Fixtures.accepted(self, MODELS, _cart.bind(Fixtures.cases(1306))):
		var slot := AABB(Vector3(-shape.slot_size.x / 2.0, -shape.height / 2.0, -shape.slot_size.y / 2.0),
			Vector3(shape.slot_size.x, shape.slot_depth, shape.slot_size.y))
		var faces: Dictionary[float, int] = {-1.0: 0, 1.0: 0}
		for at in Fixtures.points(shape.mesh_arrays(&"metal", DETAIL)):
			var mm := at / MM
			if mm.z > shape.wings() - 0.5:
				continue
			assert_bool(slot.has_point(mm)).is_true()
			faces[signf(mm.z)] += 1
		assert_int(faces[-1.0]).is_equal(faces[1.0])
		assert_int(faces[1.0]).is_greater(0)


func test_a_super_famicom_cartridge_is_the_european_one_s_shell() -> void:
	# The same scene: its models are those of the European one.
	assert_str(MediumManifest.found()["sfc_cart"].scene).is_equal(SCENE)


## A cartridge drawn around the shipped one, which its rules accept.
static func _cart(random: RandomNumberGenerator) -> SnesPalCartShape:
	return Fixtures.drawn_around(SnesPalCartShape.new(), random, Vector2(0.94, 1.06), 2, 0.4) as SnesPalCartShape
