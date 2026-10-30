# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonStyleScreen
extends ChoiceScreen
## "Which button style?", a note that the choice only draws, and three cards: Xbox's letters (A at the bottom),
## Nintendo's (A on the right) or PlayStation's shapes (see [Controls]). B goes back when [member can_go_back].


func _current() -> StringName:
	return Controls.style
