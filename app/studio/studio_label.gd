# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioLabel
extends Label
## A label whose theme variation is a tracked role ([constant TrackedText.ROLES]): the layout, size, colours,
## alignment and wrapping are the label's own, its glyphs are drawn through [StudioText] at the role's tracking.

var _ink := Color.BLACK
var _outline := Color.WHITE


func _ready() -> void:
	# The engine's own glyphs stay unseen: the layout still measures with them.
	add_theme_color_override(&"font_color", Color.TRANSPARENT)
	add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_ink = themed(&"font_color", theme_type_variation, &"Label")
		_outline = themed(&"font_outline_color", theme_type_variation, &"Label")


## The colour [param item] of the project theme's [param variation] (or of a type it varies, down to
## [param base]): what a control of it shows, its own overrides aside.
static func themed(item: StringName, variation: StringName, base: StringName) -> Color:
	var project := ThemeDB.get_project_theme()
	var type := variation
	while type and not project.has_color(item, type):
		type = project.get_type_variation_base(type)
	return project.get_color(item, type if type else base)


func _draw() -> void:
	var font := get_theme_font(&"font")
	var px := get_theme_font_size(&"font_size")
	var shown := atr(text)
	var lines := TrackedText.lines(theme_type_variation, shown, px, INF if autowrap_mode == TextServer.AUTOWRAP_OFF else size.x)
	var step := font.get_height(px) + get_theme_constant(&"line_spacing")
	var top := (size.y - step * lines.size() + get_theme_constant(&"line_spacing")) * (vertical_alignment / 2.0) \
		if vertical_alignment != VERTICAL_ALIGNMENT_FILL else 0.0
	for i in lines.size():
		var line := lines[i]
		var free := size.x - line.width
		var x := 0.0 if horizontal_alignment in [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_FILL] \
			else free / 2.0 if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else free
		var y := top + i * step + line.ascent - line.baseline
		line.draw(self, Vector2(x, y), _ink, get_theme_constant(&"outline_size"), _outline)
