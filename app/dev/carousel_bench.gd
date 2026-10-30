# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselBench
extends Node
## Measures the carousel in debug builds, driven like a user would, on the games screen of the
## platform the app opens on: `scroll` holds right for [constant _DURATION_S], `turn` holds the right
## stick, so that the selected game keeps turning, underside and clear parts shown, `scrape` holds
## right as `scroll` does but from the start, while the disc scans download. `enter` goes into the
## console and back out every [constant _ENTER_EVERY_S], from the consoles screen; `step` moves along
## the consoles, right then left, every [constant _STEP_EVERY_S]. `properties` opens the selected game's
## properties and closes them again every [constant _ENTER_EVERY_S]; `order` opens the ring putting
## the consoles in order and, in turn, takes the console under the cursor, moves it right and left
## and lets it go, a press every [constant _STEP_EVERY_S], the console held drawn as a sticker; `swipe`
## swipes the games by touch every [constant _ENTER_EVERY_S], a game each time: these keep the app awake
## ([member Resting.stays_awake]), so that their frames are the motion's. `idle` stays on the games
## screen and `idle_consoles` on the consoles screen without a press, and `settings` opens the
## settings over the games and stays: these are measured once the app rests, still, to see what it
## costs when nothing moves. Then traces one `bench` line of `key=value` frame statistics, read by
## `scripts/bench.sh`. `launch` presses A once: [GameLaunch] traces its own `bench: launch:` line, with
## the launch's frames and the times to check and to start the game. `type_chooser` opens the Type
## chooser over the consoles screen, traces the time to its first drawn frame, and moves its cursor down
## then up a row every [constant _STEP_EVERY_S] while the model turns. `plinth` turns a console on the
## Type chooser's plinth over the consoles screen ([Plinth]); `soft_media` moves a row of
## `--media=N` (5) softened discs ([MediaView]) one place every [constant _STEP_EVERY_S]. `placing` places the last console
## of the row on the ring of the others every [constant _PLACING_EVERY_S], A after [constant _ARRIVED_S] (the first gap, the end,
## where it already stands: the order saved is the one it had), and traces the time from A to the consoles screen.
## Each but `scrape` starts once the app's start has settled,
## which is measured on its own. `--msaa=N` sets the 3D's antialiasing (0 to 2, the settings'
## choices) for the run.

const _SETTLE_S := 5.0
const _DURATION_S := 30.0
const _ENTER_EVERY_S := 3.0
const _STEP_EVERY_S := 0.6
const _PLACING_EVERY_S := 4.0
const _ARRIVED_S := 0.6
## The presses `order` goes round: take, move right twice, back left twice, let go.
const _ORDER_PRESSES: Array[StringName] = [&"ui_accept", &"carousel_right", &"carousel_right",
	&"carousel_left", &"carousel_left", &"screen_back"]
## The action each scenario holds from its start to its end.
const _HELD: Dictionary[String, StringName] = {
	"scroll": &"carousel_right", "scrape": &"carousel_right", "turn": &"inspect_right",
}
## A bench approximation of the games row: its places and sizes (for a disc the chosen one's place, for a
## cartridge its lift over its pose's place; the chosen one's size, a neighbour's place (x, y) and size), and each
## medium family's pose.
const _DISC_ROW := {&"centre": Vector3(0.0, 0.15, 0.0), &"size": 0.78, &"side": Vector2(0.96, -0.25), &"side_size": 0.56}
const _CART_ROW := {&"lift": 0.22, &"size": 0.85, &"side": Vector2(1.25, 0.02), &"side_size": 0.66}
## (position, rotation YXZ in degrees)
const _MEDIUM_POSES: Dictionary[StringName, Array] = {
	&"disc": [Vector3(0.015, 0.066, -0.003), Vector3(-13.4, 21.0, 0.2)],
	&"nes": [Vector3(0.046, 0.037, -0.03), Vector3(-17.3, 20.4, 0.0)],
	&"home": [Vector3(0.028, 0.099, -0.042), Vector3(-16.0, 22.3, 0.0)],
	&"handheld": [Vector3(0.028, 0.023, -0.015), Vector3(-12.1, 18.5, 0.0)],
}
const _POSE_FAMILY: Dictionary[String, StringName] = {"nes_cart": &"nes", "famicom_cart": &"nes", "snes_pal_cart": &"home",
	"sfc_cart": &"home", "snes_us_cart": &"home", "n64_cart": &"home", "gb_cart": &"handheld", "gbc_cart": &"handheld",
	"gba_cart": &"handheld"}
