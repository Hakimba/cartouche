# SPDX-License-Identifier: GPL-3.0-or-later
class_name ChoiceList
extends Control
## A list to choose one item from, over the form that opened it: up and down move, A chooses, B
## gives up. The list scrolls to keep the focused item in its middle, its focus ring whole.

## Answered once per [method choose]: the index chosen, or -1 when given up.
signal chosen(index: int)

const _ITEM_HEIGHT := 64.0

@onready var _title: Label = %Title
@onready var _items: VBoxContainer = %Items
@onready var _scroll: ScrollContainer = %Scroll


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		_answer(-1)


## Shows [param options] under [param title], the focus on [param current]; returns the index
## chosen, or -1.
func choose(title: String, options: PackedStringArray, current: int) -> int:
	_title.text = title
	# Gone at once: the focus must land on the new items, never on one about to go.
	for item in _items.get_children():
		_items.remove_child(item)
		item.queue_free()
	for i in options.size():
		var item := GlyphButton.new()
		item.text = options[i]
		item.custom_minimum_size.y = _ITEM_HEIGHT
		item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		item.pressed.connect(_answer.bind(i))
		item.focus_entered.connect(_centre.bind(item))
		_items.add_child(item)
	show()
	(_items.get_child(clampi(current, 0, options.size() - 1)) as Control).grab_focus.call_deferred()
	var index: int = await chosen
	return index


func _centre(item: Control) -> void:
	var middle := item.get_global_rect().get_center().y - _items.get_global_rect().position.y
	_scroll.scroll_vertical = roundi(middle - _scroll.size.y / 2.0)


func _answer(index: int) -> void:
	hide()
	chosen.emit(index)
