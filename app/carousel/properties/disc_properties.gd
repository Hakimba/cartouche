# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscProperties
extends PropertiesScreen
## The selected game's medium travels from its row pose into a still, front-facing staging.
## Up and down select its projected label zone or its name. The callout names that focus.
## A on the label offers source images and the system's picker for an own picture. Previewing,
## framing with the stick or touch, and keeping an image use the row's original label material.
## A on the name opens the existing keyboard. B returns from an editor or reverses the travel.
## Each travel profile uses one clock; projected extents change only with the view or the medium.

## The image picked could not be kept.
signal choice_failed
## The game was given a name, or its own title back.
signal name_kept
## The typed name could not be stored.
signal rename_failed

enum Step { CLOSED, PROPERTIES, LABELS, FRAMING, NAMING }

const _CAPTION_AWAY := 56.32
const _NAME_GAP := 23.04
static var _NAME_RISE: float:
	get: return StudioTokens.TR_PROPERTIES_RISE_PX
const _NAME_ROOM := 1098.56
## The caption beside the name stays this far inside the screen's edge.
const _CAPTION_EDGE := 28.8
const _RIM_ANGLE := -0.6
## The glide occupies the first 360 ms of either profile's clock.
static var _TRAVEL_S: float:
	get: return StudioTokens.TR_PROPERTIES_TRAVEL_S
## Opening lasts until the last zone and name fades finish, at 400 ms.
static var _OPEN_S: float:
	get: return StudioTokens.TR_PROPERTIES_OPEN_S
## Returning lasts until the neighbours and games chrome finish arriving, at 380 ms.
static var _BACK_S: float:
	get: return StudioTokens.TR_PROPERTIES_BACK_S

enum Part { MEDIUM, POOL, NEIGHBOURS, BEHIND, ZONE, NAME, CALLOUT, HINTS }

var _opening_parts: Dictionary[Part, Interval] = {}
var _back_parts: Dictionary[Part, Interval] = {}
## How fast the stick moves a picture being framed, in label widths a second, and how many times
## closer L1 / R1 frame it in a second.
const _FRAMING_SPEED := 0.6
const _ZOOM_SPEED := 1.8
## How long the cards take to fade before the picker opens.
const _TO_PICKER_S := 0.2

## The editing screens keep their established staging; properties use the medium's fitted size.
static var _in_row := Staging.new(0.0, 0.18, 1.0, 0.0, 400.0)
var _on_properties := Staging.new(1.0, 0.2, 0.98, 1.0, 400.0)
static var _on_labels := Staging.new(1.0, 0.34, 0.78, 0.45, 300.0)
## Framing a picture of one's own: the disc back in the middle, 1.2 cm above the camera's axis.
static var _on_framing := Staging.new(1.0, 0.12, 1.1, 0.4, 400.0)
## Typing its name: the disc high and small, 5.6 cm above the camera's axis, half its size.
static var _on_naming := Staging.new(1.0, 0.56, 0.5, 0.35, 220.0)
## The moves between the screens, in seconds.
static var _to_labels := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)
static var _from_labels := Move.new(Leave.SLIDE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)
## The picker covered the screen: the disc was put in place as it closed, the framing fades in.
static var _from_picker := Move.new(Leave.FADE, 0.0, 0.0, Arrive.FADE, 0.2, 0.0)
static var _framing_left := Move.new(Leave.FADE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)

static var _from_editing := Move.new(Leave.FADE, 0.15, 0.42, Arrive.FADE, 0.22, 0.26)

static var _to_naming := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)

## Set by the carousel before the first [method open].
var row: ShelfRow
var art: GameArt

var _step := Step.CLOSED
var _game: AndroidServices.Game
## The images of [member _game]'s label downloaded since they were asked for, by source and region
## (see [method _image_key]): one may arrive before the list of its images.
var _downloaded: Dictionary[String, String] = {}
var _reader := ImageReader.new()
## The picture of the user's own being framed, read from the plugin's copy.
var _picture_reader := ImageReader.new()
var _picture: AndroidServices.LabelPicture
var _picture_texture: Texture2D
var _framing := LabelFraming.new()
## The finger on the label (a tap opens its images) and on the picture being framed (a drag moves
## it); how wide the label shows, in pixels, which a drag across it moves the picture by.
var _finger := Finger.new()
var _label_px := 1.0
## The last pinch counted: its frame, place and factor.
var _pinched: Array = []
## The game whose picture, as framed, shows on its disc until its kept image is read.
var _framed_game := ""