## A medium fits a box this large.
const _MEDIUM_FIT := 1.2
const _MEDIA_TITLES: Array[String] = ["Crystal Knights", "Iron Valley", "Moss Kingdom", "Paper Comet", "Sky Garden"]
## How long after its last press the app is still.
const _STILL_AFTER_S := Resting.STILL_AFTER_S + Resting.STOPPING_S + 0.5

var _scenario: String
var _carousel: Carousel
var _row: ShelfRow
var _frames_ms := PackedFloat32Array()
## Summed over the frames: the main loop's processing (scripts and engine) and the drawing's
## preparation on the CPU, in milliseconds.
var _process_ms := 0.0
var _draw_ms := 0.0
var _elapsed_s := 0.0
## Frames drawn before the measure, to count those drawn during it: at rest, only what changes is drawn.
var _drawn_before := 0
var _next_action_s := 0.0
var _steps := 0
var _media: Array[MediaView] = []
var _row_spring: Motion.Spring


## [param action] pressed then let go, as a controller sends it.
static func press(action: StringName) -> void:
	act(action, true)
	act(action, false)


## [param action] pressed, or let go.
static func act(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _init(scenario: String, carousel: Carousel, row: ShelfRow) -> void:
	_scenario = scenario
	_carousel = carousel
	_row = row


func _ready() -> void:
	set_process(false)
	if _scenario != "scrape":
		await get_tree().create_timer(_SETTLE_S).timeout
	if _scenario not in ["enter", "step", "order", "idle_consoles", "plinth", "soft_media", "type_chooser", "placing"]:
		press(&"ui_accept")
		while _carousel.screen() != Carousel.Screen.GAMES:
			await _carousel.screen_changed
	var msaa := Diagnostics.argument("msaa")
	if msaa:
		get_viewport().msaa_3d = msaa.to_int() as Viewport.MSAA
	_row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: _steps += 1)
	if _scenario in _HELD:
		act(_HELD[_scenario], true)
	elif _scenario == "launch":
		press(&"ui_accept")
		queue_free()
	elif _scenario == "order" and not await _open_ring():
		queue_free()
		return
	elif _scenario == "settings":
		press(&"open_settings")
	elif _scenario == "plinth":
		var plinth := Plinth.create()
		plinth.position = StudioTokens.PLINTH.position
		_carousel.add_child(plinth)
		plinth.show_console("ps2_slim")
	elif _scenario == "type_chooser":
		_open_type_chooser()
	elif _scenario == "soft_media":
		var count_given := Diagnostics.argument("media")
		var count := count_given.to_int() if count_given else 5
		_media = media_row(count, "ps2_dvd", _carousel.get_viewport().get_camera_3d(), _carousel)
		_row_spring = Motion.Spring.new(0.0)
		place_row(_media, 0.0)
	if _scenario in ["idle", "idle_consoles", "settings"]:
		await get_tree().create_timer(_STILL_AFTER_S).timeout
	else:
		_carousel._resting.stays_awake = true
	set_process(true)
	_drawn_before = Engine.get_frames_drawn()
	Diagnostics.trace("bench", "%s started" % _scenario)


