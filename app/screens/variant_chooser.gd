# SPDX-License-Identifier: GPL-3.0-or-later
class_name VariantChooser
extends Control
## Previews a console's models without writing; A keeps the model, B leaves the library untouched.

signal closed(changed: bool)

var android: AndroidServices = Android
var library: AndroidServices.Library
var _platform := ""
var _models: Array[ConsoleManifest] = []
var _index := 0
var _kept := ""
var _saving := false
var _plinth: Plinth
var _title: StudioText
var _name: StudioText
var _count: StudioText
var _rim := StudioTokens.NEUTRAL

@onready var _backdrop: Cyclorama = $Backdrop
@onready var _title_node: Control = $Title
@onready var _choice: Button = $Choice
@onready var _counter: Control = $Count
@onready var _error: Label = $Error


func _ready() -> void:
	_title_node.draw.connect(_draw_title)
	_choice.draw.connect(_draw_name)
	_counter.draw.connect(_draw_count)
	_choice.pressed.connect(_keep)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_choice.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	if event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		if not _saving:
			_close(false)
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		get_viewport().set_input_as_handled()
		if not _saving:
			_index = posmod(_index + (1 if event.is_action_pressed(&"ui_right") else -1), _models.size())
			_present()


func open(platform_id: String, current: String) -> void:
	_platform = platform_id
	_models = Appearance.defaults(ConsoleManifest.found())[platform_id].models()
	_index = 0
	for i in _models.size():
		if ConsoleManifest.folder_of(_models[i]) == current:
			_index = i
	_kept = ConsoleManifest.folder_of(_models[_index])
	_saving = false
	_choice.disabled = false
	_error.text = ""
	_title = StudioText.new(tr("Variant"), StudioTokens.Face.JAKARTA_800, 58.88, -0.04)
	_plinth = Plinth.create()
	_plinth.name = "Plinth"
	_plinth.position = StudioTokens.PLINTH.position
	_plinth.size = StudioTokens.PLINTH.size
	add_child(_plinth)
	move_child(_plinth, _backdrop.get_index() + 1)
	show()
	_present()
	_choice.grab_focus()


func variant_id() -> String:
	return ConsoleManifest.folder_of(_models[_index])


func counter() -> String:
	return "%d / %d" % [_index + 1, _models.size()]


func _present() -> void:
	var model := _models[_index]
	_rim = model.gel()
	_backdrop.show_gel(_rim)
	_plinth.show_console(variant_id())
	_name = StudioText.new(model.name + " " + model.model_name,
		StudioTokens.Face.JAKARTA_800, 30.08, 0.0)
	_count = StudioText.new(counter(), StudioTokens.Face.PLEX_600, 21.76, 0.08)
	_title_node.queue_redraw()
	_choice.queue_redraw()
	_counter.queue_redraw()


func _keep() -> void:
	if _saving:
		return
	if variant_id() == _kept:
		_close(false)
		return
	_saving = true
	_choice.disabled = true
	var answer := await android.set_variant(_platform, variant_id())
	if answer.ok:
		library = answer.library
		_close(true)
	else:
		Diagnostics.trace("console", "variant not kept (%s): %s" % [answer.code, answer.detail])
		_error.text = tr("This variant could not be kept.")
		_saving = false
		_choice.disabled = false
		_choice.grab_focus()


func _close(changed: bool) -> void:
	hide()
	remove_child(_plinth)
	_plinth.queue_free()
	_plinth = null
	closed.emit(changed)


func _draw_title() -> void:
	if _title:
		_title.draw(_title_node, Vector2.ZERO, StudioTokens.INK)


func _draw_name() -> void:
	if _name:
		_name.fit(_choice.size.x)
		_name.draw(_choice, Vector2.ZERO, StudioTokens.INK)


func _draw_count() -> void:
	if _count:
		_count.draw(_counter, Vector2(-1.0, -1.0), _rim)
