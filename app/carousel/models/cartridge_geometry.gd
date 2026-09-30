# SPDX-License-Identifier: GPL-3.0-or-later
class_name CartridgeGeometry
extends RefCounted
## Builds a cartridge from its [CartridgeShape] as pure functions, so that tests check the geometry
## headless. Each block is a rounded outline swept with bevels from its back to its front; the
## body's front has the label's recess, with sloped edges, whose floor is the label.

const PARTS: Array[StringName] = [&"label", &"shell"]


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps];
## none when [param shape] has [method CartridgeShape.problems] or no such part.
static func arrays(shape: CartridgeShape, part: StringName, detail: int) -> Array:
	if not shape.problems().is_empty() or part not in PARTS:
		return []
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var back := -shape.depth / 2.0
	var front := shape.depth / 2.0
	var recessed := front - shape.recess
	# Both loops get a point where the vertical line through the label crosses them, where the
	# body's front is cut in two around the recess.
	var cut := shape.label_centre.x
	var label_corner := shape.label_corner
	var label := ShapeGeometry.rounded_box(shape.label_box(), label_corner, steps, cut)
	if part == &"label":
		ShapeGeometry.flat(mesh, label, recessed, Vector3.BACK, shape.label_box())
		return mesh.arrays()
	var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
	var half := shape.width / 2.0
	var top := shape.height / 2.0
	var body_corners := Vector2(shape.bottom_corner, shape.hidden_corner())
	var face := ShapeGeometry.block(mesh, shape.body(), body_corners, steps, back, front,
		shape.bevel, whole, cut, false)
	# The recess's edge, sloping down to the label: the label's outline, grown.
	var edge := ShapeGeometry.rounded_box(shape.label_box().grow(shape.recess_slope),
		label_corner + shape.recess_slope, steps, cut)
	var outside := ShapeGeometry.rounded_box(shape.label_box().grow(1.0), label_corner + 1.0, steps, cut)
	var face_cuts := ShapeGeometry.cuts(face, cut)
	var edge_cuts := ShapeGeometry.cuts(edge, cut)
	for side in 2:
		var around := ShapeGeometry.between(face, face_cuts[side], face_cuts[1 - side])
		var inside := ShapeGeometry.between(edge, edge_cuts[side], edge_cuts[1 - side])
		inside.reverse()
		around.append_array(inside)
		ShapeGeometry.flat(mesh, around, front, Vector3.BACK, whole)
	for i in label.size():
		var next := (i + 1) % label.size()
		var towards_label := (label[i] - outside[i]).normalized()
		var slope := Vector3(towards_label.x * shape.recess, towards_label.y * shape.recess,
			shape.recess_slope)
		mesh.quad(ShapeGeometry.add(mesh, label[i], recessed, slope, whole),
			ShapeGeometry.add(mesh, label[next], recessed, slope, whole),
			ShapeGeometry.add(mesh, edge[next], front, slope, whole),
			ShapeGeometry.add(mesh, edge[i], front, slope, whole))
	var upper_front := front + shape.ledge
	var upper := Rect2(-half, shape.step(), shape.width, shape.upper_height)
	var upper_corners := Vector2(shape.hidden_corner(), shape.top_corner)
	ShapeGeometry.block(mesh, upper, upper_corners, steps, back, upper_front, shape.bevel, whole)
	var plate := ShapeGeometry.rounded_box(shape.plate_box(), shape.plate_corner(), steps)
	ShapeGeometry.flat(mesh, plate, upper_front + shape.plate_raise, Vector3.BACK, whole)
	ShapeGeometry.wall(mesh, plate, upper_front, upper_front + shape.plate_raise, whole)
	# The ridge: a bar rounded all along, its back and top hidden in the upper part.
	var ends := shape.ridge_height / 2.0
	var ridge := Rect2(-half + shape.bevel, top - shape.ridge_height - 0.01,
		shape.width - 2.0 * shape.bevel, shape.ridge_height)
	var ridge_back := upper_front - shape.ridge_height
	# Rounded almost all the way: a thinner flat front would fold at the ends.
	var ridge_front := upper_front + shape.ridge_raise
	ShapeGeometry.block(mesh, ridge, Vector2.ONE * ends, steps, ridge_back, ridge_front, ends * 0.8,
		whole)
	return mesh.arrays()
