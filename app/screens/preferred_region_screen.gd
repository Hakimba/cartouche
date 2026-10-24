# SPDX-License-Identifier: GPL-3.0-or-later
class_name PreferredRegionScreen
extends Control
## The first launch chooses image priority before a library can start scraping.

signal chosen(region: String)

const _CARD_SIZE := Vector2(230.4, 230.4)
const _CARD_FONT_PX := 30

var _choices := PackedStringArray()

@onready var _cards: HBoxContainer = %Cards


func open(current: String, regions: PackedStringArray) -> void:
	_choices = PackedStringArray([""]) + regions
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	for region in _choices:
		var card := Button.new()
		card.name = region if not region.is_empty() else "None"
		card.text = tr(region) if not region.is_empty() else tr("None")
		card.custom_minimum_size = _CARD_SIZE
		card.add_theme_font_size_override(&"font_size", _CARD_FONT_PX)
		SatinStyle.apply_to(card)
		card.pressed.connect(chosen.emit.bind(region))
		_cards.add_child(card)
	for i in _choices.size():
		var card := _cards.get_child(i) as Control
		card.focus_neighbor_left = card.get_path_to(_cards.get_child(maxi(0, i - 1)))
		card.focus_neighbor_right = card.get_path_to(_cards.get_child(mini(_choices.size() - 1, i + 1)))
		card.focus_neighbor_top = NodePath(".")
		card.focus_neighbor_bottom = NodePath(".")
	(_cards.get_child(maxi(_choices.find(current), 0)) as Control).grab_focus()
