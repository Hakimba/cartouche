# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The NES Game Pak's own looks: its grip channel ridged, carved at the top into a pocket, the same
## pocket on the back; the label's recess open at the top edge; screws, the sticker and the plate's
## lettering on the back; the stub's end open over the connector.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Building a mesh takes a while: fewer cases than the generic tests'.
const SHAPES := 40
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
## Farther than any cartridge reaches, in millimetres.
const FAR := 1000.0


func test_impossible_nes_cart_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(100)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(pak: NesCartShape) -> void: pak.recess = 0.0],
		[&"sizes_positive", func(pak: NesCartShape) -> void: pak.screw.y = pak.screw.x],
		[&"bevel_fits", func(pak: NesCartShape) -> void: pak.corner = pak.mouth()],
		[&"bevel_fits", func(pak: NesCartShape) -> void: pak.depth = 2.0 * pak.relief()],
		[&"pocket_carved", func(pak: NesCartShape) -> void: pak.pocket_depth = pak.channel_depth],
		[&"pocket_carved", func(pak: NesCartShape) -> void: pak.pocket_corner = pak.channel.y / 2.0],
		[&"stub_fits", func(pak: NesCartShape) -> void: pak.stub.y = pak.height - pak.notch.z],
		[&"stub_fits", func(pak: NesCartShape) -> void: pak.opening.x = pak.stub.x],
		[&"top_edge_in_order", func(pak: NesCartShape) -> void: pak.label_x = pak.channel.x],
		[&"top_edge_in_order", func(pak: NesCartShape) -> void: pak.notch.y = 2.0 * pak.bevel],
		[&"notches_fit", func(pak: NesCartShape) -> void: pak.notch.z = pak.bevel],
		[&"channel_over_the_stub", func(pak: NesCartShape) -> void:
			pak.stub.x = 2.0 * absf(pak.channel_box().position.x)],
		[&"label_above_the_shoulders", func(pak: NesCartShape) -> void: pak.label_size.y = pak.height - pak.stub.y],
		[&"bars_fit", func(pak: NesCartShape) -> void: pak.bar_height = pak.bar_pitch],
		[&"bars_fit", func(pak: NesCartShape) -> void: pak.first_bar = pak.pocket - 0.1],
		[&"bars_fit", func(pak: NesCartShape) -> void: pak.bar_count += ceili(pak.height / pak.bar_pitch)],
		[&"tab_fits", func(pak: NesCartShape) -> void: pak.tab.z = pak.tab.x / 2.0],
		[&"triangle_under_the_label", func(pak: NesCartShape) -> void:
			pak.triangle_centre.y = pak.label_box().position.y],
		[&"back_apart", func(pak: NesCartShape) -> void: pak.screw_top = pak.plate_centre],
		[&"back_apart", func(pak: NesCartShape) -> void: pak.screw_low.x = pak.width / 2.0],
		[&"back_apart", func(pak: NesCartShape) -> void: pak.sticker_centre = pak.screw_top],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _pak.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_channel_is_ridged_and_carved_at_the_top_into_a_pocket_with_walls_round_its_floor_the_same_on_the_back() -> void:
	var random := Fixtures.cases(101)
	for shape: NesCartShape in Fixtures.accepted(self, SHAPES, _pak.bind(random)):
		var shell := shape.mesh_arrays(&"shell", random.randi_range(16, 64))
		var front := shape.depth / 2.0
		var floor_level := front - shape.channel_depth
		var span := shape.bar_span()
		# Off the middle, where the faces' diagonals run.
		var across := span.x + span.y * 0.37
		var k := random.randi_range(0, shape.bar_count - 1)
		var bar: Rect2 = shape.bars()[k]
		assert_float(Fixtures.hit(shell, Vector3(across, bar.get_center().y, FAR), Vector3.FORWARD).z) \
			.is_equal_approx(floor_level + shape.bar_rise, EPSILON)
		# Between two bars, and beside them in the channel.
		if k > 0:
			assert_float(Fixtures.hit(shell, Vector3(across, bar.end.y + (shape.bar_pitch - shape.bar_height) / 2.0, FAR),
				Vector3.FORWARD).z).is_equal_approx(floor_level, EPSILON)
		assert_float(Fixtures.hit(shell, Vector3(span.x - shape.bar_gap / 2.0, bar.get_center().y, FAR),
			Vector3.FORWARD).z).is_equal_approx(floor_level, EPSILON)
		var channel := shape.channel_box()
		var foot := shape.height / 2.0 - shape.pocket
		var floor_at := front - shape.relief()
		for side: float in [1.0, -1.0]:
			var towards := Vector3(0.0, 0.0, -side)
			var pocket_bars := shape.pocket_bars()
			var i := random.randi_range(0, pocket_bars.size() - 1)
			var on_bar := pocket_bars[i]
			assert_float(Fixtures.hit(shell, Vector3(across, on_bar.get_center().y, side * FAR), towards).z * side) \
				.is_equal_approx(floor_at + shape.bar_rise, EPSILON)
			# One floor all through, between the bars: no terraces.
			# Under a bar but the lowest, which stands at its foot; away from the top edge's rounding.
			var gap := (shape.pocket_pitch() - shape.bar_height) / 2.0
			var between := on_bar.position.y - gap if i < pocket_bars.size() - 1 else on_bar.end.y + gap
			assert_float(Fixtures.hit(shell, Vector3(across, between, side * FAR), towards).z * side) \
				.is_equal_approx(floor_at, EPSILON)
			# Its walls, over the bars: on either side, and at its foot.
			var over_bars := Vector3(across, between, side * (floor_at + shape.bar_rise + floor_level) / 2.0)
			var middle_of := Vector3(channel.get_center().x, between, over_bars.z)
			assert_float(Fixtures.hit(shell, middle_of, Vector3.LEFT).x).is_equal_approx(channel.position.x, EPSILON)
			assert_float(Fixtures.hit(shell, middle_of, Vector3.RIGHT).x).is_equal_approx(channel.end.x, EPSILON)
			assert_float(Fixtures.hit(shell, over_bars, Vector3.DOWN).y).is_equal_approx(foot, EPSILON)
			# Its bottom corners rounded: the floor's corner is filled, the wall's middle is not.
			var in_corner := Vector3(channel.position.x + 0.1 * shape.pocket_corner,
				foot + 0.1 * shape.pocket_corner, side * FAR)
			assert_float(Fixtures.hit(shell, in_corner, towards).z * side).is_greater(floor_at + EPSILON)
		# Under the back's pocket, the back's face.
		assert_float(Fixtures.hit(shell, Vector3(across, foot - 1.0, -FAR), Vector3.BACK).z) \
			.is_equal_approx(-front, EPSILON)


