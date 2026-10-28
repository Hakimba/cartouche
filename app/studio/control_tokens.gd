# SPDX-License-Identifier: GPL-3.0-or-later
class_name ControlTokens
extends Node
## Visual overrides from the screen tokens, kept separate from the content a screen displays.

static var _styled_controls: Dictionary[int, WeakRef] = {}

var edits: Dictionary = StudioTokens.CONTROL_EDITS
var _patterns: Array[Dictionary] = []
var _placing: Dictionary[int, bool] = {}
var _pending: Dictionary[int, int] = {}


func _ready() -> void:
	for id: String in edits:
		var values: Dictionary = edits[id]
		var pattern := RegEx.create_from_string(str(values.get("match", "$^")))
		var shared: Dictionary = StudioTokens.CONTROL_STYLES.get(values.get("style", ""), {})
		var merged := shared.duplicate()
		merged.merge(values, true)
		_patterns.append({"pattern": pattern, "values": merged})
	if _patterns.is_empty():
		return
	get_tree().node_added.connect(_watch)
	for child in get_parent().find_children("*", "Control", true, false):
		_watch(child)


func _watch(node: Node) -> void:
	if node is Control:
		_register.call_deferred(weakref(node))


func _register(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if not node or not node.is_inside_tree() or not get_parent().is_ancestor_of(node):
		return
	var path := str(node.get_path())
	for segment: String in path.split("/"):
		if segment.begins_with("@") and segment.find("@", 1) >= 0:
			return
	var control := node as Control
	var combined := {}
	for entry: Dictionary in _patterns:
		var pattern: RegEx = entry["pattern"]
		if pattern.search(path):
			var values: Dictionary = entry["values"]
			combined.merge(values, true)
	if combined.is_empty():
		return
	apply(control, combined)
	control.resized.connect(_resized.bind(control, combined))


func _resized(control: Control, values: Dictionary) -> void:
	var id := control.get_instance_id()
	if _placing.has(id):
		return
	if _pending.has(id):
		_pending[id] += 1
		return
	var running := _running_tweens()
	if running.is_empty():
		_place_after_resize(control, values)
		return
	_pending[id] = 1
	var reference: WeakRef = weakref(control)
	_watch_tweens(running, reference, values, id)
	get_tree().create_timer(1.0).timeout.connect(_finish_resize.bind(reference, values, id), CONNECT_ONE_SHOT)


func _running_tweens() -> Array[Tween]:
	return get_tree().get_processed_tweens().filter(func(tween: Tween) -> bool: return tween.is_running())


func _watch_tweens(tweens: Array[Tween], reference: WeakRef, values: Dictionary, id: int) -> void:
	var done := _finish_resize.bind(reference, values, id)
	for tween in tweens:
		if not tween.finished.is_connected(done):
			tween.finished.connect(done, CONNECT_ONE_SHOT)


func _finish_resize(reference: WeakRef, values: Dictionary, id: int) -> void:
	if not _pending.has(id):
		return
	var control: Control = reference.get_ref()
	if not control:
		_pending.erase(id)
		return
	var running := _running_tweens()
	if not running.is_empty():
		_watch_tweens(running, reference, values, id)
		return
	var changes: int = _pending[id]
	_pending.erase(id)
	if changes == 1:
		_place_after_resize(control, values)


func _place_after_resize(control: Control, values: Dictionary) -> void:
	var id := control.get_instance_id()
	_placing[id] = true
	place(control, values)
	_placing.erase(id)


static func place(control: Control, values: Dictionary) -> void:
	if values.has("rect"):
		var rect: Array = values["rect"]
		var at := Vector2(_float(rect[0]), _float(rect[1]))
		var extent := Vector2(_float(rect[2]), _float(rect[3]))
		if not control.global_position.is_equal_approx(at):
			control.global_position = at
		if not control.size.is_equal_approx(extent):
			control.size = extent
	for key: String in ["position", "size"]:
		if values.has(key):
			var pair: Array = values[key]
			var vector := Vector2(_float(pair[0]), _float(pair[1]))
			var current: Vector2 = control.get(key)
			if not current.is_equal_approx(vector):
				control.set(key, vector)
	if values.has("rotation"):
		control.rotation = values["rotation"]


static func apply(control: Control, values: Dictionary) -> void:
	place(control, values)
	if values.has("font_size"):
		control.add_theme_font_size_override(&"font_size", int(_float(values["font_size"])))
		control.set_meta(&"studio_font_size", values["font_size"])
	if values.has("text_colour"):
		var colour := _colour(values["text_colour"])
		control.add_theme_color_override(&"font_color", colour)
		control.set_meta(&"studio_text_colour", colour)
	if values.has("font_size") or values.has("text_colour"):
		refresh_text_style(control)
	if values.has("text") and (control is Label or control is BaseButton):
		control.set_meta(&"studio_text_override", str(values["text"]))
		var restore := _restore_text.bind(control)
		if not control.draw.is_connected(restore):
			control.draw.connect(restore)
		control.set("text", str(values["text"]))
	if values.has("colour") and control is ColorRect:
		(control as ColorRect).color = _colour(values["colour"])
	var reference: WeakRef = control.get_meta(&"studio_backing") if control.has_meta(&"studio_backing") else null
	var backing: SatinPanel.Backing = reference.get_ref() if reference else null
	if backing:
		backing.tune(values)
	else:
		var style_name := &"normal" if control is BaseButton else &"panel"
		var style := control.get_theme_stylebox(style_name) as StyleBoxFlat if control.has_theme_stylebox(style_name) else null
		if style:
			var copy := style.duplicate() as StyleBoxFlat
			if values.has("colour"): copy.bg_color = _colour(values["colour"])
			if values.has("border_colour"): copy.border_color = _colour(values["border_colour"])
			if values.has("corner_radius"): copy.set_corner_radius_all(int(_float(values["corner_radius"])))
			control.add_theme_stylebox_override(style_name, copy)
	for child in control.find_children("*", "Control", true, false):
		(child as Control).queue_redraw()
	control.queue_redraw()


static func _restore_text(control: Control) -> void:
	if control.has_meta(&"studio_text_override"):
		var content: String = control.get_meta(&"studio_text_override")
		if control.get("text") != content:
			control.set("text", content)


static func refresh_text_style(control: Control) -> void:
	var id := control.get_instance_id()
	if not control.has_meta(&"studio_font_size") and not control.has_meta(&"studio_text_colour"):
		_styled_controls.erase(id)
		return
	if not _styled_controls.has(id):
		_styled_controls[id] = weakref(control)
		if control.is_inside_tree():
			var remove := _forget_text_style.bind(id)
			if not control.tree_exiting.is_connected(remove):
				control.tree_exiting.connect(remove, CONNECT_ONE_SHOT)


static func _forget_text_style(id: int) -> void:
	_styled_controls.erase(id)


static func has_text_edits() -> bool:
	if _styled_controls.is_empty():
		return false
	for id: int in _styled_controls.keys():
		if not _styled_controls[id].get_ref():
			_styled_controls.erase(id)
	return not _styled_controls.is_empty()


static func text_style(canvas: CanvasItem) -> Dictionary:
	var result := {}
	var node: Node = canvas
	while node:
		for key: StringName in [&"studio_font_size", &"studio_text_colour"]:
			if not result.has(key) and node.has_meta(key):
				result[key] = node.get_meta(key)
		node = node.get_parent()
	return result


static func _colour(value: Variant) -> Color:
	var rgba: Array = value
	return Color(_float(rgba[0]), _float(rgba[1]), _float(rgba[2]), _float(rgba[3]))


static func _float(value: Variant) -> float:
	return value
