# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConfirmRemoval
extends Control
## "Remove <platform>?": what goes, and that the game files stay. The focus starts on "Cancel";
## B cancels too.

## [param remove] is false when cancelled.
signal answered(remove: bool)

@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _cancel: Button = %Cancel


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		answered.emit(false)


## Asks about [param platform_name] and its [param games] games, whose folder is on
## [param volume] (`card`, `internal`, or empty when unknown).
func open(platform_name: String, games: int, volume: StringName) -> void:
	_title.text = tr("Remove {platform}?").format({"platform": platform_name})
	var goes := tr_n("Its {count} game, its image and the access to its folder will be removed from Cartouche.",
		"Its {count} games, their images and the access to its folder will be removed from Cartouche.", games) \
		if games > 0 else tr("Its choices and the access to its folder will be removed from Cartouche.")
	var stays: String = {
		&"card": tr("Your game files stay on the SD card."),
		&"internal": tr("Your game files stay in the internal storage."),
	}.get(volume, tr("Your game files stay where they are."))
	_text.text = goes.format({"count": games}) + " " + stays
	_cancel.grab_focus()


func _on_cancel_pressed() -> void:
	Sounds.play(SoundEffects.Cue.BACK)
	answered.emit(false)


func _on_remove_pressed() -> void:
	Sounds.play(SoundEffects.Cue.REMOVE)
	answered.emit(true)
