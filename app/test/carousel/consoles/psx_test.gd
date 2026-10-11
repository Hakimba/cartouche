# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The first PlayStation's own looks: its lid in the deck over the well, the arc the well cuts in
## the wings, its buttons and its light.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const PSX := "res://carousel/consoles/psx/psx.tscn"
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 100
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_psx_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(60)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(psx: PsxShape) -> void: psx.lid_gap = 0.0],
		[&"corner_rounds_the_bevel", func(psx: PsxShape) -> void: psx.corner = psx.bevel],
		[&"wings_beside_the_deck", func(psx: PsxShape) -> void: psx.centre_width = psx.width],
		[&"deck_below_the_wings", func(psx: PsxShape) -> void: psx.step = psx.bevel],
		[&"deck_below_the_wings", func(psx: PsxShape) -> void: psx.well_depth = psx.height],
		[&"lid_rests_in_the_deck", func(psx: PsxShape) -> void: psx.lid_raise = psx.lid_thickness / 2.0 - 0.1],
		[&"lid_rests_in_the_deck", func(psx: PsxShape) -> void: psx.lid_raise = psx.step],
		[&"opening_inside_the_top", func(psx: PsxShape) -> void: psx.rim = psx.bevel],
		[&"opening_inside_the_top", func(psx: PsxShape) -> void: psx.lid_centre.y = psx.depth / 2.0],
		[&"disc_turns_in_the_well", func(psx: PsxShape) -> void: psx.lid_radius = PsxShape.DISC_RADIUS],
		[&"seat_between_floor_and_lid", func(psx: PsxShape) -> void: psx.seat_depth = psx.well_depth],
		[&"seat_between_floor_and_lid", func(psx: PsxShape) -> void:
			psx.seat_depth = psx.lid_thickness - psx.lid_raise + 2.9],
		[&"buttons_on_the_wings", func(psx: PsxShape) -> void: psx.power_centre = psx.lid_centre],
		[&"buttons_on_the_wings", func(psx: PsxShape) -> void: psx.reset_centre = psx.power_centre],
		[&"buttons_on_the_wings", func(psx: PsxShape) -> void: psx.open_centre.x = psx.width / 2.0],
		[&"vents_up_the_sides", func(psx: PsxShape) -> void: psx.vent_width = psx.vent_pitch],
		[&"vents_up_the_sides", func(psx: PsxShape) -> void: psx.vent_band.y = psx.height],
		[&"vents_up_the_sides", func(psx: PsxShape) -> void: psx.vent_count = 0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _psx.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_lid_rests_in_its_opening_in_the_deck_and_the_disc_sits_over_the_well() -> void:
	var random := Fixtures.cases(61)
	for shape: PsxShape in Fixtures.accepted(self, SHAPES, _psx.bind(random)):
		var detail := random.randi_range(16, 128)
		# The lid is given about its hinge: put back where it closes.
		var lid := _box(shape.mesh_arrays(&"lid", detail), shape.hinge())
		var disc := Rect2(shape.lid_centre - Vector2.ONE * shape.lid_radius, Vector2.ONE * 2.0 * shape.lid_radius)
		var top := shape.deck() + shape.lid_raise
		assert_vector(lid.position).is_equal_approx(Vector3(disc.position.x, top - shape.lid_thickness,
			disc.position.y), Vector3.ONE * EPSILON)
		assert_vector(lid.end).is_equal_approx(Vector3(disc.end.x, top, disc.end.y), Vector3.ONE * EPSILON)
		# Proud of the deck, under the wings' tops, its bottom in the opening.
		assert_float(lid.end.y).is_between(shape.deck(), shape.height)
		assert_float(lid.position.y).is_less(shape.deck())
		var hinge := shape.hinge() / MM
		assert_vector(Vector2(hinge.x, -hinge.z)).is_equal_approx(shape.lid_centre + Vector2(0.0, shape.lid_radius),
			Vector2.ONE * EPSILON)
		var seat := shape.seat()
		assert_vector(seat.origin / MM).is_equal_approx(
			Vector3(shape.lid_centre.x, shape.deck() - shape.seat_depth, -shape.lid_centre.y), Vector3.ONE * EPSILON)
		assert_vector(seat.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		# A seated disc turns clear of the well's wall, between its floor and the closed lid.
		assert_float(shape.opening()).is_greater(PsxShape.DISC_RADIUS)
		assert_float(seat.origin.y / MM).is_between(shape.deck() - shape.well_depth, lid.position.y)


func test_the_well_goes_down_through_the_deck_and_its_arc_cuts_the_wings() -> void:
	var random := Fixtures.cases(62)
	var cut := 0
	for shape: PsxShape in Fixtures.accepted(self, SHAPES, _psx.bind(random)):
		var detail := random.randi_range(16, 128)
		var floor_height := shape.deck() - shape.well_depth
		for point in Fixtures.points(shape.mesh_arrays(&"centre", detail)):
			var at := point / MM
			if Vector2(at.x, -at.z).distance_to(shape.lid_centre) < shape.opening() - 0.01:
				assert_float(at.y).override_failure_message("the deck covers the well at %s" % at) \
					.is_less_equal(floor_height + EPSILON)
		# The arc is drawn in straight sides: where they meet the wing's edge is inside the circle.
		var sagitta := shape.notch() * (1.0 - cos(PI / (16 * ShapeGeometry.corner_steps(detail))))
		for side: int in [-1, 1]:
			var on_arc := 0
			for point in Fixtures.points(shape.mesh_arrays(&"left" if side < 0 else &"right", detail)):
				var at := point / MM
				var away := Vector2(at.x, -at.z).distance_to(shape.lid_centre)
				assert_float(away).override_failure_message("a wing in the well's arc at %s" % at) \
					.is_greater(shape.notch() - sagitta - 0.01)
				on_arc += 1 if absf(away - shape.notch()) < 0.01 else 0
			# How far the arc reaches into the wing.
			var into := shape.notch() - (shape.centre_width / 2.0 - side * shape.lid_centre.x)
			if into > 3.0 or into < 0.0:
				assert_bool(on_arc > 0).is_equal(into > 0.0)
				cut += 1 if into > 0.0 else 0
	assert_int(cut).is_between(40, 160)


func test_the_power_and_open_buttons_go_down() -> void:
	var console: PsxModel = auto_free(Fixtures.new_console(PSX))
	add_child(console)
	var power: Node3D = console.get_node("%PowerButton")
	var open: Node3D = console.get_node("%OpenButton")
	var shape: PsxShape = console.shape
	var power_rest := PsxGeometry.button_top(shape, &"power")
	var open_rest := PsxGeometry.button_top(shape, &"open")
	assert_vector(power.position).is_equal(power_rest)
	assert_vector(open.position).is_equal(open_rest)
	var pressed := Vector2(Fixtures.open_of(console, &"power_mm"), Fixtures.open_of(console, &"open_mm"))
	console.power_mm = pressed.x
	assert_vector(power.position).is_equal_approx(power_rest + Vector3.DOWN * pressed.x * MM, Vector3.ONE * 1e-6)
	assert_vector(open.position).is_equal(open_rest)
	console.open_mm = pressed.y
	assert_vector(open.position).is_equal_approx(open_rest + Vector3.DOWN * pressed.y * MM, Vector3.ONE * 1e-6)


func test_the_lid_opens_upwards_about_its_back_edge_out_of_the_disc_s_way() -> void:
	var console: PsxModel = auto_free(Fixtures.new_console(PSX))
	add_child(console)
	var shape: PsxShape = console.shape
	var cover: MeshInstance3D = console.get_node("%Lid/Cover")
	var back := shape.lid_centre.y + shape.lid_radius
	var lid: MovingPart = console.moving_parts().filter(func(part: MovingPart) -> bool:
		return part.property == &"lid_degrees")[0]
	var fully := lid.open
	for degrees: float in [15.0, 45.0, fully]:
		console.lid_degrees = degrees
		var open := Fixtures.box_of(console, cover)
		var rise := 2.0 * shape.lid_radius * sin(deg_to_rad(degrees))
		var top := shape.deck() + shape.lid_raise
		assert_float(open.end.y / MM).is_between(top + rise - shape.lid_thickness, top + rise + shape.lid_thickness)
		assert_float(-open.position.z / MM).is_between(back - shape.lid_thickness, back + shape.lid_thickness)
	# Fully open, it stands behind the disc seated in the well.
	console.lid_degrees = fully
	var disc_back := shape.lid_centre.y + PsxShape.DISC_RADIUS
	assert_float(-Fixtures.box_of(console, cover).end.z / MM).is_greater(disc_back)


## A first PlayStation's dimensions [param random] draws, any its rules accept: the lid's arc
## cutting the wings or not, each button anywhere on its wing; the last drawn after a thousand draws.
static func _psx(random: RandomNumberGenerator) -> PsxShape:
	var shape: PsxShape
	for attempt in 1000:
		shape = PsxShape.new()
		shape.bevel = random.randf_range(0.3, 2.0)
		shape.lid_thickness = random.randf_range(2.0, 8.0)
		shape.lid_raise = random.randf_range(shape.lid_thickness / 2.0, shape.lid_thickness - 0.6)
		shape.step = maxf(shape.lid_raise, shape.bevel + 0.1) + random.randf_range(0.1, 5.0)
		shape.lid_radius = PsxShape.DISC_RADIUS + random.randf_range(1.1, 20.0)
		shape.lid_gap = random.randf_range(0.1, 2.0)
		shape.rim = shape.bevel + random.randf_range(0.2, 5.0)
		shape.seat_depth = shape.lid_thickness - shape.lid_raise + random.randf_range(3.1, 8.0)
		shape.well_depth = shape.seat_depth + random.randf_range(2.1, 15.0)
		shape.height = shape.step + shape.well_depth + 2.0 * shape.bevel + random.randf_range(1.1, 30.0)
		shape.centre_width = 2.0 * shape.notch() * random.randf_range(0.7, 1.15)
		shape.lid_centre = Vector2(random.randf_range(-0.1, 0.1) * shape.centre_width, random.randf_range(-5.0, 5.0))
		shape.bay = random.randf_range(1.0, 15.0)
		shape.depth = 2.0 * (shape.notch() + absf(shape.lid_centre.y)) + shape.bay + 2.0 * shape.bevel \
			+ random.randf_range(2.1, 40.0)
		shape.button_radius = random.randf_range(4.0, 20.0)
		shape.reset_radius = random.randf_range(3.0, 10.0)
		shape.groove = random.randf_range(0.3, 2.0)
		var reach := shape.button_radius + shape.groove
		var cut := maxf(0.0, shape.notch() - shape.centre_width / 2.0 + absf(shape.lid_centre.x))
		var wing := 2.0 * (cut + reach + shape.bevel + 1.0) + random.randf_range(1.0, 30.0)
		shape.width = shape.centre_width + 2.0 * wing
		shape.corner = random.randf_range(shape.bevel + 0.2, minf(10.0, wing / 2.0 - 0.2))
		var middle := shape.centre_width / 2.0 + wing / 2.0
		var front := -shape.depth / 2.0 + shape.light_box().size.y + shape.bevel + 1.5 + reach
		shape.power_centre = Vector2(-middle + random.randf_range(-1.0, 1.0), front + random.randf_range(0.1, 10.0))
		shape.open_centre = Vector2(middle + random.randf_range(-1.0, 1.0), front + random.randf_range(0.1, 30.0))
		shape.reset_centre = shape.power_centre + Vector2(random.randf_range(-1.0, 1.0),
			reach + shape.reset_radius + shape.groove + random.randf_range(0.6, 20.0))
		shape.vent_pitch = random.randf_range(1.0, 6.0)
		shape.vent_width = random.randf_range(0.2, 0.9) * shape.vent_pitch
		shape.vent_fin = random.randf_range(0.2, 3.0)
		shape.vent_band = Vector2(shape.bevel + random.randf_range(0.6, 5.0),
			shape.height - shape.bevel - random.randf_range(0.6, 5.0))
		var room := shape.depth - 2.0 * shape.corner - 2.0 - shape.vent_width
		shape.vent_count = random.randi_range(0, floori(room / shape.vent_pitch))
		if shape.problems().is_empty():
			break
	return shape


## The box of [param arrays]' points, moved by [param by] first, in millimetres: X to the right, Y
## up and Z towards the back.
static func _box(arrays: Array, by: Vector3) -> AABB:
	var flipped := Vector3(1.0, 1.0, -1.0) / MM
	return Fixtures.bounds(Transform3D(Basis.from_scale(flipped), by * flipped) * Fixtures.points(arrays))
