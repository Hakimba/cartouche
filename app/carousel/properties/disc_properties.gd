# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscProperties
extends Control
## A game's properties. The selected game's medium travels from its place in the row to a still staging, facing
## front, under the light of an operating table ([OperatingLight]). Up and down select its label or its name, which
## the callout names. A on the label offers the sources' images and the system's picker for a picture of the user's
## own, to preview, frame with the stick or by touch, and keep. A on the name opens the keyboard ([NameEditor]). B
## goes back from an editor, or the medium travels back into the row. Each move from one of its screens to another
## plays in three parts: what leaves goes, the 3D moves from one staging to the next, then what comes arrives
## ([Move]). No press counts while a staging moves ([member _busy]) or the plugin answers ([member _held]): two
## seconds into an answer, B goes back as it does there, the answer applied whenever it comes.

## Back on the screen behind, the model in its row again.
signal closed
## The image picked could not be kept.
signal choice_failed
## The game was given a name, or its own title back.
signal name_kept
## The typed name could not be stored.
signal rename_failed

enum Step { CLOSED, PROPERTIES, LABELS, FRAMING, NAMING }
enum Part { MEDIUM, POOL, NEIGHBOURS, BEHIND, ZONE, NAME, CALLOUT, HINTS }
## How what leaves a screen goes: fading, or sliding down as it fades.
enum Leave { FADE, SLIDE }
## How what comes arrives: fading in, or rising as it does.
enum Arrive { FADE, RISE }
## Which travel between the row and the staging shows: none, the opening's parts, or the way back's. Either can be
## played backwards (B during the opening, X during the way back).
enum Travel { NONE, OPENING, CLOSING }
## What picking a picture of one's own came to: read, it shows on the disc to be framed; the picker was closed
## without one; or it could not be picked or read.
enum Own { FRAMED, NONE, FAILED }

const _CAPTION_AWAY := 56.32
const _NAME_GAP := 23.04
const _NAME_ROOM := 1098.56
## The caption beside the name stays this far inside the screen's edge.
const _CAPTION_EDGE := 28.8
const _RIM_ANGLE := -0.6
## How long the cards take to fade before the picker opens.
const _TO_PICKER_S := 0.2
## How far, in pixels, what arrives rises and what leaves slides down.
const _RISE := 30.0
const _SLIDE := 40.0

## Where the disc stands on each screen; the properties screen's own staging ([member _on_properties])
## is fitted to each medium instead.
static var _in_row := Staging.new(0.0, 0.18, 1.0, 0.0, 400.0)
static var _on_labels := Staging.new(1.0, 0.34, 0.78, 0.45, 300.0)
## Framing a picture of one's own: the disc back in the middle, a little above the camera's axis.
static var _on_framing := Staging.new(1.0, 0.12, 1.1, 0.4, 400.0)
## Typing its name: the disc high, at half its size.
static var _on_naming := Staging.new(1.0, 0.56, 0.5, 0.35, 220.0)
## The moves between the screens, in seconds.
static var _to_labels := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)
static var _from_labels := Move.new(Leave.SLIDE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)
## The picker covered the screen: the disc was put in place as it closed, the framing fades in.
static var _from_picker := Move.new(Leave.FADE, 0.0, 0.0, Arrive.FADE, 0.2, 0.0)
static var _framing_left := Move.new(Leave.FADE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)
static var _from_editing := Move.new(Leave.FADE, 0.15, 0.42, Arrive.FADE, 0.22, 0.26)
static var _to_naming := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)

## Set by the carousel before the first [method open], and given to the label chooser.
var android: AndroidServices:
	set(services):
		android = services
		_chooser.android = services
## Milliseconds since the start, as fingers are read (see [member Carousel.clock]).
var clock := Callable(Time, &"get_ticks_msec")
## Set by the carousel before the first opening.
var light: OperatingLight
## What the screen behind shows over its row: it leaves while the properties show.
var behind: Array[CanvasItem] = []
## Set by the carousel before the first [method open].
var row: ShelfRow
var art: GameArt:
	set(images):
		art = images
		art.loaded.connect(_on_art_loaded)
