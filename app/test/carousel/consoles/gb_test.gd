# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy's own looks: its cartridge comes down into the bay at the top of its back, its power
## switch slides along its slot, it shows its front, and the dimensions it cannot be built from are
## refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/gb/gb.tscn"
## Building a whole console takes a while: fewer cases than the carousel's properties.
const SHAPES := 100
const CONSOLES := 12
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_game_boy_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(100)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(gb: GbShape) -> void: gb.cartridge.z = 0.0],
		[&"shells_hold_their_edges", func(gb: GbShape) -> void: gb.corner = gb.back_bevel],
		# Corners a hair rounder than the back's bevel; a knob too short for its own bevel.
		[&"shells_hold_their_edges", func(gb: GbShape) -> void: gb.corner = gb.back_bevel + 0.1],
		[&"power_slot_on_the_top", func(gb: GbShape) -> void: gb.depth -= gb.knob().size.y - 2.9],
		[&"shells_hold_their_edges", func(gb: GbShape) -> void: gb.seam = gb.bevel + GbShape.SEAM_BEVEL],
		[&"bay_in_the_back", func(gb: GbShape) -> void: gb.cartridge.x = gb.width - 2.0 * gb.corner],
		[&"bay_in_the_back", func(gb: GbShape) -> void: gb.bay_depth = gb.height - GbShape.COVER.end.y],
		[&"cartridge_stands_in_the_bay", func(gb: GbShape) -> void: gb.cartridge.y = gb.bay_depth],
		# The slot's foot below the plate's bottom; a slot too narrow for the connector.
		[&"cartridge_stands_in_the_bay", func(gb: GbShape) -> void:
			gb.cartridge.y = gb.height - gb.plate().position.y],
		[&"cartridge_stands_in_the_bay", func(gb: GbShape) -> void: gb.cartridge.x = 48.0],
		[&"rails_on_the_bay_floor", func(gb: GbShape) -> void:
			gb.bay_depth = GbShape.RAIL_ENDS.x + GbShape.RAIL_ENDS.y],
		[&"rails_on_the_bay_floor", func(gb: GbShape) -> void: gb.cartridge.x = 2.0 * GbShape.RAIL_X - 1.0],
		[&"power_slot_on_the_top", func(gb: GbShape) -> void: gb.power_slot = GbShape.KNOB_WIDTH],
		[&"power_slot_on_the_top", func(gb: GbShape) -> void: gb.seam = gb.depth - gb.slot_thickness() - 3.0],
		[&"screen_in_the_bezel", func(gb: GbShape) -> void: gb.screen_size.y = gb.bezel_size.y],
		[&"light_beside_the_screen", func(gb: GbShape) -> void: gb.screen_size.x = gb.bezel_size.x - 4.0],
		[&"band_under_the_top", func(gb: GbShape) -> void: gb.bezel_offset.y = GbShape.BAND_GAP + gb.corner],
		[&"controls_on_the_front", func(gb: GbShape) -> void: gb.a_button = gb.dpad_centre],
		[&"controls_on_the_front", func(gb: GbShape) -> void: gb.speaker_start.x = gb.width / 2.0],
		[&"controls_on_the_front", func(gb: GbShape) -> void: gb.dpad_size.x = gb.dpad_size.y + 3.9],
		[&"plates_and_screws_on_the_back", func(gb: GbShape) -> void: gb.width = GbShape.COVER.size.x + 2.0],
		[&"openings_on_the_sides", func(gb: GbShape) -> void: gb.seam = gb.depth - gb.back_bevel - 2.0],
		# A bezel too narrow for its stripes, left and right, apart.
		[&"stripes_over_the_screen", func(gb: GbShape) -> void:
			gb.bezel_size.x = GbShape.STRIPE_LENGTHS.x + GbShape.STRIPE_LENGTHS.y + 2.0 * GbShape.STRIPE_INSET + 2.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _gb.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_a_cartridge_comes_down_the_slot_to_the_connector_its_label_flush_with_the_back_behind_the_plate() -> void:
	var random := Fixtures.cases(101)
	for shape: GbShape in Fixtures.accepted(self, CONSOLES, _gb.bind(random)):
		var console: GbModel = auto_free(Fixtures.new_console(SCENE))
		console.shape = shape
		var seat := console.seat()
		# Its label (+Z) to the back, its top (+Y) up, and it comes down from above.
		assert_vector(seat.basis.z).is_equal_approx(Vector3.FORWARD, Vector3.ONE * EPSILON)
		assert_vector(seat.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * EPSILON)
		assert_vector(console.approach()).is_equal(Vector3.UP)
		var seated := AABB(seat.origin / MM - shape.cartridge / 2.0, shape.cartridge)
		assert_float(seated.position.z).is_equal_approx(-shape.depth / 2.0, EPSILON)
		assert_float(seated.end.y).is_equal_approx(shape.height + GbShape.CARTRIDGE_RISE, EPSILON)
		# Its lower part goes in behind the plate, which covers its foot.
		assert_float(seated.position.y).is_between(shape.plate().position.y, shape.plate().end.y - 10.0)
		Fixtures.assert_in_slot(self, shape, seated, GbShape.BAY_PLAY * Vector2(0.5, 1.0),
			random.randi_range(16, 64))


func test_the_bay_is_as_wide_as_each_game_pak_of_the_platform_and_its_play() -> void:
	var gb: GbShape = load("res://carousel/consoles/gb/gb_shape.tres")
	for medium in Fixtures.media("gb"):
		var width: float = Fixtures.medium_shape(medium).get(&"width")
		assert_float(gb.bay().size.x).override_failure_message(medium).is_equal_approx(width + GbShape.BAY_PLAY.x, EPSILON)


func test_the_power_switch_slides_right_from_its_slot_s_left_end_to_its_right_end() -> void:
	var random := Fixtures.cases(102)
	for shape: GbShape in Fixtures.accepted(self, CONSOLES, _gb.bind(random)):
		var console: GbModel = Fixtures.built(self, SCENE, shape)
		var knob: MeshInstance3D = console.get_node("%Power/Knob")
		var powers := console.moving_parts().filter(func(part: MovingPart) -> bool:
			return part.role == MovingPart.Role.POWER)
		assert_int(powers.size()).is_equal(1)
		var power: MovingPart = powers[0]
		var at_rest := Fixtures.box_of(console, knob)
		console.set(power.property, power.open)
		var slid := Fixtures.box_of(console, knob)
		console.set(power.property, power.rest)
		var slot := shape.power()
		for box: AABB in [at_rest, slid]:
			# Seen from above, X to the right, Y from the front backwards.
			var plan := Rect2(box.position.x / MM, shape.depth / 2.0 - box.end.z / MM, box.size.x / MM, box.size.z / MM)
			assert_bool(slot.grow(EPSILON).encloses(plan)).is_true()
			assert_float(box.end.y / MM).is_between(shape.height, shape.height + 0.5)
			assert_float(box.position.y / MM).is_less(shape.height - GbShape.SLOT_SINK)
		assert_float(at_rest.position.x / MM).is_equal_approx(slot.position.x + GbShape.KNOB_MARGIN, EPSILON)
		assert_float(slid.end.x / MM).is_equal_approx(slot.end.x - GbShape.KNOB_MARGIN, EPSILON)
		assert_vector(slid.position - at_rest.position).is_equal_approx(Vector3.RIGHT * power.open * MM,
			Vector3.ONE * EPSILON * MM)


func test_it_shows_its_front_to_the_camera_its_top_leant_towards_it() -> void:
	var console: GbModel = auto_free(Fixtures.new_console(SCENE))
	var facing := console.presented()
	assert_float((facing * Vector3.BACK).z).is_greater(cos(deg_to_rad(20.0)))
	var way_in := facing * console.seat().basis * console.approach()
	assert_float(way_in.z).is_greater(0.0)
	assert_float(way_in.y).is_greater(cos(deg_to_rad(20.0)))


## A Game Boy [param random] draws that [method GbShape.problems] accepts: each dimension up to 8 %
## from the measured one, the speaker a slit more or fewer.
static func _gb(random: RandomNumberGenerator) -> GbShape:
	return Fixtures.drawn_around(GbShape.new(), random, Vector2(0.92, 1.08), 1) as GbShape
