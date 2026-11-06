# SPDX-License-Identifier: GPL-3.0-or-later
class_name BoxCartGeometry
extends RefCounted
## Builds a box cartridge from its [BoxCartShape] as pure functions, so that tests check the geometry
## headless: a block of the rounded outline, its front laid around the label's recess, the label the
## recess's floor, the grip's ridges standing on the front.

const PARTS: Array[StringName] = [&"label", &"shell"]
## How far the ridges go into the front, hidden.
const _SUNK := 0.1


static func arrays(shape: BoxCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.depth / 2.0
	var label := shape.label_box()
	# The front is laid in two pieces either side of a line through the recess.
	var line := label.get_center().x
	var recess := ShapeGeometry.rounded_box(label, shape.label_corner, steps, line)
	match part:
		&"label":
			ShapeGeometry.flat(mesh, recess, front - shape.recess, Vector3.BACK, label)
		&"shell":
			var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
			var face := ShapeGeometry.block(mesh, whole, Vector2.ONE * shape.corner, steps, -front, front, shape.bevel,
				whole, line, false)
			ShapeGeometry.holed(mesh, face, [recess], front, Vector3.BACK, whole, PackedFloat32Array([line]))
			ShapeGeometry.sunk(mesh, recess, front - shape.recess, front, whole, false)
			for ridge in shape.ridges():
				ShapeGeometry.prism(mesh, ShapeGeometry.square(ridge), front - _SUNK, front + BoxCartShape.GRIP_RISE, whole)
	return mesh.arrays()
