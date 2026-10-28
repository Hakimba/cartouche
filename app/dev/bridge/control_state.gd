# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The control before a live edit, including shared theme resources and satin gradients.

const META: Array[StringName] = [&"studio_font_size", &"studio_text_colour", &"studio_text_override"]


static func capture(control: Control) -> Dictionary:
	var style := &"normal" if control is BaseButton else &"panel"
	var values := {"position": control.position, "size": control.size, "rotation": control.rotation,
		"font_size_override": control.has_theme_font_size_override(&"font_size"),
		"font_size": control.get_theme_font_size(&"font_size"),
		"font_colour_override": control.has_theme_color_override(&"font_color"),
		"font_colour": control.get_theme_color(&"font_color"),
		"style_name": style, "style_override": control.has_theme_stylebox_override(style), "metadata": {}}
	if control.has_theme_stylebox(style):
		values["style"] = control.get_theme_stylebox(style)
	for key in META:
		if control.has_meta(key):
			values["metadata"][key] = control.get_meta(key)
	if control is Label or control is BaseButton:
		values["text"] = control.get("text")
	if control is ColorRect:
		values["colour"] = (control as ColorRect).color
	var backing := _backing(control)
	if backing:
		values["backing"] = backing._tuning.duplicate(true)
	return values


static func restore(control: Control, values: Dictionary) -> void:
	control.position = values["position"]
	control.size = values["size"]
	control.rotation = values["rotation"]
	if values["font_size_override"]:
		var pixels: int = values["font_size"]
		control.add_theme_font_size_override(&"font_size", pixels)
	else:
		control.remove_theme_font_size_override(&"font_size")
	if values["font_colour_override"]:
		var colour: Color = values["font_colour"]
		control.add_theme_color_override(&"font_color", colour)
	else:
		control.remove_theme_color_override(&"font_color")
	var style: StringName = values["style_name"]
	if values["style_override"]:
		var box: StyleBox = values["style"]
		control.add_theme_stylebox_override(style, box)
	else:
		control.remove_theme_stylebox_override(style)
	for key in META:
		var metadata: Dictionary = values["metadata"]
		if metadata.has(key):
			control.set_meta(key, metadata[key])
		elif control.has_meta(key):
			control.remove_meta(key)
	ControlTokens.refresh_text_style(control)
	if values.has("text"):
		control.set("text", values["text"])
	if values.has("colour"):
		(control as ColorRect).color = values["colour"]
	var backing := _backing(control)
	if backing and values.has("backing"):
		var tuning: Dictionary = values["backing"]
		backing._tuning = tuning.duplicate(true)
		backing._paint()
	for child in control.find_children("*", "Control", true, false):
		(child as Control).queue_redraw()
	control.queue_redraw()


static func _backing(control: Control) -> SatinPanel.Backing:
	var holder: WeakRef = control.get_meta(&"studio_backing") if control.has_meta(&"studio_backing") else null
	var backing: SatinPanel.Backing = holder.get_ref() if holder else null
	return backing
