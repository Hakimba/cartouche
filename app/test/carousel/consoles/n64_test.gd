# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Nintendo 64's own looks: its top and the slot in it, its flaps, its switches and where its
## cartridge stands.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/n64/n64.tscn"
## Building a whole console takes a while: fewer cases than the carousel's properties.
const SHAPES := 200
const CONSOLES := 12
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001


func test_INV_E10_02_impossible_n64_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(80)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(n64: N64Shape) -> void: n64.flap_thickness = 0.0],
		[&"shells_hold_their_edges", func(n64: N64Shape) -> void: n64.seam = 2.0 * n64.bevel],
		[&"top_climbs_to_the_hill", func(n64: N64Shape) -> void: n64.back_height = n64.shoulder_height],
		[&"top_climbs_to_the_hill", func(n64: N64Shape) -> void: n64.height = n64.back_height],
		[&"corners_round_the_edges", func(n64: N64Shape) -> void: n64.corner = n64.crown.x],
		# So deep a console that its flaps would fold through the slot's floor.
		[&"no_deeper_than_wide", func(n64: N64Shape) -> void: n64.depth = 539.270429611206],
		[&"pods_at_the_front_corners", func(n64: N64Shape) -> void: n64.pod_height = n64.shoulder_height],
		[&"tongue_and_hill_on_the_top", func(n64: N64Shape) -> void: n64.hill.x = n64.body_width],
		[&"slot_in_the_tongue", func(n64: N64Shape) -> void: n64.slot_size.x = n64.tongue.x],
		[&"slot_in_the_tongue", func(n64: N64Shape) -> void: n64.bowl.y = n64.floor_reach()],
		# A slot turned inside out, refused before its box is measured.
		[&"slot_in_the_tongue", func(n64: N64Shape) -> void: n64.slot_size = -n64.slot_size],
		[&"slot_takes_the_cartridge", func(n64: N64Shape) -> void: n64.cartridge.x = n64.slot_size.x],
		[&"slot_takes_the_cartridge", func(n64: N64Shape) -> void: n64.cartridge.z = n64.slot_size.y],
		[&"flaps_fold_into_the_slot", func(n64: N64Shape) -> void: n64.flap_recess = n64.back_height - n64.seam],
		[&"cartridge_stands_out_of_the_slot", func(n64: N64Shape) -> void: n64.cartridge_floor = n64.seam],
		[&"cartridge_stands_out_of_the_slot", func(n64: N64Shape) -> void:
			n64.cartridge.y = n64.height - n64.cartridge_floor],
		[&"logo_behind_the_slot", func(n64: N64Shape) -> void:
			n64.slot_centre = n64.body().end.y - n64.crown.x - n64.slot_size.y / 2.0 - 4.0],
		[&"lid_on_the_hill", func(n64: N64Shape) -> void: n64.lid_size.x = n64.hill.x + 1.0],
		[&"lid_on_the_hill", func(n64: N64Shape) -> void: n64.lid_size.y = n64.depth],
		[&"switches_on_the_hill_s_flanks", func(n64: N64Shape) -> void: n64.switch_x = 0.0],
		[&"switches_on_the_hill_s_flanks", func(n64: N64Shape) -> void: n64.switch_x = n64.hill.x / 2.0 + n64.hill.y],
		[&"vents_fit", func(n64: N64Shape) -> void: n64.vent_count = 0],
		[&"vents_fit", func(n64: N64Shape) -> void: n64.vent_count = 80],
		[&"badge_on_the_front", func(n64: N64Shape) -> void: n64.crown.y = n64.height - n64.seam - 14.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _n64.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])
	# Found by INV-E10-02's draws: the power switch's ON and OFF off the flank's straight part, sunk into
	# the shell.
	Fixtures.assert_found_refused(self, N64Shape.new(), &"switches_on_the_hill_s_flanks", [
		{&"back_height": 61.15536451339722, &"front_inset": 10.279102563858032, &"hill": Vector2(60.151745, 59.86214),
			&"pod_height": 42.474117040634155, &"pod_size": Vector2(45.406483, 89.53308)},
		{&"body_width": 864.5473289489746, &"crown": Vector2(9.865287, 7.9061313), &"height": 77.29332673549652,
			&"lid_size": Vector2(55.104225, 48.564518), &"slot_centre": 43.0939576625824,
			&"switch_x": 68.41139054298401},
	])


func test_the_slot_lies_in_the_top_nothing_around_or_behind_it_higher_the_hill_ahead_of_it_highest() -> void:
	var random := Fixtures.cases(84)
	for shape: N64Shape in Fixtures.accepted(self, CONSOLES, _n64.bind(random)):
		var points: PackedVector3Array = shape.mesh_arrays(&"upper", 32)[Mesh.ARRAY_VERTEX]
		var around := shape.slot().grow(N64Shape.SURROUND)
		var highest := points[0]
		for point in points:
			var plan := Vector2(point.x, -point.z) / MM
			if around.has_point(plan) or plan.y >= shape.slot_centre:
				assert_float(point.y / MM).is_less_equal(shape.back_height + EPSILON)
			if point.y > highest.y:
				highest = point
		assert_float(highest.y / MM).is_equal_approx(shape.height, EPSILON)
		assert_float(-highest.z / MM).is_less(shape.crest() + EPSILON)


func test_the_slits_lie_on_the_ramp_between_the_slot_s_floor_and_the_crest() -> void:
	var random := Fixtures.cases(85)
	for shape: N64Shape in Fixtures.accepted(self, SHAPES, _n64.bind(random)):
		for index in shape.vent_count:
			var ends := shape.vent(index)
			assert_float(shape.ramp(ends[0])).is_greater(0.0)
			assert_float(shape.ramp(ends[1])).is_less(1.0)
			assert_bool(shape.surround().has_point(ends[0])).is_false()


