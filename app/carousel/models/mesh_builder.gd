# SPDX-License-Identifier: GPL-3.0-or-later
class_name MeshBuilder
extends RefCounted
## Collects the vertices and faces of a mesh, given in millimetres, then gives its arrays in world
## units. Faces are turned towards their vertices' normals, so that callers never deal with Godot's
## winding order.

## World units per millimetre: a DVD is 1.2 units wide.
const UNITS_PER_MM := 0.01

## Turns each vertex added, its normal and tangent with it: the pieces of one part laid out in
## another plane than the part's, such as a side's.
var basis := Basis()

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _tangents := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _colours := PackedColorArray()
var _indices := PackedInt32Array()


## Adds a vertex and gives its index. Its [param tangent] is made square to its normal, as normal
## maps need it: a tangent along the normal falls back to one across it. Its [param colour] marks
## it for the shaders that read it (a disc's recorded area, its rim): black, by default, for none.
func add(point: Vector3, normal: Vector3, uv: Vector2, tangent := Vector3.RIGHT,
		colour := Color.BLACK) -> int:
	var towards := (basis * normal).normalized()
	var turned := basis * tangent
	var across := turned - towards * towards.dot(turned)
	if across.length_squared() < 1e-6:
		across = towards.cross(Vector3.UP if absf(towards.y) < 0.9 else Vector3.RIGHT)
	across = across.normalized()
	_vertices.append(basis * point * UNITS_PER_MM)
	_normals.append(towards)
	_tangents.append_array([across.x, across.y, across.z, 1.0])
	_uvs.append(uv)
	_colours.append(colour)
	return _vertices.size() - 1


func triangle(a: int, b: int, c: int) -> void:
	var face := (_vertices[b] - _vertices[a]).cross(_vertices[c] - _vertices[a])
	# Godot's front faces are clockwise seen from the side they face.
	var towards := _normals[a] + _normals[b] + _normals[c]
	_indices.append_array([a, b, c] if face.dot(towards) < 0.0 else [a, c, b])


## Adds the face of four vertices in order around it.
func quad(a: int, b: int, c: int, d: int) -> void:
	triangle(a, b, c)
	triangle(a, c, d)


func arrays() -> Array:
	var mesh := []
	mesh.resize(Mesh.ARRAY_MAX)
	mesh[Mesh.ARRAY_VERTEX] = _vertices
	mesh[Mesh.ARRAY_NORMAL] = _normals
	mesh[Mesh.ARRAY_TANGENT] = _tangents
	mesh[Mesh.ARRAY_TEX_UV] = _uvs
	mesh[Mesh.ARRAY_COLOR] = _colours
	mesh[Mesh.ARRAY_INDEX] = _indices
	return mesh
