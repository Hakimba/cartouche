# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const ControlState := preload("res://dev/bridge/control_state.gd")

const Preview := preload("res://dev/bridge/plinth_preview.gd")
var _controls: Dictionary[int, Dictionary] = {}
var _poses: Dictionary[int, Dictionary] = {}
var _light_values: Dictionary[int, Dictionary] = {}
var _rooms: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000


func _process(_delta: float) -> void:
	for id: int in _controls.keys():
		var record: Dictionary = _controls[id]
		var reference: WeakRef = record["node"]
		var control: Control = reference.get_ref()
		if control:
			_place_control(control, _values(record))
		else:
			_controls.erase(id)
	for id: int in _poses.keys():
		var record: Dictionary = _poses[id]
		var reference: WeakRef = record["node"]
		var model: Node3D = reference.get_ref()
		if model:
			_apply_pose(model, _values(record))
		else:
			_poses.erase(id)
	for id: int in _light_values.keys():
		var record: Dictionary = _light_values[id]
		var reference: WeakRef = record["node"]
		var light: Light3D = reference.get_ref()
		if light:
			_edit_light(light, record)
		else:
			_light_values.erase(id)
	for id: int in _rooms.keys():
		var record: Dictionary = _rooms[id]
		var reference: WeakRef = record["environment"]
		var environment: Environment = reference.get_ref()
		if environment:
			environment.ambient_light_energy = record["energy"]
		else:
			_rooms.erase(id)


func tune(scene: Node, message: Dictionary) -> Dictionary:
	var raw: Variant = message.get("values")
	if raw is not Dictionary:
		return _error("invalid values")
	var values: Dictionary = raw
	var target: Variant = message.get("target")
	if target == "controls":
		for path: String in values:
			if values[path] is not Dictionary:
				return _error("invalid controls")
			var placed: Dictionary = values[path]
			var result := _control(scene, path, placed, false)
			if not result.get("ok", true):
				return result
		for path: String in values:
			var placed: Dictionary = values[path]
			_control(scene, path, placed)
		return {"ok": true}
	if target == "control":
		return _control(scene, message.get("path"), values)
	if target == "motion":
		return _motion(values)
	var shown := _shown(scene, true)
	if shown.is_empty():
		return _error("no shown model")
	var answer := {"ok": true}
	if target == "pose":
		if not _valid_values(values, {"position": 3, "rotation": 3, "scale": 3}):
			return _error("invalid pose")
		var model: Node3D = shown["model"]
		var record: Dictionary = _poses.get(model.get_instance_id(), {"node": weakref(model), "values": {}})
		var edited: Dictionary = record["values"]
		edited.merge(values, true)
		_poses[model.get_instance_id()] = record
		_apply_pose(model, edited)
		answer = _pose_answer(shown)
	elif target == "turntable":
		var preview: Preview = shown.get("preview")
		if preview == null or not _valid_values(values, {"rotation": 3, "position": 3, "size": 0}):
			return _error("invalid turntable values")
		var start := preview.start
		var size: float = values.get("size", start.size)
		preview.place(Plinth.Start.new(_vector3(values.get("rotation", _array(start.rotation))),
			_vector3(values.get("position", _array(start.position))), size))
		answer = _pose_answer(shown)
	elif target == "light":
		var index: Variant = message.get("index")
		var lights: Array[Light3D] = []
		var built: Array = shown["lights"]
		lights.assign(built)
		if not _number(index) or index != int(_float(index)) or index < 0 or index >= lights.size():
			return _error("invalid light index")
		if not _valid_values(values, {"position": 3, "target": 3, "colour": 3,
				"energy": 0, "range": 0, "angle": 0, "softness": 0, "shadow": -1}):
			return _error("invalid light values")
		var light := lights[int(_float(index))]
		var record: Dictionary = _light_values.get(light.get_instance_id(), {"node": weakref(light), "values": {}, "rig": shown["rig"],
			"index": int(_float(index))})
		var edited: Dictionary = record["values"]
		edited.merge(values, true)
		_light_values[light.get_instance_id()] = record
		_edit_light(light, record)
	elif target == "room":
		var environment := _environment(shown)
		if not _valid_values(values, {"energy": 0}) or environment == null:
			return _error("invalid room values")
		_rooms[environment.get_instance_id()] = {"environment": weakref(environment), "energy": values["energy"]}
		environment.ambient_light_energy = values["energy"]
	else:
		return _error("unknown tune target")
	_redraw(shown)
	return answer


