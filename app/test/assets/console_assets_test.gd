# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The shipped consoles as models: what their meshes and moving parts must be whichever console it is. Asset checks, run
## when a console folder or the data changes and before a release (scripts/test_godot.sh), not on every run.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const MM := Fixtures.MM
## The least area, in square millimetres, of a face that is one.
const MIN_AREA_MM2 := 1.0e-6
## The moving parts of the bench models that stand out at rest, as supplied: the SP's screen stands open and the PS2
## tray's bezel stands proud.
const STANDING_OUT: Array[String] = ["gba_sp: lid", "ps2_fat: tray"]
## At least this share of a glb mesh's triangles face the way the vertex normals say.
const WINDING_AGREES := 0.98
## The side of the grid's squares a medium's way in is checked by, in millimetres.
const _CELL_MM := 4.0


func test_every_medium_a_console_s_platform_declares_comes_down_its_way_in_clear_of_its_parts() -> void:
	var appearance := Appearance.read(APPEARANCE)
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		add_child(model)
		var media := Fixtures.platform(manifest.platform).media
		for medium in Fixtures.media(manifest.platform):
			var shown: Node3D = auto_free(appearance.model_of(medium, media).instantiate())
			var box := appearance.medium_box(medium, media)
			_assert_moving_parts_fit(model, box)
			_assert_medium_clear(model, shown, box)


func test_a_glb_console_s_meshes_never_degenerate_and_their_winding_agrees_with_their_normals() -> void:
	var checked := 0
	for manifest in ConsoleManifest.found():
		var model: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		if not Fixtures.is_glb(model):
			continue
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var arrays := geometry.mesh.surface_get_arrays(0)
			var meshes: Array[Array] = [arrays]
			var label := "%s: %s" % [ConsoleManifest.folder_of(manifest), geometry.name]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var agreeing := 0
			for point in points:
				assert_bool(is_finite(point.x) and is_finite(point.y) and is_finite(point.z)).override_failure_message(
					"%s: a point is not a number" % label).is_true()
			for t in range(0, corners.size(), 3):
				var facing := Fixtures.face_normal(points[corners[t]], points[corners[t + 1]], points[corners[t + 2]])
				assert_float(facing.length() / (MM * MM)).override_failure_message("%s: a degenerate face" % label) \
					.is_greater(MIN_AREA_MM2)
				var told := normals[corners[t]] + normals[corners[t + 1]] + normals[corners[t + 2]]
				agreeing += 1 if facing.dot(told) > 0.0 else 0
			assert_float(agreeing / (corners.size() / 3.0)).override_failure_message(
				"%s: its winding disagrees with its normals" % label).is_greater_equal(WINDING_AGREES)
			if geometry.name == &"body":
				var volume := 0.0
				for piece in Fixtures.volumes(meshes):
					volume += piece
				assert_float(volume).override_failure_message("%s: its volume is not positive" % label).is_greater(0.0)
			checked += 1
	assert_int(checked).is_greater(10)


## Each opening of [param model] (a flap is one) moves a part; at rest, every part an opening moves
## lies within the bounds of the rest of the console, and any other part that moves stands out of
## them by [constant ConsoleModel.PROUD_MM] at most. All its openings open at once: a part whose
## opening moves the seat carries the medium, and still holds the seat; no other part an opening
## moves meets a medium filling [param medium] (in the seat's frame) on its way in, from the seat to
## as far as the placeholder lifts it.
func _assert_moving_parts_fit(model: ConsoleModel, medium: AABB) -> void:
	var parts := model.moving_parts()
	var openings: Array[ConsolePart] = []
	openings.assign(parts.filter(func(part: ConsolePart) -> bool:
		return part.role in [ConsolePart.Role.OPENING, ConsolePart.Role.FLAP]))
	var resting := _boxes(model)
	var seat := model.seat()
	var moving: Dictionary[MeshInstance3D, bool] = {}
	# The meshes the openings move, and whether each carries the medium.
	var opened_by: Dictionary[MeshInstance3D, bool] = {}
	for part in parts:
		model.set(part.property, part.open)
		var opened := _boxes(model)
		var moved := _moved(resting, opened)
		if part in openings:
			assert_array(moved).override_failure_message("%s opens nothing" % part.property).is_not_empty()
			var carries := not moved.is_empty() and not model.seat().is_equal_approx(seat)
			if carries:
				var holder := opened[moved[0]]
				for geometry in moved:
					holder = holder.merge(opened[geometry])
				assert_bool(holder.grow(MM).has_point(model.seat().origin)).override_failure_message(
					"%s carries the seat away from it" % part.property).is_true()
			for geometry in moved:
				opened_by[geometry] = carries
		for geometry in moved:
			moving[geometry] = true
		model.set(part.property, part.rest)
	var body := AABB()
	for geometry in resting:
		if geometry not in moving:
			body = resting[geometry] if body.size == Vector3.ZERO else body.merge(resting[geometry])
	for geometry in moving:
		if "%s: %s" % [model.scene_file_path.get_base_dir().get_file(), geometry.name] in STANDING_OUT:
			continue
		var proud := 0.5 if geometry in opened_by else ConsoleModel.PROUD_MM
		assert_bool(body.grow(proud * MM).encloses(resting[geometry])).override_failure_message(
			"%s sticks out at rest" % geometry.name).is_true()
	for part in openings:
		model.set(part.property, part.open)
	# In millimetres, as all that is crossed: in world units, a small triangle seems flat.
	var to_seat := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * model.seat().affine_inverse() \
		* model.global_transform.affine_inverse()
	var reach := LaunchAnimation.lift(model.approach(), medium) / MM
	var sized := AABB(medium.position / MM, medium.size / MM).grow(-0.5)
	var way := sized.merge(Transform3D(Basis(), model.approach() * reach) * sized)
	for geometry in opened_by:
		if not opened_by[geometry]:
			assert_bool(Fixtures.meets(_triangles(geometry, to_seat, way), way)).override_failure_message(
				"%s is in the way in once open" % geometry.name).is_false()
	for part in openings:
		model.set(part.property, part.rest)