func test_closed_the_flaps_fill_the_bezel_open_they_hang_down_clear_of_the_cartridge() -> void:
	var random := Fixtures.cases(81)
	for shape: N64Shape in Fixtures.accepted(self, CONSOLES, _n64.bind(random)):
		var console: N64Model = Fixtures.built(self, SCENE, shape)
		var inside := shape.slot().grow(-N64Shape.BEZEL + EPSILON)
		var cartridge := console.seat().origin.z
		for front: bool in [true, false]:
			var flap: MeshInstance3D = console.get_node("%FrontFlap/Cover" if front else "%BackFlap/Cover")
			var closed := Fixtures.box_of(console, flap)
			assert_float(closed.end.y / MM).is_equal_approx(shape.back_height - shape.flap_recess, EPSILON)
			assert_bool(inside.encloses(_plan(closed))).is_true()
			console.flaps_degrees = 90.0
			var open := Fixtures.box_of(console, flap)
			console.flaps_degrees = 0.0
			# Upright along the bezel, as long as it was deep, above the well's floor.
			assert_float(open.size.y / MM).is_equal_approx(shape.flap(front).size.y, EPSILON)
			assert_float(open.size.z / MM).is_equal_approx(shape.flap_thickness, EPSILON)
			assert_float(open.position.y / MM).is_greater(shape.seam)
			var clear := shape.cartridge.z / 2.0 * MM
			if front:
				assert_float(open.position.z).is_greater(cartridge + clear)
			else:
				assert_float(open.end.z).is_less(cartridge - clear)


func test_the_power_switch_and_the_reset_button_slide_back_within_their_recesses() -> void:
	var random := Fixtures.cases(82)
	for shape: N64Shape in Fixtures.accepted(self, CONSOLES, _n64.bind(random)):
		var console: N64Model = Fixtures.built(self, SCENE, shape)
		for power: bool in [true, false]:
			var property := &"power_mm" if power else &"reset_mm"
			var knob: MeshInstance3D = console.get_node("%Power/Knob" if power else "%Reset/Knob")
			var room := shape.recess(power).grow(EPSILON)
			var at_rest := Fixtures.box_of(console, knob)
			var moved := console.moving_parts().filter(func(part: MovingPart) -> bool:
				return part.property == property)
			assert_int(moved.size()).is_equal(1)
			var part: MovingPart = moved[0]
			console.set(property, part.open)
			var slid := Fixtures.box_of(console, knob)
			console.set(property, part.rest)
			assert_bool(room.encloses(_plan(at_rest))).is_true()
			assert_bool(room.encloses(_plan(slid))).is_true()
			assert_float(_plan(slid).position.y - _plan(at_rest).position.y).is_equal_approx(shape.travel(power), EPSILON)
			assert_float(shape.travel(power)).is_greater(1.0)


func test_each_knob_leans_with_the_hill_s_flank_sunk_into_it_and_standing_its_height_out_of_it() -> void:
	var random := Fixtures.cases(86)
	for shape: N64Shape in Fixtures.accepted(self, CONSOLES, _n64.bind(random)):
		for power: bool in [true, false]:
			var points: PackedVector3Array = shape.mesh_arrays(&"power_knob" if power else &"reset_knob", 32)[
				Mesh.ARRAY_VERTEX]
			var lowest := INF
			var highest := -INF
			for point in points:
				var above := point.y / MM - shape.top_height(Vector2(point.x, -point.z) / MM)
				lowest = minf(lowest, above)
				highest = maxf(highest, above)
			# Square to a flank leant at most 30 degrees, the grip on top of the power switch's knob.
			assert_float(lowest).is_less(0.0)
			assert_float(highest).is_between(N64Shape.KNOB_HEIGHT,
				(N64Shape.KNOB_HEIGHT + (1.8 if power else 0.0)) / cos(deg_to_rad(30.0)))


func test_a_cartridge_comes_down_into_the_slot_and_stands_upright_its_label_to_the_front() -> void:
	var random := Fixtures.cases(83)
	for shape: N64Shape in Fixtures.accepted(self, SHAPES, _n64.bind(random)):
		var console: N64Model = auto_free(Fixtures.new_console(SCENE))
		console.shape = shape
		var seat := console.seat()
		assert_bool(seat.basis.is_equal_approx(Basis())).is_true()
		assert_vector(console.approach()).is_equal(Vector3.UP)
		assert_vector(seat.origin / MM).is_equal_approx(Vector3(0.0,
			shape.cartridge_floor + shape.cartridge.y / 2.0, -shape.slot_centre), Vector3.ONE * EPSILON)
		# The cartridge passes between the bezel's edges and stands out of the slot.
		var standing := AABB(seat.origin / MM - shape.cartridge / 2.0, shape.cartridge)
		var inside := shape.slot().grow(-N64Shape.BEZEL)
		assert_bool(inside.encloses(Rect2(standing.position.x, -standing.end.z, standing.size.x, standing.size.z))) \
			.is_true()
		assert_float(standing.position.y).is_greater(shape.seam)
		assert_float(standing.end.y).is_greater(shape.height)


## A Nintendo 64 [param random] draws that [method N64Shape.problems] accepts: each dimension up to
## 8 % from the measured one, the vents a few more or fewer.
static func _n64(random: RandomNumberGenerator) -> N64Shape:
	return Fixtures.drawn_around(N64Shape.new(), random, Vector2(0.92, 1.08), 3) as N64Shape


## [param box] seen from above, in millimetres: X to the right, Y towards the back.
static func _plan(box: AABB) -> Rect2:
	return Rect2(Vector2(box.position.x, -box.end.z) / MM, Vector2(box.size.x, box.size.z) / MM)