var _staging: Staging
var _busy := false:
	set(value):
		_busy = value
		_hold_fingers()
## The plugin's answer awaited, one at a time: it holds the presses but B once it has lasted
## [constant ScreenFlow.HeldSave.ESCAPE_MS].
var _held := ScreenFlow.HeldSave.new(func() -> int: return clock.call())
## B let the answer awaited go: it is no longer awaited for what it was asked for.
var _left := false
var _on_properties := Staging.new(1.0, 0.2, 0.98, 1.0, 400.0)
var _step := Step.CLOSED
var _game: AndroidServices.Game
## The finger on the label (a tap opens its images) and on the picture being framed (a drag moves
## it); how wide the label shows, in pixels, which a drag across it moves the picture by.
var _finger := Finger.new()
var _label_px := 1.0
var _kind := LabelZone.Shape.DISC
var _gel := StudioTokens.NEUTRAL
var _medium: MediaView
## The selected game's model and label, lent by the row while the properties show: its model is in [member _medium].
var _lent: LabelledModel
var _label_vertices := PackedVector3Array()
var _body_vertices := PackedVector3Array()
var _model_centre := Vector3.ZERO
var _travel_stand := Transform3D.IDENTITY
## The travel between the row and the staging, its parts as [member _travel] has them.
var _clock := Motion.Timeline.new(_apply_travel)
var _travel := Travel.NONE
var _name_text: _NameText
## What the overlays were last placed for: the stand, the camera, where it is, how it projects, the canvas and the
## window; nothing before the first placing.
var _projected := _Placing.new()
var _body_box := Rect2()
var _pool_opacity := -1.0

@onready var _properties: Control = %Properties
@onready var _zone: LabelZone = %Zone
@onready var _labels: Control = %Labels
@onready var _chooser := LabelChooser.new(%Cards as HBoxContainer, %Prompt as Label)
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
	hide()
	set_process(false)
	add_to_group(SoundEffects.MOVES)
	_name.pressed.connect(_open_naming)
	_naming.submitted.connect(_keep_name)
	add_child(_chooser)
	_chooser.card_pressed.connect(_choose)
	_chooser.own_pressed.connect(_pick_own)
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
	_clock.arrived.connect(_travelled)


func _process(delta: float) -> void:
	# The travel first: the overlays are placed on where it puts the medium this frame.
	_clock.tick(minf(delta, 0.1))
	if not _medium:
		return
	if _step == Step.FRAMING and not _holding():
		_chooser.frame(delta)
	# The staged disc stands still: whatever its look became (label, ring) is drawn again once, as the row does.
	if _lent.dirty:
		_medium.redraw()
		_lent.dirty = false
	var at := _travel_stand if _clock.is_playing() or (_step == Step.PROPERTIES and not _holding()) else row.selected_stand()
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
	if not _projected.moved(stand, camera, get_viewport().get_visible_rect().size, get_window().size):
		return false
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
	if _step == Step.CLOSED or event.is_echo() or _clock.is_playing():
		return
	if _step == Step.FRAMING and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if not _holding():
			_keep_own()
		return
	if _step == Step.NAMING and _naming_press(event):
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if not _holding():
		_go_back()


## B: back from an editor, or the medium travels back into the row.
func _go_back() -> void:
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


func _input(event: InputEvent) -> void:
	if _clock.is_playing() and event.is_pressed():
		if event.is_action_pressed(&"screen_back"):
			_travel_to(false)
		elif event.is_action_pressed(&"open_properties"):
			_travel_to(true)
		get_viewport().set_input_as_handled()
		return
	# The pad's presses while the plugin answers; B lets the answer go once it has lasted.
	if _held.pending() and _step != Step.CLOSED and (event is InputEventKey or event is InputEventJoypadButton
			or event is InputEventJoypadMotion or event is InputEventAction) and event.is_pressed():
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"screen_back") and not _busy and _held.lasted():
			Diagnostics.trace("properties", "%s let go" % _held.key)
			_left = true
			_go_back()
		return
	var pinch := event as InputEventMagnifyGesture
	if pinch and _step == Step.FRAMING and not _holding():
		get_viewport().set_input_as_handled()
		_chooser.pinch(pinch)