var _kind := LabelZone.Shape.DISC
var _gel := StudioTokens.NEUTRAL
var _medium: MediaView
var _model: Node3D
var _model_parent: Node3D
var _label_mesh: MeshInstance3D
var _label_vertices := PackedVector3Array()
var _body_vertices := PackedVector3Array()
var _model_centre := Vector3.ZERO
var _row_stand := Transform3D.IDENTITY
var _travel_stand := Transform3D.IDENTITY
var _back_profile := false
var _travel := 0.0
var _direction := 0
var _name_text: _NameText
var _projected := false
var _projected_stand := Transform3D.IDENTITY
var _projected_camera: Camera3D
var _projected_camera_transform := Transform3D.IDENTITY
var _projected_projection := Projection()
var _projected_size := Vector2.ZERO
var _projected_pixels := Vector2i.ZERO
var _body_box := Rect2()
var _pool_opacity := -1.0

@onready var _zone: LabelZone = %Zone
@onready var _labels: Control = %Labels
@onready var _cards: HBoxContainer = %Cards
@onready var _prompt: Label = %Prompt
@onready var _framing_screen: Control = %Framing
@onready var _hints: Control = $Properties/Hints
@onready var _callout: FocusCallout = %Callout
@onready var _name: Button = %Name
@onready var _naming: NameEditor = %Naming
## What X, Y and Start do on the keyboard.
@onready var _naming_presses: Dictionary[StringName, Callable] = {
	&"open_properties": _naming.erase, &"open_settings": _naming.space, &"form_submit": _keep_name,
	&"previous_letter": _naming.move_caret.bind(-1), &"next_letter": _naming.move_caret.bind(1)}


func _init() -> void:
	_staging = _in_row


func _ready() -> void:
	super()
	add_to_group(SoundEffects.MOVES)
	_name.pressed.connect(_open_naming)
	_naming.submitted.connect(_keep_name)
	add_child(_reader)
	_reader.read.connect(_on_image_read)
	add_child(_picture_reader)
	_picture_reader.read.connect(_on_picture_read)
	_callout.use_studio()
	_name_text = _NameText.new()
	_name.add_child(_name_text)
	_name_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_name.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
		_name.add_theme_color_override(state, Color.TRANSPARENT)
	_name.add_theme_constant_override(&"outline_size", 0)
	_name.focus_entered.connect(_name_text.queue_redraw)
	_name.focus_exited.connect(_name_text.queue_redraw)
	_zone.gui_input.connect(_on_zone_input)
	_framing_screen.gui_input.connect(_on_framing_input)


func _process(delta: float) -> void:
	if _direction != 0:
		_tick_travel(minf(delta, 0.1))
	if not _medium:
		return
	if _step == Step.FRAMING and not _busy:
		_frame(delta)
	# The staged disc stands still: whatever its look became (label, ring) is drawn again once, as the row does.
	var shown := _model_parent as ShelfRow.LabelledModel
	if shown.dirty:
		_medium.redraw()
		shown.dirty = false
	var at := _travel_stand if _direction != 0 or (_step == Step.PROPERTIES and not _busy) else row.selected_stand()
	var stand := row.global_transform * at
	var camera := get_viewport().get_camera_3d()
	var changed := _refresh_extents(stand, camera)
	if changed or _pool_opacity != _staging.darkness:
		light.shaped(_body_box, _gel, _staging.darkness)
		_pool_opacity = _staging.darkness
	_name.position = Vector2((size.x - _name.size.x) / 2.0,
		maxf(_zone.get_rect().end.y, _body_box.end.y) + _NAME_GAP + _name_drop())
	_point_at_focus(_body_box.get_center(), _zone.size.x / 2.0)


func _refresh_extents(stand: Transform3D, camera: Camera3D) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := get_window().size
	var projection := camera.get_camera_projection()
	if _projected and stand == _projected_stand and camera == _projected_camera \
			and camera.global_transform == _projected_camera_transform and projection == _projected_projection \
			and viewport_size == _projected_size and pixels == _projected_pixels:
		return false
	_projected = true
	_projected_stand = stand
	_projected_camera = camera
	_projected_camera_transform = camera.global_transform
	_projected_projection = projection
	_projected_size = viewport_size
	_projected_pixels = pixels
	_medium.place(stand, 0.0)
	var label := _project(_label_vertices, stand, camera)
	_body_box = _project(_body_vertices, stand, camera)
	_label_px = maxf(label.size.x, 1.0)
	_zone.place(label, _kind, _gel)
	return true


func _project(vertices: PackedVector3Array, stand: Transform3D, camera: Camera3D) -> Rect2:
	var box := Rect2(camera.unproject_position(stand * vertices[0]), Vector2.ZERO)
	for vertex in vertices:
		box = box.expand(camera.unproject_position(stand * vertex))
	return box


