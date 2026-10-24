# SPDX-License-Identifier: GPL-3.0-or-later
class_name ContactShadow
extends Control
## A console's contact shadow and floor reflection under it, laid over the whole 4:3 frame the console is
## drawn in: the shadow first, then the reflection (the ring shows the shadow alone, the consoles screen the
## reflection alone). Both come baked per
## console, softened as the design shows them, from the console's own silhouette (each column meets the
## floor at its lowest covered pixel): `studio/grounds/<console>-shadow.png` and `-reflection.png`, at the
## frame's size over 3.72. Only the shown console's pair is loaded.

const FOLDER := "res://studio/grounds/"
## What shows for a console without a ground: nothing.
const _NONE := preload("res://studio/no_logo.tres")

var _shadow := TextureRect.new()
var _reflection := TextureRect.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for layer: TextureRect in [_shadow, _reflection]:
		layer.mouse_filter = MOUSE_FILTER_IGNORE
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(layer)


## Shows the ground of the console in [param folder] (under res://carousel/consoles): its shadow when
## [param shadowed], its reflection when [param reflected]; nothing for a console without one.
func show_ground(folder: String, shadowed := true, reflected := true) -> void:
	_shadow.texture = _layer(folder, "shadow") if shadowed else null
	_reflection.texture = _layer(folder, "reflection") if reflected else null


## The two layers shown, shadow then reflection.
func layers() -> Array[TextureRect]:
	return [_shadow, _reflection]


static func _layer(folder: String, layer: String) -> Texture2D:
	var path := FOLDER + "%s-%s.png" % [folder, layer]
	if ResourceLoader.exists(path):
		return load(path)
	Diagnostics.trace("studio", "no %s under %s" % [layer, folder])
	return _NONE
