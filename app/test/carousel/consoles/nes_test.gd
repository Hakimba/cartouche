# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The NES's own looks and gesture, from its glb: its parts are the glb's nodes; its door, lifted by hand,
## turns up and back and stands above the top, its face to the front; its tray carries the cartridge in
## from the front, tilted, and presses it down level, the door closed over it; its buttons go in; its diode
## lights.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const NES := "res://carousel/consoles/nes/nes.tscn"
## Measured on the glb: its triangles, and the door's hinge, in millimetres, forwards and up from the body's
## middle and the table.
const TRIANGLES := 6564
const HINGE := Vector2(66.5, 88.6)
const HINGE_PLAY_MM := 0.1
## The tray's pivot in the glb, in millimetres: up, and behind the body's middle.
const TRAY_PIVOT := Vector3(-20.05, 46.77, -31.5)
const NODES: Dictionary[StringName, Array] = {
	&"door_degrees": ["door"], &"tray_degrees": ["tray"], &"power_mm": ["power"], &"reset_mm": ["reset"],
	&"light_energy": ["led"],
}


func test_every_part_the_nes_moves_is_a_node_of_its_glb_and_it_is_drawn_within_its_triangle_budget() -> void:
	Fixtures.assert_glb(self, Fixtures.shown_console(self, NES), "nes", NODES, TRIANGLES)


func test_the_door_turns_up_and_back_about_its_hinge_and_stands_above_the_top_its_face_to_the_front() -> void:
	var console := Fixtures.shown_console(self, NES) as NesModel
	var door: MeshInstance3D = console.get_node(^"Model/nes/door")
	var body: MeshInstance3D = console.get_node(^"Model/nes/body")
	var hinge := Vector2(door.position.z, door.position.y) / Fixtures.MM
	assert_vector(hinge).is_equal_approx(HINGE, Vector2.ONE * HINGE_PLAY_MM)
	assert_bool(door.basis.is_equal_approx(Basis())).is_true()
	var top := Fixtures.box_of(console, body).end.y
	var closed := Fixtures.box_of(console, door)
	assert_float(closed.end.y).is_less_equal(top + Fixtures.EPSILON)
	console.door_degrees = NesShape.DOOR_OPEN
	var open := Fixtures.box_of(console, door)
	# The hinge stays; the lid's front edge stands high above the top, the face tipped back yet to the front.
	assert_vector(Vector2(door.position.z, door.position.y) / Fixtures.MM).is_equal_approx(HINGE, Vector2.ONE * HINGE_PLAY_MM)
	assert_float(open.end.y).is_greater(top + 0.4 * closed.size.z)
	assert_float(door.basis.z.z).is_greater(0.0)
	assert_float(door.basis.z.y).is_greater(0.0)
	console.door_degrees = 0.0
	assert_bool(door.basis.is_equal_approx(Basis())).is_true()


func test_the_tray_pivots_where_the_glb_puts_it_and_the_cartridge_s_seat_rides_on_it_as_drawn() -> void:
	var console := Fixtures.shown_console(self, NES) as NesModel
	var tray: Node3D = console.get_node(^"Model/nes/tray")
	var shape: NesShape = console.shape
	assert_vector(tray.position / Fixtures.MM).is_equal_approx(shape.tray_pivot, Vector3.ONE * 0.01)
	assert_vector(shape.tray_pivot).is_equal_approx(TRAY_PIVOT, Vector3.ONE * 0.05)
	var on_tray := tray.transform.affine_inverse() * console.seat()
	for degrees: float in [shape.tray_tilt / 3.0, shape.tray_tilt]:
		console.tray_degrees = degrees
		assert_bool(tray.transform.is_equal_approx(shape.tray(degrees))).is_true()
		assert_bool((tray.transform.affine_inverse() * console.seat()).is_equal_approx(on_tray)).is_true()
	assert_bool(console.seat().is_equal_approx(shape.seat(shape.tray_tilt))).is_true()


func test_a_cartridge_comes_in_from_the_front_along_the_tray_label_up_and_sinks_level_behind_the_lip() -> void:
	var console := Fixtures.shown_console(self, NES) as NesModel
	var shape: NesShape = console.shape
	for degrees: float in [0.0, shape.tray_tilt / 2.0, shape.tray_tilt]:
		console.tray_degrees = degrees
		var tilt := deg_to_rad(degrees)
		var seat := console.seat().basis
		var near := Vector3.ONE * Fixtures.EPSILON
		assert_vector(seat * console.approach()).is_equal_approx(Vector3(0.0, sin(tilt), cos(tilt)), near)
		assert_vector(seat.z).is_equal_approx(Vector3(0.0, cos(tilt), -sin(tilt)), near)
		# Not mirrored: a cartridge's own right stays the console's left, seen from its label.
		assert_float(seat.determinant()).is_equal_approx(1.0, Fixtures.EPSILON)
	# Pressed down: level, its label up, its front end behind the body's front.
	console.tray_degrees = 0.0
	var seated := console.seat()
	assert_vector(seated.basis.y).is_equal_approx(Vector3.BACK, Vector3.ONE * Fixtures.EPSILON)
	assert_float(seated.origin.z + shape.cartridge.y / 2.0 * Fixtures.MM).is_less(
		Fixtures.box_of(console, console.get_node(^"Model/nes/body") as MeshInstance3D).end.z)


func test_the_door_is_lifted_before_the_cartridge_comes_and_closed_once_it_is_pressed_down() -> void:
	var console: NesModel = auto_free(Fixtures.new_console(NES))
	var shape: NesShape = console.shape
	var animation := LaunchAnimation.placeholder(console, AABB(-shape.cartridge / 2.0 * Fixtures.MM, shape.cartridge * Fixtures.MM))
	var value_at := func(property: StringName, moment: StringName) -> float:
		var track := animation.find_track(NodePath("Consoles/%s:%s" % [console.name, property]), Animation.TYPE_VALUE)
		return animation.value_track_interpolate(track, LaunchAnimation.moment(animation, moment))
	assert_float(value_at.call(&"door_degrees", &"consoles")).is_zero()
	assert_float(value_at.call(&"door_degrees", &"seated")).is_equal_approx(NesShape.DOOR_OPEN, Fixtures.EPSILON)
	assert_float(value_at.call(&"tray_degrees", &"seated")).is_equal_approx(shape.tray_tilt, Fixtures.EPSILON)
	assert_float(value_at.call(&"door_degrees", &"black")).is_zero()
	assert_float(value_at.call(&"tray_degrees", &"black")).is_zero()


func test_the_power_and_reset_buttons_go_in_from_where_the_glb_has_them_and_come_back() -> void:
	var console := Fixtures.shown_console(self, NES) as NesModel
	for part: StringName in [&"power_mm", &"reset_mm"]:
		var button: Node3D = console.get_node("Model/nes/%s" % NODES[part][0])
		var rest := button.position
		var pressed := Fixtures.open_of(console, part)
		console.set(part, pressed)
		assert_vector(button.position - rest).is_equal_approx(Vector3(0.0, 0.0, -pressed * Fixtures.MM), Vector3.ONE * Fixtures.EPSILON * Fixtures.MM)
		console.set(part, 0.0)
		assert_vector(button.position).is_equal_approx(rest, Vector3.ONE * Fixtures.EPSILON * Fixtures.MM)
		assert_float(pressed).is_equal(NesShape.BUTTON_IN)
