# SPDX-License-Identifier: GPL-3.0-or-later
class_name EdgeSmoothingScreen
extends Control
## "Which edge smoothing?", a note that the choice only changes the 3D's edges, and three cards side
## by side, left and right to choose: 4× (the default), 2× or none. B goes back.

## The user chose [param smoothing]; empty when they went back.
signal chosen(smoothing: StringName)

const MSAA: Dictionary[StringName, Viewport.MSAA] = {
	&"4x": Viewport.MSAA_4X,
	&"2x": Viewport.MSAA_2X,
	&"off": Viewport.MSAA_DISABLED,
}
const NAMES: Dictionary[StringName, String] = {&"4x": "Smoothing 4×", &"2x": "Smoothing 2×", &"off": "No smoothing"}


func _ready() -> void:
	for card: SmoothingCard in %Cards.get_children():
		card.chosen.connect(_on_card_chosen)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"")


## The smoothing [param viewport]'s 3D is drawn with.
static func of(viewport: Viewport) -> StringName:
	return MSAA.find_key(viewport.msaa_3d)


## Puts the focus on the card of the smoothing drawn now.
func focus() -> void:
	for card: SmoothingCard in %Cards.get_children():
		if card.smoothing == of(get_viewport()):
			card.grab_focus()


func _on_card_chosen(smoothing: StringName) -> void:
	Diagnostics.trace("screens", "edge smoothing %s" % smoothing)
	chosen.emit(smoothing)
