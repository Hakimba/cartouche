# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscGeometry
extends RefCounted
## Builds a disc from its [DiscShape] as pure functions, so that tests check the geometry headless.
## Each part is made of profiles, lines of (radius, height) points in millimetres, turned around
## the disc's axis (Z, the label facing +Z). A profile's surface faces left of the way it is
## traced: outwards on top, inwards underneath.

## Points on the slope of the stacking ring, each side.
const _RING_STEPS := 4
## Points on the rounded outer edge.
const _EDGE_STEPS := 8

const PARTS: Array[StringName] = [&"label", &"mirror", &"shell"]


## The profiles of [param part] of [param shape]: the label on top, the mirror underneath, and the
## clear plastic around them (hub, hole, rim and edge); none for a part it does not have.
static func profiles(shape: DiscShape, part: StringName) -> Array[PackedVector2Array]:
	var top := shape.thickness / 2.0
	match part:
		&"label":
			return [PackedVector2Array([Vector2(shape.label_inner, top), Vector2(shape.label_outer, top)])]
		&"mirror":
			var radii := PackedFloat32Array([
				shape.mirror_outer, shape.data_outer, shape.data_inner, shape.mirror_inner])
			var bands: Array[PackedVector2Array] = []
			for i in 3:
				bands.append(PackedVector2Array([Vector2(radii[i], -top), Vector2(radii[i + 1], -top)]))
			return bands
		&"shell":
			var edge := shape.radius - top
			var rim := PackedVector2Array([Vector2(shape.label_outer, top)])
			for step in _EDGE_STEPS + 1:
				rim.append(Vector2(edge, 0.0) + Vector2.from_angle(PI / 2.0 - PI * step / _EDGE_STEPS) * top)
			rim.append(Vector2(shape.mirror_outer, -top))
			var hub_top := _with_ring(shape, top, 1.0)
			hub_top.append(Vector2(shape.label_inner, top))
			var hub_bottom := _with_ring(shape, -top, -1.0)
			hub_bottom.append(Vector2(shape.mirror_inner, -top))
			hub_bottom.reverse()
			var hole := PackedVector2Array([Vector2(shape.hole, -top), Vector2(shape.hole, top)])
			return [rim, hub_top, hub_bottom, hole]
	return []


## The mesh arrays of [param part], turned in [param segments] steps; none when [param shape] has
## [method DiscShape.problems], no such part, or fewer than 3 steps. The vertex colour's red is 1
## on the recorded area, its green on the rim beyond the label, 0 elsewhere.
static func arrays(shape: DiscShape, part: StringName, segments: int) -> Array:
	if not shape.problems().is_empty() or part not in PARTS or segments < 3:
		return []
	var mesh := MeshBuilder.new()
	for profile in profiles(shape, part):
		var bends := _normals(profile)
		var middle := (profile[0].x + profile[-1].x) / 2.0
		var recorded := 1.0 if middle > shape.data_inner and middle < shape.data_outer else 0.0
		var beyond_label := func(point: Vector2) -> bool: return point.x > shape.label_outer
		var rim := part == &"shell" and Array(profile).any(beyond_label)
		var marks := Color(recorded, 1.0 if rim else 0.0, 0.0)
		var rings: Array[PackedInt32Array] = []
		for step in segments + 1:
			var turn := Vector2.from_angle(TAU * step / segments)
			var ring := PackedInt32Array()
			for i in profile.size():
				var point := Vector3(turn.x * profile[i].x, turn.y * profile[i].x, profile[i].y)
				var uv := Vector2(0.5, 0.5) + Vector2(point.x, -point.y) / (2.0 * shape.radius)
				var normal := Vector3(turn.x * bends[i].x, turn.y * bends[i].x, bends[i].y)
				ring.append(mesh.add(point, normal, uv, Vector3(-turn.y, turn.x, 0.0), marks))
			rings.append(ring)
		for step in segments:
			for i in profile.size() - 1:
				mesh.quad(rings[step][i], rings[step][i + 1], rings[step + 1][i + 1], rings[step + 1][i])
	return mesh.arrays()


## The hub from the hole to the far side of the stacking ring, at [param height], the ring rising
## towards [param side] (1 up, -1 down).
static func _with_ring(shape: DiscShape, height: float, side: float) -> PackedVector2Array:
	var line := PackedVector2Array([Vector2(shape.hole, height)])
	for step in 2 * _RING_STEPS + 1:
		var along := float(step) / (2 * _RING_STEPS)
		var rise := (1.0 - cos(TAU * along)) / 2.0 * shape.ring_height
		line.append(Vector2(shape.ring + (along - 0.5) * shape.ring_width, height + side * rise))
	return line


## Each point's normal: left of the way the profile goes, averaged with its neighbours' at a bend.
static func _normals(profile: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in profile.size():
		var along := profile[mini(i + 1, profile.size() - 1)] - profile[maxi(i - 1, 0)]
		found.append(-along.orthogonal().normalized())
	return found

