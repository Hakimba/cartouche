# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelledModel
extends Node3D
## A medium's model and the label drawn for it, in its own small viewport shaped like the model's `Label` mesh: one
## per medium in each place of the games row ([ShelfPlace]).

## What its label shows: nothing, the blank drawn in its viewport, or an image. Only a blank is asked about
## ([method is_blank]); the other two say what was shown.
enum LabelKind { NONE, BLANK, IMAGE }

## A label texture shown whole (see [method show_label]).
const WHOLE := Rect2(0.0, 0.0, 1.0, 1.0)
const _LABEL_VIEW := preload("res://carousel/label_view.tscn")
const _DEMO_ART := preload("res://carousel/demo_label.gdshader")
const _LABEL_WIDTH := 512
## A title area at least this tall, as a fraction of the label, takes the theme's font size;
## a smaller one shrinks it.
const _FULL_TITLE_HEIGHT := 0.22
const _DARK_INK := Color(0.12, 0.13, 0.15)
## How far above the platform's name the band starts, as a fraction of the label.
const _BAND_ABOVE := 0.02

## How many are alive, each with its label's viewport, and how many of those views hold a picture (a blank drawn):
## for the traces.
static var alive := 0
static var held_views := 0
## How many times a label changed: the row arranges again when it did, for the room's light follows the blanks.
static var label_edits := 0

## The model itself: its first child, unless lent ([method lend]).
var instance: Node3D
## The width of the model's label face over its height.
var label_proportion := 1.0
## Brings the model from its size in the row to its real size, in its own frame: its root's
## transform undone.
var to_real_size := Transform3D.IDENTITY
var dirty := true

var _fade: ModelFade
## The size of its view while it holds a blank; it holds nothing otherwise.
var _drawn_size := Vector2i.ZERO
var _label_mesh: MeshInstance3D
var _view: SubViewport = _LABEL_VIEW.instantiate()
var _background: ColorRect = _view.get_node("Background")
var _title: Label = _view.get_node("Title")
var _platform: Label = _view.get_node("Platform")
var _band: ColorRect = _view.get_node("Band")
var _ring := ProgressRing.new()
## Made when the first demo label is drawn.
var _demo_art: ShaderMaterial
var _kind := LabelKind.NONE
var _blur := 0.0


func _init(model: PackedScene) -> void:
	alive += 1
	instance = model.instantiate()
	add_child(instance)
	to_real_size = instance.transform.affine_inverse()
	add_child(_view)
	var label: MeshInstance3D = instance.get_node("Label")
	var material: ShaderMaterial = label.get_surface_override_material(0).duplicate()
	label.set_surface_override_material(0, material)
	_label_mesh = label
	_fade = ModelFade.new(instance)
	var face := label.get_aabb().size
	# To a ten-thousandth: a disc's face, built round, is square.
	label_proportion = snappedf(face.x / face.y, 0.0001)
	_drawn_size = Vector2i(_LABEL_WIDTH, roundi(_LABEL_WIDTH / label_proportion))
	_view.size = Vector2i.ZERO
	# Where the title and the platform go is the medium's manifest's, or its shape's when built from one: round a
	# disc's hub, for one.
	var manifest := MediumManifest.of_scene(model)
	var title := manifest.title_area
	var platform := manifest.platform_area
	if label.mesh is ShapedMesh:
		var shape := (label.mesh as ShapedMesh).shape
		title = shape.title_area()
		platform = shape.platform_area()
		_ring.radius = shape.progress_ring_radius()
	var size := Vector2(_drawn_size)
	_title.position = size * title.position
	_title.size = size * title.size
	var font_size := ThemeDB.get_project_theme().get_font_size(&"font_size", &"LabelTitle")
	var shrink := minf(1.0, title.size.y / _FULL_TITLE_HEIGHT)
	_title.add_theme_font_size_override(&"font_size", roundi(font_size * shrink))
	_platform.position = size * platform.position
	_platform.size = size * platform.size
	# From just above the platform's name to the bottom, where the label's edge rounds it.
	_band.position = Vector2(0.0, _platform.position.y - size.y * _BAND_ABOVE)
	_band.size = Vector2(size.x, size.y - _band.position.y)
	_ring.size = size
	_ring.hide()
	_view.add_child(_ring)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		alive -= 1
		_hold_view(false)


func is_blank() -> bool:
	return _kind == LabelKind.BLANK


## Whether its model is out, shown elsewhere ([method lend]).
func is_lent() -> bool:
	return not is_instance_valid(instance) or instance.get_parent() != self


## Takes its model out, for another view to show it ([method ShelfRow.lend_selected] only says which model the
## properties borrow); its label is still drawn on it here. Measure it first: out, it stands nowhere in the row.
func lend() -> void:
	remove_child(instance)


