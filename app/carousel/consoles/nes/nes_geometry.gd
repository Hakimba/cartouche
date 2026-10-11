# SPDX-License-Identifier: GPL-3.0-or-later
class_name NesGeometry
extends RefCounted
## Builds the NES from its [NesShape] as pure functions, so that tests check the geometry headless.
## Most pieces are rounded rectangles in front view (X right, Y up) swept towards the front along Z,
## the model's own axes, with [ShapeGeometry] blocks; the shells are slabs of outlines of any
## corners (see [method _shell]), the upper one laid out in plan (X right, Y back) and swept up, the
## door laid out from the side and swept across. The door is given about its hinge and the tray
## about its pivot, which the model turns them about.

const PARTS: Array[StringName] = [&"lower", &"upper", &"stripe", &"door", &"tray", &"bar", &"power",
	&"reset", &"diode", &"throat", &"door_logo", &"power_logo", &"reset_logo", &"ports_logo"]
## How round the small pieces are (the door, the lip, the tray, the panel), their outline then
## their ends.
const SMALL := Vector2(0.8, 0.6)
## How deep the buttons go into the shell.
const _BUTTON_DEPTH := 2.0
## How far the panels and the ports' column stand out of the lower shell, and how deep they go in;
## how wide each port's bezel is around its opening, and how far it stands out of the column.
const _PANEL := Vector2(0.3, 1.0)
const _PORTS := Vector2(0.4, 20.0)
const _BEZEL := Vector2(1.5, 0.6)
## Under the stripe at the back, as fractions of [method NesShape.column]: the connectors' panel,
## and on it the power supply's connector, square, and the aerial's, round, X from the left seen
## from the front; how far they stand out.
const _BACK_PORTS := Rect2(0.025, 0.3, 0.95, 0.55)
const _SUPPLY := Rect2(0.62, 0.45, 0.2, 0.28)
const _AERIAL := Rect2(0.18, 0.47, 0.2, 0.2)
const _BACK_PORT_RAISE := 1.0
## The vents: how deep their floor is under the top, how deep their slats' tops.
const _VENT_FLOOR := 3.0
const _SLAT_TOP := 0.8
## The door's tab, at the middle of its bottom edge: its size and how far it stands out.
const _TAB := Vector3(29.0, 2.5, 0.8)
## How long the tray's bar is, across its front top: from behind the throat's back wall, whose plane
## its back would otherwise cross as the tray tilts and goes back.
const _BAR := NesShape.TRAY_REACH + 4.0
## The faces logos are printed on (see ONBOARDING, "A logo"): the lettering on the door, from its
## bottom left corner; each button's word, centred across it, its middle that far up it; the ports'
## numbers, over their bezels, as tall as the column leaves them.
const _DOOR_LOGO := Rect2(5.4, 3.4, 80.1, 16.7)
const _BUTTON_LOGO := Vector2(14.0, 3.4)
const _BUTTON_LOGO_UP := 0.38
const _PORTS_LOGO := 2.0


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: NesShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.front()
	var small := Vector2.ONE * SMALL.x
	match part:
		&"lower":
			_shell(mesh, shape, shape.lower_outline(), steps, -front, front)
			_rect(mesh, shape.panel_box(), small, steps, front - _PANEL.y, front + _PANEL.x,
				SMALL.y / 2.0)
			_rect(mesh, _within(shape.column(), _BACK_PORTS), small, steps, -front - _PANEL.x,
				_PANEL.y - front, SMALL.y / 2.0)
		&"upper":
			_upper(mesh, shape, steps)
		&"stripe":
			_stripe(mesh, shape, steps)
		&"door":
			# Seen from the right (X back, Y up): its face down the front, its lid back over the notch.
			var door := shape.door_box()
			var inside := NesShape.DOOR - front
			var under := shape.height - NesShape.DOOR
			var profile := PackedVector2Array([Vector2(-front, door.position.y), Vector2(inside, door.position.y),
				Vector2(inside, under), Vector2(-shape.hinge().x, under), Vector2(-shape.hinge().x, shape.height),
				Vector2(-front, shape.height)])
			var radii := PackedFloat32Array()
			radii.resize(profile.size())
			radii.fill(SMALL.x)
			var outline := ShapeGeometry.filleted(profile, radii, steps)
			mesh.basis = ShapeGeometry.SIDE
			ShapeGeometry.slab(mesh, outline, door.position.x, door.end.x, Vector2.ONE * SMALL.y,
				ShapeGeometry.bounds(outline))
			mesh.basis = Basis()
			var tab := Rect2(door.get_center().x - _TAB.x / 2.0, door.position.y, _TAB.x, _TAB.y)
			_rect(mesh, tab, Vector2.ONE * _TAB.y / 4.0, steps, front, front + _TAB.z, _TAB.z / 3.0)
			return ShapeGeometry.moved(mesh.arrays(), Transform3D(Basis(), -shape.door(0.0).origin))
		&"tray":
			var rails := shape.rail_box()
			for side: float in [rails.position.x, rails.end.x - NesShape.RAIL]:
				var rail := Rect2(side, rails.position.y, NesShape.RAIL, rails.size.y)
				_rect(mesh, rail, small, steps, 0.0, rails.size.z, SMALL.y)
		&"bar":
			var rails := shape.rail_box()
			var bar := Rect2(-shape.cartridge.x / 2.0, rails.end.y - 2.0, shape.cartridge.x, 2.0)
			_rect(mesh, bar, small, steps, rails.end.z - _BAR, rails.end.z, SMALL.y)
		&"power", &"reset":
			_button(mesh, shape, 0 if part == &"power" else 1, steps)
		&"diode":
			_rect(mesh, shape.diode_box(), Vector2.ONE * 0.6, steps, front, front + _PANEL.x + 0.8,
				0.3)
		&"throat":
			# Its back wall up to the door's lid and its floor behind the lip, dark as the inside of a
			# console, a hair in front of the upper shell's and over the lower one's.
			var wall := Rect2(shape.notch_left(), shape.seam, shape.notch.x,
				shape.height - NesShape.DOOR - shape.seam)
			ShapeGeometry.flat(mesh, ShapeGeometry.square(wall), front - shape.notch.y + 0.05, Vector3.BACK,
				wall)
			var ground := Rect2(shape.notch_left(), -front + NesShape.WALL, shape.notch.x,
				shape.notch.y - NesShape.WALL)
			mesh.basis = ShapeGeometry.PLAN
			ShapeGeometry.flat(mesh, ShapeGeometry.square(ground), shape.seam + 0.05, Vector3.BACK, ground)
			mesh.basis = Basis()
			# And the ports' openings, as dark.
			for index in 2:
				var port := shape.port_box(index)
				var opening := ShapeGeometry.rounded_box(port, shape.port_corner(), steps)
				ShapeGeometry.flat(mesh, opening, front + _PORTS.x + 0.05, Vector3.BACK, port)
		&"door_logo":
			var door := shape.door_box()
			ShapeGeometry.decal(mesh, Rect2(door.position + _DOOR_LOGO.position, _DOOR_LOGO.size), front)
			return ShapeGeometry.moved(mesh.arrays(), Transform3D(Basis(), -shape.door(0.0).origin))
		&"power_logo", &"reset_logo":
			var button := shape.button_box(0 if part == &"power_logo" else 1)
			var middle := Vector2(button.get_center().x, button.position.y + button.size.y * _BUTTON_LOGO_UP)
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(middle, _BUTTON_LOGO),
				front + _PANEL.x + shape.button_raise)
		&"ports_logo":
			var column := shape.column()
			var band := Rect2(column.position.x + 2.0, shape.port_box(0).end.y + _BEZEL.x + 0.05,
				column.size.x - 4.0, _PORTS_LOGO)
			ShapeGeometry.decal(mesh, band, front + _PORTS.x)
	return mesh.arrays()