## Tries other durations for the app's motion timings until the app starts again.
static func _motion(values: Dictionary) -> Dictionary:
	for key: Variant in values:
		if StringName(str(key)) not in StudioTokens.LIVE or not _number(values[key]) or _float(values[key]) < 0.0:
			return _error("invalid motion values")
		if str(key).ends_with("_CURVE") and (_float(values[key]) != int(_float(values[key])) or _float(values[key]) > Motion.Easing.OUT_BACK):
			return _error("invalid motion values")
	for key: String in values:
		(StudioTokens as Script).set(key, _float(values[key]))
	return {"ok": true}


func pick(scene: Node, point: Vector2) -> Dictionary:
	var stack := _controls_at(scene, point)
	var control: Control = stack.back() if not stack.is_empty() else null
	var shown := _shown(scene, false)
	var model := {}
	if not shown.is_empty() and _on_model(shown, point):
		model = {"folder" if shown.has("folder") else "medium": shown.get("folder", shown.get("medium", ""))}
	var under: Array[Dictionary] = []
	for index in range(stack.size() - 1, -1, -1):
		under.append(_control_values(stack[index]))
	return {"control": _control_values(control) if control else {}, "stack": under, "model": model}


## The rig the shown lights come from: its model (a console folder or a medium), its screen and
## whether it is the one for a game without a picture; empty when no model is shown.
func light_rig(scene: Node) -> Dictionary:
	var shown := _shown(scene, false)
	if shown.is_empty():
		return {}
	if shown.has("plinth"):
		return {"model": shown["folder"], "screen": "plinth", "blank": false}
	var media: MediaView = shown.get("media")
	if media:
		var properties: bool = scene is Carousel and (scene as Carousel)._screen == Carousel.Screen.PROPERTIES
		return {"model": shown["medium"], "screen": "properties" if properties else "games", "blank": media._blank_weight > 0.5}
	return {"model": shown["folder"], "screen": "consoles", "blank": false}


func _shown(scene: Node, preview: bool) -> Dictionary:
	if scene == null:
		return {}
	var nodes: Array[Node] = [scene]
	nodes.append_array(scene.find_children("*", "", true, false))
	var media: MediaView
	for node in nodes:
		if not _visible(node):
			continue
		if node is Plinth:
			var plinth := node as Plinth
			if plinth.console().is_empty():
				continue
			var live := plinth.get_node_or_null("BridgePreview") as Preview
			if live and live.folder != plinth.console():
				plinth.remove_child(live)
				live.queue_free()
				live = null
			if preview and live == null:
				live = Preview.new()
				live.name = "BridgePreview"
				plinth.add_child(live)
				live.show_console(plinth)
			return {"folder": plinth.console(), "plinth": plinth, "preview": live, "model": live.model if live else null,
				"lights": live.lights.lights() if live else [], "rig": live.lights if live else null, "camera": live.camera if live else null}
		if node is MediaView:
			var view := node as MediaView
			if view.holder().get_child_count() > 0 and (media == null or view._softness < media._softness):
				media = view
	if media:
		var model := media.holder().get_child(0) as Node3D
		return {"model": model, "medium": _medium_id(model), "lights": media.lights(), "rig": media._lights, "media": media,
			"camera": media.camera}
	for node in nodes:
		if node is ConsoleRow and _visible(node):
			var row := node as ConsoleRow
			if row._items.is_empty():
				continue
			var shown := {"model": row.selected().model, "folder": row.selected().folder, "lights": [], "rig": row.lights(),
				"camera": row.get_viewport().get_camera_3d()}
			if row.lights():
				shown["lights"] = row.lights().lights()
			else:
				shown.merge(_today(scene), true)
			return shown
	return {}


## Hides the shown model and gives back what shows it again: a picture taken meanwhile shows the pixels it covers as the
## background has them, so that what differs from the picture with it is the model's own.
func hide_model(scene: Node) -> Callable:
	var shown := _shown(scene, true)
	var model: Node3D = shown.get("model")
	if model == null:
		return Callable()
	model.visible = false
	_redraw(shown)
	return func() -> void:
		model.visible = true
		_redraw(shown)


## The default light, which a console without a light of its own keeps: the scene's Sun and its environment.
static func _today(scene: Node) -> Dictionary:
	var sun := scene.get_node_or_null("Sun") as DirectionalLight3D
	var world := scene.get_node_or_null("Environment") as WorldEnvironment
	return {"lights": [sun] if sun else [], "environment": world.environment if world else null}


static func _environment(shown: Dictionary) -> Environment:
	var rig: StudioLights = shown["rig"]
	return rig._environment if rig else shown.get("environment")