## Whether the properties show, or are coming or going.
func is_open() -> bool:
	return _step != Step.CLOSED or _busy


## The light of [param medium] (its one without a picture when [param blank]) between its properties and the games
## row, [param in_row] of the way to the row: the lights of both, each by its share, so that it changes light as it
## travels and never at once.
static func light_of(medium: String, blank: bool, in_row := 0.0) -> StudioLights.Rig:
	return StudioLights.mixed(StudioLights.rig_of(medium, &"properties", blank), StudioLights.rig_of(medium, &"games", blank),
		in_row)


## Opens the properties of the selected game of the row.
func open() -> void:
	_game = row.selected_game()
	_kind = LabelZone.Shape.RECTANGLE if MediumManifest.is_cartridge(row.selected_medium()) else LabelZone.Shape.DISC
	var focus := get_theme_stylebox(&"focus", &"Button") as SatinStyle
	_gel = focus.gel if focus else StudioTokens.NEUTRAL
	_show_name(_name, _game.title)
	_step = Step.PROPERTIES
	_busy = true
	show()
	_labels.hide()
	_chooser.row = row
	_chooser.art = art
	if not _lend_model():
		_abort_model()
		return
	_staging = _in_row
	_travel = Travel.OPENING
	_properties.show()
	_zone.show()
	_zone.grab_focus()
	set_process(true)
	_clock.stand(0.0)
	_travel_to(true)
	Diagnostics.trace("carousel", "zone shape=%s" % ("rect" if _kind == LabelZone.Shape.RECTANGLE else "circle"))
	Diagnostics.trace("properties", "open %s" % _game.title)


func _lend_model() -> bool:
	var lent := row.lend_selected()
	if not lent:
		return false
	var model := lent.instance
	var label := model.get_node_or_null("Label")
	if not label is MeshInstance3D or not _meshes_ready(model):
		return false
	var label_mesh: MeshInstance3D = label
	# Measured where it stands in the row, before it leaves it.
	var label_vertices := _vertices(label_mesh, lent)
	var body_vertices := _vertices(model, lent)
	var box := Plinth.bounds(model, lent)
	if label_vertices.is_empty() or body_vertices.is_empty() or maxf(box.size.x, box.size.y) <= 0.0:
		return false
	_lent = lent
	_label_vertices = label_vertices
	# A cartridge's body ends where its mesh does, higher than its box's near corners; a disc's box is exact.
	_body_vertices = body_vertices if _kind == LabelZone.Shape.RECTANGLE else _corners(box)
	_model_centre = box.get_center()
	_on_properties.size = 1.2 / maxf(box.size.x, box.size.y) * (0.92 if _kind == LabelZone.Shape.RECTANGLE else 0.98)
	_medium = MediaView.new()
	_medium.camera = get_viewport().get_camera_3d()
	add_child(_medium)
	move_child(_medium, 0)
	lent.lend()
	_medium.show_medium(model, light_of(_game.medium, false), light_of(_game.medium, true))
	_medium.crossfade(0.0 if art.has_texture(_game) else 1.0)
	_projected = _Placing.new()
	_pool_opacity = -1.0
	return true


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
	_clock.stop()
	_busy = false
	row.neighbours = 1.0
	row.stand(SelectedStand.new())
	for item in behind:
		item.show()
		item.modulate.a = 1.0
	light.look(Vector2.ZERO, 0.0, 0.0)
	set_process(false)
	hide()
	Diagnostics.trace("carousel", "properties closed: no model")
	closed.emit()