## The upper shell: left of the stripe with its notch, and right of it, laid out in plan; the lip
## under the door, and the vents' slats across the stripe.
static func _upper(mesh: MeshBuilder, shape: NesShape, steps: int) -> void:
	var front := shape.front()
	var right := shape.stripe.x + shape.stripe.y / 2.0
	var beside := ShapeGeometry.square(Rect2(right, -front, shape.width / 2.0 - right, shape.depth))
	mesh.basis = ShapeGeometry.PLAN
	for outline: PackedVector2Array in [shape.upper_outline(), beside]:
		_shell(mesh, shape, outline, steps, shape.seam, shape.height)
	mesh.basis = Basis()
	var small := Vector2.ONE * SMALL.x
	var lip := Rect2(shape.notch_left(), shape.seam, shape.notch.x, shape.lip)
	_rect(mesh, lip, small, steps, front - NesShape.WALL, front, SMALL.y)
	var slat := ShapeGeometry.square(Rect2(shape.stripe_left(), shape.height - _VENT_FLOOR, shape.stripe.y,
		_VENT_FLOOR - _SLAT_TOP))
	var start := shape.stripe_ends.y - front
	var pitch := (shape.depth - shape.stripe_ends.x - shape.stripe_ends.y) / shape.vent_count
	for i in shape.vent_count:
		var middle := start + (i + 0.5) * pitch
		ShapeGeometry.prism(mesh, slat, middle - NesShape.SLAT * pitch / 2.0, middle + NesShape.SLAT * pitch / 2.0)


