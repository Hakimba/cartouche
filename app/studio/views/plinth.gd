# SPDX-License-Identifier: GPL-3.0-or-later
class_name Plinth
extends Control
## A console's still picture standing on a plinth, its logo on the plinth's plate. The picture is the
## console's own model, upright and facing front at its start pose (`data/turntable.json`), lit by the light
## designed for it there ([StudioLights], screen `plinth`); it is rendered once per model folder, in a
## transparent view of its own world that is freed right after, and kept while the edge smoothing and the
## window scale it was drawn with hold. Nothing is
## shown until the picture exists; it then rises into place.

const TURNTABLE_FILE := "res://data/turntable.json"
## The model fits a circle of this diameter and stays under this height, in world units.
const _FIT_DIAMETER := 1.24
const _HEIGHT := 1.05
## The camera, seen from a little above.
const _CAMERA := Vector3(0.0, 0.994, 3.251)
const _CAMERA_TARGET := Vector3(0.0, 0.644, 0.0)
## The rise of a new picture: from this far down (px), in this time, by the curve `rise`.
const _RISE_PX := 20.48
const _RISE_S := 0.3

static var _starts: Dictionary = {}
## Keyed by [method _key]: the smoothing and the window scale change the picture.
static var _stills: Dictionary[String, ImageTexture] = {}
## The folders waiting for their picture, each with those asking for it (called with the picture).
static var _waiting: Dictionary[String, Array] = {}
static var _drawing := false
## Draws the picture of a folder; the tests put a stand-in where there is no renderer.
static var _drawer := _render

var _console := ""
## The call waiting for the picture of [member _console], withdrawn when another console is shown.
var _asked := Callable()
var _rise: Tween

@onready var _base: SatinPanel = $Base
@onready var _plate: LogoView = $Plate
@onready var _turntable: TextureRect = $Turntable


## A new plinth, showing nothing yet.
static func create() -> Plinth:
	return (load("res://studio/views/plinth.tscn") as PackedScene).instantiate()


## The yaw and the roll, in degrees, the model of the console in [param folder] starts at.
static func start_of(folder: String) -> Vector2:
	if _starts.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TURNTABLE_FILE))
		_starts = data["consoles"]
	var pose: Dictionary = _starts[folder]
	var start_yaw: float = pose["yaw"]
	var roll: float = pose["roll"]
	return Vector2(start_yaw, roll)


## The box holding every mesh under [param root], in the space of [param space], one of its
## parents; in the tree or not.
static func bounds(root: Node3D, space: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var into := Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != space:
			into = node.transform * into
			node = node.get_parent_node_3d()
		var part := into * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## The picture of the console in [param folder] if it was rendered already; none yet otherwise.
static func still_of(folder: String) -> Texture2D:
	return _stills.get(_key(folder))


static func _key(folder: String) -> String:
	var root := (Engine.get_main_loop() as SceneTree).root
	return "%s|%d|%s" % [folder, root.msaa_3d, StudioTokens.window_scale(root)]


## Calls [param done] with the picture of the console in [param folder], now when it exists, else once it
## is rendered. One picture is rendered at a time, the most recently asked first; a [param done] whose
## object was freed meanwhile is skipped.
static func request_still(folder: String, done: Callable) -> void:
	var drawn := still_of(folder)
	if drawn:
		done.call(drawn)
		return
	# Asked again, a folder moves to the front: the last key is the one drawn next.
	var askers: Array = _waiting.get(folder, [])
	_waiting.erase(folder)
	askers.append(done)
	_waiting[folder] = askers
	if not _drawing:
		_draw_waiting()


## [param done] no longer waits for the picture of [param folder]; one nobody waits for is not drawn.
static func withdraw(folder: String, done: Callable) -> void:
	var askers: Array = _waiting.get(folder, [])
	askers.erase(done)
	if askers.is_empty():
		_waiting.erase(folder)


static func _draw_waiting() -> void:
	_drawing = true
	while not _waiting.is_empty():
		var folder: String = _waiting.keys()[-1]
		var askers: Array = _waiting[folder]
		_waiting.erase(folder)
		var live := askers.filter(func(ask: Callable) -> bool: return ask.is_valid())
		if live.is_empty():
			continue
		var picture: ImageTexture = await _drawer.call(folder)
		if picture:
			_stills[_key(folder)] = picture
		for ask: Callable in live:
			if ask.is_valid():
				ask.call(picture)
	_drawing = false


## The console in [param folder] drawn once in a view of its own, at the size the plinth shows it, then
## the view freed; none where there is no renderer or it gives no picture.
static func _render(folder: String) -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		return null
	var scene := ConsoleManifest.of(folder).scene
	# Loaded off the main thread, so a console's model never stalls the frame the user is scrolling in.
	ResourceLoader.load_threaded_request(scene)
	while ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var packed := ResourceLoader.load_threaded_get(scene) as PackedScene
	if not packed:
		return null
	var root := (Engine.get_main_loop() as SceneTree).root
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = root.msaa_3d
	view.size = Vector2i((StudioTokens.TURNTABLE.size * StudioTokens.window_scale(root)).ceil())
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var environment := WorldEnvironment.new()
	environment.environment = StudioLights.environment_of(root)
	view.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 29.5
	camera.near = 0.05
	camera.far = 50.0
	view.add_child(camera)
	var spin := Node3D.new()
	var stand := Node3D.new()
	var model := packed.instantiate() as Node3D
	spin.add_child(stand)
	stand.add_child(model)
	view.add_child(spin)
	var start := start_of(folder)
	stand.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(start.y)), Vector3.ZERO)
	var box := bounds(model, spin)
	stand.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	spin.scale = Vector3.ONE * minf(_FIT_DIAMETER / Vector2(box.size.x, box.size.z).length(), _HEIGHT / box.size.y)
	spin.rotation.y = deg_to_rad(start.x)
	StudioLights.new(view, StudioLights.rig_of(folder, &"plinth"),
		spin.transform * bounds(stand, spin).get_center(), environment.environment)
	root.add_child(view)
	camera.look_at_from_position(_CAMERA, _CAMERA_TARGET)
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	return null if image == null or image.is_empty() else ImageTexture.create_from_image(image)