func _return_model() -> void:
	if is_instance_valid(_lent):
		_lent.take_back()
	if is_instance_valid(_medium):
		_medium.queue_free()
	_medium = null
	_lent = null


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
	_busy = true
	_release_focus()
	_callout.timeline = true
	_callout.clear()
	_travel = Travel.CLOSING
	_clock.seconds = 0.0
	_travel_to(false)


## The medium travels towards the staging ([param staged]) or the row, from where it is on the travel shown.
func _travel_to(staged: bool) -> void:
	assert(_travel != Travel.NONE, "DiscProperties: no travel to play")
	_clock.play((0.0 if staged else StudioTokens.TR_PROPERTIES_BACK_S) if _travel == Travel.CLOSING
		else (StudioTokens.TR_PROPERTIES_OPEN_S if staged else 0.0))


## Whether the travel shown stands at the staging.
func _staged() -> bool:
	return _clock.seconds == (0.0 if _travel == Travel.CLOSING else StudioTokens.TR_PROPERTIES_OPEN_S)


func _travelled() -> void:
	var staged := _staged()
	_travel = Travel.NONE
	_busy = false
	if staged:
		_staging = _on_properties
		_callout.timeline = false
		_zone.grab_focus()
	else:
		_step = Step.CLOSED
		if _chooser.framed_game:
			_chooser.show_kept_label()
		row.neighbours = 1.0
		_return_model()
		row.stand(SelectedStand.new())
		# Drawn by the row in this very frame: its own turn may have passed, and this view goes.
		row.arrange()
		for item in behind:
			item.show()
			item.modulate.a = 1.0
		light.look(Vector2.ZERO, 0.0, 0.0)
		set_process(false)
		hide()
		Diagnostics.trace("properties", "closed")
		closed.emit()


## How far [param part] has come on the travel shown: the opening's, or the way back's.
func _part(part: Part) -> float:
	var t := _clock.seconds
	if _travel == Travel.CLOSING:
		match part:
			Part.MEDIUM:
				return 1.0 - Motion.phase(t, 0.0, StudioTokens.TR_PROPERTIES_TRAVEL_S, StudioTokens.TR_PROPERTIES_TRAVEL_S_CURVE)
			Part.POOL:
				return 1.0 - Motion.phase(t, 0.0, 0.3, Motion.Easing.EASE_IN)
			Part.NEIGHBOURS:
				return Motion.phase(t, 0.28, 0.1)
			Part.BEHIND:
				return Motion.phase(t, 0.22, 0.16)
			Part.ZONE:
				return 1.0 - Motion.phase(t, 0.0, 0.1)
			Part.NAME:
				return 1.0 - Motion.phase(t, 0.0, 0.16, Motion.Easing.EASE_IN)
			Part.CALLOUT:
				return 1.0 - Motion.phase(t, 0.0, 0.12)
		return 1.0 - Motion.phase(t, 0.0, StudioTokens.TR_PROPERTIES_FADE_S)
	var open_s := StudioTokens.TR_PROPERTIES_OPEN_S
	match part:
		Part.MEDIUM:
			return Motion.phase(t, 0.0, StudioTokens.TR_PROPERTIES_TRAVEL_S, StudioTokens.TR_PROPERTIES_TRAVEL_S_CURVE)
		Part.POOL:
			return Motion.phase(t, 0.0, StudioTokens.TR_PROPERTIES_POOL_S, StudioTokens.TR_PROPERTIES_POOL_S_CURVE)
		Part.NEIGHBOURS, Part.BEHIND:
			return 1.0 - Motion.phase(t, 0.0, StudioTokens.TR_PROPERTIES_FADE_S)
		Part.ZONE:
			return Motion.phase(t, StudioTokens.TR_PROPERTIES_ZONE_AT_S, open_s - StudioTokens.TR_PROPERTIES_ZONE_AT_S,
				Motion.Easing.EASE_OUT)
		Part.NAME:
			return Motion.phase(t, StudioTokens.TR_PROPERTIES_NAME_AT_S, open_s - StudioTokens.TR_PROPERTIES_NAME_AT_S,
				Motion.Easing.ARRIVE)
		Part.CALLOUT:
			return Motion.phase(t, StudioTokens.TR_PROPERTIES_CALLOUT_AT_S, open_s - StudioTokens.TR_PROPERTIES_CALLOUT_AT_S)
	return Motion.phase(t, 0.2, 0.15)