func test_the_label_s_recess_is_open_at_the_top_edge_down_to_its_floor_and_its_bottom() -> void:
	var random := Fixtures.cases(102)
	for shape: NesCartShape in Fixtures.accepted(self, SHAPES, _pak.bind(random)):
		var detail := random.randi_range(16, 64)
		var shell := shape.mesh_arrays(&"shell", detail)
		var label := shape.label_box()
		var front := shape.depth / 2.0
		# Its bottom edge rounded at the front by the bevel.
		var inside := Vector3(label.get_center().x, FAR, front - shape.recess / 2.0)
		assert_float(Fixtures.hit(shell, inside, Vector3.DOWN).y).is_between(label.position.y - shape.bevel,
			label.position.y + EPSILON)
		var on_label := label.position + label.size * Vector2(0.43, 0.61)
		var face := Fixtures.hit(shape.mesh_arrays(&"label", detail), Vector3(on_label.x, on_label.y, FAR), Vector3.FORWARD)
		assert_float(face.z).is_equal_approx(front - shape.recess, EPSILON)
		# Beside it, the front's face, from edge to edge.
		assert_float(Fixtures.hit(shell, Vector3(label.end.x + shape.mouth(), label.get_center().y, FAR),
			Vector3.FORWARD).z).is_equal_approx(front, EPSILON)


func test_the_screws_stand_on_the_back_in_their_holes_and_the_stub_s_end_is_open() -> void:
	var random := Fixtures.cases(103)
	for shape: NesCartShape in Fixtures.accepted(self, SHAPES, _pak.bind(random)):
		var detail := random.randi_range(16, 64)
		var dark := shape.mesh_arrays(&"opening", detail)
		var screws := shape.mesh_arrays(&"screws", detail)
		var back := -shape.depth / 2.0
		for at in shape.screws():
			var head := Fixtures.hit(screws, Vector3(at.x + 0.13 * shape.screw.y, at.y + 0.07 * shape.screw.y, -FAR),
				Vector3.BACK)
			assert_float(head.z).is_less(back)
			# Round the head, its hole.
			var hole := Vector3(at.x + (shape.screw.x + shape.screw.y) / 4.0, at.y, -FAR)
			assert_float(Fixtures.hit(dark, hole, Vector3.BACK).z).is_between(head.z, back)
			assert_bool(Fixtures.hit(screws, hole, Vector3.BACK).is_finite()).is_false()
		var end := Fixtures.hit(dark, Vector3(0.13 * shape.opening.x, -FAR, 0.07 * shape.opening.y), Vector3.UP)
		assert_float(end.y).is_less(-shape.height / 2.0)
		assert_bool(Fixtures.hit(dark, Vector3(shape.opening.x / 2.0 + EPSILON, -FAR, 0.0), Vector3.UP).is_finite()) \
			.is_false()


func test_the_sticker_and_the_plate_s_lettering_are_printed_on_the_back_reading_the_right_way_from_behind() -> void:
	var random := Fixtures.cases(104)
	var checked := 0
	for shape: NesCartShape in Fixtures.accepted(self, SHAPES, _pak.bind(random)):
		# Off the middle, so that a mirrored print shows.
		shape.sticker_centre.x += 1.5
		shape.plate_centre.x -= 1.5
		if not shape.problems().is_empty():
			continue
		checked += 1
		var detail := random.randi_range(16, 64)
		var back := -shape.depth / 2.0
		var shell := shape.mesh_arrays(&"shell", detail)
		for printed: Array in [[&"sticker", shape.sticker_box(), back - shape.sticker_thickness],
				[&"lettering", shape.plate_box(), back - shape.plate_rise - NesCartGeometry.OVER]]:
			var part: StringName = printed[0]
			var box: Rect2 = printed[1]
			var level: float = printed[2]
			var arrays := shape.mesh_arrays(part, detail)
			var inside := box.get_center() + box.size * Vector2(0.21, -0.13)
			var face := Fixtures.hit(arrays, Vector3(inside.x, inside.y, -FAR), Vector3.BACK)
			assert_float(face.z).is_equal_approx(level, EPSILON)
			# Over the shell's face it lies on, its edges within the box.
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


## A Game Pak [param random] draws around the shipped one, its rules accepting it.
static func _pak(random: RandomNumberGenerator) -> NesCartShape:
	return Fixtures.drawn_around(NesCartShape.new(), random, Vector2(0.85, 1.15), 2, 0.5)