static func _corners(box: AABB) -> PackedVector3Array:
	var corners := PackedVector3Array()
	for corner in 8:
		corners.append(box.get_endpoint(corner))
	return corners


static func _vertices(node: Node3D, relative_to: Node3D) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if not mesh:
			return vertices
		var at := relative_to.global_transform.affine_inverse() * node.global_transform
		for surface in mesh.get_surface_count():
			var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in points:
				vertices.append(at * point)
	for child in node.get_children():
		if child is Node3D:
			vertices.append_array(_vertices(child as Node3D, relative_to))
	return vertices


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.CLOSED or event.is_echo() or _direction != 0:
		return
	if _step == Step.FRAMING and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if not _busy:
			_keep_own()
		return
	if _step == Step.NAMING and _naming_press(event):
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	Sounds.play(SoundEffects.Cue.BACK)
	match _step:
		Step.LABELS:
			Diagnostics.trace("properties", "images left, the label as it was")
			_back_to_properties()
		Step.FRAMING:
			Diagnostics.trace("properties", "framing left, back to the images")
			_back_to_labels()
		Step.NAMING:
			Diagnostics.trace("properties", "naming left, the name as it was")
			_back_to_properties(_naming, _from_editing, _name)
		_:
			_close()


# Pinching zooms the picture being framed. Godot hands the same pinch over twice in a frame: only
# the first counts.
func _input(event: InputEvent) -> void:
	if _direction != 0 and event.is_pressed():
		if event.is_action_pressed(&"screen_back"):
			_direction = -1
		elif event.is_action_pressed(&"open_properties"):
			_direction = 1
		get_viewport().set_input_as_handled()
		return
	var pinch := event as InputEventMagnifyGesture
	if pinch and _step == Step.FRAMING and not _busy:
		get_viewport().set_input_as_handled()
		var seen := [Engine.get_process_frames(), pinch.position, pinch.factor]
		if seen == _pinched:
			return
		_pinched = seen
		_framing.zoom_by(pinch.factor, _picture.size)
		row.preview_label(_picture_texture, _framing.window(_picture.size))


## Whether the properties show, or are coming or going.
func is_open() -> bool:
	return _step != Step.CLOSED or _busy


## Opens the properties of the selected game of the row.
func open() -> void:
	_refresh_profiles()
	_game = row.selected_game()
	_kind = LabelZone.Shape.RECTANGLE if _game.medium.ends_with("_cart") else LabelZone.Shape.DISC
	var focus := get_theme_stylebox(&"focus", &"Button") as SatinStyle
	_gel = focus.gel if focus else StudioTokens.NEUTRAL
	_show_name(_name, _game.title)
	_step = Step.PROPERTIES
	_busy = true
	show()
	_labels.hide()
	if not art.loaded.is_connected(_on_art_loaded):
		art.loaded.connect(_on_art_loaded)
	if not _lend_model():
		_abort_model()
		return
	_row_stand = row.selected_stand()
	_staging = _in_row
	_travel = 0.0
	_back_profile = false
	_direction = 1
	_properties.show()
	_zone.show()
	_zone.grab_focus()
	set_process(true)
	_apply_travel()
	Diagnostics.trace("carousel", "zone shape=%s" % ("rect" if _kind == LabelZone.Shape.RECTANGLE else "circle"))
	Diagnostics.trace("properties", "open %s" % _game.title)


func _lend_model() -> bool:
	for child in row.get_children():
		if not child is ShelfRow.Place:
			continue
		var place: ShelfRow.Place = child
		if place.game != row.selected_index() or not is_instance_valid(place.shown):
			continue
		var parent := place.shown
		if parent.get_child_count() == 0:
			return false
		var source := parent.get_child(0)
		if not source is Node3D:
			return false
		var model: Node3D = source
		var label := model.get_node_or_null("Label")
		if not label is MeshInstance3D or not _meshes_ready(model):
			return false
		var label_mesh: MeshInstance3D = label
		var label_vertices := _vertices(label_mesh, parent)
		var body_vertices := _vertices(model, parent)
		var box := Plinth.bounds(model, parent)
		if label_vertices.is_empty() or body_vertices.is_empty() or maxf(box.size.x, box.size.y) <= 0.0:
			return false
		_model_parent = parent
		_model = model
		_label_mesh = label_mesh
		_label_vertices = label_vertices
		# A cartridge's body ends where its mesh does, higher than its box's near corners; a disc's box is exact.
		_body_vertices = body_vertices if _kind == LabelZone.Shape.RECTANGLE else _corners(box)
		_model_centre = box.get_center()
		_on_properties.size = 1.2 / maxf(box.size.x, box.size.y) * (0.92 if _kind == LabelZone.Shape.RECTANGLE else 0.98)
		_medium = MediaView.new()
		_medium.camera = get_viewport().get_camera_3d()
		add_child(_medium)
		move_child(_medium, 0)
		parent.remove_child(model)
		_medium.show_medium(model, StudioLights.rig_of(_game.medium, &"properties"),
			StudioLights.rig_of(_game.medium, &"properties", true))
		_medium.crossfade(0.0 if art.has_texture(_game) else 1.0)
		_projected = false
		_pool_opacity = -1.0
		return true
	return false