func _apply_travel() -> void:
	assert(_travel != Travel.NONE, "DiscProperties: no travel shown")
	var moving := _part(Part.MEDIUM)
	_staging = _in_row.towards(_on_properties, moving)
	var target := Transform3D(Basis.from_scale(Vector3.ONE * _on_properties.size), row.to_local(Vector3(0.0, 0.2, row.global_position.z)))
	target.origin -= target.basis * _model_centre
	_staging.darkness = _part(Part.POOL)
	# From where the row has it now: it went on floating there while its properties showed.
	_travel_stand = row.selected_in_row().interpolate_with(target, moving)
	_medium.remix(light_of(_game.medium, false, 1.0 - moving), light_of(_game.medium, true, 1.0 - moving))
	row.stand(SelectedStand.outside(_travel_stand, 0.0, 0.0, moving))
	row.neighbours = _part(Part.NEIGHBOURS)
	for item in behind:
		item.show()
		item.modulate.a = _part(Part.BEHIND)
	_properties.modulate.a = 1.0
	_zone.modulate.a = _part(Part.ZONE)
	_zone.scale = Vector2.ONE * lerpf(0.92 if _travel == Travel.CLOSING else 0.96, 1.0, _zone.modulate.a)
	_name.modulate.a = _part(Part.NAME)
	_callout.timeline = true
	_callout.modulate.a = _part(Part.CALLOUT)
	_hints.modulate.a = _part(Part.HINTS)
	if _staged():
		for item in behind:
			item.hide()
	_zone.pivot_offset = _zone.size / 2.0


func _name_drop() -> float:
	return StudioTokens.TR_PROPERTIES_RISE_PX * (1.0 - _part(Part.NAME)) if _clock.is_playing() else 0.0


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


## Holds every press while the picker and its picture's read run: no focus meanwhile. With [method _move], the travel
## ([method open], [method _close], [method _travelled]) and [method _abort_model], the only writer of [member _busy].
func _during(work: Callable) -> Variant:
	_busy = true
	_release_focus()
	var answer: Variant = await work.call()
	_busy = false
	return answer


## Asks the plugin [param request] ([param key] naming it), every press held but B once it has lasted
## ([member _held]), no focus meanwhile; its answer, or null when B let it go first, [param request] then applying
## what it keeps alone and [param failed] saying it was not kept, wherever the player is by then.
func _asking(key: StringName, request: Callable, failed := Signal()) -> Variant:
	_held.start(key, null)
	_left = false
	_hold_fingers()
	_release_focus()
	var answer: AndroidServices.Result = await request.call()
	_held.end()
	_hold_fingers()
	if _left and not failed.is_null() and not answer.ok:
		failed.emit()
	return null if _left else answer


## Whether the plugin's answer is awaited, B having let it go or not.
func awaits_answer() -> bool:
	return _held.pending()


## Whether no press counts: a staging moving, or the plugin's answer awaited.
func _holding() -> bool:
	return _busy or _held.pending()


func _hold_fingers() -> void:
	# A finger on a control would give it the focus, and a card its preview, through the hold.
	mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED if _holding() else MOUSE_BEHAVIOR_INHERITED


## The images the label can show, the current one with the focus.
func _open_labels() -> void:
	Sounds.play(SoundEffects.Cue.OPEN)
	var listed: AndroidServices.LabelVariants = await _asking(&"label_variants", _chooser.ask.bind(_game, _kind))
	if listed == null:
		return
	_chooser.fill(listed)
	_step = Step.LABELS
	await _move([_properties, _zone], [_labels], _on_labels, _to_labels)
	_chooser.focus_current()


