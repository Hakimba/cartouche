# SPDX-License-Identifier: GPL-3.0-or-later
class_name RingView
extends TextureRect
## A console as the consoles screen shows it in the middle, larger: its model in a world of its own, under the
## carousel's camera, room and sun, posed, swaying, floating and lit by its own rig as the ring's selected console is
## ([ConsoleRow]), seen through a frustum narrowed round its silhouette. The silhouette is measured when a console is
## shown framed ([method show_console]) and kept, so that another model of the same console shows at its own size
## against the first, as on the ring. Live, or drawn once as a picture ([method still]). Nothing is written to the
## renderer but what moves: the console, until the app rests.

const _FILL := 0.9
## What a console's launch animation starts it at, as the ring's selected console stands.
const _POSE: Array[StringName] = [&"console_position", &"console_rotation", &"console_scale", &"pose_amount",
	&"sway_degrees", &"bob_height"]

## The carousel's consoles and sun, whose camera, room, pose and light it copies. Required before a console shows.
var ring: ConsoleRow
var sun: DirectionalLight3D
var _view := SubViewport.new()
var _camera := Camera3D.new()
var _row: ConsoleRow
## The console's silhouette as measured, in px of the carousel's view; none before.
var _silhouette := Rect2()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_camera.cull_mask = ConsoleLayer.FRONT | ConsoleRow.HERO
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_view.add_child(_camera)
	add_child(_view)
	texture = _view.get_texture()
	get_viewport().size_changed.connect(_frame)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_frame()
	# Hidden, the console stops moving: the form keeps its view between openings.
	elif what == NOTIFICATION_VISIBILITY_CHANGED and _row:
		_row.set_process(is_visible_in_tree())


## Shows the console of [param platform_id] as the model in [param folder]; [param framed], measured to fill the
## view.
func show_console(platform_id: String, folder: String, framed: bool) -> void:
	if _row == null:
		_furnish()
	var manifest := ConsoleManifest.of(folder)
	var model: ConsoleModel = (load(manifest.scene) as PackedScene).instantiate()
	# Its launch animation moves its parts by this name.
	model.name = platform_id
	var item := ConsoleRow.Item.new(model, ConsoleRow.Rest.of(LaunchAnimation.read(manifest.launch, model)), folder)
	_row.show_consoles([item], 0)
	for property in _POSE:
		_row.set(property, item.rest.get(property))
	_row.arrange()
	if framed:
		_measure()
		_frame()


## The console shown, drawn once; none where nothing is drawn.
func still() -> Texture2D:
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	return ImageTexture.create_from_image(image) if image and not image.is_empty() else null


## The world the console stands in: the carousel's room and sun, and a row of its own posed as the ring.
func _furnish() -> void:
	var room := WorldEnvironment.new()
	room.environment = StudioLights.environment_of(ring)
	# Drawn over the form's backdrop, not as a canvas of its own.
	room.environment.background_mode = Environment.BG_CLEAR_COLOR
	_view.add_child(room)
	var light := DirectionalLight3D.new()
	light.transform = sun.global_transform
	light.light_specular = sun.light_specular
	light.light_cull_mask = sun.light_cull_mask
	_view.add_child(light)
	_row = ConsoleRow.new()
	_row.transform = ring.global_transform
	for property: StringName in [&"tilt", &"turn", &"sway_period_s"]:
		_row.pose.set(property, ring.pose.get(property))
	_view.add_child(_row)


## Measures the console's silhouette as it stands now, through the carousel's camera.
func _measure() -> void:
	var watched := ring.get_viewport().get_camera_3d()
	var low := Vector2.INF
	var high := -Vector2.INF
	for part in _row.selected().geometry:
		if not part.visible:
			continue
		var box := part.get_aabb()
		for corner in 8:
			var seen := watched.unproject_position(part.global_transform * box.get_endpoint(corner))
			low = low.min(seen)
			high = high.max(seen)
	_silhouette = Rect2(low, high - low) if low.x < INF else Rect2()


## The camera as the carousel's, its frustum narrowed round the silhouette; the view at the window's scale.
func _frame() -> void:
	_view.size = Vector2i((size * StudioTokens.window_scale(get_window())).ceil())
	_view.msaa_3d = get_viewport().msaa_3d
	if not _silhouette.has_area():
		return
	var watched := ring.get_viewport().get_camera_3d()
	_camera.global_transform = watched.global_transform
	# The carousel's view keeps its height: one of its px is this much of the near plane.
	var view := ring.get_viewport().get_visible_rect().size
	var near_px := 2.0 * watched.near * tan(deg_to_rad(watched.fov) / 2.0) / view.y
	var zoom := minf(_FILL * size.x / _silhouette.size.x, _FILL * size.y / _silhouette.size.y)
	var centre := _silhouette.get_center() - view / 2.0
	_camera.set_frustum(size.y / zoom * near_px, Vector2(centre.x, -centre.y) * near_px, watched.near, watched.far)