static func _meshes_ready(model: Node3D) -> bool:
	if model is MeshInstance3D:
		var root_mesh: MeshInstance3D = model
		if not root_mesh.mesh:
			return false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh:
			return false
	return true


func _abort_model() -> void:
	_return_model()
	_step = Step.CLOSED
	_direction = 0
	_busy = false
	row.stage = 0.0
	row.neighbours = 1.0
	row.pose_selected()
	for item in behind:
		item.show()
		item.modulate.a = 1.0
	light.look(Vector2.ZERO, 0.0, 0.0)
	set_process(false)
	hide()
	Diagnostics.trace("carousel", "properties closed: no model")
	closed.emit()


func _return_model() -> void:
	if is_instance_valid(_model) and is_instance_valid(_model_parent) and _model.get_parent() != _model_parent:
		_model.reparent(_model_parent, false)
		_model_parent.move_child(_model, 0)
	if is_instance_valid(_medium):
		_medium.queue_free()
	_medium = null
	_model = null


func _exit_tree() -> void:
	_return_model()


func _point_at_focus(centre: Vector2, ring: float) -> void:
	var anchor := Vector2.ZERO
	var at := Vector2.ZERO
	if _zone.has_focus():
		var box := _zone.get_rect()
		anchor = Vector2(box.end.x, box.position.y + 0.3 * box.size.y) if _kind == LabelZone.Shape.RECTANGLE \
			else Vector2(centre.x, box.get_center().y) + Vector2.from_angle(_RIM_ANGLE) * ring
		at = anchor + Vector2(_CAPTION_AWAY, -_CAPTION_AWAY)
		_callout.point(tr("Label image"), at, anchor)
	elif _name.has_focus():
		var box := _name.get_rect()
		anchor = Vector2(box.end.x, box.get_center().y)
		_callout.point(tr("Game name"), anchor + Vector2(_CAPTION_AWAY, 0.0), anchor)
	else:
		_callout.clear()


func _close() -> void:
	_refresh_profiles()
	_busy = true
	_release_focus()
	_callout.timeline = true
	_callout.clear()
	_back_profile = true
	_travel = 1.0
	_direction = -1


func _tick_travel(delta: float) -> void:
	_travel = clampf(_travel + delta * _direction / (_BACK_S if _back_profile else _OPEN_S), 0.0, 1.0)
	_apply_travel()
	if _travel == 1.0 and _direction > 0:
		_direction = 0
		_staging = _on_properties
		_callout.timeline = false
		_busy = false
		_zone.grab_focus()
	elif _travel == 0.0 and _direction < 0:
		_direction = 0
		_busy = false
		_step = Step.CLOSED
		if _framed_game:
			_show_kept_label()
		row.stage = 0.0
		row.neighbours = 1.0
		row.pose_selected()
		_return_model()
		for item in behind:
			item.show()
			item.modulate.a = 1.0
		light.look(Vector2.ZERO, 0.0, 0.0)
		set_process(false)
		hide()
		Diagnostics.trace("properties", "closed")
		closed.emit()


