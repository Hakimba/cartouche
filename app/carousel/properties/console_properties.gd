# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleProperties
extends PropertiesScreen
## The properties of the selected console. It comes to the middle of the screen, still, under the
## light of an operating table ([OperatingLight]), while the other consoles and what the consoles
## screen shows over them fade out; its name has the focus, outlined in black and named by a
## callout on its right; the right stick turns it. A on the name opens a keyboard (as for a game's
## name): Start keeps the name typed (blank, or its own, the console takes its own name back), B
## leaves it as it was. Y, or A on "Change place", goes to the ring putting the consoles in order
## ([ConsoleOrder]), the console going back to its place as the ring takes it. B goes back to the
## consoles.

## The console was given a name ([param named]), or its own back: it shows as [param shown].
signal name_kept(platform_id: String, named: bool, shown: String)
## The consoles are to be put in order: the properties close as the ring opens.
signal order_asked

enum Step { CLOSED, PROPERTIES, NAMING }

## The callout stands right of the name, this far from its frame, in pixels; its caption takes
## this much more than its text.
const _CAPTION_AWAY := 70.0
const _CAPTION_ROOM := 40.0

## Where the console stands and how the light falls on it: in the row; on its properties, a little
## higher, clear of its name, the room half dark round a pool of light 440 pixels wide; with its
## name's keyboard, risen 3.6 cm and smaller.
static var _in_row := Staging.new(0.0, 0.0, 1.0, 0.0, 440.0)
static var _on_properties := Staging.new(1.0, 0.12, 1.0, 0.5, 440.0)
static var _on_naming := Staging.new(1.0, 0.36, 0.65, 0.35, 240.0)
## The moves between the screens, in seconds, as a game's properties have them.
static var _opening := Move.new(Leave.FADE, 0.15, 0.52, Arrive.RISE, 0.24, 0.32)
static var _closing := Move.new(Leave.FADE, 0.15, 0.48, Arrive.FADE, 0.2, 0.3)

## Set by the carousel before the first [method open].
var consoles: ConsoleRow
## Whether the consoles can be put in order: not a console alone.
var orderable := true

var _step := Step.CLOSED
var _platform_id := ""
## The name the console shows, and its own.
var _shown := ""
var _own := ""
## The caption measured last, and how wide it is with its arrow's room: not measured each frame.
var _measured := ""
var _wide := 0.0

@onready var _change_place: Button = %ChangePlace


func _init() -> void:
	_staging = _in_row


func _ready() -> void:
	super()
	_change_place.pressed.connect(_to_order)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var centre := camera.unproject_position(consoles.selected().model.global_position)
	light.look(centre, _staging.radius, _staging.darkness)
	if _name.has_focus():
		var box := _name.get_rect()
		var middle := box.position.y + box.size.y / 2.0
		var caption := tr("Console name")
		if caption != _measured:
			_measured = caption
			_wide = _callout.get_theme_font(&"font").get_string_size(caption).x + _CAPTION_ROOM
		# Right of the name while there is room, else above its end, as a game's name has it.
		if box.end.x + _CAPTION_AWAY + _wide <= size.x:
			_callout.point(caption, Vector2(box.end.x + _CAPTION_AWAY, middle), Vector2(box.end.x + 14.0, middle))
		else:
			var at := Vector2(box.end.x - _wide, box.position.y - _CAPTION_AWAY)
			_callout.point(caption, at, Vector2(box.end.x - 30.0, box.position.y - 10.0))
	else:
		_callout.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.CLOSED or event.is_echo():
		return
	if _step == Step.NAMING and _naming_press(event):
		return
	# Y, the button settings have elsewhere.
	if _step == Step.PROPERTIES and orderable and event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		_to_order()
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	if _step == Step.NAMING:
		Diagnostics.trace("properties", "console naming left, the name as it was")
		_back_to_properties()
	else:
		_close()


## Whether the properties show, or are coming or going.
func is_open() -> bool:
	return _step != Step.CLOSED or _busy


## Opens the properties of [param platform_id]'s console, shown as [param shown], its own name
## [param own].
func open(platform_id: String, shown: String, own: String) -> void:
	_platform_id = platform_id
	_shown = shown
	_own = own
	_show_name(_name, shown)
	_change_place.visible = orderable
	_step = Step.PROPERTIES
	Diagnostics.trace("properties", "open the console %s" % platform_id)
	show()
	set_process(true)
	await _move(behind, [_properties], _on_properties, _opening)
	_name.grab_focus()


func _close() -> void:
	_step = Step.CLOSED
	Diagnostics.trace("properties", "console properties closed")
	_put_back([_properties], behind, _in_row, _closing)


## Closes for the ring putting the consoles in order, which comes in their place.
func _to_order() -> void:
	if _busy:
		return
	_step = Step.CLOSED
	Diagnostics.trace("properties", "console properties left for the order of the consoles")
	order_asked.emit()
	_put_back([_properties], [], _in_row, _closing)


func _open_naming() -> void:
	if _busy:
		return
	_step = Step.NAMING
	_naming.open(_shown, _own)
	await _move([_properties], [_naming], _on_naming, _to_naming)
	_naming.focus_keys()


func _back_to_properties() -> void:
	_step = Step.PROPERTIES
	await _move([_naming], [_properties], _on_properties, _from_editing)
	_name.grab_focus()


## Keeps the name typed, then goes back to the properties; stays on the keyboard when it cannot be
## kept.
func _keep_name() -> void:
	if _busy:
		return
	var typed := _naming.typed().strip_edges()
	if typed == _shown:
		_back_to_properties()
		return
	var answer := await _renaming(android.rename_console.bind(_platform_id, typed, _own)) as AndroidServices.ConsoleRenamed
	if not answer.ok:
		return
	_shown = answer.name if answer.has_name else _own
	Diagnostics.trace("properties", "console %s now shown as '%s'" % [_platform_id, _shown])
	_show_name(_name, _shown)
	name_kept.emit(_platform_id, answer.has_name, _shown)
	_back_to_properties()


func _place() -> void:
	consoles.stage = _staging.amount
	consoles.staged_lift = _staging.height
	consoles.staged_size = _staging.size
