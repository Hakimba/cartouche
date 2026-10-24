# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## The 3D views on their own, for the eye and the captures: a console's still picture on its plinth where the
## Console chooser has it, and a row of five games of a medium as the games screen stands them, the
## middle one sharp and its neighbours softened. `--console=<folder>` (ps2_slim), `--medium=<medium>`
## (ps2_dvd), `--row=<place>` the row standing that many places on (0),
## `--views=plinth`, `--views=media` or `--views=ground` (a console's contact shadow and reflection over the
## whole frame) only one of them, `--plates` also each shot's 3D alone (its views' pictures where they
## lie, `<frame>.alpha.png`), `--msaa=<0|1|2>` the edge smoothing, `--hide=<frame>` hides the plinth at that frame,
## `--shots=<dir> --frames=<n,n,...>` saves the screen at those frames and quits.

const Fixtures := preload("res://test/studio/views/views_fixtures.gd")

var _views: Array[MediaView] = []
var _frame := 0
var _shots: PackedInt32Array
var _medium := ""

@onready var _camera: Camera3D = $Camera
@onready var _plinth: Plinth = $Plinth


func _ready() -> void:
	($Environment as WorldEnvironment).environment = Fixtures.app_environment()
	var msaa := _argument("msaa", "")
	if msaa:
		get_viewport().msaa_3d = msaa.to_int() as Viewport.MSAA
	_medium = _argument("medium", "ps2_dvd")
	var views := _argument("views", "plinth,media")
	var console := _argument("console", "ps2_slim")
	_plinth.visible = views.contains("plinth")
	($Media as Control).visible = views.contains("media")
	if views.contains("ground"):
		var ground := ContactShadow.new()
		ground.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ground)
		ground.show_ground(console)
	_plinth.show_console(console)
	($Backdrop/Cyclorama as Cyclorama).show_gel(Cyclorama.gel_of(ConsoleManifest.of(console)), false)
	if views.contains("media"):
		_views = CarouselBench.media_row(5, _medium, _camera, $Media)
		CarouselBench.place_row(_views, float(_argument("row", "0")), _medium)
	var frames := _argument("frames", "")
	_shots = PackedInt32Array(Array(frames.split(",", false)).map(func(f: String) -> int: return f.to_int()))


func _process(_delta: float) -> void:
	_frame += 1
	if str(_frame) == _argument("hide", ""):
		_plinth.hide()
		Diagnostics.trace("studio", "views scene: plinth hidden at frame %d" % _frame)
	if _frame in _shots:
		var shot := _frame
		await RenderingServer.frame_post_draw
		var path := _argument("shots", "user://").path_join("%05d.png" % shot)
		get_viewport().get_texture().get_image().save_png(path)
		Diagnostics.trace("studio", "views scene: frame %d saved" % shot)
		if OS.get_cmdline_user_args().has("--plates"):
			_plate().save_png(path.get_basename() + ".alpha.png")
		if shot == _shots[-1]:
			get_tree().quit()


## The 3D of the shot alone: each view's picture where it lies on the 1280 x 960 frame, on nothing.
func _plate() -> Image:
	var plate := Image.create(1280, 960, false, Image.FORMAT_RGBA8)
	var shown: Array[Control] = []
	shown.assign(_views.filter(func(view: MediaView) -> bool: return view.visible))
	if _plinth.visible:
		shown.append(_plinth.get_node("Turntable") as Control)
	for control in shown:
		var raw := (control as TextureRect).texture.get_image()
		raw.convert(Image.FORMAT_RGBA8)
		raw.resize(roundi(control.size.x), roundi(control.size.y), Image.INTERPOLATE_BILINEAR)
		plate.blend_rect(raw, Rect2i(Vector2i.ZERO, raw.get_size()), Vector2i(control.global_position.round()))
	return plate


static func _argument(option: String, otherwise: String) -> String:
	var given := Diagnostics.argument(option)
	return given if given else otherwise
