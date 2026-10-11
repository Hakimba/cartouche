# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy Color's own looks: its power switch, its face rolling back, how it is presented
## and where its cartridge stands.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/gbc/gbc.tscn"
## Building a whole console takes a while: fewer cases than the carousel's properties.
const SHAPES := 200
const CONSOLES := 12
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_gbc_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(90)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(gbc: GbcShape) -> void: gbc.ir_width = 0.0],
		[&"shell_holds_its_edges", func(gbc: GbcShape) -> void: gbc.top_corner = gbc.bevel],
		[&"face_rolls_back_below_the_bezel", func(gbc: GbcShape) -> void: gbc.chin_drop = gbc.depth],
		[&"face_rolls_back_below_the_bezel", func(gbc: GbcShape) -> void: gbc.panel_width = gbc.width],
		[&"face_rolls_back_below_the_bezel", func(gbc: GbcShape) -> void: gbc.chin_height = gbc.height / 2.0],
		[&"pocket_in_the_back", func(gbc: GbcShape) -> void: gbc.pocket_depth = 2.0 * gbc.bevel],
		[&"pocket_in_the_back", func(gbc: GbcShape) -> void: gbc.slot_width = gbc.width - 2.0 * gbc.top_corner],
		[&"slot_takes_the_cartridge", func(gbc: GbcShape) -> void: gbc.cartridge.x = gbc.slot_width],
		[&"slot_takes_the_cartridge", func(gbc: GbcShape) -> void:
			gbc.cartridge.z = gbc.pocket_depth - gbc.cartridge_inset],
		[&"cartridge_stands_in_the_slot", func(gbc: GbcShape) -> void: gbc.cartridge_rise = 0.0],
		[&"cartridge_stands_in_the_slot", func(gbc: GbcShape) -> void:
			gbc.cartridge.y = gbc.pocket_length + gbc.cartridge_rise],
		# The connector down in the bottom edge's rounded corners; a cartridge against the back plate's wall.
		[&"cartridge_stands_in_the_slot", func(gbc: GbcShape) -> void:
			gbc.cartridge.y = gbc.height - gbc.bottom_corner],
		[&"slot_takes_the_cartridge", func(gbc: GbcShape) -> void: gbc.cartridge_inset = gbc.back_wall()],
		[&"battery_cover_on_the_back", func(gbc: GbcShape) -> void: gbc.battery_size.x = gbc.width],
		[&"screws_and_sticker_on_the_back", func(gbc: GbcShape) -> void:
			gbc.battery_size.y = gbc.height - gbc.pocket_length - 10.0],
		[&"bezel_on_the_face", func(gbc: GbcShape) -> void: gbc.led = gbc.screen().get_center()],
		[&"buttons_on_the_face", func(gbc: GbcShape) -> void: gbc.button_b = gbc.button_a],
		[&"buttons_on_the_face", func(gbc: GbcShape) -> void: gbc.dpad.y = gbc.bezel().position.y],
		[&"speaker_on_the_face", func(gbc: GbcShape) -> void: gbc.speaker_radius = GbcShape.HOLE_PITCH],
		[&"switch_on_the_right_side", func(gbc: GbcShape) -> void: gbc.power_travel = GbcShape.RECESS.x],
		[&"switch_on_the_right_side", func(gbc: GbcShape) -> void: gbc.power_y = gbc.height / 2.0],
		[&"wheel_and_link_on_the_left_side", func(gbc: GbcShape) -> void:
			gbc.wheel_y = gbc.height / 2.0 - gbc.top_corner],
		[&"ribs_above_the_switch_and_the_link", func(gbc: GbcShape) -> void: gbc.ribs_y = gbc.power_y],
		[&"ir_window_on_the_top", func(gbc: GbcShape) -> void: gbc.ir_x = gbc.width / 2.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _gbc.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_power_knob_slides_up_its_recess_on_the_right_side_standing_out_of_it_half_a_millimetre_at_most() -> void:
	var random := Fixtures.cases(91)
	for shape: GbcShape in Fixtures.accepted(self, CONSOLES, _gbc.bind(random)):
		var console: GbcModel = Fixtures.built(self, SCENE, shape)
		var knob: MeshInstance3D = console.get_node("%Power/Knob")
		var recess := shape.recess().grow(EPSILON)
		var at_rest := Fixtures.box_of(console, knob)
		var power: MovingPart = console.moving_parts().filter(func(part: MovingPart) -> bool:
			return part.role == MovingPart.Role.POWER)[0]
		console.set(power.property, power.open)
		var slid := Fixtures.box_of(console, knob)
		console.set(power.property, power.rest)
		for box: AABB in [at_rest, slid]:
			assert_bool(recess.encloses(_on_the_side(box))).is_true()
			assert_float(box.end.x / MM).is_between(shape.width / 2.0, shape.width / 2.0 + 0.5)
		assert_float((slid.position.y - at_rest.position.y) / MM).is_equal_approx(shape.power_travel, EPSILON)
		assert_float(shape.power_travel).is_greater(0.5)


func test_a_cartridge_goes_down_the_pocket_and_behind_the_back_plate_to_the_connector_standing_out() -> void:
	var random := Fixtures.cases(92)
	for shape: GbcShape in Fixtures.accepted(self, SHAPES, _gbc.bind(random)):
		var console: GbcModel = auto_free(Fixtures.new_console(SCENE))
		console.shape = shape
		var seat := console.seat()
		assert_vector(console.approach()).is_equal(Vector3.UP)
		assert_vector(seat.basis * Vector3.UP).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		assert_vector(seat.basis * Vector3.BACK).is_equal_approx(Vector3.FORWARD, Vector3.ONE * EPSILON)
		var standing := AABB(seat.origin / MM - shape.cartridge / 2.0, shape.cartridge)
		# Between the pocket's sides, behind the front half, its label behind the back.
		assert_float(standing.position.x).is_greater(-shape.slot_width / 2.0)
		assert_float(standing.end.x).is_less(shape.slot_width / 2.0)
		assert_float(standing.position.z).is_greater(-shape.depth / 2.0)
		assert_float(standing.end.z).is_less(shape.seam())
		assert_float(standing.end.y).is_equal_approx(shape.height / 2.0 + shape.cartridge_rise, EPSILON)
		assert_float(standing.position.y).is_less(shape.slot().position.y)
		var behind := shape.cartridge_inset - shape.back_wall()
		var play := Vector2((shape.slot_width - shape.cartridge.x) / 2.0,
			maxf(behind, shape.pocket_depth - shape.cartridge_inset - shape.cartridge.z))
		Fixtures.assert_in_slot(self, shape, standing, play, random.randi_range(16, 64))


func test_the_face_is_flat_over_the_panel_and_beside_the_bezel_and_rolls_back_most_towards_the_bottom() -> void:
	var random := Fixtures.cases(93)
	for shape: GbcShape in Fixtures.accepted(self, SHAPES, _gbc.bind(random)):
		var face := shape.face()
		var down := shape.levels()
		assert_float(shape.drop(shape.panel().get_center())).is_equal(0.0)
		assert_float(shape.drop(Vector2(face.position.x, (down[0] + face.end.y - shape.top_corner) / 2.0))).is_equal(0.0)
		assert_float(shape.drop(Vector2(face.position.x, (down[1] + down[2]) / 2.0))) \
			.is_equal_approx(shape.side_drop, EPSILON)
		var chin := shape.panel().position.y
		assert_float(shape.drop(Vector2(0.0, face.position.y))).is_equal_approx(shape.chin_drop, EPSILON)
		# Already sloping where it leaves the panel, steeper towards the edge.
		var midway := shape.drop(Vector2(0.0, (chin + face.position.y) / 2.0))
		assert_float(midway).is_greater(0.1 * shape.chin_drop)
		assert_float(midway).is_less(0.5 * shape.chin_drop)


func test_the_shell_s_face_lies_where_its_shape_says_it_rolls_back() -> void:
	var random := Fixtures.cases(94)
	for shape: GbcShape in Fixtures.accepted(self, CONSOLES, _gbc.bind(random)):
		var front := shape.depth / 2.0
		var face := shape.face().grow(0.01)
		var arrays := shape.mesh_arrays(&"shell", 64)
		var points := Fixtures.points(arrays)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var rolled := 0
		for k in points.size():
			var at := points[k] / MM
			var plan := Vector2(at.x, at.y)
			# The face and its edge face forwards more than the rest of the rounded edge does.
			if at.z < shape.seam() + shape.bevel + 0.5 or normals[k].z < 0.87 or not face.has_point(plan):
				continue
			assert_float(at.z).is_equal_approx(front - shape.drop(plan), EPSILON)
			if shape.drop(plan) > 0.6 * shape.chin_drop:
				rolled += 1
		assert_int(rolled).is_greater(0)


func test_the_console_is_presented_its_face_to_the_camera_its_top_tipped_towards_it() -> void:
	var console: GbcModel = auto_free(Fixtures.new_console(SCENE))
	var facing := console.presented()
	assert_float((facing * Vector3.BACK).z).is_greater(0.9)
	assert_float((facing * Vector3.UP).z).is_greater(0.1)
	assert_float((facing * Vector3.RIGHT).x).is_equal_approx(1.0, EPSILON)


## A Game Boy Color [param random] draws that [method GbcShape.problems] accepts: each dimension up to
## 8 % from the measured one.
static func _gbc(random: RandomNumberGenerator) -> GbcShape:
	return Fixtures.drawn_around(GbcShape.new(), random, Vector2(0.92, 1.08)) as GbcShape


## [param box] seen on the right side, in millimetres: Y up it and Z across it.
static func _on_the_side(box: AABB) -> Rect2:
	return Rect2(Vector2(box.position.y, box.position.z) / MM, Vector2(box.size.y, box.size.z) / MM)
