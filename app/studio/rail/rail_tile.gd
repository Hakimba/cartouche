# SPDX-License-Identifier: GPL-3.0-or-later
class_name RailTile
extends Control
## One tile of the consoles rail: a satin tile of radius 19.2 px holding the console's logo made for the
## rail-tile slot ([LogoView]), centred. [method reflected] makes its floor reflection: the same tile
## mirrored under its bottom edge, whose mask the rail's group gives it.

const SIZE := Vector2(151.04, 102.4)
const RADIUS := 19.2
## The reflection starts this far under the tile's bottom edge.
const REFLECTION_GAP := 4.48

var _console := ""
var _logo := LogoView.new()


## The face: the satin box with its radius, which is the tile's own and not satin's.
class Face:
	extends SatinPanel

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
			_backing.place(Rect2(Vector2.ZERO, size), RADIUS)


## The face of a reflection: the satin box without its outer shadows, which the browser leaves out of the mirror.
class Plain:
	extends Control

	var _material := ShaderMaterial.new()

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		var shown := StudioMaterial.new(StudioTokens.Look.SATIN)
		shown.radius = RADIUS
		shown.shadows = shown.shadows.filter(func(shadow: StudioMaterial.Shadow) -> bool: return shadow.inset)
		_material.shader = preload("res://studio/satin_panel.gdshader")
		var parameters := SatinPanel.Backing.recipe(shown)
		for parameter in parameters:
			_material.set_shader_parameter(parameter, parameters[parameter])
		_material.set_shader_parameter(&"box_position", Vector2.ZERO)
		_material.set_shader_parameter(&"box_size", SIZE)
		material = _material
		size = SIZE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color.WHITE)


func _init(mirrored := false) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	var face: Control = Plain.new() if mirrored else Face.new()
	face.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(face)
	face.size = SIZE
	add_child(_logo)


## The tile holding the logo of the console in [param folder] (under res://carousel/consoles).
static func of(folder: String) -> RailTile:
	var tile := RailTile.new()
	tile.show_console(folder)
	return tile


func show_console(folder: String) -> void:
	_console = folder
	_logo.show_logo(LogoView.Slot.RAIL_TILE, folder)
	var picture := _logo.texture.get_size()
	_logo.size = picture
	_logo.position = ((SIZE - picture) / 2.0).round()


## The console shown, its folder.
func console() -> String:
	return _console


## The logo on the tile.
func logo() -> LogoView:
	return _logo


## The same tile mirrored about its bottom edge, [constant REFLECTION_GAP] under it.
func reflected() -> RailTile:
	var mirror := RailTile.new(true)
	mirror.show_console(_console)
	mirror.pivot_offset = Vector2.ZERO
	mirror.scale = Vector2(1.0, -1.0)
	return mirror