## Back to the properties from [param screen], the focus on [param focused], the disc showing its own
## label (the one kept, or as it was), unless [param own_label] is false: what it shows stays then.
func _back_to_properties(screen: Control = _labels, move := _from_labels, focused: Control = _zone,
		own_label := true) -> void:
	_step = Step.PROPERTIES
	if own_label:
		row.show_own_label()
	await _move([screen], [_properties, _zone], _on_properties, move)
	_chooser.clear()
	focused.grab_focus()


func _choose(card: LabelCard) -> void:
	if not card.is_ready():
		Diagnostics.trace("properties", "image of '%s' from %s not downloaded yet: not kept" % [card.region, card.source])
		return
	var answer: AndroidServices.Result = await _asking(&"choose_label", _chooser.choose.bind(card), choice_failed)
	if answer == null:
		return
	if not answer.ok:
		card.grab_focus()
		choice_failed.emit()
		return
	Sounds.play(SoundEffects.Cue.SUCCESS)
	_back_to_properties()


## Opens the system's picker on the user's pictures, the cards fading out meanwhile; the picture picked is read
## and framed, and the cards come back if none is.
func _pick_own() -> void:
	if _holding():
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	var own: Own = await _during(_read_own)
	if own == Own.FRAMED:
		await _move([_labels], [_framing_screen], _on_framing, _from_picker)
		return
	_back_from_picker()
	if own == Own.FAILED:
		choice_failed.emit()


## The cards fade, the picker opens, the picture picked is read and shown on the disc where it is framed.
func _read_own() -> Own:
	await create_tween().tween_property(_labels, ^"modulate:a", 0.0, _TO_PICKER_S).finished
	var picked := await _chooser.pick()
	if not picked.ok:
		# Closing the picker is no failure; a picture that cannot be read, or no picker, is.
		return Own.NONE if picked.code == AndroidServices.Result.CANCELLED else Own.FAILED
	# The disc goes where it is framed while nothing shows: the cards have gone.
	_stage(1.0, _staging, _on_framing)
	var picture: Texture2D = await _chooser.picture_read
	if not picture:
		Diagnostics.trace("properties", "picture picked not readable")
		return Own.FAILED
	_chooser.start_framing(picture)
	_step = Step.FRAMING
	return Own.FRAMED


## The cards as they were before the picker, the focus on the user's own card.
func _back_from_picker() -> void:
	_stage(1.0, _staging, _on_labels)
	_labels.modulate.a = 1.0
	_chooser.own_card().grab_focus()


## Keeps the picture as framed on the label, then goes back to the properties; stays on the
## framing when it cannot be kept.
func _keep_own() -> void:
	var answer: AndroidServices.Result = await _asking(&"keep_own_label", _chooser.keep_own, choice_failed)
	if answer == null:
		return
	if not answer.ok:
		choice_failed.emit()
		return
	Sounds.play(SoundEffects.Cue.SUCCESS)
	_back_to_properties(_framing_screen, _from_editing, _zone, false)


## Back to the cards from the framing, nothing kept; the focus on the user's own card.
func _back_to_labels() -> void:
	_step = Step.LABELS
	_chooser.drop_picture()
	await _move([_framing_screen], [_labels], _on_labels, _framing_left)
	_chooser.own_card().grab_focus()


func _on_art_loaded(game_id: String) -> void:
	if _medium and _game and game_id == _game.id:
		_medium.crossfade(0.0 if art.has_texture(_game) else 1.0)
	if game_id == _chooser.framed_game:
		if _step == Step.FRAMING:
			# The picture being framed is another one, and the disc shows it.
			_chooser.framed_game = ""
		else:
			# On the images the disc shows the card in focus: the way back shows the one kept.
			_chooser.show_kept_label(_step != Step.LABELS)
	if _step == Step.LABELS and game_id == _game.id and _game.label_own:
		_chooser.own_card().show_label(art.texture(_game))


