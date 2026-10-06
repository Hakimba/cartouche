# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleLayer
extends TextureRect
## The consoles drawn apart, behind the games, blurred, faded and greyed as the launch animation has
## them, so that the games stay readable over them. They are drawn here only while they are behind;
## otherwise in the carousel's own view, where a game can go into them. Behind the games they stand
## still, as the steps have them: the view is drawn again only when the animation moves them.

## The render layers the consoles are drawn in: in front, then behind the games, where only this
## view's camera sees them (the carousel's leaves layer 2 out).
const FRONT := 1
const BEHIND := 1 << 1
## The render layer of the console peeled off the ring, which only the sticker's view draws
## ([ConsoleSticker]).
const STICKER := 1 << 2
## The view is drawn at this fraction of the window's size: the blur hides the difference.
const _RESOLUTION := 0.5

## The carousel's camera, whose view this one copies.
@export var watched: Camera3D
@export var view: SubViewport
@export var camera: Camera3D

@onready var _material: ShaderMaterial = material


func _ready() -> void:
	texture = view.get_texture()
	get_window().size_changed.connect(_fit)
	look(false, 0.0, 1.0, 1.0)


## Shows the consoles [param behind] the games, blurred over [param blur] pixels of the carousel's
## screen (as wide as its viewport width setting), at [param opacity], their colours at
## [param saturation]; or not at all.
func look(behind: bool, blur: float, opacity: float, saturation: float) -> void:
	if behind and not visible:
		# From the first frame drawn, where the carousel's camera looks.
		_fit()
		camera.global_transform = watched.global_transform
		camera.fov = watched.fov
	visible = behind
	view.render_target_update_mode = SubViewport.UPDATE_ONCE if behind else SubViewport.UPDATE_DISABLED
	if not behind:
		return
	var width: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	# In the window's pixels, which the blur's taps step through.
	_material.set_shader_parameter(&"radius", blur * get_window().size.x / width)
	_material.set_shader_parameter(&"opacity", opacity)
	_material.set_shader_parameter(&"saturation", saturation)


func _fit() -> void:
	view.size = Vector2i(Vector2(get_window().size) * _RESOLUTION)
	if visible:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
