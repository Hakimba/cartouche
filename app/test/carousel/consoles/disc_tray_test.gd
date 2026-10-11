# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The disc drive's tray the Xboxes share: a disc lies in its recess on the hub's clamp ring, the
## cone through its hole, nothing of the tray above its underside; the opening's lip leaves the tray
## its way out; and the trays a disc cannot lie in are refused.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const MM := MeshBuilder.UNITS_PER_MM
const EPSILON := 0.001
## A DVD's hole and thickness.
const HOLE := 7.5
const THICKNESS := 1.2


func test_a_disc_lies_in_its_recess_on_the_clamp_ring_the_cone_through_its_hole() -> void:
	var random := Fixtures.cases(120)
	var found := 0
	while found < 40:
		var tray := _drawn(random)
		var area: Rect2 = tray[0]
		var levels: Vector2 = tray[1]
		var centre: Vector2 = tray[2]
		var radius: float = tray[3]
		if not DiscTray.fits(area, levels, centre, radius):
			continue
		found += 1
		var steps := random.randi_range(3, 8)
		var under := DiscTray.floor_level(levels.y)
		var plate := _points(func(mesh: MeshBuilder) -> void: DiscTray.plate(mesh, area, levels, centre, radius, steps))
		var tops := 0
		for point in plate:
			if Vector2(point.x, point.y).distance_to(centre) < radius:
				assert_float(point.z).override_failure_message("the tray at %s under the disc" % point) \
					.is_less_equal(under + EPSILON)
			tops += 1 if is_equal_approx(point.z, levels.y) else 0
		assert_int(tops).is_greater(0)
		assert_float(under).is_equal_approx(levels.y - DiscTray.RECESS_DEPTH, EPSILON)
		var ring := Fixtures.bounds(_points(func(mesh: MeshBuilder) -> void:
			DiscTray.clamp_ring(mesh, centre, levels.y, steps)))
		assert_float(ring.end.z).is_equal_approx(under, EPSILON)
		var cone := _points(func(mesh: MeshBuilder) -> void: DiscTray.hub(mesh, centre, levels, steps))
		assert_float(Fixtures.bounds(cone).end.z).is_greater(under + THICKNESS)
		for point in cone:
			if point.z > under:
				assert_float(Vector2(point.x, point.y).distance_to(centre)).is_less(HOLE)


func test_the_lip_round_the_opening_leaves_the_tray_and_the_hub_room_to_go_through() -> void:
	var random := Fixtures.cases(121)
	for _case in 40:
		var mouth := Rect2(random.randf_range(-150.0, 0.0), random.randf_range(30.0, 60.0),
			random.randf_range(130.0, 160.0), random.randf_range(12.0, 20.0))
		var tray := Rect2(mouth.position.x + random.randf_range(1.0, 3.0), mouth.position.y + random.randf_range(1.0, 2.0),
			mouth.size.x - random.randf_range(4.0, 6.0), random.randf_range(3.0, 5.0))
		var front := random.randf_range(50.0, 150.0)
		var points := _points(func(mesh: MeshBuilder) -> void:
			DiscTray.opening(mesh, ShapeGeometry.square(mouth), tray, front, front - 140.0))
		var lip := false
		var room := Rect2(tray.position.x, mouth.position.y, tray.size.x, tray.end.y + DiscTray.LIP_ROOM - mouth.position.y)
		for point in points:
			assert_bool(room.grow(-EPSILON).has_point(Vector2(point.x, point.y))) \
				.override_failure_message("the opening in the tray's way at %s" % point).is_false()
			lip = lip or is_equal_approx(point.z, front - DiscTray.LIP)
		assert_bool(lip).is_true()


func test_a_tray_too_thin_too_narrow_or_too_small_for_its_window_is_refused() -> void:
	var random := Fixtures.cases(122)
	var found := 0
	while found < 40:
		var tray := _drawn(random)
		var area: Rect2 = tray[0]
		var levels: Vector2 = tray[1]
		var centre: Vector2 = tray[2]
		var radius: float = tray[3]
		if not DiscTray.fits(area, levels, centre, radius):
			continue
		found += 1
		var thin := Vector2(levels.x, levels.x + DiscTray.RAIL.y + DiscTray.RECESS_DEPTH + DiscTray.STEP_DEPTH)
		assert_bool(DiscTray.fits(area, thin, centre, radius)).is_false()
		# Its left side at the disc's edge.
		var narrow := Rect2(centre.x - radius, area.position.y, area.end.x - centre.x + radius, area.size.y)
		assert_bool(DiscTray.fits(narrow, levels, centre, radius)).is_false()
		assert_bool(DiscTray.fits(area, levels, centre, DiscTray.WINDOW_RADIUS / DiscTray.STEP_SHARE)).is_false()


## A tray drawn by [param random], often one a disc fits: its plate, its foot and top, the disc's
## centre and radius.
static func _drawn(random: RandomNumberGenerator) -> Array:
	var radius := random.randf_range(30.0, 80.0)
	var area := Rect2(random.randf_range(-100.0, 100.0), random.randf_range(-100.0, 100.0),
		2.0 * radius + random.randf_range(2.0, 12.0), 2.0 * radius + random.randf_range(5.0, 30.0))
	var centre := Vector2(area.get_center().x, area.position.y + random.randf_range(1.0, 5.0) + radius)
	var foot := random.randf_range(0.0, 60.0)
	return [area, Vector2(foot, foot + random.randf_range(3.0, 6.0)), centre, radius]


## The points [param build] adds to a mesh, in millimetres.
static func _points(build: Callable) -> PackedVector3Array:
	var mesh := MeshBuilder.new()
	build.call(mesh)
	var found := PackedVector3Array()
	for point in Fixtures.points(mesh.arrays()):
		found.append(point / MM)
	return found