func _naming_press(event: InputEvent) -> bool:
	if _holding():
		return false
	for action in _naming_presses:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_naming_presses[action].call()
			return true
	return false


## Gives [param game] the name [param typed], shown wherever it shows once kept.
func _rename(game: AndroidServices.Game, typed: String) -> AndroidServices.Renamed:
	var answer := await android.rename_game(game, typed)
	if not answer.ok:
		return answer
	Diagnostics.trace("properties", "%s now shown as '%s'" % [game.id, answer.title])
	game.title = answer.title
	game.has_original_title = answer.has_original_title
	game.original_title = answer.original_title
	if game == _game and _step != Step.CLOSED:
		_show_name(_name, game.title)
	name_kept.emit()
	return answer


## The keyboard under the disc, the name as it is to start with.
func _open_naming() -> void:
	if _holding():
		return
	Sounds.play(SoundEffects.Cue.OPEN)
	_step = Step.NAMING
	_naming.open(_game.title, _game.own_title())
	await _move([_properties, _zone], [_naming], _on_naming, _to_naming)
	_naming.focus_keys()


## Keeps the name typed, then goes back to the properties; stays on the keyboard when it cannot be
## kept.
func _keep_name() -> void:
	if _holding():
		return
	# A name left as it was is no name to keep: the game keeps its own title.
	var typed := _naming.typed()
	if typed.strip_edges() == _game.title:
		Sounds.play(SoundEffects.Cue.SELECT)
		_back_to_properties(_naming, _from_editing, _name)
		return
	var focused := get_viewport().gui_get_focus_owner()
	var answer: AndroidServices.Renamed = await _asking(&"rename_game", _rename.bind(_game, typed), rename_failed)
	if answer == null:
		return
	if not answer.ok:
		Diagnostics.trace("properties", "name not kept (%s): %s" % [answer.code, answer.detail])
		if focused:
			focused.grab_focus()
		rename_failed.emit()
		return
	Sounds.play(SoundEffects.Cue.SUCCESS)
	_back_to_properties(_naming, _from_editing, _name)


## Moves from one screen to the next as [param move] has it: [param leaving] goes, the 3D moves to
## [param staging], then [param arriving] comes; no focus meanwhile.
func _move(leaving: Array[CanvasItem], arriving: Array[CanvasItem], staging: Staging,
		move: Move) -> void:
	_busy = true
	_release_focus()
	var moves := create_tween().set_parallel()
	for item in leaving:
		moves.tween_property(item, ^"modulate:a", 0.0, move.leave_s)
		if move.leave == Leave.SLIDE and item is Control:
			var down := (item as Control).position.y + _SLIDE
			moves.tween_property(item, ^"position:y", down, move.leave_s)
	moves.tween_method(_stage.bind(_staging, staging), 0.0, 1.0, move.staging_s).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	for item in arriving:
		item.modulate.a = 0.0
		item.show()
		moves.tween_property(item, ^"modulate:a", 1.0, move.arrive_s).set_delay(move.arrive_after_s)
		if move.arrive == Arrive.RISE and item is Control:
			var y := (item as Control).position.y
			moves.tween_property(item, ^"position:y", y, move.arrive_s).from(y + _RISE) \
				.set_delay(move.arrive_after_s)
	await moves.finished
	for item in leaving:
		if item not in arriving:
			item.hide()
			item.modulate.a = 1.0
		if move.leave == Leave.SLIDE and item is Control:
			(item as Control).position.y -= _SLIDE
	_busy = false


## The 3D [param amount] of the way from [param from] to [param to].
func _stage(amount: float, from: Staging, to: Staging) -> void:
	_staging = to if amount >= 1.0 else from.towards(to, amount)
	_place()


