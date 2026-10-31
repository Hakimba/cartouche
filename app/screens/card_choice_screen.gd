# SPDX-License-Identifier: GPL-3.0-or-later
class_name CardChoiceScreen
extends Control
## A setting chosen on a page of its own, among cards of a grid built from the values the plugin takes: the
## preferred region of images, the language. The empty value comes first; the one in use now is ticked and has
## the focus. Left and right go through the cards in reading order, up and down from row to row. B goes back
## when [member can_go_back], keeping the value it had.

signal chosen(value: String)

const _CARD_FONT_PX := 26

## The page's title and the line under it, as their `msgid`s.
@export var title := ""
@export var note := ""
@export_range(1, 6) var columns := 4
@export var card_size := Vector2(268.8, 80.0)

## Whether B goes back, keeping the value: not on the first launch.
var can_go_back := false
var _choices := PackedStringArray()
var _current := ""

@onready var _cards: GridContainer = %Cards


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)
	(%Title as Label).text = title
	(%Note as Label).text = note


func _unhandled_input(event: InputEvent) -> void:
	if can_go_back and is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		chosen.emit(_current)


## Offers the empty value then [param values], each card reading [param name_of] of its value, the card of
## [param current] ticked.
func open(current: String, values: PackedStringArray, name_of: Callable) -> void:
	_current = current
	(%Back as Control).visible = can_go_back
	_choices = PackedStringArray([""]) + values
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	_cards.columns = columns
	for value in _choices:
		var card := Button.new()
		card.name = value if value else "None"
		card.text = name_of.call(value)
		card.custom_minimum_size = card_size
		card.add_theme_font_size_override(&"font_size", _CARD_FONT_PX)
		SatinStyle.apply_to(card)
		card.pressed.connect(_choose.bind(value))
		if value == current:
			card.add_child(Tick.new())
		_cards.add_child(card)
	# Set by index: the grid lays its cards out only on the next frame, too late for a first press.
	var last := _choices.size() - 1
	for i in _choices.size():
		var card := _cards.get_child(i) as Control
		# Down from the row above the last, where nothing stands below: to the last card.
		var below := i + columns if i + columns <= last else last if i + columns - i % columns <= last else i
		card.focus_neighbor_left = card.get_path_to(_cards.get_child(maxi(0, i - 1)))
		card.focus_neighbor_right = card.get_path_to(_cards.get_child(mini(last, i + 1)))
		card.focus_neighbor_top = card.get_path_to(_cards.get_child(i - columns if i >= columns else i))
		card.focus_neighbor_bottom = card.get_path_to(_cards.get_child(below))
	(_cards.get_child(maxi(_choices.find(current), 0)) as Control).grab_focus()


func _choose(value: String) -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(value)


## The tick on the card of the value chosen now, drawn: fonts rarely have the sign.
class Tick extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_left = -44.0

	func _draw() -> void:
		draw_polyline([Vector2(0.0, 0.0), Vector2(7.0, 7.0), Vector2(20.0, -8.0)], StudioTokens.INK, 3.5, true)
