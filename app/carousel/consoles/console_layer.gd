# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleLayer
extends TextureRect
## The consoles drawn apart, behind the games, blurred, faded and greyed as the launch animation has
## them, so that the games stay readable over them. They are drawn here only while they are behind;
## otherwise in the carousel's own view, where a game can go into them. Behind the games they stand
## still, as the steps have them: the view is drawn again only when the animation moves them, not
## when only their opacity changes.

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
## [param saturation]; or not at all. Their view is drawn as they appear, then only through
## [method draw_again].
func look(behind: bool, blur: float, opacity: float, saturation: float) -> void:
	var appearing := behind and not visible
	visible = behind
	if appearing:
		# From the first frame drawn, where the carousel's camera looks.
		_fit()
		camera.global_transform = watched.global_transform
		camera.fov = watched.fov
	if not behind:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# In the window's pixels, which the blur's taps step through.
	_material.set_shader_parameter(&"radius", blur * StudioTokens.window_scale(get_window()))
	_material.set_shader_parameter(&"opacity", opacity)
	_material.set_shader_parameter(&"saturation", saturation)


## The consoles moved: their view is drawn again, while they show.
func draw_again() -> void:
	if visible:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _fit() -> void:
	view.size = Vector2i(Vector2(get_window().size) * _RESOLUTION)
	draw_again()
