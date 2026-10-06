# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleWheel
extends RefCounted
## The consoles in a ring, in their order, and a cursor on one of them. The ring has no end: n steps
## either way come back to the same console. A console taken moves with the cursor, trading places
## with each one it passes, so that the ring shows at once the order it would leave; put down, it
## keeps that order; let go, the order goes back to what it was.

## The platform ids, in their order round the ring.
var order: Array[String] = []
## The index in [member order] of the console the cursor is on.
var cursor := 0

## The order as it was when the console was taken; empty while none is.
var _before: Array[String] = []


func _init(platform_ids: Array[String], at: int) -> void:
	order = platform_ids.duplicate()
	cursor = at


func selected() -> String:
	return order[cursor]


func is_holding() -> bool:
	return not _before.is_empty()


## Whether the console held stands elsewhere than where it was taken.
func is_moved() -> bool:
	return is_holding() and order != _before


## One step round the ring towards [param direction] (-1 or 1), the console held, if any, with it.
func step(direction: int) -> void:
	var next := posmod(cursor + direction, order.size())
	if is_holding():
		var passed := order[next]
		order[next] = order[cursor]
		order[cursor] = passed
	cursor = next


## The cursor on the console at [param index] of [member order], none being held.
func point(index: int) -> void:
	if not is_holding():
		cursor = index


## Takes the console under the cursor.
func take() -> void:
	_before = order.duplicate()


## Puts the console held down where it is; whether the order changed.
func put_down() -> bool:
	var moved := is_moved()
	_before = []
	return moved


## Lets go of the console held: the order as it was, the cursor on it again.
func let_go() -> void:
	if not is_holding():
		return
	var held := selected()
	order = _before
	_before = []
	cursor = order.find(held)


## The consoles either side of the cursor's, before then after it; the same one twice when there
## are only two, none when it is alone.
func neighbours() -> Array[String]:
	var around: Array[String] = []
	if order.size() > 1:
		around.assign([order[posmod(cursor - 1, order.size())], order[posmod(cursor + 1, order.size())]])
	return around
