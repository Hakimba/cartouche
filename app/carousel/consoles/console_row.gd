# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleRow
extends Node3D
## The consoles screen's row: one console per platform with games, the selected one in the middle,
## laid out, faded and posed as the games are ([CarouselLayout], [ShelfRow.Pose]); the right stick
## turns it ([StickTurn]). Left and right step along the row, from end to end.
##
## The selected console stands as its launch animation has it: the animation drives the properties
## below, from where the console rests to where a game goes into it. The others rest as their own
## animations start, and fade out with [member others_opacity].

signal selection_changed(index: int)

## Where the selected console stands, turned (radians, about X then Y then Z) and sized.
var console_position := Vector3.ZERO
var console_rotation := Vector3.ZERO
var console_scale := 1.0
## How much of its pose, sway and float it has, from 0 (none) to 1.
var pose_amount := 1.0
var sway_degrees := CarouselLayout.SWAY_DEGREES
var bob_height := CarouselLayout.BOB_HEIGHT
var others_opacity := 1.0
## How far the selected console's lid is open, when it has one.
var lid_degrees := 0.0
var pose := ShelfRow.Pose.new()

var _items: Array[Item] = []
var _geometry: Array[VisualInstance3D] = []
var _position := 0
var _scroll := 0.0
var _clock_s := 0.0
var _stick := Vector2.ZERO
var _turn := StickTurn.new()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_clock_s += delta
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_turn.follow(_stick, _position, delta)
	arrange()


## Shows [param items] in platform order from [param from].
func show_consoles(items: Array[Item], from: int) -> void:
	for item in _items:
		item.model.queue_free()
	_items = items
	for item in _items:
		add_child(item.model)
	_geometry.assign(find_children("*", "VisualInstance3D", true, false))
	_position = from
	_scroll = from
	_turn = StickTurn.new()
	set_process(true)
	arrange()


func selected_index() -> int:
	return _position


func selected() -> Item:
	return _items[_position]


## One step towards [param direction] (-1 or 1), stopping at the ends.
func step(direction: int) -> void:
	var next := clampi(_position + direction, 0, _items.size() - 1)
	if next == _position:
		return
	_position = next
	_turn.release()
	selection_changed.emit(_position)


## Turns the selected console while [param stick] (each axis from -1 to 1) is pushed (see
## [StickTurn]).
func inspect(stick: Vector2) -> void:
	_stick = stick


## The selected console turns back to the front, in the middle of the row.
func face_front() -> void:
	_stick = Vector2.ZERO
	_turn.release()
	_scroll = _position


## Draws every console in the render layers of [param mask].
func show_in_layers(mask: int) -> void:
	for geometry in _geometry:
		geometry.layers = mask


## Stands every console as the properties above have it; each frame does, and so does whoever
## needs where they stand at once.
func arrange() -> void:
	var shown := CarouselLayout.offsets(_items.size(), _scroll)
	for i in _items.size():
		var item := _items[i]
		item.model.visible = i in shown
		if not item.model.visible:
			continue
		var offset: float = shown[i]
		var chosen := i == _position
		var rest := item.rest
		var at_position := console_position if chosen else rest.console_position
		var amount := pose_amount if chosen else rest.pose_amount
		var centred := CarouselLayout.centred(offset) * amount
		var place := CarouselLayout.place(offset)
		pose.sway = sway_degrees if chosen else rest.sway_degrees
		var bob := CarouselLayout.float_height(_clock_s, bob_height if chosen else rest.bob_height, centred)
		var turned := _three_euler(console_rotation if chosen else rest.console_rotation)
		var size := console_scale if chosen else rest.console_scale
		var posed := place.basis * pose.at(_clock_s, centred) * _turn.of(i)
		var stand := posed * turned.scaled(Vector3.ONE * size)
		item.model.transform = Transform3D(stand, at_position + place.origin + Vector3.UP * bob)
		var presence := 1.0 if chosen else others_opacity
		item.fade.call(CarouselLayout.faded(offset, presence))
		if chosen and item.model is ConsoleModel:
			var console: ConsoleModel = item.model
			console.lid_degrees = lid_degrees


## Turned about X, then Y, then Z, each about the axes the previous turns left, as the steps of a
## launch animation give it.
static func _three_euler(angles: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y) \
		* Basis(Vector3.BACK, angles.z)


## One console of the row: its model, how to fade it, and where it rests.
class Item:
	var model: Node3D
	## Takes how transparent the model is, from 0 (opaque) to 1 (gone).
	var fade: Callable
	var rest: Rest

	## [param shown] has a `fade(amount)` method.
	func _init(shown: Node3D, resting: Rest) -> void:
		model = shown
		fade = Callable(shown, &"fade")
		rest = resting


## Where a console rests: its launch animation's first values.
class Rest:
	var console_position := Vector3.ZERO
	var console_rotation := Vector3.ZERO
	var console_scale := 1.0
	var pose_amount := 1.0
	var sway_degrees := CarouselLayout.SWAY_DEGREES
	var bob_height := CarouselLayout.BOB_HEIGHT

	## The rest [param animation] starts from.
	static func of(animation: Animation) -> Rest:
		var rest := Rest.new()
		for property: StringName in [&"console_position", &"console_rotation", &"console_scale",
				&"pose_amount", &"sway_degrees", &"bob_height"]:
			var track := animation.find_track(NodePath("Consoles:" + property), Animation.TYPE_VALUE)
			if track >= 0:
				rest.set(property, animation.value_track_interpolate(track, 0.0))
		return rest
