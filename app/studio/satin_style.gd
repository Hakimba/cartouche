# SPDX-License-Identifier: GPL-3.0-or-later
class_name SatinStyle
extends StyleBox
## A Studio material ([StudioMaterial]) as a StyleBox, for Godot's own controls: buttons, fields, cards. A
## control draws its StyleBox into its own canvas item, where no shader can go, so the material is drawn here as
## polygons: the fill as a gradient over the box's outline (exact for a fill from top to bottom), a hard inset
## highlight as the box less the box moved by its offset, and each outer shadow as rings outside the box whose
## colours follow its Gaussian falloff; CSS draws no outer shadow under the box, nor do these rings. Each box size
## is built once.

## Points on each quarter of a corner.
const _ARC := 8
## Antialiasing: every edge fades over a pixel, as StyleBoxFlat's do.
const _FEATHER := 1.0
## One style dresses every control of a theme type, each size built once: past this many, it starts over.
const _SIZES_KEPT := 32

@export var look := StudioTokens.Look.SATIN:
	set(value):
		look = value
		_material = StudioMaterial.new(value)
		_built.clear()
		emit_changed()
## The colour of the shadows that take the gel (the focus ring and its glow).
var gel := StudioTokens.NEUTRAL:
	set(value):
		gel = value
		_built.clear()
		emit_changed()

var _material := StudioMaterial.new(StudioTokens.Look.SATIN)
## The triangles of each box size drawn so far.
var _built: Dictionary[Vector2, Mesh2D] = {}


## The same satin normal states and gel focus on a native button.
static func apply_to(button: Button, color := StudioTokens.NEUTRAL) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := SatinStyle.new()
		style.look = StudioTokens.Look.FOCUS if state == &"focus" else StudioTokens.Look.SATIN
		style.gel = color
		button.add_theme_stylebox_override(state, style)


## Triangles with a colour at each point.
class Mesh2D:
	extends RefCounted

	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(point: Vector2, color: Color) -> void:
		points.append(point)
		colors.append(color)

	func add_all(added: PackedVector2Array, color: Color) -> void:
		for point in added:
			add(point, color)

	## Triangles between the [param count] points from [param start] and the [param count] after them.
	func join(start: int, count: int) -> void:
		for i in count:
			var j := (i + 1) % count
			indices.append_array([start + i, start + j, start + count + i, start + j, start + count + j, start + count + i])


## A closed outline and each point's outward normal.
class Outline:
	extends RefCounted

	var points := PackedVector2Array()
	var normals := PackedVector2Array()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size not in _built:
		if _built.size() >= _SIZES_KEPT:
			_built.clear()
		_built[rect.size] = build(rect.size)
	var mesh := _built[rect.size]
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, rect.position))
	RenderingServer.canvas_item_add_triangle_array(to_canvas_item, mesh.indices, mesh.points, mesh.colors)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(_material.reach())


## The material on a box of [param size] at the origin, bottom layer first.
func build(size: Vector2) -> Mesh2D:
	var mesh := Mesh2D.new()
	var box := Rect2(Vector2.ZERO, size)
	for i in range(_material.shadows.size() - 1, -1, -1):
		var shadow := _material.shadows[i]
		if not shadow.inset:
			outer_shadow(mesh, box, shadow)
	_fill(mesh, box)
	for shadow in _material.shadows:
		if shadow.inset:
			# A hard highlight: the box less the box moved by the offset, over the fill (CSS clips it to the box).
			var lit := Rect2(box.position + shadow.offset.max(Vector2.ZERO), box.size - shadow.offset.abs())
			var start := mesh.points.size()
			var edge := _outline(box, 0.0).points
			mesh.add_all(edge + _outline(lit, 0.0).points, shadow.shown(gel))
			mesh.join(start, edge.size())
	return mesh


