# SPDX-License-Identifier: GPL-3.0-or-later
class_name Plinth
extends Control
## A console's still picture standing on a plinth, its logo on the plinth's plate. The picture is the
## console's own model, upright and facing front at its start pose (`data/turntable.json`), lit by the light
## designed for it there ([StudioLights], screen `plinth`), drawn ahead by `scripts/bake_plinths.sh` into the
## console's folder ([constant PICTURES]): showing one loads a picture, never a model. Nothing is shown until the
## picture is loaded; it then rises into place.

const TURNTABLE_FILE := "res://data/turntable.json"
## A console's pictures in its folder, by how many times the size a 1280x960 window shows them at they are drawn:
## a picture no larger than the window needs is the one a handheld sends to its graphics card as the cursor moves.
const PICTURES: Dictionary[float, String] = {1.0: "plinth.png", 2.0: "plinth_2x.png"}
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

var _console := ""
## The pictures being loaded: the shown console's, and those of the consoles the cursor passed.
var _loading: Dictionary[String, bool] = {}
var _rise: Tween

@onready var _base: SatinPanel = $Base
@onready var _plate: LogoView = $Plate
@onready var _turntable: TextureRect = $Turntable


## A new plinth, showing nothing yet.
static func create() -> Plinth:
	return (load("res://studio/views/plinth.tscn") as PackedScene).instantiate()


## Drops the starts read so far, so that the next ones follow a file the debug bridge reloaded.
static func forget() -> void:
	_starts.clear()


## The pose the model of the console in [param folder] starts at; a console the file gives only a yaw and a
## roll is neither leaned, moved nor sized, and one it does not list stands as its model is drawn.
static func start_of(folder: String) -> Start:
	if _starts.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TURNTABLE_FILE))
		_starts = data["consoles"]
	var pose: Dictionary = _starts.get(folder, {})
	var pitch: float = pose.get("pitch", 0.0)
	var yaw: float = pose.get("yaw", 0.0)
	var roll: float = pose.get("roll", 0.0)
	var at: PackedFloat32Array = pose.get("position", [0.0, 0.0, 0.0])
	var sized: float = pose.get("size", 1.0)
	return Start.new(Vector3(pitch, yaw, roll), StudioLights._vector(at), sized)


## Stands [param model], a child of [param stand] under [param spin], at [param start]: leaned and rolled, set
## on the plinth's centre and fitted as the tilt leaves it, then turned about the vertical, moved and sized.
## Returns the model's box centre in the world, which its lights stand about.
static func stand_at(spin: Node3D, stand: Node3D, model: Node3D, start: Start) -> Vector3:
	var turn := start.rotation * PI / 180.0
	stand.transform = Transform3D(Basis.from_euler(Vector3(turn.x, 0.0, turn.z)), Vector3.ZERO)
	var box := bounds(model, spin)
	stand.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	spin.transform = Transform3D(Basis(Vector3.UP, turn.y).scaled(Vector3.ONE * start.size
		* minf(_FIT_DIAMETER / Vector2(box.size.x, box.size.z).length(), _HEIGHT / box.size.y)), start.position)
	return spin.transform * bounds(stand, spin).get_center()


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


## The file of the picture of the console in [param folder] drawn [param times] the size of a 1280x960 window's;
## by default the one the window needs, the larger in a window larger than that.
static func picture_of(folder: String, times := 0.0) -> String:
	if times == 0.0:
		times = 2.0 if StudioTokens.window_scale((Engine.get_main_loop() as SceneTree).root) > 1.0 else 1.0
	return ConsoleManifest.FOLDERS.path_join(folder).path_join(PICTURES[times])


