# SPDX-License-Identifier: GPL-3.0-or-later
class_name Cyclorama
extends Control
## The backdrop of every screen, as the backdrop shown ([member Backdrop.palette]) draws its wall: a small lit photo
## studio (the paper wall curving into the floor and its vignette are one baked picture; over it, in one shader,
## the key light and the floor's pool of light, without the console's colour); that studio's shape in another
## wall's colours, with no light of its own; or black.
## Over it, while [member Backdrop.veil], the pixel veil drifts in the backdrop's veil colours, or in the staged
## console's gel while [member Backdrop.veil_gel], matched to the wall: the
## one thing drawn again while the app rests. Otherwise nothing moves, so nothing is drawn again. Of the backdrops drawn
## full size (not previews) and shown, only the one in front moves: a screen with its own backdrop hides the one behind
## it.

## Every backdrop in the tree.
static var _all: Array[Cyclorama] = []

## A preview's own backdrop; none: the one shown.
var palette: Palette:
	set(value):
		palette = value
		_lay_out()
## The staged console's colour, which the veil takes while [member Backdrop.veil_gel].
var gel := StudioTokens.NEUTRAL:
	set(value):
		gel = value
		if _drawn_gel:
			_paint_veil()

var _wall := ShaderMaterial.new()
var _glows := ShaderMaterial.new()
var _veil := ShaderMaterial.new()
## What the layers draw now: the palette, whether the veil moves and whether in the gel.
var _drawn: Palette
var _drawn_veil := false
var _drawn_gel := false
## The veil's own time.
var _time := 0.0


func _enter_tree() -> void:
	_all.append(self)
	_follow_all()


func _exit_tree() -> void:
	_all.erase(self)
	_follow_all()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_wall.shader = preload("res://studio/wall.gdshader")
	_glows.shader = preload("res://studio/cyclorama.gdshader")
	_veil.shader = preload("res://studio/pixel_veil.gdshader")
	_lay_out()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_lay_out()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_follow_all()
	elif what == NOTIFICATION_RESIZED:
		_frame_veil()


## The veil's time.
func _process(delta: float) -> void:
	_time += delta * StudioTokens.VEIL_TIME_SCALE
	_veil.set_shader_parameter(&"t", _time)


## The veil's pixels at their strongest over [param wall] (its mean colour), in [param tint]: as far from the wall in
## lightness (CIE L*, which keeps its steps near black) as the veil tuned over [constant StudioTokens.VEIL_TUNED_OVER]
## is from that wall. Over a dark wall, light is added; over a light one, the tint is laid as a deep ink. Returns the
## light added and the ink with its alpha.
static func veil_paint(wall: Color, tint: Color) -> Array[Color]:
	var tuned := Palette.of(StudioTokens.VEIL_TUNED_OVER).veil_base
	var light := tint.lerp(Color.WHITE, StudioTokens.VEIL_WHITENED) * StudioTokens.VEIL_ADDED
	var step := _lightness((tuned + light).clamp()) - _lightness(tuned)
	var target := _lightness(wall)
	if target < 50.0:
		var share := _solved(func(k: float) -> float: return _lightness((wall + light * k).clamp()) - target - step, 0.0, 4.0)
		return [Color(light * share, 0.0), Color(0, 0, 0, 0)]
	var lab := StudioMaterial.oklab(tint)
	var ink := StudioMaterial.srgb(Vector3(_oklab_l(target - StudioTokens.VEIL_INK_DEPTH * step), lab.y, lab.z)).clamp()
	var alpha := _solved(func(a: float) -> float: return target - step - _lightness(wall.lerp(ink, a)), 0.0, 1.0)
	return [Color(0, 0, 0, 0), Color(ink, alpha)]


## The layers of the backdrop to draw and its veil, made anew when either changed.
func _lay_out() -> void:
	if not is_node_ready():
		return
	var shown := palette if palette else Backdrop.palette
	if shown == _drawn and Backdrop.veil == _drawn_veil and Backdrop.veil_gel == _drawn_gel:
		return
	_drawn = shown
	_drawn_veil = Backdrop.veil
	_drawn_gel = Backdrop.veil_gel
	for layer in get_children():
		layer.free()
	match shown.wall:
		&"studio":
			_add(_studio(), null)
			_lay_glows()
		&"mapped":
			_add(_studio(), _wall)
			_wall.set_shader_parameter(&"low", _rgba(shown.wall_low))
			_wall.set_shader_parameter(&"high", _rgba(shown.wall_high))
		&"black":
			var black := ColorRect.new()
			black.color = Color.BLACK
			_add(black, null)
	if _drawn_veil:
		_frame_veil()
		_add(ColorRect.new(), _veil)
	_paint_veil()
	_follow()


