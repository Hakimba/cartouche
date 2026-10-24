# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_INV_E12_04_each_medium_has_its_pill_20_48_pixels_under_its_lowest_projected_vertex() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1280, 960)
	add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.0, 0.1, 3.7)
	camera.fov = 32.0
	var media := MediumManifest.found()
	assert_int(media.size()).is_equal(15)
	for medium in media:
		var model := (load(media[medium].scene) as PackedScene).instantiate() as Node3D
		viewport.add_child(model)
		model.transform = TitlePlace.fitting(model) * model.transform
		var fitted := TitlePlace.vertices(model)
		assert_int(fitted.size()).is_greater(100)
		var box := AABB(fitted[0], Vector3.ZERO)
		for point in fitted:
			box = box.expand(point)
		assert_float(maxf(box.size.x, box.size.y)).is_equal_approx(1.2, 1e-4)
		assert_vector(box.get_center()).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-4)
		var chosen := GamesLayout.new(medium).chosen
		var predicted := TitlePlace.top(fitted, chosen)
		model.transform = chosen * model.transform
		var lowest := -INF
		var counted := 0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var corners: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in corners:
					lowest = maxf(lowest, camera.unproject_position(mesh.global_transform * vertex).y)
					counted += corners.size()
		assert_int(counted).is_greater(100)
		assert_float(predicted).override_failure_message(medium).is_equal_approx(lowest + 20.48, 1.0)
		model.free()


func test_projection_keeps_nested_mesh_transforms_and_the_gap_scales_with_the_frame() -> void:
	var model := Node3D.new()
	var pivot := Node3D.new()
	pivot.position = Vector3(0.2, -0.3, 0.1)
	model.add_child(pivot)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(-0.1, 0.1, 0.2)
	pivot.add_child(mesh)
	model.position = Vector3(0.1, 0.2, 0.0)
	var points := TitlePlace.vertices(model)
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	assert_vector(box.get_center()).is_equal_approx(Vector3(0.2, 0.0, 0.3), Vector3.ONE * 1e-5)
	var top := TitlePlace.top(points, Transform3D.IDENTITY)
	assert_float(TitlePlace.top(points, Transform3D.IDENTITY, TitlePlace.CAMERA, Vector2(640, 480))).is_equal_approx(top / 2.0, 1e-5)
	model.free()