func _refresh_profiles() -> void:
	_opening_parts = {
		Part.MEDIUM: Interval.new(0.0, _TRAVEL_S, StudioTokens.TR_PROPERTIES_TRAVEL_S_CURVE),
		Part.POOL: Interval.new(0.0, StudioTokens.TR_PROPERTIES_POOL_S, StudioTokens.TR_PROPERTIES_POOL_S_CURVE),
		Part.NEIGHBOURS: Interval.new(0.0, StudioTokens.TR_PROPERTIES_FADE_S, Motion.Easing.LINEAR, 1.0, 0.0),
		Part.BEHIND: Interval.new(0.0, StudioTokens.TR_PROPERTIES_FADE_S, Motion.Easing.LINEAR, 1.0, 0.0),
		Part.ZONE: Interval.new(StudioTokens.TR_PROPERTIES_ZONE_AT_S, maxf(0.001, _OPEN_S - StudioTokens.TR_PROPERTIES_ZONE_AT_S), Motion.Easing.EASE_OUT),
		Part.NAME: Interval.new(StudioTokens.TR_PROPERTIES_NAME_AT_S, maxf(0.001, _OPEN_S - StudioTokens.TR_PROPERTIES_NAME_AT_S), Motion.Easing.ARRIVE),
		Part.CALLOUT: Interval.new(StudioTokens.TR_PROPERTIES_CALLOUT_AT_S, maxf(0.001, _OPEN_S - StudioTokens.TR_PROPERTIES_CALLOUT_AT_S)),
		Part.HINTS: Interval.new(0.2, 0.15),
	}
	_back_parts = {
		Part.MEDIUM: Interval.new(0.0, _TRAVEL_S, StudioTokens.TR_PROPERTIES_TRAVEL_S_CURVE, 1.0, 0.0),
		Part.POOL: Interval.new(0.0, 0.3, Motion.Easing.EASE_IN, 1.0, 0.0),
		Part.NEIGHBOURS: Interval.new(0.28, 0.1),
		Part.BEHIND: Interval.new(0.22, 0.16),
		Part.ZONE: Interval.new(0.0, 0.1, Motion.Easing.LINEAR, 1.0, 0.0),
		Part.NAME: Interval.new(0.0, 0.16, Motion.Easing.EASE_IN, 1.0, 0.0),
		Part.CALLOUT: Interval.new(0.0, 0.12, Motion.Easing.LINEAR, 1.0, 0.0),
		Part.HINTS: Interval.new(0.0, StudioTokens.TR_PROPERTIES_FADE_S, Motion.Easing.LINEAR, 1.0, 0.0),
	}


func _part(part: Part) -> float:
	var profile := _back_parts if _back_profile else _opening_parts
	var elapsed := (1.0 - _travel) * _BACK_S if _back_profile else _travel * _OPEN_S
	return profile[part].at(elapsed)


func _apply_travel() -> void:
	var moving := _part(Part.MEDIUM)
	_staging = _in_row.towards(_on_properties, moving)
	var target := Transform3D(Basis.from_scale(Vector3.ONE * _on_properties.size), row.to_local(Vector3(0.0, 0.2, row.global_position.z)))
	target.origin -= target.basis * _model_centre
	_staging.darkness = _part(Part.POOL)
	_travel_stand = _row_stand.interpolate_with(target, moving)
	row.stand_selected(_travel_stand, 0.0, 0.0)
	row.stage = moving
	row.neighbours = _part(Part.NEIGHBOURS)
	for item in behind:
		item.show()
		item.modulate.a = _part(Part.BEHIND)
	_properties.modulate.a = 1.0
	_zone.modulate.a = _part(Part.ZONE)
	_zone.scale = Vector2.ONE * lerpf(0.92 if _back_profile else 0.96, 1.0, _zone.modulate.a)
	_name.modulate.a = _part(Part.NAME)
	_callout.timeline = true
	_callout.modulate.a = _part(Part.CALLOUT)
	_hints.modulate.a = _part(Part.HINTS)
	if _travel == 1.0:
		for item in behind:
			item.hide()
	_zone.pivot_offset = _zone.size / 2.0


func _name_drop() -> float:
	return _NAME_RISE * (1.0 - _part(Part.NAME)) if _direction != 0 else 0.0


func _show_name(name_button: Button, title: String) -> void:
	name_button.text = title
	var line := StudioText.new(title, StudioTokens.Face.JAKARTA_800, 53.76, -0.035)
	# The name is centred, so the caption pointing at its end must fit on its right.
	var caption := StudioText.new(tr("Game name"), StudioTokens.Face.JAKARTA_700, 23.04)
	line.fit(minf(_NAME_ROOM, size.x - 2.0 * (_CAPTION_AWAY + caption.width + 30.72 + _CAPTION_EDGE) - 61.44))
	name_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	name_button.size = Vector2(line.width + 61.44, line.height + 12.8)
	if _name_text:
		_name_text.line = line
		_name_text.gel = _gel
		_name_text.queue_redraw()


## The images the label can show, the current one with the focus.
func _open_labels() -> void:
	Sounds.play(SoundEffects.Cue.OPEN)
	_busy = true
	_release_focus()
	_downloaded.clear()
	if not android.label_variant_downloaded.is_connected(_on_label_variant_downloaded):
		android.label_variant_downloaded.connect(_on_label_variant_downloaded)
	var started := Time.get_ticks_msec()
	var answer := await android.label_variants(_game)
	if not answer.ok:
		Diagnostics.trace("properties", "no images listed (%s): %s" % [answer.code, answer.detail])
	Diagnostics.trace("properties", "%d images of %s listed in %d ms" % [
		answer.variants.size(), _game.title, Time.get_ticks_msec() - started])
	_step = Step.LABELS
	_fill_cards(answer.variants)
	await _move([_properties, _zone], [_labels], _on_labels, _to_labels)
	_focus_current()


