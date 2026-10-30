# SPDX-License-Identifier: GPL-3.0-or-later
class_name StyleCard
extends ChoiceCard
## One button style to choose ([member ChoiceCard.value]): the four face buttons drawn as that style marks them,
## and the style's name.

## The face buttons of each style: top, left, right, bottom.
const _FACES: Dictionary[StringName, Array] = {
	&"xbox": ["Y", "X", "B", "A"],
	&"nintendo": ["X", "Y", "A", "B"],
	&"playstation": ["△", "□", "○", "✕"],
}
const _BUTTON_RADIUS := 31.0
const _SPREAD := 65.0
const _TITLE_SIZE := 28


func _draw_sample() -> void:
	var centre := Vector2(size.x / 2.0, size.y * 0.44)
	var offsets: Array[Vector2] = [Vector2(0, -_SPREAD), Vector2(-_SPREAD, 0), Vector2(_SPREAD, 0), Vector2(0, _SPREAD)]
	var faces: Array[String] = []
	faces.assign(_FACES[value])
	for i in 4:
		var at := centre + offsets[i]
		ButtonMark.draw(self, faces[i], at, _BUTTON_RADIUS, 28.0)
	var font := get_theme_font(&"font", &"FieldValue")
	var title := Controls.NAMES[value]
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_SIZE).x
	draw_string(font, Vector2((size.x - width) / 2.0, size.y - 40.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_TITLE_SIZE, StudioTokens.INK)
