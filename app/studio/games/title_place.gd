# SPDX-License-Identifier: GPL-3.0-or-later
class_name TitlePlace
extends RefCounted
## The title's top is measured from the medium's vertices, never from its shadow or bounding-box corners.

const GAP := 20.48
const CAMERA := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 3.7))


## Fits a model in its parent's space, centred on its box, with its largest face dimension 1.2.
static func fitting(model: Node3D) -> Transform3D:
	var box := Plinth.bounds(model, model.get_parent_node_3d())
	var by := 1.2 / maxf(box.size.x, box.size.y)
	return Transform3D(Basis.from_scale(Vector3.ONE * by), -box.get_center() * by)


## Every mesh vertex under a model, in its parent's space, whether the model is in the tree or not.
static func vertices(model: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var into := Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != model.get_parent_node_3d():
			into = node.transform * into
			node = node.get_parent_node_3d()
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var corners: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			points.append_array(into * corners)
	return points


## The pill's top in canvas pixels under the chosen, still medium seen through the given camera.
static func top(points: PackedVector3Array, chosen: Transform3D, camera := CAMERA, frame := CarouselLayout.FRAME, fov := 32.0) -> float:
	var into := camera.affine_inverse() * chosen
	var focal := frame.y / (2.0 * tan(deg_to_rad(fov) / 2.0))
	var lowest := -INF
	for vertex in points:
		var point := into * vertex
		lowest = maxf(lowest, frame.y / 2.0 + focal * point.y / point.z)
	return lowest + GAP * frame.x / CarouselLayout.FRAME.x
