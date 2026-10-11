# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The NES's own looks and gesture: its door, lifted by hand, turns up and back and stands above the
## top, its face to the front; its tray carries the cartridge in from the front, tilted between the
## lip and the door's lid, and presses it down behind the lip, the door closed over it; its diode
## lights.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const NES := "res://carousel/consoles/nes/nes.tscn"
## Building a mesh takes a while: fewer cases than the carousel's properties.
const SHAPES := 150
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_nes_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(80)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(nes: NesShape) -> void: nes.lip = 0.0],
		[&"sizes_positive", func(nes: NesShape) -> void: nes.port_size.x = -1.0],
		# A button narrower than its rounded corners.
		[&"sizes_positive", func(nes: NesShape) -> void: nes.button_size.x = 1.8877707],
		[&"edges_round_the_bevel", func(nes: NesShape) -> void: nes.corner = nes.bevel],
		[&"shells_hold_their_bevels", func(nes: NesShape) -> void: nes.seam = 2.0 * nes.corner + 1.0],
		[&"outlines_round", func(nes: NesShape) -> void: nes.slope = nes.width / 2.0],
		[&"stripe_on_the_top", func(nes: NesShape) -> void: nes.stripe.x = nes.width / 2.0],
		[&"stripe_on_the_top", func(nes: NesShape) -> void: nes.stripe_ends.y = nes.depth - nes.stripe_ends.x],
		[&"vents_fit", func(nes: NesShape) -> void: nes.vent_count = 0],
		[&"notch_beside_the_stripe", func(nes: NesShape) -> void: nes.notch.y = nes.stripe_ends.x + 1.0],
		[&"notch_beside_the_stripe", func(nes: NesShape) -> void: nes.notch.x = nes.stripe_left() + nes.width / 2.0],
		[&"door_holds_its_lid_and_face", func(nes: NesShape) -> void: nes.notch.y = NesShape.DOOR + NesShape.GAP + 2.0],
		[&"cartridge_passes_the_door", func(nes: NesShape) -> void:
			nes.cartridge.z = nes.height - NesShape.DOOR - nes.seam - nes.lip],
		[&"cartridge_passes_the_door", func(nes: NesShape) -> void: nes.cartridge.x = nes.notch.x],
		[&"cartridge_sinks_behind_the_lip", func(nes: NesShape) -> void: nes.cartridge.y = 1.0],
		[&"tray_moves_inside", func(nes: NesShape) -> void: nes.cartridge.y = 4.0 * nes.depth],
		[&"panel_on_the_lower_front", func(nes: NesShape) -> void: nes.panel_centre.x = nes.stripe_left()],
		[&"panel_on_the_lower_front", func(nes: NesShape) -> void: nes.button_size.x = nes.panel_size.x],
		[&"panel_on_the_lower_front", func(nes: NesShape) -> void: nes.button_raise = ConsoleModel.PROUD_MM],
		[&"buttons_press_in_and_show", func(nes: NesShape) -> void: nes.button_raise = NesShape.SHOWN_PRESS],
		[&"ports_fit", func(nes: NesShape) -> void: nes.port_size.y = nes.seam],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _nes.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])
	# Its rails longer: under the closed door at their tilt, through it at the placeholder's rebound.
	Fixtures.assert_found_refused(self, NesShape.new(), &"tray_moves_inside", [{&"notch": Vector2(145.0, 18.0)}])


func test_the_door_fills_its_notch_and_lifts_up_and_back_standing_above_the_top_its_face_to_the_front() -> void:
	var random := Fixtures.cases(81)
	for shape: NesShape in Fixtures.accepted(self, SHAPES, _nes.bind(random)):
		var door := Fixtures.points(shape.mesh_arrays(&"door", random.randi_range(16, 64)))
		var closed := _box(shape.door(0.0) * door)
		var face := shape.door_box()
		var lid := shape.height - NesShape.DOOR
		var near := Vector3.ONE * EPSILON
		assert_vector(closed.position).is_equal_approx(Vector3(face.position.x, face.position.y, shape.hinge().x), near)
		assert_vector(Vector2(closed.end.x, closed.end.y)).is_equal_approx(face.end, Vector2.ONE * EPSILON)
		assert_float(closed.end.z).is_greater_equal(shape.front())
		for degrees: float in [NesShape.DOOR_OPEN, NesShape.DOOR_OPEN * NesShape.REBOUND]:
			var open := _box(shape.door(degrees) * door)
			# Above its lid closed, in front of its hinge, its lid's front edge (rounded) high over the top,
			# its face turned up yet to the front.
			assert_float(open.position.y).is_greater_equal(lid - EPSILON)
			assert_float(open.position.z).is_greater_equal(shape.hinge().x - EPSILON)
			var lid_front := shape.front() - shape.hinge().x
			assert_float(open.end.y).is_greater(shape.height + lid_front * sin(deg_to_rad(degrees)) - 1.0)
			var facing := shape.door(degrees).basis.z
			assert_float(facing.z).is_greater(0.0)
			assert_float(facing.y).is_greater(0.0)


