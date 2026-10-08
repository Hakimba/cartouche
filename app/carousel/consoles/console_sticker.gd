# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleSticker
extends Control
## The console peeled off the ring ([ConsoleRow]) drawn as a sticker: alone, in a view of its own
## (the render layer [constant ConsoleLayer.STICKER], which the carousel's camera leaves out), then
## outlined in white and shadowed by [code]sticker.gdshader[/code], which runs only round it. The
## view is drawn again only when the console moves or peels, and it is window-sized only while the
## ring shows ([method watch]): a full-size view with its MSAA weighs some tens of megabytes.

## The border and the shadow's offset, in pixels of the screen, once peeled off.
const _BORDER := 9.0
const _SHADOW := Vector2(6.0, 11.0)

## Set by the carousel before the ring first opens.
var consoles: ConsoleRow

## What the view showed last: the console's place and how far it was peeled.
var _drawn := []

@onready var _view: SubViewport = %StickerView
@onready var _camera: Camera3D = %StickerCamera
@onready var _material: ShaderMaterial = material


func _ready() -> void:
	_material.set_shader_parameter(&"picture", _view.get_texture())
	get_window().size_changed.connect(_fit)
	watch(false)


## Follows the console peeled off while [param on], as the ring shows; else it holds nothing.
func watch(on: bool) -> void:
	set_process(on)
	if on:
		# The edges' smoothing the user chose may have changed since the last time.
		_view.msaa_3d = get_viewport().msaa_3d
		_fit()
	else:
		_view.size = Vector2i.ONE
		_drawn = []
		queue_redraw()


func _process(_delta: float) -> void:
	var geometry := consoles.peeled_geometry()
	var drawn := [consoles.peel, geometry[0].global_transform] if not geometry.is_empty() else []
	if drawn == _drawn:
		return
	_drawn = drawn
	if drawn.is_empty():
		queue_redraw()
		return
	var watched := get_viewport().get_camera_3d()
	_camera.global_transform = watched.global_transform
	_camera.fov = watched.fov
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var pixels := Vector2(_view.size) / size
	_material.set_shader_parameter(&"border", _BORDER * consoles.peel * pixels.x)
	_material.set_shader_parameter(&"shadow", _SHADOW * consoles.peel * pixels)
	queue_redraw()


func _draw() -> void:
	var geometry := consoles.peeled_geometry()
	if geometry.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var box := Rect2(camera.unproject_position(geometry[0].global_position), Vector2.ZERO)
	for part in geometry:
		var aabb := part.get_aabb()
		for corner in 8:
			box = box.expand(camera.unproject_position(part.global_transform * aabb.get_endpoint(corner)))
	box = box.grow(_BORDER + _SHADOW.length() + 4.0)
	var pixels := Vector2(_view.size) / size
	draw_texture_rect_region(_view.get_texture(), box, Rect2(box.position * pixels, box.size * pixels))


## The view as large as the window, while it is watched: the sticker as sharp as the rest.
func _fit() -> void:
	if is_processing():
		_view.size = get_window().size
		_drawn = []