## The stripe's dark pieces: at the front, a piece behind the top's first groove and three bands
## down its front; at the back, two pieces; the vents' floor between them; and under it, the column
## down the lower shell's front with the ports' bezels, and the connectors at the back.
static func _stripe(mesh: MeshBuilder, shape: NesShape, steps: int) -> void:
	var front := shape.front()
	var left := shape.stripe_left()
	var wide := shape.stripe.y
	var upper := shape.height - shape.seam
	var bottom := upper * NesShape.BANDS.x
	var top := upper * NesShape.BANDS.y
	var middle := front - shape.stripe_ends.x / 2.0
	var rounding := Vector2.ONE * shape.corner
	var whole := Rect2(left, shape.seam, wide, upper)
	_rect(mesh, whole, rounding, steps, front - shape.stripe_ends.x, middle, shape.bevel)
	var bands: Array[Rect2] = [Rect2(left, shape.height - top, wide, top),
		Rect2(left, shape.seam, wide, bottom),
		Rect2(left, shape.seam + bottom, wide, upper - bottom - top)]
	for band in bands:
		_rect(mesh, band, rounding, steps, middle, front, shape.bevel)
	var back := shape.stripe_ends.y - front
	_rect(mesh, whole, rounding, steps, -front, back - shape.stripe_ends.y / 2.0, shape.bevel)
	_rect(mesh, whole, rounding, steps, back - shape.stripe_ends.y / 2.0, back, shape.bevel)
	_rect(mesh, Rect2(left, shape.seam, wide, upper - _VENT_FLOOR), rounding, steps, back,
		front - shape.stripe_ends.x, shape.bevel)
	_rect(mesh, shape.column(), rounding, steps, front - _PORTS.y, front + _PORTS.x, shape.bevel)
	for index in 2:
		var port := shape.port_box(index)
		var opening := ShapeGeometry.rounded_box(port, shape.port_corner(), steps)
		var bezel := Vector2.ONE * (shape.port_corner() + _BEZEL.x)
		ShapeGeometry.block(mesh, port.grow(_BEZEL.x), bezel, steps, front + _PORTS.x - 0.1,
			front + _PORTS.x + _BEZEL.y, _BEZEL.y / 3.0, port, NAN, true, opening)
	var supply := _within(shape.column(), _SUPPLY)
	var aerial := _within(shape.column(), _AERIAL)
	var round_by := minf(aerial.size.x, aerial.size.y) / 2.0 - 0.1
	var out := -front - _BACK_PORT_RAISE
	_rect(mesh, supply, Vector2.ONE * SMALL.x, steps, out, _PANEL.y - front, SMALL.y)
	_rect(mesh, aerial, Vector2.ONE * round_by, steps, out, _PANEL.y - front, SMALL.y)


## Adds the button [param index] (see [method NesShape.button_box]), standing out of its panel.
static func _button(mesh: MeshBuilder, shape: NesShape, index: int, steps: int) -> void:
	var front := shape.front()
	_rect(mesh, shape.button_box(index), Vector2.ONE * NesShape.BUTTON_ROUND.x, steps, front - _BUTTON_DEPTH,
		front + _PANEL.x + shape.button_raise, NesShape.BUTTON_ROUND.y)


## Adds the block of the rectangle [param box] (see [method ShapeGeometry.block]).
static func _rect(mesh: MeshBuilder, box: Rect2, corners: Vector2, steps: int, back: float,
		front: float, bevel: float) -> void:
	ShapeGeometry.block(mesh, box, corners, steps, back, front, bevel, box)


## Adds the shell of [param polygon] (counter-clockwise, any corners, each rounded by the shell's
## corner) from [param low] to [param high], its edges rounded by its bevel.
static func _shell(mesh: MeshBuilder, shape: NesShape, polygon: PackedVector2Array, steps: int, low: float,
		high: float) -> void:
	var radii := PackedFloat32Array()
	radii.resize(polygon.size())
	radii.fill(shape.corner)
	var outline := ShapeGeometry.filleted(polygon, radii, steps)
	ShapeGeometry.slab(mesh, outline, low, high, Vector2.ONE * shape.bevel, ShapeGeometry.bounds(outline))


## The part [param fraction] of [param whole], as fractions of its size.
static func _within(whole: Rect2, fraction: Rect2) -> Rect2:
	return Rect2(whole.position + fraction.position * whole.size, fraction.size * whole.size)
