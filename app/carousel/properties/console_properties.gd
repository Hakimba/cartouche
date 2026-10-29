# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleProperties
extends PropertiesScreen
## The console staged under its light, with the existing ordering action. A console with
## other models has its model focusable, a callout naming it: A shows every model in a mosaic, the
## console turning into the one the cursor is on; A keeps it, B brings back the one it had.

signal order_asked
## The console is shown as the model in [param folder]: for a look while choosing, or back.
signal variant_shown(folder: String)
## The model in [param folder] is kept for the console.
signal variant_kept(folder: String)

enum Step { CLOSED, PROPERTIES, VARIANTS }

static var _in_row := Staging.new(0.0, 0.0, 1.0, 0.0, 440.0)
static var _on_properties := Staging.new(1.0, 0.12, 1.0, 0.5, 440.0)
static var _opening := Move.new(Leave.FADE, 0.15, 0.52, Arrive.RISE, 0.24, 0.32)
static var _closing := Move.new(Leave.FADE, 0.15, 0.48, Arrive.FADE, 0.2, 0.3)

var consoles: ConsoleRow
var orderable := true
var _step := Step.CLOSED
var _models: Array[ConsoleManifest] = []
## The model the console had when the mosaic opened.
var _kept := ""

@onready var _change_place: Button = %ChangePlace
@onready var _model: Button = %Model
@onready var _callout: FocusCallout = %Callout
@onready var _variants: HBoxContainer = %Variants


func _init() -> void:
	_staging = _in_row


func _ready() -> void:
	super()
	add_to_group(SoundEffects.MOVES)
	_variants.set_meta(SoundEffects.MOVE_SOUND, SoundEffects.Cue.MODEL)
	_change_place.pressed.connect(_to_order)
	_model.pressed.connect(_open_variants)
	_callout.use_studio()
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_model.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _process(_delta: float) -> void:
	var box := consoles.staged_box()
	var shown := Rect2(consoles.to_view(box.position), box.size * consoles.view_scale())
	light.look(shown.get_center(), _staging.radius, _staging.darkness)
	_model.position = shown.position
	_model.size = shown.size
	if _model.has_focus() or _step == Step.VARIANTS:
		# On the silhouette's upper right corner, as close to every console.
		var anchor := shown.position + Vector2(shown.size.x, 0.0)
		_callout.point(tr("Variant"), anchor + Vector2(40.0, -40.0), anchor)
	else:
		_callout.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.CLOSED or event.is_echo() or _busy:
		return
	if _step == Step.VARIANTS and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		variant_shown.emit(_kept)
		_close_variants()
	elif _step == Step.VARIANTS:
		return
	elif event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		_close()


func is_open() -> bool:
	return _step != Step.CLOSED or _busy


func open() -> void:
	_change_place.visible = orderable
	var shown := ConsoleManifest.of(consoles.selected().folder) if consoles.selected().modelled else null
	var base: ConsoleManifest = Appearance.defaults(ConsoleManifest.found()).get(shown.platform) if shown else null
	_models = base.models() if base else ([] as Array[ConsoleManifest])
	_model.visible = _models.size() > 1
	_change_place.focus_neighbor_top = _change_place.get_path_to(_model if _model.visible else _change_place)
	_step = Step.PROPERTIES
	show()
	set_process(true)
	await _move(behind, [_properties], _on_properties, _opening)
	_focus_first()


func _focus_first() -> void:
	(_model if _model.visible else _change_place if orderable else _properties).grab_focus()


## Every model of the console in a mosaic, the cursor on the one it has.
func _open_variants() -> void:
	Sounds.play(SoundEffects.Cue.OPEN)
	_step = Step.VARIANTS
	_kept = consoles.selected().folder
	_change_place.hide()
	var focused: Button
	for model in _models:
		var tile := _variant_tile(model)
		_variants.add_child(tile)
		if ConsoleManifest.folder_of(model) == _kept:
			focused = tile
	# A ring, as the consoles' row: left of the first is the last.
	var tiles := _variants.get_children()
	for i in tiles.size():
		var tile: Button = tiles[i]
		tile.focus_neighbor_left = tile.get_path_to(tiles[i - 1])
		tile.focus_neighbor_right = tile.get_path_to(tiles[(i + 1) % tiles.size()])
	_variants.show()
	focused.grab_focus()


func _variant_tile(model: ConsoleManifest) -> Button:
	var folder := ConsoleManifest.folder_of(model)
	var tile := Button.new()
	tile.text = model.model_name
	tile.custom_minimum_size = Vector2(160.0, 44.0)
	tile.add_theme_font_size_override(&"font_size", 22)
	tile.focus_neighbor_top = tile.get_path_to(tile)
	tile.focus_neighbor_bottom = tile.get_path_to(tile)
	tile.focus_entered.connect(func() -> void: variant_shown.emit(folder))
	tile.pressed.connect(_keep_variant.bind(folder))
	return tile


func _keep_variant(folder: String) -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	if folder != _kept:
		variant_kept.emit(folder)
	_close_variants()


func _close_variants() -> void:
	_step = Step.PROPERTIES
	for tile in _variants.get_children():
		tile.queue_free()
	_variants.hide()
	_change_place.visible = orderable
	_model.grab_focus()


func _close() -> void:
	_step = Step.CLOSED
	_put_back([_properties], behind, _in_row, _closing)


func _to_order() -> void:
	if _busy:
		return
	_step = Step.CLOSED
	order_asked.emit()
	_put_back([_properties], [], _in_row, _closing)


func _place() -> void:
	consoles.stage = _staging.amount
	consoles.staged_size = _staging.size
