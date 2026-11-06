# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## The design's table, a snapshot of twelve consoles measured on it: each folder's silhouette box (x0, y0, x1, y1 as
## fractions of a 4:3 picture) and its weight, in its order. The code's weights ([method RingFit.weight_of]) must agree.
const _DESIGN: Dictionary[String, Array] = {
	"ps2_slim": [Vector4(.256, .298, .808, .674), 1.0], "psx": [Vector4(.224, .283, .840, .802), 1.065],
	"nes": [Vector4(.224, .314, .834, .698), 1.090], "snes": [Vector4(.259, .275, .826, .729), 0.996],
	"n64": [Vector4(.256, .302, .837, .744), 1.016], "gc": [Vector4(.323, .240, .706, .775), 1.142],
	"wii": [Vector4(.334, .217, .640, .779), 1.278], "xbox": [Vector4(.250, .225, .840, .760), 1.373],
	"xbox360": [Vector4(.401, .213, .605, .806), 1.663], "gb": [Vector4(.390, .271, .648, .760), 0.880],
	"gbc": [Vector4(.392, .275, .642, .725), 0.822], "gba": [Vector4(.241, .295, .785, .702), 0.566],
}
var _folders: Array[String] = Array(_DESIGN.keys(), TYPE_STRING, &"", null)
## The window the suites share is put back as it was: some tests of other folders measure in its size.
var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size


func after_test() -> void:
	get_window().size = _window


func _box(shape: int) -> Rect2:
	var edges: Vector4 = _DESIGN[_folders[shape]][0]
	return Rect2(edges.x, edges.y, edges.z - edges.x, edges.w - edges.y)


## The fit of [param shapes] (indices of the table) at even angles in that order.
func _fit(shapes: Array[int]) -> float:
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	var angles := PackedFloat64Array()
	for k in shapes.size():
		boxes.append(_box(shapes[k]))
		weights.append(RingFit.weight_of(_folders[shapes[k]]))
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
		var weight: float = _DESIGN[_folders[shapes[k]]][1]
		var across := size * weight * (1.0 + 0.045 * cos(angle)) * 12.8 * 1.06
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


func test_no_two_boxes_overlap_and_the_room_is_kept_for_any_count_and_order() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 12
	var tight := 0
	for draw in 60:
		var shapes: Array[int] = []
		shapes.assign(range(_DESIGN.size()))
		for i in range(_DESIGN.size() - 1, 0, -1):
			shapes.insert(random.randi_range(0, i), shapes.pop_back())
		shapes = shapes.slice(0, random.randi_range(2, _DESIGN.size()))
		var size := _fit(shapes)
		var gap := _least_gap(_on_screen(shapes, size))
		# The room is kept, as the box grows by the pointed growth: grown boxes stand 15.36 px apart.
		assert_float(gap).override_failure_message("draw %d %s: gap %f at %f" % [draw, shapes, gap, size]).is_greater_equal(15.36 - 0.1)
		# And it is the largest scale: a hair more and some pair has less room.
		if size < RingFit.WIDEST / _box(0).size.x - 1e-6:
			assert_float(_least_gap(_on_screen(shapes, size * 1.003))).is_less(15.36)
			tight += 1
	assert_int(tight).is_greater(5)


func test_one_or_two_consoles_stand_at_the_cap() -> void:
	var cap := RingFit.WIDEST / _box(0).size.x
	for picked: Array in [[0], [8], [5, 8], [0, 1]]:
		var shapes: Array[int] = []
		shapes.assign(picked)
		assert_float(_fit(shapes)).is_equal_approx(cap, 1e-5)


func test_one_console_has_no_room_to_keep() -> void:
	var one: Array[int] = [3]
	assert_float(_fit(one)).is_equal_approx(RingFit.WIDEST / _box(0).size.x, 1e-5)
	assert_float(RingFit.least_room([_box(3)], PackedFloat64Array([1.0]), PackedFloat64Array([0.0]), 10.0)).is_equal(INF)