## Stands the model as [member _staging] has it.
func _place() -> void:
	row.neighbours = 1.0 - _staging.amount
	var centre := row.to_local(Vector3(0.0, _staging.height, row.global_position.z))
	var basis := Basis.from_scale(Vector3.ONE * _staging.size)
	_travel_stand = Transform3D(basis, centre - basis * _model_centre)
	row.stand(SelectedStand.staged(_travel_stand, _staging.amount))


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()


func _on_zone_input(event: InputEvent) -> void:
	# Touches go on to the carousel too: it turns the disc with a drag, and lifts its own finger.
	var now: int = clock.call()
	var tapped := _finger.read(event, now) == Finger.Gesture.TAP
	if (tapped or (event.is_action_pressed(&"ui_accept") and not event.is_echo())) and not _holding():
		if not tapped:
			_zone.accept_event()
		_open_labels()


## By touch, the picture being framed follows the finger.
func _on_framing_input(event: InputEvent) -> void:
	var now: int = clock.call()
	var dragged := _finger.read(event, now) == Finger.Gesture.DRAG
	if dragged and not _holding():
		_framing_screen.accept_event()
		_chooser.move_picture(_finger.moved / _label_px)


## Where the model stands on a screen, and how the light falls on it.
class Staging:
	## How far the model is out of its row, from 0 (in it) to 1.
	var amount: float
	## The height of the model's centre, in world units, and its size, as a part of its size in
	## the middle of the row.
	var height: float
	var size: float
	## How dark the room is round it, from 0 to 1, and how far its pool of light reaches (in pixels
	## of the 1280×960 layout frame).
	var darkness: float
	var radius: float

	func _init(out_of_row: float, at: float, sized: float, dark: float, reach: float) -> void:
		amount = out_of_row
		height = at
		size = sized
		darkness = dark
		radius = reach

	## The staging [param part] of the way to [param other].
	func towards(other: Staging, part: float) -> Staging:
		return Staging.new(lerpf(amount, other.amount, part), lerpf(height, other.height, part),
			lerpf(size, other.size, part), lerpf(darkness, other.darkness, part),
			lerpf(radius, other.radius, part))


## How a move from one screen to the next plays: what leaves goes in [member leave_s] seconds,
## the 3D moves in [member staging_s] (easing in and out), what comes arrives in [member arrive_s]
## once [member arrive_after_s] have passed; all from the same start.
class Move:
	var leave: Leave
	var leave_s: float
	var staging_s: float
	var arrive: Arrive
	var arrive_s: float
	var arrive_after_s: float

	func _init(how_leaving: Leave, leaving_s: float, moving_s: float, how_arriving: Arrive,
			arriving_s: float, after_s: float) -> void:
		leave = how_leaving
		leave_s = leaving_s
		staging_s = moving_s
		arrive = how_arriving
		arrive_s = arriving_s
		arrive_after_s = after_s


## What the overlays were last placed for, kept field by field: compared at every frame, it allocates nothing.
class _Placing:
	var _placed := false
	var _stand := Transform3D.IDENTITY
	var _camera: Camera3D
	var _camera_at := Transform3D.IDENTITY
	var _projection := Projection()
	var _size := Vector2.ZERO
	var _pixels := Vector2i.ZERO

	## Whether [param stand] seen by [param camera] on a canvas of [param canvas] in a window of [param pixels] is
	## placed otherwise than last time; kept as the last placing then.
	func moved(stand: Transform3D, camera: Camera3D, canvas: Vector2, pixels: Vector2i) -> bool:
		var projection := camera.get_camera_projection()
		if _placed and stand == _stand and camera == _camera and camera.global_transform == _camera_at \
				and projection == _projection and canvas == _size and pixels == _pixels:
			return false
		_placed = true
		_stand = stand
		_camera = camera
		_camera_at = camera.global_transform
		_projection = projection
		_size = canvas
		_pixels = pixels
		return true


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
			line.draw(self, Vector2(30.72, 6.4), Backdrop.palette.ink)
