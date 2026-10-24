# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## The window the suites share is put back as it was: some tests of other folders measure in its size.
var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size


func after_test() -> void:
	get_window().size = _window


## The twelve silhouette boxes of the design's table (x0, y0, x1, y1 as fractions of a 4:3 picture), in its order.
const FOLDERS: Array[String] = ["ps2_slim", "psx", "nes", "snes", "n64", "gc", "wii", "xbox", "xbox360", "gb", "gbc", "gba"]
const _EDGES: Array[Vector4] = [Vector4(.256, .298, .808, .674), Vector4(.224, .283, .840, .802),
	Vector4(.224, .314, .834, .698), Vector4(.259, .275, .826, .729), Vector4(.256, .302, .837, .744),
	Vector4(.323, .240, .706, .775), Vector4(.334, .217, .640, .779), Vector4(.250, .225, .840, .760),
	Vector4(.401, .213, .605, .806), Vector4(.390, .271, .648, .760), Vector4(.392, .275, .642, .725),
	Vector4(.241, .295, .785, .702)]
## The weights of the same table.
const _WEIGHTS: Array[float] = [1.0, 1.065, 1.090, 0.996, 1.016, 1.142, 1.278, 1.373, 1.663, 0.880, 0.822, 0.566]


func _box(shape: int) -> Rect2:
	var edges := _EDGES[shape]
	return Rect2(edges.x, edges.y, edges.z - edges.x, edges.w - edges.y)


## The fit of [param shapes] (indices of the table) at even angles in that order.
func _fit(shapes: Array[int]) -> float:
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	var angles := PackedFloat64Array()
	for k in shapes.size():
		boxes.append(_box(shapes[k]))
		weights.append(RingFit.weight_of(FOLDERS[shapes[k]]))
		angles.append(k * TAU / shapes.size())
	return RingFit.scale(boxes, weights, angles, RingFit.WIDEST / _box(0).size.x)


## The boxes of [param shapes] on the screen at the scale [param size], in px, each grown as the ring grows its
## pointed console: laid out from the table's own weights (not the code's) and read back through a camera, the way the
## app's models are, in a window of the design's size.
func _on_screen(shapes: Array[int], size: float) -> Array[Rect2]:
	get_window().size = Vector2i(1280, 960)
	var camera: Camera3D = auto_free(Camera3D.new())
	camera.fov = 32.0
	add_child(camera)
	camera.position = Vector3(0.0, 0.1, 3.7)
	var rects: Array[Rect2] = []
	for k in shapes.size():
		var angle := k * TAU / shapes.size()
		var at := Vector2(640.0 + 390.4 * sin(angle), 471.04 + 325.12 * cos(angle))
		var across := size * _WEIGHTS[shapes[k]] * (1.0 + 0.045 * cos(angle)) * 12.8 * 1.06
		var box := _box(shapes[k])
		var half := Vector2(box.size.x * across, box.size.y * across * 0.75) / 2.0
		var low := camera.unproject_position(camera.project_position(at - half, 4.0))
		var high := camera.unproject_position(camera.project_position(at + half, 4.0))
		rects.append(Rect2(low, high - low))
	return rects


## The least gap in px between two of the rects: negative when two overlap.
func _least_gap(rects: Array[Rect2]) -> float:
	var least := INF
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var across := maxf(rects[j].position.x - rects[i].end.x, rects[i].position.x - rects[j].end.x)
			var down := maxf(rects[j].position.y - rects[i].end.y, rects[i].position.y - rects[j].end.y)
			least = minf(least, maxf(across, down))
	return least


func test_the_twelve_in_the_default_order_stand_on_the_design_s_scale() -> void:
	var all: Array[int] = []
	all.assign(range(12))
	var size := _fit(all)
	assert_float(size).is_equal_approx(16.95, 0.02)
	assert_float(_on_screen(all, size)[0].size.x / 1.06).is_equal_approx(125.18, 0.2)


