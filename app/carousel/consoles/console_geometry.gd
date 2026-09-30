# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleGeometry
extends RefCounted
## Builds a console from its [ConsoleShape] as pure functions, so that tests check the geometry
## headless. Each part is laid out in plan, X to the right and Y towards the back, swept up along Z
## with [ShapeGeometry] blocks, then turned into the model's space: top up (+Y), front towards +Z.
## The upper block has the lid's opening through it; the lid is given around its hinge, which the
## model turns it about.

const PARTS: Array[StringName] = [&"lower", &"upper", &"lid", &"well", &"ribs"]
## From plan (X right, Y back, Z up) to the model's space (Y up, Z to the front).
const _TO_MODEL := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps];
## none when [param shape] has [method ConsoleShape.problems] or no such part.
static func arrays(shape: ConsoleShape, part: StringName, detail: int) -> Array:
	if not shape.problems().is_empty() or part not in PARTS:
		return []
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var corners := Vector2.ONE * shape.corner
	var at := Transform3D(_TO_MODEL, Vector3.ZERO)
	# As many points around the opening as around the top, so that they join point to point.
	var opening := ShapeGeometry.rounded_box(shape.opening(), shape.lid_corner + shape.lid_gap, steps)
	match part:
		&"lower":
			ShapeGeometry.block(mesh, body, corners, steps, 0.0, shape.seam, shape.bevel, body)
		&"upper":
			ShapeGeometry.block(mesh, body, corners, steps, shape.seam, shape.height, shape.bevel, body,
				NAN, true, opening)
		&"lid":
			# Rounded less than its corners, so that each outline along the bevel keeps its shape.
			var edge := minf(minf(shape.bevel, shape.lid_thickness / 3.0), shape.lid_corner / 2.0)
			ShapeGeometry.block(mesh, shape.lid_box(), Vector2.ONE * shape.lid_corner, steps,
				shape.height - shape.lid_thickness, shape.height, edge, shape.lid_box())
			at.origin = -shape.hinge()
		&"well":
			# Just above the lower block's top, which it hides.
			ShapeGeometry.flat(mesh, opening, shape.seam + 0.05, Vector3.BACK, shape.opening())
		&"ribs":
			var rib_corner := shape.rib_corner()
			for rib in shape.ribs():
				ShapeGeometry.block(mesh, rib, Vector2.ONE * rib_corner, steps, shape.height,
					shape.height + shape.rib_raise, minf(shape.rib_raise * 0.3, rib_corner / 2.0), rib)
	return _moved(mesh.arrays(), at)


## [param built] moved by [param at]: its points, and its normals and tangents turned with them.
static func _moved(built: Array, at: Transform3D) -> Array:
	var points: PackedVector3Array = built[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = built[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = built[Mesh.ARRAY_TANGENT]
	built[Mesh.ARRAY_VERTEX] = at * points
	built[Mesh.ARRAY_NORMAL] = Transform3D(at.basis, Vector3.ZERO) * normals
	for i in points.size():
		var tangent := at.basis * Vector3(tangents[4 * i], tangents[4 * i + 1], tangents[4 * i + 2])
		tangents[4 * i] = tangent.x
		tangents[4 * i + 1] = tangent.y
		tangents[4 * i + 2] = tangent.z
	built[Mesh.ARRAY_TANGENT] = tangents
	return built
