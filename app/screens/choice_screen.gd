# SPDX-License-Identifier: GPL-3.0-or-later
class_name ChoiceScreen
extends Page
## A choice among cards side by side ([ChoiceCard]), left and right to move, A or a tap to choose. B goes back, choosing
## nothing, when [member can_go_back]. It answers the value chosen, empty when the user went back.

var can_go_back := false


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)
	for card: ChoiceCard in %Cards.get_children():
		card.chosen.connect(_on_card_chosen)


func _unhandled_input(event: InputEvent) -> void:
	if can_go_back and is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		done.emit(&"")


## Puts the focus on the card of the choice in use now.
func focus() -> void:
	for card: ChoiceCard in %Cards.get_children():
		if card.value == _current():
			card.grab_focus()


func _open(_request: Variant) -> void:
	focus()


## The choice in use now.
func _current() -> StringName:
	return &""


func _on_card_chosen(value: StringName) -> void:
	Diagnostics.trace("screens", "%s %s" % [name, value])
	Sounds.play(SoundEffects.Cue.SELECT)
	done.emit(value)