## Every light rig the scene shows built again from the light file as it now reads, where it stands: the
## consoles row's, the plinth's preview, each medium's (on the games screen or in its properties).
static func relight(scene: Node) -> void:
	if scene == null:
		return
	for node in scene.find_children("*", "", true, false):
		if node is ConsoleRow:
			(node as ConsoleRow).relight()
		elif node is Preview:
			(node as Preview).relight()
		elif node is MediaView:
			var view := node as MediaView
			if view.holder().get_child_count() == 0:
				continue
			var medium := _medium_id(view.holder().get_child(0) as Node3D)
			var screen := &"games" if view.get_parent() is ShelfRow else &"properties"
			view.relight(StudioLights.rig_of(medium, screen), StudioLights.rig_of(medium, screen, true))


static func _medium_id(model: Node3D) -> String:
	if model.scene_file_path:
		return ConsoleManifest.folder_of(load(model.scene_file_path))
	for child in model.get_children():
		if child is Node3D:
			var found := _medium_id(child as Node3D)
			if found:
				return found
	return ""


static func _visible(node: Node) -> bool:
	while node:
		if node is CanvasItem:
			var item := node as CanvasItem
			if not item.visible or item.modulate.a <= 0.001:
				return false
		elif node is Node3D and not (node as Node3D).visible:
			return false
		node = node.get_parent()
	return true


static func _pose_values(model: Node3D) -> Dictionary:
	return {"position": _array(model.position), "rotation": _array(model.rotation), "scale": _array(model.scale)}


## The screen rectangle [x, y, w, h] the shown model's box covers.
static func _screen_rect(shown: Dictionary) -> Array:
	var model: Node3D = shown["model"]
	var camera: Camera3D = shown["camera"]
	var box := Plinth.bounds(model, model)
	if camera == null or not box.has_volume():
		return []
	var view := _view(shown)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in 8:
		var point := camera.unproject_position(model.global_transform * box.get_endpoint(corner))
		point = view.position + point * view.size / camera.get_viewport().get_visible_rect().size
		low = low.min(point)
		high = high.max(point)
	return [low.x, low.y, high.x - low.x, high.y - low.y]


## The screen rectangle the shown model's camera picture is drawn in: the plinth's own view is drawn in its
## turntable, every other camera fills the screen.
static func _view(shown: Dictionary) -> Rect2:
	var plinth: Plinth = shown.get("plinth")
	if plinth:
		var turntable := plinth.get_node("Turntable") as Control
		return turntable.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, turntable.size)
	var camera: Camera3D = shown["camera"]
	return camera.get_viewport().get_visible_rect()


## What a pose editor needs to draw handles on the shown model: the model's `pose`, the screen `rect` its box
## covers, and its `space`: the camera's `projection` and `camera` transform, the screen rectangle `view` its
## picture is drawn in, the `model`'s and its `parent`'s transforms in the camera's world, and the model's box
## `centre` in its own space. Transforms are 12 numbers, the basis columns then the origin; the projection 16,
## column by column.
static func _pose_answer(shown: Dictionary) -> Dictionary:
	var model: Node3D = shown["model"]
	var camera: Camera3D = shown["camera"]
	var answer := {"ok": true, "pose": _pose_values(model), "rect": _screen_rect(shown)}
	if camera == null:
		return answer
	var projection := camera.get_camera_projection()
	var columns: Array = []
	for column: Vector4 in [projection.x, projection.y, projection.z, projection.w]:
		columns.append_array([column.x, column.y, column.z, column.w])
	var view := _view(shown)
	answer["space"] = {"projection": columns, "camera": _transform(camera.global_transform),
		"view": [view.position.x, view.position.y, view.size.x, view.size.y],
		"model": _transform(model.global_transform), "parent": _transform(model.get_parent_node_3d().global_transform),
		"centre": _array(Plinth.bounds(model, model).get_center())}
	return answer


static func _transform(at: Transform3D) -> Array:
	return _array(at.basis.x) + _array(at.basis.y) + _array(at.basis.z) + _array(at.origin)


static func _array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


static func _apply_pose(model: Node3D, values: Dictionary) -> void:
	for key: String in values:
		model.set(key, _vector3(values[key]))


static func _edit_light(light: Light3D, record: Dictionary) -> void:
	var rig: StudioLights = record["rig"]
	var values: Dictionary = record["values"]
	if rig == null:
		_apply_light(light, values, Vector3.ZERO)
		return
	var source := rig._rig.sources[record["index"]]
	var centre := light.position - source.position
	if values.has("position"):
		source.position = _vector3(values["position"])
	_apply_light(light, values, centre)