## Back to the properties from [param screen], the focus on [param focused], the disc showing its own
## label (the one kept, or as it was), unless [param own_label] is false: what it shows stays then.
func _back_to_properties(screen: Control = _labels, move := _from_labels, focused: Control = _zone,
		own_label := true) -> void:
	_step = Step.PROPERTIES
	if own_label:
		row.show_own_label()
	await _move([screen], [_properties, _zone], _on_properties, move)
	_clear_cards()
	focused.grab_focus()


func _fill_cards(variants: Array[AndroidServices.LabelVariant]) -> void:
	_clear_cards()
	for variant in variants:
		var card := LabelCard.new(variant.region, variant.source,
			"%s · %s" % [_region_name(variant.region), variant.source_name])
		card.focus_entered.connect(_preview.bind(card))
		card.pressed.connect(_choose.bind(card))
		_cards.add_child(card)
		_shape_card(card)
		var path: String = variant.path if variant.has_path else _downloaded.get(_image_key(variant.region, variant.source), "")
		if path:
			_read(card, path)
	var own := LabelCard.new("", "", tr("My own image"), true)
	own.focus_entered.connect(row.show_own_label)
	own.pressed.connect(_pick_own)
	_cards.add_child(own)
	_shape_card(own)
	if _game.label_own:
		if art.has_texture(_game):
			own.show_label(art.texture(_game))
		else:
			art.request(_game)
	_prompt.text = (tr("Choose the label's image") if variants
		else tr("No other image of this game is known"))


func _clear_cards() -> void:
	_reader.cancel_all()
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()


## The focus on the card of the image the label shows: the one chosen (the user's own picture
## included), else the first: the closest region's, or the user's own when there is none.
func _focus_current() -> void:
	var cards: Array[LabelCard] = []
	cards.assign(_cards.get_children())
	var chosen := cards.filter(func(card: LabelCard) -> bool:
		return (card.own and _game.label_own) or (not card.own and _game.has_label_region
			and card.region == _game.label_region and card.source == _game.label_source))
	for card: LabelCard in chosen + cards:
		card.grab_focus()
		return


func _region_cards() -> Array[LabelCard]:
	var cards: Array[LabelCard] = []
	for card: LabelCard in _cards.get_children():
		if not card.own:
			cards.append(card)
	return cards


func _preview(card: LabelCard) -> void:
	if card.is_ready():
		Diagnostics.trace("properties", "image of '%s' from %s on the disc" % [card.region, card.source])
		row.preview_label(card.label)


func _choose(card: LabelCard) -> void:
	if _busy:
		return
	if not card.is_ready():
		Diagnostics.trace("properties", "image of '%s' from %s not downloaded yet: not kept" % [card.region, card.source])
		return
	_busy = true
	_release_focus()
	var answer := await android.choose_label(_game, card.region, card.source)
	_busy = false
	if not answer.ok:
		Diagnostics.trace("properties", "label not kept (%s): %s" % [answer.code, answer.detail])
		card.grab_focus()
		choice_failed.emit()
		return
	Diagnostics.trace("properties", "%s: label of region '%s' from %s kept" % [_game.title, card.region, card.source])
	_game.has_label_region = true
	_game.label_region = card.region
	_game.label_source = card.source
	_game.label_own = false
	Sounds.play(SoundEffects.Cue.SUCCESS)
	art.add(answer.art, card.label)
	_back_to_properties()


## Opens the system's picker on the user's pictures, the cards fading out meanwhile; the picture
## picked is read to be framed ([method _on_picture_read]), and the cards come back if none is.
func _pick_own() -> void:
	if _busy:
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	_busy = true
	_release_focus()
	await create_tween().tween_property(_labels, ^"modulate:a", 0.0, _TO_PICKER_S).finished
	var started := Time.get_ticks_msec()
	_picture = await android.pick_label_picture()
	if not _picture.ok:
		Diagnostics.trace("properties", "no picture picked (%s): %s" % [_picture.code, _picture.detail])
		_back_from_picker()
		# Closing the picker is no failure; a picture that cannot be read, or no picker, is.
		if _picture.code != &"cancelled":
			choice_failed.emit()
		return
	Diagnostics.trace("properties", "picture of %dx%d picked in %d ms" % [
		_picture.size.x, _picture.size.y, Time.get_ticks_msec() - started])
	# The disc goes where it is framed while nothing shows: the cards have gone.
	_stage(1.0, _staging, _on_framing)
	_picture_reader.request("picture", _picture.path, "%s, own picture" % _game.title)


