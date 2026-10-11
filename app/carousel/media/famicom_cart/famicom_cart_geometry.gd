# SPDX-License-Identifier: GPL-3.0-or-later
class_name FamicomCartGeometry
extends RefCounted
## Builds a Famicom cartridge from its [FamicomCartShape] as pure functions, so that tests check the
## geometry headless: the outline the NES Game Pak's is drawn as ([NesCartGeometry]), swept with
## bevels from the back to the front, whose front is cut in two through the label's centre around
## the recess, whose floor is the label.

const PARTS: Array[StringName] = [&"label", &"shell", &"opening"]


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: FamicomCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.depth / 2.0
	var cut := shape.label_centre.x
	var hole := ShapeGeometry.rounded_box(shape.label_box(), shape.label_corner, steps, cut)
	match part:
		&"label":
			ShapeGeometry.flat(mesh, hole, front - shape.recess, Vector3.BACK, shape.label_box())
		&"shell":
			var size := Vector2(shape.width, shape.height)
			var whole := ShapeGeometry.centred(Vector2.ZERO, size)
			var outline := NesCartGeometry.loop(NesCartGeometry.outline(size, shape.foot, shape.top_corner,
				shape.corner, 0.0, []), steps)
			var face := ShapeGeometry.slab(mesh, ShapeGeometry.crossed(outline, cut), -front, front,
				Vector2.ONE * shape.bevel, whole, false)
			ShapeGeometry.holed(mesh, face, [hole], front, Vector3.BACK, whole, PackedFloat32Array([cut]))
			ShapeGeometry.sunk(mesh, hole, front - shape.recess, front, whole, false)
		&"opening":
			NesCartGeometry.opening(mesh, shape.opening, -shape.height / 2.0)
	return mesh.arrays()
