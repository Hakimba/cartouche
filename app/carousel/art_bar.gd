# SPDX-License-Identifier: GPL-3.0-or-later
class_name ArtBar
extends Control
## How looking for the games' art goes, beside the hints: a bar that moves to each count, grey with the reason
## while the run waits, full then fading once it is over; nothing for a run with nothing to look for.

const _STEP_S := 0.3
const _FULL_S := 1.0
const _FADE_S := 0.4

var _tween: Tween

@onready var _content: Control = $Content
@onready var _bar: ProgressBar = $Content/Bar
@onready var _text: Label = $Content/ArtText


func follow(progress: AndroidServices.ArtProgress) -> void:
	var over := progress.done >= progress.total
	if progress.total == 0 or (over and not visible):
		hide()
		return
	if not over:
		show()
		_content.modulate.a = 1.0
	_bar.max_value = progress.total
	_bar.theme_type_variation = &"ArtBar" if progress.stall.is_empty() else &"ArtBarStalled"
	match progress.stall:
		&"offline":
			_text.text = tr("Disc images · offline, resuming when the network is back")
		&"refused":
			_text.text = tr("Disc images · server unavailable, trying again later")
		&"storage":
			_text.text = tr("Disc images · no room left on the device")
		_:
			_text.text = tr("Disc images · {done} / {total}").format({"done": progress.done, "total": progress.total})
	_tween = Motion.restart(self, _tween)
	_tween.tween_property(_bar, ^"value", float(progress.done), _STEP_S)
	if over:
		_tween.tween_interval(_FULL_S)
		_tween.tween_property(_content, ^"modulate:a", 0.0, _FADE_S)
		_tween.tween_callback(hide)


## Leaves its place to a message while [param message_shown].
func give_way(message_shown: bool) -> void:
	_content.visible = not message_shown
