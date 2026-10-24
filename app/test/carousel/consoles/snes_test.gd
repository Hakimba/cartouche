# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The PAL Super Nintendo's own looks, from its glb: its parts are the glb's nodes; its flaps rest flat and
## hang straight down the slot, its cartridge's seat between them; its eject lever, knob and reset button.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/snes/snes.tscn"
## Measured on the glb: its triangles, and how wide the well a cartridge goes down is, in millimetres.
const TRIANGLES := 5994
const WELL_WIDTH := 137.2
## The well's floor, which a seated cartridge must stay above, and its walls front and back, measured on the
## glb's body by rays from the seat (millimetres); how far a cartridge's top stands out of the console's.
const WELL_FLOOR := 20.0
const WELL_Z := Vector2(-40.89, -10.49)
const RISE_MM := Vector2(45.0, 49.0)
const NODES: Dictionary[StringName, Array] = {
	&"flaps_degrees": ["back_flap", "front_flap"], &"eject_degrees": ["eject"], &"power_mm": ["knob"],
	&"reset_mm": ["reset"],
}


func test_every_part_the_snes_moves_is_a_node_of_its_glb_and_it_is_drawn_within_its_triangle_budget() -> void:
	Fixtures.assert_glb(self, Fixtures.shown_console(self, SCENE), "snes", NODES, TRIANGLES)


func test_the_flaps_rest_flat_and_hang_straight_down_the_slot_the_back_one_turning_the_other_way() -> void:
	var console := Fixtures.shown_console(self, SCENE) as SnesModel
	var back: MeshInstance3D = console.get_node(^"Model/snes/back_flap")
	var front: MeshInstance3D = console.get_node(^"Model/snes/front_flap")
	assert_float(Fixtures.open_of(console, &"flaps_degrees")).is_equal(90.0)
	var flaps: Array[MeshInstance3D] = [back, front]
	var flat: Array[AABB] = [Fixtures.box_of(console, back), Fixtures.box_of(console, front)]
	console.flaps_degrees = 90.0
	var hung: Array[AABB] = [Fixtures.box_of(console, back), Fixtures.box_of(console, front)]
	for i in 2:
		# Hanging from its hinge as long as the flap lay, no longer sticking out sideways.
		var hinge := flaps[i].position.y
		assert_float(hung[i].size.y).is_equal_approx(flat[i].size.z, Fixtures.EPSILON * Fixtures.MM)
		assert_float(hung[i].end.y).is_equal_approx(hinge, 0.03 * Fixtures.MM)
		assert_float(hung[i].size.z).is_less(flat[i].size.y + Fixtures.EPSILON * Fixtures.MM)
	assert_float(back.rotation.x).is_equal_approx(PI / 2.0, Fixtures.EPSILON)
	assert_float(front.rotation.x).is_equal_approx(-PI / 2.0, Fixtures.EPSILON)
	console.flaps_degrees = 0.0
	assert_bool(back.basis.is_equal_approx(Basis())).is_true()
	assert_bool(front.basis.is_equal_approx(Basis())).is_true()


func test_a_cartridge_stands_in_the_well_its_label_to_the_front_clear_of_its_walls_and_floor_and_standing_out_of_the_top() -> void:
	var console := Fixtures.shown_console(self, SCENE) as SnesModel
	var seat := console.seat()
	var top := Fixtures.box_of(console, console.get_node(^"Model/snes/body") as MeshInstance3D).end.y
	assert_bool(seat.basis.is_equal_approx(Basis())).is_true()
	assert_vector(console.approach()).is_equal(Vector3.UP)
	for medium in Fixtures.media("snes"):
		var shape := Fixtures.medium_shape(medium)
		var width: float = shape.get(&"width")
		var height: float = shape.get(&"height")
		var thickness: float = shape.get(&"thickness")
		var size := Vector3(width, height, thickness) * Fixtures.MM
		var standing := AABB(seat.origin - size / 2.0, size)
		# Across the well, from its front wall to its back wall, above its floor, its top out of the console's.
		assert_float(standing.position.x / Fixtures.MM).override_failure_message(medium).is_greater_equal(-WELL_WIDTH / 2.0)
		assert_float(standing.end.x / Fixtures.MM).override_failure_message(medium).is_less_equal(WELL_WIDTH / 2.0)
		assert_float(standing.position.z / Fixtures.MM).override_failure_message(medium).is_greater_equal(WELL_Z.x)
		assert_float(standing.end.z / Fixtures.MM).override_failure_message(medium).is_less_equal(WELL_Z.y)
		assert_float(standing.position.y / Fixtures.MM).override_failure_message(medium).is_greater_equal(WELL_FLOOR)
		assert_float((standing.end.y - top) / Fixtures.MM).override_failure_message(medium).is_between(RISE_MM.x, RISE_MM.y)


func test_pressed_the_eject_lever_comes_level_with_the_panel_the_reset_button_goes_down_and_the_knob_slides_back() -> void:
	var console := Fixtures.shown_console(self, SCENE) as SnesModel
	var lever: MeshInstance3D = console.get_node(^"Model/snes/eject")
	var top := lever.get_aabb()
	# The middle of its top's front edge comes down to the lever's own origin, the panel's height.
	console.eject_degrees = Fixtures.open_of(console, &"eject_degrees")
	assert_float((lever.basis * Vector3(0.0, top.end.y, top.end.z)).y / Fixtures.MM).is_equal_approx(0.0, 0.3)
	var button: Node3D = console.get_node(^"Model/snes/reset")
	var knob: Node3D = console.get_node(^"Model/snes/knob")
	var resting := [button.position, knob.position]
	console.reset_mm = Fixtures.open_of(console, &"reset_mm")
	console.power_mm = Fixtures.open_of(console, &"power_mm")
	assert_vector((button.position - resting[0]) / Fixtures.MM).is_equal_approx(Vector3(0.0, -0.45, 0.0), Vector3.ONE * Fixtures.EPSILON)
	assert_vector((knob.position - resting[1]) / Fixtures.MM).is_equal_approx(Vector3(0.0, 0.0, -4.5), Vector3.ONE * Fixtures.EPSILON)
