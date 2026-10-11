# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy Advance's own looks: where its cartridge stands, its power switch, its shoulder
## buttons and the grey parts the front hides, how it is presented, and the dimensions it cannot be
## built from.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/gba/gba.tscn"
## Building a whole console takes a while: fewer cases than the carousel's properties.
const SHAPES := 150
const CONSOLES := 12
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_gba_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(100)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(gba: GbaShape) -> void: gba.cartridge_head = 0.0],
		[&"outline_holds_its_edges", func(gba: GbaShape) -> void: gba.corner = gba.bevel],
		[&"outline_holds_its_edges", func(gba: GbaShape) -> void: gba.shoulder.y = 4.0 * gba.shoulder.y],
		[&"shells_in_depth", func(gba: GbaShape) -> void: gba.front_depth = gba.bevel],
		[&"hump_on_the_back", func(gba: GbaShape) -> void: gba.hump_depth = gba.body_depth],
		[&"bezel_on_the_face", func(gba: GbaShape) -> void: gba.bezel_size.y = gba.height],
		[&"screen_in_the_bezel", func(gba: GbaShape) -> void: gba.screen_size = gba.bezel_size],
		[&"logo_above_the_bezel", func(gba: GbaShape) -> void:
			gba.bezel_size.y = 2.0 * (gba.logo().position.y - GbaShape.BEZEL_CENTRE.y)],
		[&"controls_on_the_face", func(gba: GbaShape) -> void:
			gba.bezel_size.x = 2.0 * (gba.half() - GbaShape.BUTTON_B.x)],
		[&"slot_in_the_hump_top", func(gba: GbaShape) -> void: gba.slot_width = 2.0 * gba.shoulder.x],
		[&"slot_takes_the_cartridge", func(gba: GbaShape) -> void: gba.cartridge.x = gba.slot_width],
		[&"slot_takes_the_cartridge", func(gba: GbaShape) -> void: gba.cartridge.z = gba.slot().size.y],
		[&"cartridge_stands_in_the_slot", func(gba: GbaShape) -> void: gba.cartridge_head = gba.cartridge.y / 2.0],
		# So long the slot's back wall would leave the leaning hump.
		[&"cartridge_stands_in_the_slot", func(gba: GbaShape) -> void:
			gba.cartridge.y = GbaShape.HUMP_BEVEL / gba.hump_lean()],
		# So deep a head the hump would be no taller than its corners.
		[&"hump_on_the_back", func(gba: GbaShape) -> void:
			gba.cartridge_head = gba.height - 2.0 * GbaShape.HUMP_CORNER],
		[&"ports_on_the_bottom", func(gba: GbaShape) -> void:
			gba.corner = GbaShape.VOLUME_FROM_END - GbaShape.VOLUME.x / 2.0],
		[&"link_port_on_the_top", func(gba: GbaShape) -> void:
			gba.shoulder.x = GbaShape.LINK_X + GbaShape.LINK.x / 2.0],
		[&"cover_and_label_on_the_back", func(gba: GbaShape) -> void:
			gba.hump_width = 2.0 * GbaShape.BATTERY_COVER.end.x],
		[&"grey_ends_fit", func(gba: GbaShape) -> void:
			gba.hump_width = 2.0 * (gba.half() - GbaShape.SHOULDER_LENGTH)],
		# A screen of no width.
		[&"screen_in_the_bezel", func(gba: GbaShape) -> void: gba.screen_size.x = 0.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _gba.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_cartridge_comes_down_the_slot_in_the_top_to_the_connector_its_label_to_the_back() -> void:
	var random := Fixtures.cases(101)
	for shape: GbaShape in Fixtures.accepted(self, CONSOLES, _gba.bind(random)):
		var console: GbaModel = auto_free(Fixtures.new_console(SCENE))
		console.shape = shape
		var seat := console.seat()
		assert_vector(seat.basis.z).is_equal_approx(Vector3.FORWARD, Vector3.ONE * EPSILON)
		assert_vector(seat.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		assert_vector(console.approach()).is_equal(Vector3.UP)
		# The cartridge's box: its head stands out of its body on the label's side, to the back.
		var centre := seat.origin / MM + Vector3.FORWARD * GbaShape.CARTRIDGE_HEAD / 2.0
		var top := shape.height / 2.0
		# Through the slot's opening, standing out of the top as far as it does not go in.
		var footprint := Rect2(centre.x - shape.cartridge.x / 2.0, -centre.z - shape.cartridge.z / 2.0,
			shape.cartridge.x, shape.cartridge.z)
		assert_bool(shape.slot().encloses(footprint)).is_true()
		assert_float(centre.y + shape.cartridge.y / 2.0).is_equal_approx(top, EPSILON)
		# Its head alone stands above the hump, filling the step up to the shells' top.
		var hump: PackedVector3Array = shape.mesh_arrays(&"hump", 32)[Mesh.ARRAY_VERTEX]
		assert_float(top - Fixtures.bounds(hump).end.y / MM).is_equal_approx(shape.cartridge_head, EPSILON)
		var play := (Vector2(shape.slot_width, shape.slot().size.y) - Vector2(shape.cartridge.x, shape.cartridge.z)) \
			/ 2.0
		Fixtures.assert_in_slot(self, shape, AABB(centre - shape.cartridge / 2.0, shape.cartridge), play,
			random.randi_range(16, 64))


func test_the_hump_stops_below_the_top_by_the_platform_s_cartridge_head() -> void:
	var cartridge: GbaCartShape = load("res://carousel/media/gba_cart/gba_cart_shape.tres")
	assert_float(GbaShape.new().cartridge_head).is_equal(cartridge.head_drop)


func test_the_power_switch_slides_along_the_bottom_within_its_recess_towards_the_middle() -> void:
	var random := Fixtures.cases(102)
	for shape: GbaShape in Fixtures.accepted(self, CONSOLES, _gba.bind(random)):
		var console: GbaModel = Fixtures.built(self, SCENE, shape)
		var knob: MeshInstance3D = console.get_node("%Power/Knob")
		var recess: Transform3D = shape.bottom_ports(3)[0][0]
		var moved := console.moving_parts().filter(func(part: MovingPart) -> bool:
			return part.property == &"power_mm")
		assert_int(moved.size()).is_equal(1)
		var part: MovingPart = moved[0]
		assert_int(part.role).is_equal(MovingPart.Role.POWER)
		var at_rest := _in_frame(console, knob, recess)
		console.power_mm = part.open
		var on := _in_frame(console, knob, recess)
		console.power_mm = part.rest
		var room := Rect2(-GbaShape.SWITCH_RECESS / 2.0, GbaShape.SWITCH_RECESS).grow(EPSILON)
		for box: AABB in [at_rest, on]:
			assert_bool(room.encloses(Rect2(box.position.x, box.position.y, box.size.x, box.size.y))).is_true()
			# Standing out of the bottom, its foot inside the console.
			assert_float(box.position.z).is_less(0.0)
			assert_float(box.end.z).is_greater(1.0)
		# On towards the middle: the switch is at the left, its frame's X to the right.
		assert_float(recess.origin.x).is_less(0.0)
		assert_float(on.position.x - at_rest.position.x).is_equal_approx(shape.switch_travel(), EPSILON)
		assert_float(shape.switch_travel()).is_greater(1.0)


func test_the_shoulder_buttons_press_their_outer_ends_down_clear_of_the_panels_under_them() -> void:
	var random := Fixtures.cases(103)
	for shape: GbaShape in Fixtures.accepted(self, CONSOLES, _gba.bind(random)):
		var console: GbaModel = Fixtures.built(self, SCENE, shape)
		var pressed := console.moving_parts().filter(func(part: MovingPart) -> bool:
			return part.property == &"shoulders_degrees")
		assert_int(pressed.size()).is_equal(1)
		var part: MovingPart = pressed[0]
		var buttons: Array[MeshInstance3D] = [console.get_node("%LeftShoulder/Button"),
			console.get_node("%RightShoulder/Button")]
		var resting: Array[AABB] = []
		resting.assign(buttons.map(func(button: MeshInstance3D) -> AABB: return Fixtures.box_of(console, button)))
		# The point of each furthest out, at the left end and at the right one.
		var outer: Array[int] = []
		for side in 2:
			var xs := Array(_points(console, buttons[side])).map(func(point: Vector3) -> float: return point.x)
			outer.append(xs.find(xs.min() if side == 0 else xs.max()))
		var at_rest: Array[PackedVector3Array] = [_points(console, buttons[0]), _points(console, buttons[1])]
		console.shoulders_degrees = part.open
		for side in 2:
			var down := _points(console, buttons[side])
			assert_float(at_rest[side][outer[side]].y - down[outer[side]].y).is_greater(1.0)
			var panel_top := shape.grey_end(false, 0.0, 3)[-1].y
			assert_float(Fixtures.box_of(console, buttons[side]).position.y / MM).is_greater(panel_top)
		# Mirror images of each other, pressed as at rest.
		var left := Fixtures.box_of(console, buttons[0])
		var right := Fixtures.box_of(console, buttons[1])
		assert_vector(Vector3(-left.end.x, left.position.y, left.position.z)).is_equal_approx(right.position,
			Vector3.ONE * EPSILON * MM)
		console.shoulders_degrees = part.rest
		assert_bool(Fixtures.box_of(console, buttons[0]).is_equal_approx(resting[0])).is_true()


func test_the_grey_parts_stay_within_the_outline_the_front_shows_and_cover_the_shells_ends() -> void:
	var random := Fixtures.cases(104)
	for shape: GbaShape in Fixtures.accepted(self, CONSOLES, _gba.bind(random)):
		var console: GbaModel = Fixtures.built(self, SCENE, shape)
		# The outline a hair wider than the shells, as finely drawn as they are in the scene.
		var front := shape.outline(shape.half(), shape.corner, -0.1, 0.0, ShapeGeometry.corner_steps(128))
		for path: String in ["%LeftShoulder/Button", "%RightShoulder/Button", "SidePanels"]:
			var part: MeshInstance3D = console.get_node(path)
			var points := _points(console, part)
			var xs := Array(points).map(func(point: Vector3) -> float: return absf(point.x))
			assert_float(xs.max()).override_failure_message("%s falls short of the end" % path) \
				.is_greater(shape.half() - 0.1)
			for point in points:
				assert_bool(_inside(Vector2(point.x, point.y), front)) \
					.override_failure_message("%s shows round the front at %s" % [path, point]).is_true()


func test_it_is_presented_standing_its_screen_to_the_camera_its_top_tipped_towards_it() -> void:
	var console: GbaModel = auto_free(Fixtures.new_console(SCENE))
	var facing := console.presented()
	assert_bool(facing.is_equal_approx(facing.orthonormalized())).is_true()
	assert_float((facing * Vector3.BACK).z).is_greater(cos(deg_to_rad(30.0)))
	var way_in := facing * console.seat().basis * console.approach()
	assert_float(way_in.z).is_greater(0.1)
	assert_float(way_in.y).is_greater(0.9)


## A Game Boy Advance [param random] draws that [method GbaShape.problems] accepts: each dimension up
## to 6 % from the measured one.
static func _gba(random: RandomNumberGenerator) -> GbaShape:
	return Fixtures.drawn_around(GbaShape.new(), random, Vector2(0.94, 1.06)) as GbaShape


## Where [param part]'s points stand in [param console], in millimetres.
static func _points(console: Node3D, part: MeshInstance3D) -> PackedVector3Array:
	var placed := console.global_transform.affine_inverse() * part.global_transform
	var points: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return Transform3D(Basis.from_scale(Vector3.ONE / MM), Vector3.ZERO) * placed * points


## The box [param part]'s points fill in [param frame] (in millimetres, in the model's space).
static func _in_frame(console: Node3D, part: MeshInstance3D, frame: Transform3D) -> AABB:
	return Fixtures.bounds(frame.affine_inverse() * _points(console, part))


## Whether [param point] lies inside [param loop]: a ray from it to the right crosses the loop an odd
## number of times, each side counted with its lower end and not its upper one, so that a ray through
## a corner counts once (Geometry2D.is_point_in_polygon casts a ray askew, which a corner can make it
## count twice).
static func _inside(point: Vector2, loop: PackedVector2Array) -> bool:
	var crossings := 0
	for i in loop.size():
		var from := loop[i - 1]
		var to := loop[i]
		if (from.y <= point.y) != (to.y <= point.y) \
				and point.x < from.x + (point.y - from.y) * (to.x - from.x) / (to.y - from.y):
			crossings += 1
	return crossings % 2 == 1