func test_a_cartridge_slides_in_tilted_between_the_lip_and_the_door_s_lid_then_sinks_behind_the_lip() -> void:
	var random := Fixtures.cases(82)
	var tight := 0
	for shape: NesShape in Fixtures.accepted(self, SHAPES, _nes.bind(random)):
		var tilt := shape.tray_tilt
		var lip := shape.seam + shape.lip
		var door_lid := shape.height - NesShape.DOOR
		# Its centre line, out along its top edge, where it crosses the front.
		var open := _mm(shape.seat(tilt))
		var along := open.basis.y.normalized()
		var at_front := open.origin + along * (shape.front() - open.origin.z) / along.z
		assert_float(rad_to_deg(atan2(along.y, along.z))).is_equal_approx(tilt, EPSILON)
		var half := shape.cartridge.z / 2.0 / cos(deg_to_rad(tilt))
		assert_float(at_front.y + half).is_less(door_lid)
		assert_float(at_front.y - half).is_greater(lip)
		tight += 1 if door_lid - lip - 2.0 * half < 2.5 else 0
		# Pressed down: level, its label up, its front end behind the lip.
		var seated := _mm(shape.seat(0.0))
		assert_vector(seated.basis.y).is_equal_approx(Vector3.BACK, Vector3.ONE * EPSILON)
		assert_vector(seated.basis.z).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		assert_float(seated.origin.x).is_equal_approx(shape.notch_left() + shape.notch.x / 2.0, EPSILON)
		assert_float(seated.origin.z + shape.cartridge.y / 2.0).is_equal_approx(
			shape.front() - shape.cartridge_inset, EPSILON)
		assert_float(seated.origin.y + shape.cartridge.z / 2.0).is_less(lip)
	assert_int(10 * tight).is_greater(SHAPES)


func test_the_tray_carries_the_cartridge_about_its_pivot_and_holds_it_once_open() -> void:
	var random := Fixtures.cases(83)
	for shape: NesShape in Fixtures.accepted(self, SHAPES, _nes.bind(random)):
		var rails := Fixtures.points(shape.mesh_arrays(&"tray", random.randi_range(16, 64)))
		var pivot := shape.tray(0.0).origin
		var resting := shape.seat(0.0).origin
		for degrees: float in [0.0, random.randf_range(0.0, shape.tray_tilt), shape.tray_tilt]:
			var seat := shape.seat(degrees).origin
			assert_float(seat.distance_to(pivot)).is_equal_approx(resting.distance_to(pivot), EPSILON * MM)
			var raised := seat - pivot
			assert_float(rad_to_deg(atan2(raised.y, raised.z))).is_equal_approx(degrees, EPSILON)
		# Open, its rails stand around the cartridge's centre.
		var open := _box(shape.tray(shape.tray_tilt) * rails)
		assert_bool(open.grow(1.0).has_point(shape.seat(shape.tray_tilt).origin / MM)).is_true()


func test_the_cartridge_s_seat_rides_on_the_tray_as_drawn() -> void:
	var console: NesModel = auto_free(Fixtures.new_console(NES))
	add_child(console)
	var tray: Node3D = console.get_node("%Tray")
	var shape: NesShape = console.shape
	var on_tray := tray.transform.affine_inverse() * console.seat()
	for degrees: float in [shape.tray_tilt / 3.0, shape.tray_tilt]:
		console.tray_degrees = degrees
		assert_bool((tray.transform.affine_inverse() * console.seat()).is_equal_approx(on_tray)).is_true()
	assert_bool(console.seat().is_equal_approx(shape.seat(shape.tray_tilt))).is_true()


func test_a_cartridge_comes_in_from_the_front_along_the_tray_label_up() -> void:
	var console: NesModel = auto_free(Fixtures.new_console(NES))
	var shape: NesShape = console.shape
	for degrees: float in [0.0, shape.tray_tilt / 2.0, shape.tray_tilt]:
		console.tray_degrees = degrees
		var tilt := deg_to_rad(degrees)
		var seat := console.seat().basis
		var near := Vector3.ONE * EPSILON
		assert_vector(seat * console.approach()).is_equal_approx(Vector3(0.0, sin(tilt), cos(tilt)), near)
		assert_vector(seat.z).is_equal_approx(Vector3(0.0, cos(tilt), -sin(tilt)), near)


