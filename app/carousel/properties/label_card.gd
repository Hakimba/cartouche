# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelCard
extends Button
## One image a game's label can show: a small disc with that label and, below, where it comes
## from. Faded while its image is still to come or could not be had, and then not to be chosen.
## The card of the user's own picture shows a "+" until it shows the one the label has.

const _THUMBNAIL := preload("res://carousel/properties/label_thumbnail.gdshader")
const _SIZE := Vector2(210, 220)
const _FADED := 0.45

## What the thumbnail draws its blank disc on, before the image.
static var _blank: Texture2D

## The region of the art sources the image is for, as they name it (empty when they name none).
var region: String
## Whether it is the card of the user's own image rather than of a region.
var own: bool
## The image, once read; none before.
var label: Texture2D
var _thumbnail := TextureRect.new()
var _material := ShaderMaterial.new()


func _init(region_name: String, caption: String, of_own := false) -> void:
	region = region_name
	own = of_own
	theme_type_variation = &"Card"
	custom_minimum_size = _SIZE
	# Up and down lead nowhere: the cards are one row.
	focus_neighbor_top = ^"."
	focus_neighbor_bottom = ^"."
	var items := VBoxContainer.new()
	items.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 14)
	items.mouse_filter = MOUSE_FILTER_IGNORE
	_material.shader = _THUMBNAIL
	_thumbnail.material = _material
	if not _blank:
		var image := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
		image.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(image)
	_thumbnail.texture = _blank
	_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumbnail.size_flags_vertical = SIZE_EXPAND_FILL
	_thumbnail.mouse_filter = MOUSE_FILTER_IGNORE
	var where := Label.new()
	where.theme_type_variation = &"CardText"
	where.text = caption
	where.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	where.mouse_filter = MOUSE_FILTER_IGNORE
	items.add_child(_thumbnail)
	items.add_child(where)
	add_child(items)
	modulate.a = 1.0 if own else _FADED
	_material.set_shader_parameter(&"own", own)


## Whether its image can be chosen: it has one, or it opens the user's pictures.
func is_ready() -> bool:
	return own or label != null


## Shows [param image], its label.
func show_label(image: Texture2D) -> void:
	label = image
	_thumbnail.texture = image
	_material.set_shader_parameter(&"has_label", true)
	_material.set_shader_parameter(&"own", false)
	modulate.a = 1.0
