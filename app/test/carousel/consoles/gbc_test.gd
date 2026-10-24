# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Game Boy Color's own looks, from its glb: its parts are the glb's nodes; its power switch rests on the
## printed OFF and slides down to ON; how it is presented and where its cartridge stands.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## Loaded, never preloaded: INV-E10-04 tells which consoles were loaded by the cache.
const SCENE := "res://carousel/consoles/gbc/gbc.tscn"
## Measured on the glb: its triangles.
const TRIANGLES := 9426
## The pocket the cartridge goes down, measured on the glb's body by rays from the seat (millimetres): across
## it, and from the back plate's wall to the front wall; and the floor the cartridge's foot goes through, by
## design, into the shell, where its connector sits.
const POCKET_X := Vector2(-30.75, 29.6)
const POCKET_Z := Vector2(-9.63, -0.78)
const POCKET_FLOOR := 23.19
const SINK_MAX_MM := 19.0
## How far the cartridge's top stands out of the console's top, as the app has always had it.
const RISE_MM := 3.0
const NODES: Dictionary[StringName, Array] = {&"power_mm": ["power"], &"light_energy": ["led"]}


func test_every_part_the_gbc_moves_is_a_node_of_its_glb_and_it_is_drawn_within_its_triangle_budget() -> void:
	Fixtures.assert_glb(self, Fixtures.shown_console(self, SCENE), "gbc", NODES, TRIANGLES)


func test_the_power_switch_rests_on_the_printed_off_and_slides_down_to_on_on_the_right_side() -> void:
	var console := Fixtures.shown_console(self, SCENE) as GbcModel
	var power: MeshInstance3D = console.get_node(^"Model/gbc/power")
	var body: MeshInstance3D = console.get_node(^"Model/gbc/body")
	var travel := Fixtures.open_of(console, &"power_mm")
	assert_float(travel).is_equal((console.shape as GbcShape).power_travel).is_greater(0.5)
	var at_rest := Fixtures.box_of(console, power)
	console.power_mm = travel
	var slid := Fixtures.box_of(console, power)
	# Down, by its travel and no sideways, on the body's right side, within its ribs and half a millimetre out.
	assert_float((at_rest.position.y - slid.position.y) / Fixtures.MM).is_equal_approx(travel, Fixtures.EPSILON)
	assert_float(slid.position.x).is_equal_approx(at_rest.position.x, Fixtures.EPSILON * Fixtures.MM)
	assert_float(slid.position.z).is_equal_approx(at_rest.position.z, Fixtures.EPSILON * Fixtures.MM)
	var side := Fixtures.box_of(console, body).end.x
	for box: AABB in [at_rest, slid]:
		assert_float((box.end.x - side) / Fixtures.MM).is_between(-1.0, 0.5)
	console.power_mm = 0.0
	assert_float(power.position.y).is_equal_approx(0.0, Fixtures.EPSILON * Fixtures.MM)
	assert_vector(Fixtures.box_of(console, power).position).is_equal_approx(at_rest.position, Vector3.ONE * Fixtures.EPSILON * Fixtures.MM)


func test_a_cartridge_goes_down_the_pocket_label_to_the_back_within_its_walls_standing_out_of_the_top() -> void:
	var console := Fixtures.shown_console(self, SCENE) as GbcModel
	var shape: GbcShape = console.shape
	var seat := console.seat()
	assert_vector(console.approach()).is_equal(Vector3.UP)
	assert_vector(seat.basis * Vector3.UP).is_equal_approx(Vector3.UP, Vector3.ONE * Fixtures.EPSILON)
	assert_vector(seat.basis * Vector3.BACK).is_equal_approx(Vector3.FORWARD, Vector3.ONE * Fixtures.EPSILON)
	var standing := AABB(seat.origin - shape.cartridge * Fixtures.MM / 2.0, shape.cartridge * Fixtures.MM)
	var body := Fixtures.box_of(console, console.get_node(^"Model/gbc/body") as MeshInstance3D)
	# Its top stands out of the console's top, its foot sunk below the pocket's floor by no more than the
	# connector's room, and across and through the pocket within its walls.
	assert_float((standing.end.y - body.end.y) / Fixtures.MM).is_equal_approx(RISE_MM, 0.5)
	assert_float(POCKET_FLOOR - standing.position.y / Fixtures.MM).is_between(0.0, SINK_MAX_MM)
	assert_float(standing.position.x / Fixtures.MM).is_greater_equal(POCKET_X.x)
	assert_float(standing.end.x / Fixtures.MM).is_less_equal(POCKET_X.y)
	assert_float(standing.position.z / Fixtures.MM).is_greater_equal(POCKET_Z.x)
	assert_float(standing.end.z / Fixtures.MM).is_less_equal(POCKET_Z.y)


func test_the_console_is_presented_its_face_to_the_camera_its_top_tipped_towards_it() -> void:
	var console: GbcModel = auto_free(Fixtures.new_console(SCENE))
	var facing := console.presented()
	assert_float((facing * Vector3.BACK).z).is_greater(0.9)
	assert_float((facing * Vector3.UP).z).is_greater(0.1)
	assert_float((facing * Vector3.RIGHT).x).is_equal_approx(1.0, Fixtures.EPSILON)
