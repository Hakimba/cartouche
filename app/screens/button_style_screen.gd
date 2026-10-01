# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonStyleScreen
extends Control
## "Which button style?", a note that the choice only draws, and three cards side by side, left
## and right to choose: Xbox's letters (A at the bottom), Nintendo's (A on the right) or
## PlayStation's shapes (see [Controls]). B goes back when [member can_go_back].

## The user chose [param style]; empty when they went back.
signal chosen(style: StringName)

## Whether B goes back, choosing nothing: not on the first launch.
var can_go_back := false


func _ready() -> void:
	for card: StyleCard in %Cards.get_children():
		card.chosen.connect(_on_card_chosen)


func _unhandled_input(event: InputEvent) -> void:
	if can_go_back and is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"")


## Puts the focus on the card of the style drawn now.
func focus() -> void:
	for card: StyleCard in %Cards.get_children():
		if card.style == Controls.style:
			card.grab_focus()


func _on_card_chosen(style: StringName) -> void:
	Diagnostics.trace("screens", "button style %s" % style)
	chosen.emit(style)
