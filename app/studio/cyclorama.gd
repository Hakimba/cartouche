# SPDX-License-Identifier: GPL-3.0-or-later
class_name Cyclorama
extends Control
## The backdrop of every screen: a small lit photo studio. The paper wall curving into the floor and its
## vignette are one picture baked from the design; over it, in one shader, the console's gel glows on the floor
## and on the wall, and the key light and the floor's pool of light lie over the gel, as the design paints them.
## Nothing moves but the gel's change, so nothing is drawn again at rest.

var _glows := ShaderMaterial.new()
var _gel: Color
var _fade: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var still := TextureRect.new()
	still.texture = preload("res://studio/cyclorama.png")
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	still.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(still)
	_glows.shader = preload("res://studio/cyclorama.gdshader")
	var centres: Array[Vector2] = []
	var radii: Array[Vector2] = []
	var colors: Array[Vector4] = []
	var stops: Array[float] = []
	var tinted: Array[float] = []
	for glow: Array in StudioTokens.BACKDROP_GLOWS:
		var color: Color = glow[2]
		centres.append(glow[0])
		radii.append(glow[1])
		colors.append(Vector4(color.r, color.g, color.b, color.a))
		stops.append(glow[3])
		tinted.append(1.0 if glow[4] else 0.0)
	_glows.set_shader_parameter(&"centres", centres)
	_glows.set_shader_parameter(&"radii", radii)
	_glows.set_shader_parameter(&"colors", colors)
	_glows.set_shader_parameter(&"stops", stops)
	_glows.set_shader_parameter(&"tinted", tinted)
	var over := ColorRect.new()
	over.material = _glows
	over.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	over.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(over)
	show_gel(StudioTokens.NEUTRAL, false)


## The gel of [param color], crossfaded from the one shown when [param animated].
func show_gel(color: Color, animated := true) -> void:
	if color == _gel:
		return
	_gel = color
	Diagnostics.trace("studio", "backdrop gel=#%s" % color.to_html(false))
	if _fade:
		_fade.kill()
	if not animated:
		_glows.set_shader_parameter(&"gel", color)
		return
	_fade = create_tween()
	_fade.tween_property(_glows, ^"shader_parameter/gel", color, StudioTokens.GEL_FADE_S) \
		.set_custom_interpolator(Motion.curve(Motion.Easing.EASE))


## The gel of [param console], its platform's (a variant takes its base model's).
static func gel_of(console: ConsoleManifest) -> Color:
	return console.gel()