func _process(delta: float) -> void:
	_elapsed_s += delta
	_frames_ms.append(Diagnostics.frame_ms)
	_process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_draw_ms += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	if _scenario == "enter" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		press(&"ui_accept" if _carousel.screen() == Carousel.Screen.CONSOLES else &"screen_back")
	elif _scenario == "step" and _elapsed_s >= _next_action_s:
		_next_action_s += _STEP_EVERY_S
		_steps += 1
		press(&"carousel_right" if _steps % 2 == 1 else &"carousel_left")
	elif _scenario == "properties" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		press(&"open_properties" if _carousel.screen() == Carousel.Screen.GAMES else &"screen_back")
	elif _scenario == "order" and _carousel.screen() != Carousel.Screen.ORDER:
		# Never a press elsewhere: an A on the games screen would launch a game.
		Diagnostics.trace("bench", "order stopped: the ring closed after %d presses" % _steps)
		queue_free()
		return
	elif _scenario == "order" and _elapsed_s >= _next_action_s and _ring_still():
		_next_action_s += _STEP_EVERY_S
		press(_ORDER_PRESSES[_steps % _ORDER_PRESSES.size()])
		_steps += 1
	elif _scenario == "type_chooser" and _elapsed_s >= _next_action_s:
		_next_action_s += _STEP_EVERY_S
		press(&"ui_down" if _steps % 22 < 11 else &"ui_up")
		_steps += 1
	elif _scenario == "placing" and _elapsed_s >= _next_action_s:
		_next_action_s += _PLACING_EVERY_S
		_place_last()
	elif _scenario == "soft_media":
		if _elapsed_s >= _next_action_s:
			_next_action_s += _STEP_EVERY_S
			_steps += 1
			_row_spring.target += 1.0
		_row_spring.step(delta)
		place_row(_media, _row_spring.position)
	elif _scenario == "swipe" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		_swipe()
	if _elapsed_s >= _DURATION_S:
		if _scenario in _HELD:
			act(_HELD[_scenario], false)
		_report()
		queue_free()


## From the screen shown, back to the consoles screen, then the ring opened and still: whether it is (traced when not).
func _open_ring() -> bool:
	if _carousel.screen() == Carousel.Screen.GAMES:
		press(&"screen_back")
	if not await _until(func() -> bool: return _carousel.screen() == Carousel.Screen.CONSOLES):
		Diagnostics.trace("bench", "order stopped: no consoles screen")
		return false
	press(&"ui_down")
	if not await _until(_ring_still):
		Diagnostics.trace("bench", "order stopped: no ring (a single console?)")
		return false
	return true


## Whether the ring shows and takes presses: open, neither coming nor moving a console.
func _ring_still() -> bool:
	return _carousel.screen() == Carousel.Screen.ORDER and _carousel._order.is_open() and not _carousel._order._busy


## Frames until [param condition] holds, ten seconds at most: whether it did.
func _until(condition: Callable) -> bool:
	var waited_s := 0.0
	while not condition.call() and waited_s < 10.0:
		await get_tree().process_frame
		waited_s += get_process_delta_time()
	return condition.call()


## The last console of the row placed on the ring of the others, as the form's Add does: the screens cover the
## consoles, the ring comes, A flies the console where it already stands, the consoles screen comes back.
func _place_last() -> void:
	var started := 0
	get_tree().create_timer(_ARRIVED_S).timeout.connect(func() -> void:
		started = Time.get_ticks_msec()
		press(&"ui_accept"))
	await _carousel.place_last_console()
	Diagnostics.trace("bench", "placing: %d ms from A to the consoles screen" % (Time.get_ticks_msec() - started))
	_steps += 1


## The Type chooser over the whole catalog's offer, and the time from asking to its first drawn frame.
func _open_type_chooser() -> void:
	var chooser: StudioChooser = (load("res://studio/chooser/studio_chooser.tscn") as PackedScene).instantiate()
	_carousel.add_child(chooser)
	var asked := Time.get_ticks_usec()
	chooser.choose_console(_carousel.android.catalog.offered, 0)
	await RenderingServer.frame_post_draw
	Diagnostics.trace("bench", "type chooser first frame in %.1f ms" % ((Time.get_ticks_usec() - asked) / 1000.0))