func test_the_door_is_lifted_before_the_cartridge_comes_and_closed_once_it_is_pressed_down() -> void:
	var console: NesModel = auto_free(Fixtures.new_console(NES))
	var shape: NesShape = console.shape
	var animation := LaunchAnimation.placeholder(console, AABB(-shape.cartridge / 2.0 * MM, shape.cartridge * MM))
	var value_at := func(property: StringName, moment: StringName) -> float:
		var track := animation.find_track(NodePath("Consoles/%s:%s" % [console.name, property]), Animation.TYPE_VALUE)
		return animation.value_track_interpolate(track, LaunchAnimation.moment(animation, moment))
	assert_float(value_at.call(&"door_degrees", &"consoles")).is_zero()
	assert_float(value_at.call(&"door_degrees", &"seated")).is_equal_approx(NesShape.DOOR_OPEN, EPSILON)
	assert_float(value_at.call(&"tray_degrees", &"seated")).is_equal_approx(shape.tray_tilt, EPSILON)
	assert_float(value_at.call(&"door_degrees", &"black")).is_zero()
	assert_float(value_at.call(&"tray_degrees", &"black")).is_zero()


func test_the_power_and_reset_buttons_go_in() -> void:
	var console: NesModel = auto_free(Fixtures.new_console(NES))
	add_child(console)
	for part: StringName in [&"power_mm", &"reset_mm"]:
		var button: MeshInstance3D = console.get_node(String(part.trim_suffix("_mm")).capitalize())
		var pressed := Fixtures.open_of(console, part)
		console.set(part, pressed)
		assert_float(button.position.z).is_equal_approx(-pressed * MM, EPSILON * MM)
		assert_float(pressed).is_greater_equal(NesShape.SHOWN_PRESS)


func test_pressed_a_button_still_stands_out_of_its_panel_going_in_less_when_it_stands_out_less() -> void:
	var random := Fixtures.cases(83)
	var shallow := 0
	var shapes := Fixtures.accepted(self, SHAPES, _nes.bind(random))
	for i in shapes.size():
		var shape: NesShape = shapes[i]
		if i % 2 == 0:
			shape.button_raise = random.randf_range(0.0, NesShape.POWER_IN + 1.0)
		if not shape.problems().is_empty():
			continue
		var console: NesModel = auto_free(Fixtures.new_console(NES))
		console.shape = shape
		var panel := _box(Fixtures.points(shape.mesh_arrays(&"lower", 32))).end.z
		for part: MovingPart in console.moving_parts().filter(func(moving: MovingPart) -> bool:
				return moving.property.ends_with("_mm")):
			var button := _box(Fixtures.points(shape.mesh_arrays(StringName(part.property.trim_suffix("_mm")), 32)))
			assert_float(button.end.z - part.open - panel).is_greater_equal(ConsoleModel.PRESSED_SHOWS_MM - EPSILON)
			assert_float(part.open).is_greater_equal(NesShape.SHOWN_PRESS)
		shallow += 1 if shape.button_raise < NesShape.POWER_IN + ConsoleModel.PRESSED_SHOWS_MM else 0
	assert_int(shallow).is_greater(10)


## A NES whose dimensions [param random] draws around the real one's, any its rules accept; one in
## three times its cartridges as thick as its slot takes.
static func _nes(random: RandomNumberGenerator) -> NesShape:
	var shape: NesShape = Fixtures.drawn_around(NesShape.new(), random, Vector2(0.8, 1.2), 4, 0.5)
	var slot := shape.height - NesShape.DOOR - shape.seam - shape.lip - 2.0
	var thick := slot * cos(deg_to_rad(shape.tray_tilt)) - random.randf_range(0.0, 0.5)
	if random.randf() < 0.33 and thick > 0.0:
		var thinner := shape.cartridge.z
		shape.cartridge.z = thick
		if not shape.problems().is_empty():
			shape.cartridge.z = thinner
	return shape


## [param transform] in millimetres.
static func _mm(transform: Transform3D) -> Transform3D:
	return Transform3D(transform.basis, transform.origin / MM)


## The box of [param points], in millimetres.
static func _box(points: PackedVector3Array) -> AABB:
	return Fixtures.bounds(Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * points)