## What moves follows, while shown: a backdrop hidden behind a screen in front, or behind another backdrop, draws
## nothing.
func _follow() -> void:
	set_process(is_visible_in_tree() and _drawn_veil and not _hidden())


## Whether a backdrop drawn full size and shown stands in front of this one, drawn full size too.
func _hidden() -> bool:
	return not palette and _all.any(func(other: Cyclorama) -> bool:
		return other != self and not other.palette and other.is_visible_in_tree() and other._in_front_of(self))


## Whether this backdrop is drawn after [param other]: on a higher canvas layer, or later in the tree on the same.
func _in_front_of(other: Cyclorama) -> bool:
	var mine := _layer()
	var theirs := other._layer()
	return mine > theirs or (mine == theirs and is_greater_than(other))


func _layer() -> int:
	var canvas := get_canvas_layer_node()
	return canvas.layer if canvas else 0


static func _follow_all() -> void:
	for each in _all:
		each._follow()


## The veil's pixels keep their size on the screen, also in a preview drawn small.
func _frame_veil() -> void:
	_veil.set_shader_parameter(&"frame", size * get_global_transform().get_scale())


## The key light and the floor's pool, those the console's gel does not tint.
func _lay_glows() -> void:
	var centres: Array[Vector2] = []
	var radii: Array[Vector2] = []
	var colors: Array[Vector4] = []
	var stops: Array[float] = []
	for glow: Array in StudioTokens.BACKDROP_GLOWS:
		if glow[4]:
			continue
		var color: Color = glow[2]
		centres.append(glow[0])
		radii.append(glow[1])
		colors.append(_rgba(color))
		stops.append(glow[3])
	_glows.set_shader_parameter(&"centres", centres)
	_glows.set_shader_parameter(&"radii", radii)
	_glows.set_shader_parameter(&"colors", colors)
	_glows.set_shader_parameter(&"stops", stops)
	_glows.set_shader_parameter(&"count", stops.size())
	_add(ColorRect.new(), _glows)


## The veil in the colours of the backdrop drawn, or in the gel, each painted for its wall.
func _paint_veil() -> void:
	if not _drawn_veil:
		return
	var lights: Array[Vector4] = []
	var inks: Array[Vector4] = []
	var colours := _drawn.veil_colours
	if _drawn_gel:
		colours = [_drawn.gel(gel)]
	for colour in colours:
		var paint := veil_paint(_drawn.veil_base, colour)
		lights.append(_rgba(paint[0]))
		inks.append(_rgba(paint[1]))
	_veil.set_shader_parameter(&"lights", lights)
	_veil.set_shader_parameter(&"inks", inks)
	_veil.set_shader_parameter(&"count", lights.size())
	_veil.set_shader_parameter(&"waves", not _drawn_gel and _drawn.veil_spread == &"waves")


static func _studio() -> TextureRect:
	var still := TextureRect.new()
	still.texture = preload("res://studio/cyclorama.png")
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return still


func _add(layer: Control, material_used: ShaderMaterial) -> void:
	layer.material = material_used
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(layer)


static func _rgba(colour: Color) -> Vector4:
	return Vector4(colour.r, colour.g, colour.b, colour.a)


## CIE L* of [param colour], from 0 (black) to 100 (white).
static func _lightness(colour: Color) -> float:
	var lin := colour.srgb_to_linear()
	var y := 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


## The OKLab lightness of the grey of CIE L* [param lightness].
static func _oklab_l(lightness: float) -> float:
	var y := pow((lightness + 16.0) / 116.0, 3.0) if lightness > 8.0 else lightness / 903.3
	return pow(maxf(y, 0.0), 1.0 / 3.0)


## Where [param f], rising, crosses 0 between [param low] and [param high].
static func _solved(f: Callable, low: float, high: float) -> float:
	for i in 24:
		var middle := (low + high) / 2.0
		if f.call(middle) < 0.0:
			low = middle
		else:
			high = middle
	return (low + high) / 2.0