## Its model back as its first child, if it was out.
func take_back() -> void:
	if is_instance_valid(instance) and instance.get_parent() != self:
		instance.reparent(self, false)
		move_child(instance, 0)


## Shows no label, and lets go of what it showed: its picture, its view's.
func clear_label() -> void:
	_label(&"has_label", false)
	_label(&"label_texture", null)
	_show_as(LabelKind.NONE)


## Draws a blank of [param look] with [param title] and the platform's name; plain, with
## neither, nor the band holding it, when [param title] is empty.
func draw_label(title: String, look: ShelfRow.LabelLook) -> void:
	_background.color = look.color
	if look.demo_art:
		if not _demo_art:
			_demo_art = ShaderMaterial.new()
			_demo_art.shader = _DEMO_ART
		_demo_art.set_shader_parameter(&"seed", fposmod(title.hash() / 1000.0, 1.0))
		_background.material = _demo_art
	else:
		_background.material = null
	# The ink that stands out most from the label, and white with a dark outline on artwork.
	var shade := look.color.get_luminance()
	var dark := absf(shade - _DARK_INK.get_luminance()) > absf(shade - 1.0)
	var ink := _DARK_INK if dark and not look.demo_art else Color.WHITE
	for text: Label in [_title, _platform]:
		text.add_theme_color_override(&"font_color", Color(ink, 1.0 if text == _title else 0.7))
		text.add_theme_constant_override(&"outline_size", 10 if look.demo_art else 0)
	# The band carries the platform's name: a plain blank has none, its ring takes the band's colour.
	var banded := look.band.a > 0.0 and not look.demo_art
	_band.visible = banded and not title.is_empty()
	_band.color = look.band
	if _band.visible:
		_platform.add_theme_color_override(&"font_color", Color.WHITE)
	_title.text = title
	_platform.text = "" if title.is_empty() else look.band_text if _band.visible else look.platform_name
	_ring.color = look.band if banded else ink
	_show_as(LabelKind.BLANK)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_show(_view.get_texture(), WHOLE, false)


## Shows on the blank the ring of a download [param fraction] read (below 0 when its size is
## unknown), or none when NAN; the blank shown is drawn again.
func ring(fraction: float) -> void:
	_ring.visible = not is_nan(fraction)
	_ring.fraction = fraction
	_redraw_ring()


## Turns the ring of a download of unknown size by [param delta] seconds.
func turn_ring(delta: float) -> void:
	_ring.turn = fposmod(_ring.turn + delta * TAU, TAU)
	_redraw_ring()


func _redraw_ring() -> void:
	dirty = dirty or is_blank()
	_ring.queue_redraw()
	if is_blank():
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Shows [param label], an image of a real label, as the model's label; only its [param window] when given, as
## fractions of it, and of that, the middle of the label's proportions: an image of another shape (a Famicom's
## label on an NES cartridge) covers the label, cut, never stretched.
func show_label(label: Texture2D, window := WHOLE) -> void:
	_show(label, window, true)
	_show_as(LabelKind.IMAGE)


## Turns the model [param angle] radians about its own axis, its label blurred over
## [param blur] radians as when it spins fast.
func spin(angle: float, blur: float) -> void:
	var turned := Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
	dirty = dirty or transform != turned
	transform = turned
	# Told every frame while it stands launched: only a blur that changed is a look that changed.
	if blur != _blur:
		_blur = blur
		_label(&"spin_blur", blur)


## What its label shows from now on. Only a blank shown needs its view's picture.
func _show_as(kind: LabelKind) -> void:
	_kind = kind
	_hold_view(kind == LabelKind.BLANK)


func _show(label: Texture2D, window: Rect2, scanned: bool) -> void:
	var pixels := Vector2(label.get_size()) * window.size
	var cover := window.size
	if pixels.x > 0.0 and pixels.y > 0.0:
		var wider := pixels.x / pixels.y / label_proportion
		cover *= Vector2(minf(1.0, 1.0 / wider), minf(1.0, wider))
	var shown := Rect2(window.get_center() - cover / 2.0, cover)
	_label(&"label_texture", label)
	_label(&"label_window", Vector4(shown.position.x, shown.position.y, shown.size.x, shown.size.y))
	_label(&"scanned", scanned)
	_label(&"has_label", true)


# A view sized holds its picture on the graphics card, drawn or not.
func _hold_view(held: bool) -> void:
	if held != (_view.size == _drawn_size):
		held_views += 1 if held else -1
		_view.size = _drawn_size if held else Vector2i.ZERO


func _label(parameter: StringName, value: Variant) -> void:
	label_edits += 1
	dirty = true
	_fade.set_shader_value(_label_mesh, parameter, value)