func test_INV_E12_S4_01_no_two_boxes_overlap_and_the_room_is_kept_for_any_count_and_order() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 12
	var tight := 0
	for draw in 300:
		var shapes: Array[int] = []
		shapes.assign(range(12))
		for i in range(11, 0, -1):
			shapes.insert(random.randi_range(0, i), shapes.pop_back())
		shapes = shapes.slice(0, random.randi_range(2, 12))
		var size := _fit(shapes)
		var gap := _least_gap(_on_screen(shapes, size))
		# The room is kept, as the box grows by the pointed growth: grown boxes stand 15.36 px apart.
		assert_float(gap).override_failure_message("draw %d %s: gap %f at %f" % [draw, shapes, gap, size]).is_greater_equal(15.36 - 0.1)
		# And it is the largest scale: a hair more and some pair has less room.
		if size < RingFit.WIDEST / _box(0).size.x - 1e-6:
			assert_float(_least_gap(_on_screen(shapes, size * 1.003))).is_less(15.36)
			tight += 1
	assert_int(tight).is_greater(30)


func test_one_or_two_consoles_stand_at_the_cap() -> void:
	var cap := RingFit.WIDEST / _box(0).size.x
	for picked: Array in [[0], [8], [5, 8], [0, 1]]:
		var shapes: Array[int] = []
		shapes.assign(picked)
		assert_float(_fit(shapes)).is_equal_approx(cap, 1e-5)
	assert_float(cap).is_equal_approx(12.5 / 0.552, 1e-5)


func test_one_console_has_no_room_to_keep_and_least_room_is_the_gap_two_boxes_leave() -> void:
	var one: Array[int] = [3]
	assert_float(_fit(one)).is_equal_approx(RingFit.WIDEST / _box(0).size.x, 1e-5)
	assert_float(RingFit.least_room([_box(3)], PackedFloat64Array([1.0]), PackedFloat64Array([0.0]), 10.0)).is_equal(INF)
	# Two PS2 boxes at the bottom and the top, 16.95 wide: the vertical gap less the grown halves.
	var boxes: Array[Rect2] = [_box(0), _box(0)]
	var weights := PackedFloat64Array([1.0, 1.0])
	var angles := PackedFloat64Array([0.0, PI])
	var tall := 0.376 * 0.75 * 16.95 * 1.06
	var gap := ((325.12 * 2.0) / 12.8 - tall * (1.045 + 0.955) / 2.0) * 12.8
	assert_float(RingFit.least_room(boxes, weights, angles, 16.95)).is_equal_approx(gap, 0.05)


func test_the_ring_s_places_and_the_reach_to_a_box_edge() -> void:
	assert_vector(RingFit.place(0.0)).is_equal_approx(Vector2(640.0, 796.16), Vector2(1e-3, 1e-3))
	assert_vector(RingFit.place(PI / 2.0)).is_equal_approx(Vector2(1030.4, 471.04), Vector2(1e-3, 1e-3))
	assert_vector(RingFit.place(PI)).is_equal_approx(Vector2(640.0, 145.92), Vector2(1e-3, 1e-3))
	# The PS2 at the bottom, 16.95 wide: its box 16.95 × 1.045 × 1.06 × .376 × .75 cqw tall, half of it.
	var reach := 16.95 * 1.045 * 1.06 * 0.376 * 0.75 / 2.0 * 12.8
	assert_float(RingFit.ext(RingFit.PS2_BOX, 1.0, 16.95, 0.0)).is_equal_approx(reach, 0.01)
	# On the left it is the box's width that is reached: the radial is horizontal.
	var across := 16.95 * 1.065 * (1.0 - 0.0) * 1.06 * 0.616 / 2.0 * 12.8
	assert_float(RingFit.ext(_box(1), 1.065, 16.95, 1.5 * PI)).is_equal_approx(across, 0.01)


func test_each_console_weighs_its_real_size_against_the_ps2() -> void:
	for k in FOLDERS.size():
		assert_float(RingFit.weight_of(FOLDERS[k])).override_failure_message(FOLDERS[k]).is_equal_approx(_WEIGHTS[k], 0.0015)
	assert_float(RingFit.weight_of("unknown")).is_equal(1.0)
