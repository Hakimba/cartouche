# SPDX-License-Identifier: GPL-3.0-or-later
class_name PreferredRegionScreen
extends Control
## The region labels' images prefer, on a page of its own: on the first launch before a library can
## start scraping, and from the settings. Every choice is a card of a grid, none first; the one
## chosen now is ticked and has the focus. Left and right go through the cards in reading order, up
## and down from row to row. B goes back when [member can_go_back], keeping the region it had.

signal chosen(region: String)

const _COLUMNS := 4
const _CARD_SIZE := Vector2(268.8, 80.0)
const _CARD_FONT_PX := 26

## Whether B goes back, keeping the region: not on the first launch.
var can_go_back := false
var _choices := PackedStringArray()
var _current := ""

@onready var _cards: GridContainer = %Cards


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)


func _unhandled_input(event: InputEvent) -> void:
	if can_go_back and is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		chosen.emit(_current)


func open(current: String, regions: PackedStringArray) -> void:
	_current = current
	(%Back as Control).visible = can_go_back
	_choices = PackedStringArray([""]) + regions
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	_cards.columns = _COLUMNS
	for region in _choices:
		var card := Button.new()
		card.name = region if not region.is_empty() else "None"
		card.text = tr(region) if not region.is_empty() else tr("None")
		card.custom_minimum_size = _CARD_SIZE
		card.add_theme_font_size_override(&"font_size", _CARD_FONT_PX)
		SatinStyle.apply_to(card)
		card.pressed.connect(_choose.bind(region))
		if region == current:
			card.add_child(Tick.new())
		_cards.add_child(card)
	# Set by index: the grid lays its cards out only on the next frame, too late for a first press.
	var last := _choices.size() - 1
	for i in _choices.size():
		var card := _cards.get_child(i) as Control
		# Down from the row above the last, where nothing stands below: to the last card.
		var below := i + _COLUMNS if i + _COLUMNS <= last else last if i + _COLUMNS - i % _COLUMNS <= last else i
		card.focus_neighbor_left = card.get_path_to(_cards.get_child(maxi(0, i - 1)))
		card.focus_neighbor_right = card.get_path_to(_cards.get_child(mini(last, i + 1)))
		card.focus_neighbor_top = card.get_path_to(_cards.get_child(i - _COLUMNS if i >= _COLUMNS else i))
		card.focus_neighbor_bottom = card.get_path_to(_cards.get_child(below))
	(_cards.get_child(maxi(_choices.find(current), 0)) as Control).grab_focus()


func _choose(region: String) -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(region)


## The tick on the card of the region chosen now, drawn: fonts rarely have the sign.
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