## The transparent view of its own world in which [param packed], the model of [param folder], stands lit and
## framed as the plinth's picture shows it, added under [param parent]; [param source] gives the edge smoothing,
## the window scale and the room.
static func build_view(folder: String, packed: PackedScene, source: Node, parent: Node) -> View:
	var rig := View.new()
	var view := SubViewport.new()
	rig.view = view
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = source.get_viewport().msaa_3d
	view.size = Vector2i((StudioTokens.TURNTABLE.size * StudioTokens.window_scale(source.get_window())).ceil())
	parent.add_child(view)
	rig.environment = WorldEnvironment.new()
	rig.environment.environment = StudioLights.environment_of(source)
	view.add_child(rig.environment)
	rig.camera = Camera3D.new()
	rig.camera.fov = 29.5
	rig.camera.near = 0.05
	rig.camera.far = 50.0
	view.add_child(rig.camera)
	rig.spin = Node3D.new()
	rig.stand = Node3D.new()
	rig.model = packed.instantiate() as Node3D
	rig.spin.add_child(rig.stand)
	rig.stand.add_child(rig.model)
	view.add_child(rig.spin)
	rig.start = start_of(folder)
	rig.lights = StudioLights.new(view, StudioLights.rig_of(folder, &"plinth"),
		stand_at(rig.spin, rig.stand, rig.model, rig.start), rig.environment.environment)
	rig.camera.look_at_from_position(_CAMERA, _CAMERA_TARGET)
	return rig


func _ready() -> void:
	_base.look = StudioTokens.Look.PLINTH
	_turntable.position = StudioTokens.TURNTABLE.position - StudioTokens.PLINTH.position
	_turntable.size = StudioTokens.TURNTABLE.size
	var top: TextureRect = $TopShadow
	top.position = StudioTokens.PLINTH_TOP_SHADOW.position
	top.size = StudioTokens.PLINTH_TOP_SHADOW.size
	item_rect_changed.connect(_place_logo)
	set_process(not _loading.is_empty())


## Shows the shown console's picture once loaded; a picture loaded for a console the cursor left is let go.
func _process(_delta: float) -> void:
	for path: String in _loading.keys():
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(path)
		var picture := ResourceLoader.load_threaded_get(path) as Texture2D
		if picture and path == picture_of(_console):
			_turntable.texture = picture
			_rise_in()
	set_process(not _loading.is_empty())


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		var shade := (($TopShadow as TextureRect).texture as GradientTexture2D).gradient
		shade.colors = PackedColorArray([Backdrop.palette.plinth_top_shade, Color(Backdrop.palette.plinth_top_shade, 0.0)])
	elif what == NOTIFICATION_EXIT_TREE:
		# A picture asked for is kept by the loader until it is taken.
		for path: String in _loading:
			ResourceLoader.load_threaded_get(path)
		_loading.clear()


## Shows the logo of the console in [param folder] (under res://carousel/consoles) on the plate and its
## picture, which rises as soon as it exists; nothing of the previous console stays.
func show_console(folder: String) -> void:
	if folder == _console:
		return
	_console = folder
	_plate.show_logo(LogoView.Slot.PLINTH_PLATE, folder)
	_place_logo()
	_base.gel = ConsoleManifest.of(folder).gel()
	_turntable.texture = null
	# Loaded off the main thread, so a picture never stalls the frame the user is scrolling in.
	if ResourceLoader.load_threaded_request(picture_of(folder)) == OK:
		_loading[picture_of(folder)] = true
		set_process(true)


## Presents the same picture again, as a chooser or form reopens.
func restart() -> void:
	_place_logo()
	_plate.modulate.a = 1.0
	if _turntable.texture:
		_rise_in()


## Clears the presentation.
func clear() -> void:
	_console = ""
	_base.gel = StudioTokens.NEUTRAL
	_turntable.texture = null
	_plate.show_logo(LogoView.Slot.PLINTH_PLATE, "")


## The console shown, its folder; none yet.
func console() -> String:
	return _console


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


## The logo at the plate's centre, on whole pixels.
func _place_logo() -> void:
	var logo := _plate.texture.get_size()
	_plate.size = logo
	_plate.global_position = (global_position + StudioTokens.PLINTH_PLATE.get_center() - logo / 2.0).round()


## A console's start on the turntable, as it is posed by hand: its turns in degrees (x leans
## it, y turns it about the vertical, z rolls it; applied y, x then z, as a Node3D's), its move in world units
## and its size, both after the model is fitted on the plinth.
class Start:
	var rotation: Vector3
	var position: Vector3
	var size: float

	func _init(turns: Vector3, move := Vector3.ZERO, scale := 1.0) -> void:
		rotation = turns
		position = move
		size = scale


## What [method build_view] builds.
class View:
	var view: SubViewport
	var environment: WorldEnvironment
	var camera: Camera3D
	var spin: Node3D
	var stand: Node3D
	var model: Node3D
	var start: Start
	var lights: StudioLights