static func _apply_light(light: Light3D, values: Dictionary, centre: Vector3) -> void:
	if values.has("position"):
		light.position = centre + _vector3(values["position"])
	if values.has("target"):
		var direction := _vector3(values["target"])
		if light is not DirectionalLight3D:
			direction += centre - light.position
		if not direction.is_zero_approx():
			light.basis = StudioLights._aimed(direction)
	if values.has("energy"):
		light.light_energy = values["energy"]
		light.visible = light.light_energy > 0
	if values.has("colour"):
		var rgb := _vector3(values["colour"])
		light.light_color = Color(rgb.x, rgb.y, rgb.z)
	if values.has("shadow"):
		light.shadow_enabled = values["shadow"]
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		if values.has("range"): spot.spot_range = values["range"]
		if values.has("angle"): spot.spot_angle = values["angle"]
		if values.has("softness"): spot.spot_angle_attenuation = values["softness"]
	elif light is OmniLight3D and values.has("range"):
		(light as OmniLight3D).omni_range = values["range"]


static func _redraw(shown: Dictionary) -> void:
	var media: MediaView = shown.get("media")
	if media:
		media.redraw()


func _control(scene: Node, path: Variant, values: Dictionary, apply := true) -> Dictionary:
	if scene == null or path is not String:
		return _error("invalid control path")
	var control := scene.get_node_or_null(NodePath(str(path))) as Control
	if control == null or (control != scene and not scene.is_ancestor_of(control)):
		return _error("control not found in current scene")
	if values.has("reset"):
		if values.size() != 1 or values["reset"] != true:
			return _error("invalid control reset")
		if apply and _controls.has(control.get_instance_id()):
			var original: Dictionary = _controls[control.get_instance_id()]
			var snapshot: Dictionary = original["original"]
			ControlState.restore(control, snapshot)
			original["values"] = {}
		return {"ok": true}
	var numbers := values.duplicate()
	numbers.erase("text")
	if not _valid_values(numbers, {"position": 2, "size": 2, "rotation": 0,
			"corner_radius": 0, "colour": 4, "text_colour": 4, "border_colour": 4, "font_size": 0}):
		return _error("invalid control values")
	if values.has("text"):
		if values["text"] is not String or not (control is Label or control is BaseButton):
			return _error("ce contrôle ne porte pas de texte éditable")
		if _translated(control):
			return _error("ce texte vient des traductions")
	if values.has("corner_radius") and not control.has_meta(&"studio_backing") and _corner_style(control) == null:
		return _error("control has no corner radius")
	if not apply:
		return {"ok": true}
	var record: Dictionary
	if _controls.has(control.get_instance_id()):
		record = _controls[control.get_instance_id()]
	else:
		record = {"node": weakref(control), "values": {}, "original": ControlState.capture(control)}
	var placed: Dictionary = record["values"]
	placed.merge(values, true)
	_controls[control.get_instance_id()] = record
	ControlTokens.apply(control, values)
	control.queue_redraw()
	return {"ok": true}


static func _translated(control: Control) -> bool:
	if not (control is Label or control is BaseButton):
		return false
	var content := str(control.get("text"))
	return control.tr(content) != content


static func _corner_style(control: Control) -> StyleBoxFlat:
	return control.get_theme_stylebox(&"normal" if control is BaseButton else &"panel") as StyleBoxFlat


## Every visible control under the point, the topmost last.
func _controls_at(scene: Node, point: Vector2) -> Array[Control]:
	var found: Array[Control] = []
	if scene == null:
		return found
	var nodes: Array[Node] = [scene]
	nodes.append_array(scene.find_children("*", "", true, false))
	for node in nodes:
		if node is Control:
			var control := node as Control
			if _visible(control) and _inside(control, point) and _unclipped(control, point):
				found.append(control)
	var order := {}
	for index in found.size():
		order[found[index]] = index
	found.sort_custom(func(a: Control, b: Control) -> bool:
		var by := [_layer(a), _z(a), order[a]]
		var against := [_layer(b), _z(b), order[b]]
		return by < against)
	return found


static func _place_control(control: Control, values: Dictionary) -> void:
	for key: String in ["position", "size"]:
		if values.has(key): control.set(key, _vector2(values[key]))
	if values.has("rotation"): control.rotation = values["rotation"]
	if control is SatinPanel and values.has("corner_radius"):
		(control as SatinPanel)._backing.place(Rect2(Vector2.ZERO, control.size), _float(values["corner_radius"]))


static func _layer(control: CanvasItem) -> int:
	var node: Node = control
	while node:
		if node is CanvasLayer:
			return (node as CanvasLayer).layer
		node = node.get_parent()
	return 0