## Every vertex of [param medium]'s model (filling [param box] on the seat, at its real size), brought
## half a millimetre into it, comes from the seat of [param model], its openings open, along its way
## in, as far as the placeholder lifts it, through none of the parts that never move but those it
## lies in, drawn solid ([member SeatShape.housings]): the console's body leaves its way in open.
func _assert_medium_clear(model: ConsoleModel, medium: Node3D, box: AABB) -> void:
	# Each point once, its faces' normals summed: brought in along them, a corner goes in from each face.
	var points: Dictionary[Vector3i, Vector3] = {}
	var normals: Dictionary[Vector3i, Vector3] = {}
	for part: MeshInstance3D in medium.find_children("*", "MeshInstance3D", false, false):
		var placed := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * part.transform
		var arrays := part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var faces: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var key := Vector3i((placed * vertices[i] * 100.0).round())
			points[key] = placed * vertices[i]
			normals[key] = normals.get(key, Vector3.ZERO) + (placed.basis * faces[i]).normalized()
	var openings := model.moving_parts().filter(func(part: ConsolePart) -> bool:
		return part.role in [ConsolePart.Role.OPENING, ConsolePart.Role.FLAP])
	var still := _still(model).filter(func(geometry: MeshInstance3D) -> bool:
		return geometry.name not in model.shape.housings)
	for part: ConsolePart in openings:
		model.set(part.property, part.open)
	var axis := model.approach()
	var reach := axis * LaunchAnimation.lift(axis, box) / MM
	var sized := AABB(box.position / MM, box.size / MM)
	var to_seat := Transform3D.IDENTITY.scaled(Vector3.ONE / MM) * model.seat().affine_inverse() \
		* model.global_transform.affine_inverse()
	var walls := PackedVector3Array()
	var names := PackedStringArray()
	for geometry: MeshInstance3D in still:
		var found := _triangles(geometry, to_seat, sized.merge(Transform3D(Basis(), reach) * sized).grow(1.0))
		walls.append_array(found)
		for _corner in found:
			names.append(geometry.name)
	for part: ConsolePart in openings:
		model.set(part.property, part.rest)
	# Each wall listed under the squares of a grid across the way in that it lies over: a point is
	# checked against those over its square only.
	var across := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
	var square := func(point: Vector3) -> Vector2i:
		return Vector2i(floori(point.dot(across) / _CELL_MM), floori(point.dot(axis.cross(across)) / _CELL_MM))
	var over: Dictionary[Vector2i, PackedInt32Array] = {}
	for i in range(0, walls.size(), 3):
		var low: Vector2i = square.call(walls[i])
		var high := low
		for corner: Vector3 in [walls[i + 1], walls[i + 2]]:
			var at: Vector2i = square.call(corner)
			low = low.min(at)
			high = high.max(at)
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				if not over.has(Vector2i(x, y)):
					over[Vector2i(x, y)] = PackedInt32Array()
				over[Vector2i(x, y)].append(i)
	for key in points:
		var from := points[key] - normals[key].normalized() * 0.5
		var near: PackedInt32Array = over.get(square.call(from), PackedInt32Array())
		for i in near:
			if Geometry3D.segment_intersects_triangle(from, from + reach, walls[i], walls[i + 1], walls[i + 2]) != null:
				assert_bool(false).override_failure_message("%s: %s goes through its %s from %s" % [model.name,
					medium.name, names[i], from]).is_true()
				return


## The meshes of [param model] that none of its moving parts moves.
static func _still(model: ConsoleModel) -> Array[MeshInstance3D]:
	var resting := _boxes(model)
	var still: Array[MeshInstance3D] = []
	still.assign(resting.keys())
	for part in model.moving_parts():
		model.set(part.property, part.open)
		for geometry in _moved(resting, _boxes(model)):
			still.erase(geometry)
		model.set(part.property, part.rest)
	return still


## The meshes whose box moved from [param resting] to [param moved].
static func _moved(resting: Dictionary[MeshInstance3D, AABB],
		moved: Dictionary[MeshInstance3D, AABB]) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	found.assign(resting.keys().filter(func(geometry: MeshInstance3D) -> bool:
		return not moved[geometry].is_equal_approx(resting[geometry])))
	return found


## Where each mesh of [param model] stands, in the model's space.
static func _boxes(model: ConsoleModel) -> Dictionary[MeshInstance3D, AABB]:
	var found: Dictionary[MeshInstance3D, AABB] = {}
	var to_model := model.global_transform.affine_inverse()
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		found[geometry] = to_model * geometry.global_transform * geometry.get_aabb()
	return found


## The corners of [param geometry]'s triangles, three by three, placed by [param to] from the world;
## only those of triangles meeting [param within], when given.
static func _triangles(geometry: MeshInstance3D, to: Transform3D, within := AABB()) -> PackedVector3Array:
	var found := PackedVector3Array()
	var placed := to * geometry.global_transform
	for surface in geometry.mesh.get_surface_count():
		for corners in Fixtures.triangles(geometry.mesh.surface_get_arrays(surface)):
			var triangle := placed * corners
			var box := AABB(triangle[0], Vector3.ZERO).expand(triangle[1]).expand(triangle[2])
			if within.size == Vector3.ZERO or within.intersects(box):
				found.append_array(triangle)
	return found
