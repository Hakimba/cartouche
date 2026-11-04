# SPDX-License-Identifier: GPL-3.0-or-later
class_name BackdropScreen
extends ChoiceScreen
## "Which background?", a note on what it changes, and a card for each backdrop, each showing it drawn
## ([BackdropCard]). A card chosen shows its backdrop at once, the cards staying; B goes back.

func _init() -> void:
	can_go_back = true


func _current() -> StringName:
	return Backdrop.choice