## A finger swiped from right to left beside the game in the middle, a few frames long.
func _swipe() -> void:
	var window := get_tree().root.get_final_transform()
	var at := Vector2(1100.0, 760.0)
	var touch := InputEventScreenTouch.new()
	touch.position = window * at
	touch.pressed = true
	Input.parse_input_event(touch)
	for move in 4:
		await get_tree().process_frame
		at.x -= 160.0
		var drag := InputEventScreenDrag.new()
		drag.position = window * at
		Input.parse_input_event(drag)
	touch = touch.duplicate()
	touch.position = window * at
	touch.pressed = false
	Input.parse_input_event(touch)


## [param count] games of [param medium] drawn as the games row draws them, through [param camera], each
## view over [param front].
static func media_row(count: int, medium: String, camera: Camera3D, front: Node) -> Array[MediaView]:
	var manifest: MediumManifest = load("res://carousel/media/%s/medium.tres" % medium)
	var views: Array[MediaView] = []
	for j in count:
		var view := MediaView.new()
		view.camera = camera
		front.add_child(view)
		var labelled := ShelfRow.LabelledModel.new(load(manifest.scene) as PackedScene)
		var look := ShelfRow.LabelLook.new()
		look.demo_art = true
		labelled.draw_label(_MEDIA_TITLES[j % _MEDIA_TITLES.size()], look)
		view.show_medium(_fitted(labelled), StudioLights.rig_of(medium, &"games"), StudioLights.rig_of(medium, &"games", true))
		views.append(view)
	return views


## [param views] with the row standing [param at] places on: each game drawn at its place, the farthest
## first.
static func place_row(views: Array[MediaView], at: float, medium := "ps2_dvd") -> void:
	var order := MediaView.drawing_order(views.size(), at)
	for j in views.size():
		views[j].visible = j in order
	for j in order:
		var d := MediaView.offset(j, at, views.size())
		views[j].place(_standing(d, medium), MediaView.softness(d))
		views[j].move_to_front()


## Where a game of [param medium] [param d] places from the centre stands, by this bench's row.
static func _standing(d: float, medium: String) -> Transform3D:
	var cart := medium in _POSE_FAMILY
	var row: Dictionary = _CART_ROW if cart else _DISC_ROW
	var pose: Array = _MEDIUM_POSES[_POSE_FAMILY.get(medium, &"disc")]
	var posed: Vector3 = pose[0]
	var turn: Vector3 = pose[1]
	var lift: float = row.get(&"lift", 0.0)
	var size: float = row[&"size"]
	var side: Vector2 = row[&"side"]
	var side_size: float = row[&"side_size"]
	var centre: Vector3 = posed + Vector3(0.0, lift, 0.0) if cart else row[&"centre"]
	var chosen := Transform3D(Basis.from_euler(turn * PI / 180.0, EULER_ORDER_YXZ).scaled(Vector3.ONE * size), centre)
	return MediaView.standing(d, chosen, side, side_size)


## [param model] centred on its box, its largest side [constant _MEDIUM_FIT].
static func _fitted(model: Node3D) -> Node3D:
	var fitted := Node3D.new()
	fitted.add_child(model)
	var box := Plinth.bounds(model, fitted)
	model.position = -box.get_center()
	fitted.scale = Vector3.ONE * _MEDIUM_FIT / maxf(box.size.x, box.size.y)
	var holder := Node3D.new()
	holder.add_child(fitted)
	return holder


func _report() -> void:
	var frames := Diagnostics.frame_statistics(_frames_ms, _elapsed_s)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var count := maxi(_frames_ms.size(), 1)
	var drawn_per_s := (Engine.get_frames_drawn() - _drawn_before) / maxf(_elapsed_s, 0.001)
	Diagnostics.trace("bench", "%s: %s steps=%d %s draw_calls=%d process_ms=%.2f draw_cpu_ms=%.2f drawn_per_s=%.1f" % [
		_scenario, frames, _steps, Diagnostics.memory(), draw_calls, _process_ms / count, _draw_ms / count, drawn_per_s])