## A CSS outer shadow around [param box], outside it only: at a distance t past the box's edge along its normal
## n, the shadow's own edge lies spread + offset·n past the box's, and a Gaussian of standard deviation blur / 2
## leaves Φ((that − t) / σ) of its colour.
func outer_shadow(mesh: Mesh2D, box: Rect2, shadow: StudioMaterial.Shadow) -> void:
	var sigma := maxf(shadow.blur / 2.0, _FEATHER / 2.0)
	var color := shadow.shown(gel)
	var farthest := shadow.spread + shadow.offset.length() + 3.0 * sigma
	if farthest <= 0.0:
		return
	var steps := ceili(farthest / (sigma / 2.0))
	var previous := _outline(box, 0.0)
	var previous_t := 0.0
	for step in steps:
		var t := farthest * (step + 1) / steps
		var next := _outline(box, t)
		var start := mesh.points.size()
		_add_faded(mesh, previous, previous_t, shadow, color, sigma)
		_add_faded(mesh, next, t, shadow, color, sigma)
		mesh.join(start, previous.points.size())
		previous = next
		previous_t = t


## The points of [param outline], [param distance] past the box, in what [param shadow] leaves of [param color].
func _add_faded(mesh: Mesh2D, outline: Outline, distance: float, shadow: StudioMaterial.Shadow, color: Color,
		sigma: float) -> void:
	for i in outline.points.size():
		var left := _gaussian_cdf((shadow.spread + shadow.offset.dot(outline.normals[i]) - distance) / sigma)
		mesh.add(outline.points[i], Color(color, color.a * left))


## The box in the material's fill, its edge feathered.
func _fill(mesh: Mesh2D, box: Rect2) -> void:
	SatinStyle.fill_rounded(mesh, box, _material.radius, func(at: Vector2) -> Color: return _material.fill_at(at.y / box.size.y))


## [param box] rounded by [param corner], filled with [param color_at] (a colour by point), its edge feathered over
## [param feather] px across it, as a browser covers an edge (none for a box on whole pixels).
static func fill_rounded(mesh: Mesh2D, box: Rect2, corner: float, color_at: Callable, feather := _FEATHER) -> void:
	var inner := _rounded(box, -feather / 2.0, corner).points
	var outer := _rounded(box, feather / 2.0, corner).points
	var start := mesh.points.size()
	for point in inner:
		var color: Color = color_at.call(point)
		mesh.add(point, color)
	for i in inner.size():
		mesh.add(outer[i], Color(mesh.colors[start + i], 0.0))
	for i in range(1, inner.size() - 1):
		mesh.indices.append_array([start, start + i, start + i + 1])
	mesh.join(start, inner.size())


## The outline of [param box] grown by [param by], its corners rounded by the material's radius + by.
func _outline(box: Rect2, by: float) -> Outline:
	return _rounded(box, by, _material.radius)


## The outline of [param box] grown by [param by], its corners rounded by [param corner] + by.
static func _rounded(box: Rect2, by: float, corner: float) -> Outline:
	var radius := clampf(corner, 0.0, minf(box.size.x, box.size.y) / 2.0)
	var grown := box.grow(by)
	var round_by := maxf(radius + by, 0.0)
	var corners: Array[Vector2] = [Vector2(grown.end.x - round_by, grown.position.y + round_by),
		grown.end - Vector2.ONE * round_by, Vector2(grown.position.x + round_by, grown.end.y - round_by),
		grown.position + Vector2.ONE * round_by]
	var outline := Outline.new()
	for quarter in 4:
		for i in _ARC + 1:
			var normal := Vector2.from_angle(-PI / 2.0 + (quarter + float(i) / _ARC) * PI / 2.0)
			outline.points.append(corners[quarter] + normal * round_by)
			outline.normals.append(normal)
	return outline


## The standard normal distribution's cumulative function (Abramowitz and Stegun 7.1.26, within 1.5e-7).
static func _gaussian_cdf(x: float) -> float:
	var z := absf(x) / sqrt(2.0)
	var t := 1.0 / (1.0 + 0.3275911 * z)
	var erf := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z)
	return 0.5 * (1.0 + (erf if x >= 0.0 else -erf))