func _ready() -> void:
	_base.look = StudioTokens.Look.PLINTH
	_turntable.position = StudioTokens.TURNTABLE.position - StudioTokens.PLINTH.position
	_turntable.size = StudioTokens.TURNTABLE.size
	var top: TextureRect = $TopShadow
	top.position = StudioTokens.PLINTH_TOP_SHADOW.position
	top.size = StudioTokens.PLINTH_TOP_SHADOW.size
	var shade := (top.texture as GradientTexture2D).gradient
	shade.colors = PackedColorArray([StudioTokens.PLINTH_TOP_SHADE, Color(StudioTokens.PLINTH_TOP_SHADE, 0.0)])
	item_rect_changed.connect(_place_logo)


## Shows the logo of the console in [param folder] (under res://carousel/consoles) on the plate and its
## picture, which rises as soon as it exists; nothing of the previous console stays.
func show_console(folder: String) -> void:
	if folder == _console:
		return
	_withdraw()
	_console = folder
	_plate.show_logo(LogoView.Slot.PLINTH_PLATE, folder)
	_place_logo()
	_base.gel = Cyclorama.gel_of(ConsoleManifest.of(folder))
	_turntable.texture = null
	_asked = _show_still.bind(folder)
	request_still(folder, _asked)


## Presents the same picture again, as a chooser or form reopens.
func restart() -> void:
	_place_logo()
	_plate.modulate.a = 1.0
	if _turntable.texture:
		_rise_in()


## Clears the presentation.
func clear() -> void:
	_withdraw()
	_console = ""
	_base.gel = StudioTokens.NEUTRAL
	_turntable.texture = null
	_plate.show_logo(LogoView.Slot.PLINTH_PLATE, "")


## The console shown, its folder; none yet.
func console() -> String:
	return _console


func _withdraw() -> void:
	withdraw(_console, _asked)


func _show_still(picture: Texture2D, folder: String) -> void:
	if folder != _console or picture == null:
		return
	_turntable.texture = picture
	_rise_in()


## The picture rises into place and appears.
func _rise_in() -> void:
	if _rise:
		_rise.kill()
	var rest_y := StudioTokens.TURNTABLE.position.y - StudioTokens.PLINTH.position.y
	# From the frame it appears on: a tween sets its start only once it steps.
	_turntable.modulate.a = 0.0
	_turntable.position.y = rest_y + _RISE_PX
	_rise = create_tween().set_parallel()
	_rise.tween_property(_turntable, ^"modulate:a", 1.0, _RISE_S).set_custom_interpolator(Motion.curve(Motion.Easing.RISE))
	_rise.tween_property(_turntable, ^"position:y", rest_y, _RISE_S).set_custom_interpolator(Motion.curve(Motion.Easing.RISE))


## The logo at the plate's centre, on whole pixels as the browser lays it.
func _place_logo() -> void:
	var logo := _plate.texture.get_size()
	_plate.size = logo
	_plate.global_position = (global_position + StudioTokens.PLINTH_PLATE.get_center() - logo / 2.0).round()
