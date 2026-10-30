# SPDX-License-Identifier: GPL-3.0-or-later
class_name Cyclorama
extends Control
## The backdrop of every screen: a small lit photo studio. The paper wall curving into the floor and its
## vignette are one baked picture; over it, in one shader, the key light and the floor's pool of
## light, without the console's colour. Nothing moves, so nothing is drawn again.

var _glows := ShaderMaterial.new()


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
	for glow: Array in StudioTokens.BACKDROP_GLOWS:
		if glow[4]:
			continue
		var color: Color = glow[2]
		centres.append(glow[0])
		radii.append(glow[1])
		colors.append(Vector4(color.r, color.g, color.b, color.a))
		stops.append(glow[3])
	_glows.set_shader_parameter(&"centres", centres)
	_glows.set_shader_parameter(&"radii", radii)
	_glows.set_shader_parameter(&"colors", colors)
	_glows.set_shader_parameter(&"stops", stops)
	_glows.set_shader_parameter(&"count", stops.size())
	var over := ColorRect.new()
	over.material = _glows
	over.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	over.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(over)