static func _z(control: CanvasItem) -> int:
	var z := control.z_index
	var parent := control.get_parent() as CanvasItem
	if parent and control.z_as_relative and not control.is_set_as_top_level():
		z += _z(parent)
	return z


static func _inside(control: Control, point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, control.size).has_point(control.get_global_transform_with_canvas().affine_inverse() * point)


static func _unclipped(control: Control, point: Vector2) -> bool:
	var parent := control.get_parent()
	while parent:
		if parent is Control:
			var box := parent as Control
			if box.clip_contents and not _inside(box, point):
				return false
		parent = parent.get_parent()
	return true


static func _control_values(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var result := {"path": str(control.get_path()), "class": control.get_class(),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"position": [control.position.x, control.position.y], "size": [control.size.x, control.size.y],
		"translated": _translated(control)}
	if control is Label or control is BaseButton:
		result["text"] = str(control.get("text"))
	if control.has_theme_font_size(&"font_size"):
		result["font_size"] = control.get_theme_font_size(&"font_size")
	if control.has_theme_color(&"font_color"):
		var colour := control.get_theme_color(&"font_color")
		result["text_colour"] = [colour.r, colour.g, colour.b, colour.a]
	if control is ColorRect:
		var colour := (control as ColorRect).color
		result["colour"] = [colour.r, colour.g, colour.b, colour.a]
	if control is SatinPanel:
		result["corner_radius"] = (control as SatinPanel)._backing._material.get_shader_parameter(&"radius")
	else:
		var style_name := &"normal" if control is BaseButton else &"panel"
		if control.has_theme_stylebox(style_name):
			var style := control.get_theme_stylebox(style_name) as StyleBoxFlat
			if style:
				result["corner_radius"] = style.corner_radius_top_left
				var colour := style.bg_color
				result["colour"] = [colour.r, colour.g, colour.b, colour.a]
				colour = style.border_color
				result["border_colour"] = [colour.r, colour.g, colour.b, colour.a]
	var reference: WeakRef = control.get_meta(&"studio_backing") if control.has_meta(&"studio_backing") else null
	var backing: SatinPanel.Backing = reference.get_ref() if reference else null
	if backing:
		if not result.has("text_colour"):
			result["text_colour"] = [StudioTokens.INK.r, StudioTokens.INK.g, StudioTokens.INK.b, StudioTokens.INK.a]
		var colours: Array = backing._material.get_shader_parameter(&"colors")
		if not colours.is_empty():
			var first: Vector4 = colours[0]
			result["colour"] = [first.x, first.y, first.z, first.w]
		result["corner_radius"] = backing._material.get_shader_parameter(&"radius")
		var look := StudioMaterial.new(backing.look)
		for shadow in look.shadows:
			if shadow.inset:
				var ink := shadow.shown(backing.tint)
				result["border_colour"] = [ink.r, ink.g, ink.b, ink.a]
				break
	return result


static func _on_model(shown: Dictionary, point: Vector2) -> bool:
	var plinth: Plinth = shown.get("plinth")
	if plinth:
		return (plinth.get_node("Turntable") as Control).get_global_rect().has_point(point)
	var model: Node3D = shown.get("model")
	var camera: Camera3D = shown.get("camera")
	if model == null or camera == null:
		return false
	var box := Plinth.bounds(model, model)
	if not box.has_volume():
		return false
	var inverse := model.global_transform.affine_inverse()
	var start := inverse * camera.project_ray_origin(point)
	var direction := inverse.basis * camera.project_ray_normal(point)
	return box.intersects_ray(start, direction) != null


static func _valid_values(values: Dictionary, fields: Dictionary) -> bool:
	for key: Variant in values:
		if not fields.has(key):
			return false
		var count: int = fields[key]
		var value: Variant = values[key]
		if count == -1:
			if value is not bool: return false
		elif count == 0:
			if not _number(value): return false
		else:
			if value is not Array: return false
			var components: Array = value
			if components.size() != count: return false
			for component: Variant in components:
				if not _number(component): return false
	return true


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(_float(value))


static func _vector3(value: Variant) -> Vector3:
	var components: Array = value
	return Vector3(_float(components[0]), _float(components[1]), _float(components[2]))


static func _vector2(value: Variant) -> Vector2:
	var components: Array = value
	return Vector2(_float(components[0]), _float(components[1]))


static func _float(value: Variant) -> float:
	return value


static func _error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}


static func _values(record: Dictionary) -> Dictionary:
	return record["values"]


func controls(scene: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if scene:
		for node in scene.find_children("*", "Control", true, false):
			var control := node as Control
			if control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0:
				found.append(_control_values(control))
	return found