## The cards as they were before the picker, the focus on the user's own card.
func _back_from_picker() -> void:
	_stage(1.0, _staging, _on_labels)
	_labels.modulate.a = 1.0
	_busy = false
	_own_card().grab_focus()


## The card of the user's own picture: the last one.
func _own_card() -> LabelCard:
	return _cards.get_child(-1) as LabelCard


func _on_picture_read(_key: String, picture: Texture2D) -> void:
	if _step != Step.LABELS:
		return
	if not picture:
		Diagnostics.trace("properties", "picture picked not readable")
		_back_from_picker()
		choice_failed.emit()
		return
	_picture_texture = picture
	_framing = LabelFraming.new(row.selected_label_proportion())
	_step = Step.FRAMING
	row.preview_label(_picture_texture, _framing.window(_picture.size))
	await _move([_labels], [_framing_screen], _on_framing, _from_picker)


## Moves and zooms the picture being framed as the stick and L1 / R1 are held, for [param delta]
## seconds.
func _frame(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var zoom := Input.get_axis(&"label_zoom_out", &"label_zoom_in")
	if push.is_zero_approx() and is_zero_approx(zoom):
		return
	# The picture follows the stick: what is right of the label comes into it as it goes left.
	_framing.move(-push * _FRAMING_SPEED * delta, _picture.size)
	_framing.zoom_by(pow(_ZOOM_SPEED, zoom * delta), _picture.size)
	row.preview_label(_picture_texture, _framing.window(_picture.size))


## Keeps the picture as framed on the label, then goes back to the properties; stays on the
## framing when it cannot be kept.
func _keep_own() -> void:
	_busy = true
	var answer := await android.keep_own_label(_game, _framing)
	if not answer.ok:
		Diagnostics.trace("properties", "own picture not kept (%s): %s" % [answer.code, answer.detail])
		_busy = false
		choice_failed.emit()
		return
	Diagnostics.trace("properties", "%s: own picture kept, zoom %.2f, centre %s" % [_game.title, _framing.zoom, _framing.centre])
	Sounds.play(SoundEffects.Cue.SUCCESS)
	_game.label_own = true
	_game.has_label_region = false
	# The picture as framed stays on the disc until the image the plugin cut is read.
	art.add(answer.art)
	_framed_game = _game.id
	art.request(_game)
	_back_to_properties(_framing_screen, _from_editing, _zone, false)


## Back to the cards from the framing, nothing kept; the focus on the user's own card.
func _back_to_labels() -> void:
	_step = Step.LABELS
	row.show_own_label()
	_picture_texture = null
	await _move([_framing_screen], [_labels], _on_labels, _framing_left)
	_own_card().grab_focus()


## The disc shows the image kept for its label, read now, in place of the picture as framed.
func _show_kept_label() -> void:
	_framed_game = ""
	_picture_texture = null
	row.show_own_label()


func _on_art_loaded(game_id: String) -> void:
	if _medium and _game and game_id == _game.id:
		_medium.crossfade(0.0 if art.has_texture(_game) else 1.0)
	if game_id == _framed_game:
		_show_kept_label()
	elif _step == Step.LABELS and game_id == _game.id and _game.label_own:
		_own_card().show_label(art.texture(_game))


func _naming_press(event: InputEvent) -> bool:
	if _busy:
		return false
	for action in _naming_presses:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_naming_presses[action].call()
			return true
	return false


func _renaming(request: Callable) -> AndroidServices.Result:
	_busy = true
	var focused := get_viewport().gui_get_focus_owner()
	_release_focus()
	var answer: AndroidServices.Result = await request.call()
	_busy = false
	if not answer.ok:
		Diagnostics.trace("properties", "name not kept (%s): %s" % [answer.code, answer.detail])
		if focused:
			focused.grab_focus()
		rename_failed.emit()
	return answer


## The keyboard under the disc, the name as it is to start with.
func _open_naming() -> void:
	if _busy:
		return
	Sounds.play(SoundEffects.Cue.OPEN)
	_step = Step.NAMING
	_naming.open(_game.title, _game.own_title())
	await _move([_properties, _zone], [_naming], _on_naming, _to_naming)
	_naming.focus_keys()


## Keeps the name typed, then goes back to the properties; stays on the keyboard when it cannot be
## kept.
func _keep_name() -> void:
	if _busy:
		return
	# A name left as it was is no name to keep: the game keeps its own title.
	var typed := _naming.typed()
	if typed.strip_edges() == _game.title:
		Sounds.play(SoundEffects.Cue.SELECT)
		_back_to_properties(_naming, _from_editing, _name)
		return
	var answer := await _renaming(android.rename_game.bind(_game, typed)) as AndroidServices.Renamed
	if not answer.ok:
		return
	Diagnostics.trace("properties", "%s now shown as '%s'" % [_game.id, answer.title])
	_game.title = answer.title
	_game.has_original_title = answer.has_original_title
	_game.original_title = answer.original_title
	_show_name(_name, _game.title)
	Sounds.play(SoundEffects.Cue.SUCCESS)
	name_kept.emit()
	_back_to_properties(_naming, _from_editing, _name)


func _on_label_variant_downloaded(variant: AndroidServices.LabelVariant) -> void:
	if not _game or variant.game_id != _game.id:
		return
	if not variant.has_path:
		Diagnostics.trace("properties", "image of '%s' from %s not downloaded: %s" % [
			variant.region, variant.source, variant.failure])
		return
	_downloaded[_image_key(variant.region, variant.source)] = variant.path
	for card in _region_cards():
		if card.region == variant.region and card.source == variant.source:
			_read(card, variant.path)


func _read(card: LabelCard, path: String) -> void:
	_reader.request(_image_key(card.region, card.source), path, "%s, %s from %s" % [_game.title, card.region, card.source])


func _on_image_read(key: String, image: Texture2D) -> void:
	if not image:
		return
	for card in _region_cards():
		if _image_key(card.region, card.source) == key:
			card.show_label(image)
			if card.has_focus():
				_preview(card)


## What names an image among a game's: its [param source], then its [param region].
func _image_key(region: String, source: String) -> String:
	return source + "/" + region


## How the art sources' [param region] reads on a card.
func _region_name(region: String) -> String:
	return tr(region) if region else tr("No region")


func _place() -> void:
	row.pose_selected()
	row.stage = _staging.amount
	row.neighbours = 1.0 - _staging.amount
	var centre := row.to_local(Vector3(0.0, _staging.height, row.global_position.z))
	var basis := Basis.from_scale(Vector3.ONE * _staging.size)
	row.staged = Transform3D(basis, centre - basis * _model_centre)
	_travel_stand = row.staged


func _on_zone_input(event: InputEvent) -> void:
	# Touches go on to the carousel too: it turns the disc with a drag, and lifts its own finger.
	var now: int = clock.call()
	var tapped := _finger.read(event, now) == Finger.Gesture.TAP
	if (tapped or (event.is_action_pressed(&"ui_accept") and not event.is_echo())) and not _busy:
		if not tapped:
			_zone.accept_event()
		_open_labels()


## By touch, the picture being framed follows the finger.
func _on_framing_input(event: InputEvent) -> void:
	var now: int = clock.call()
	var dragged := _finger.read(event, now) == Finger.Gesture.DRAG
	if dragged and not _busy:
		_framing_screen.accept_event()
		_framing.move(-_finger.moved / _label_px, _picture.size)
		row.preview_label(_picture_texture, _framing.window(_picture.size))


func _shape_card(card: LabelCard) -> void:
	var thumbnail := card.get_child(0).get_child(0) as TextureRect
	var shader := thumbnail.material as ShaderMaterial
	shader.set_shader_parameter(&"cartridge", _kind == LabelZone.Shape.RECTANGLE)
	shader.set_shader_parameter(&"proportion", row.selected_label_proportion())


class _NameText extends Control:
	var line: StudioText
	var gel := StudioTokens.NEUTRAL
	var _backing: SatinPanel.Backing

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var button := get_parent() as Button
		if button.has_focus():
			if not _backing:
				_backing = SatinPanel.Backing.new(self, StudioTokens.Look.FOCUS)
				_backing.tint = gel
			_backing.place(Rect2(Vector2.ZERO, size), 17.92)
		else:
			_backing = null
		if line:
			line.draw(self, Vector2(30.72, 6.4), StudioTokens.INK)


class Interval extends RefCounted:
	var start: float
	var duration: float
	var curve: Motion.Easing
	var from: float
	var to: float

	func _init(at_s: float, seconds: float, easing := Motion.Easing.LINEAR, first := 0.0, last := 1.0) -> void:
		start = at_s
		duration = seconds
		curve = easing
		from = first
		to = last

	func at(elapsed: float) -> float:
		var part := Motion.eased(curve, clampf((elapsed - start) / duration, 0.0, 1.0))
		return lerpf(from, to, part)
