# SPDX-License-Identifier: GPL-3.0-or-later
class_name ScreenLayout
extends RefCounted
## Where a screen of any shape puts what is drawn in px of the 1280 × 960 frame ([constant CarouselLayout.FRAME]).
## The screen is the viewport's visible rect: the stretch keeps it 960 high when wider than 4:3, 1280 wide when narrower.
##
## Three places a part can belong to. The [b]stage[/b] (the consoles, the games, the cards and forms, the ring) is the
## frame in the middle of the screen, at its size: the stretch always shows it whole. A node of the stage is anchored on
## the screen's centre (both ways), the 3D through its camera ([StageLens]). The [b]top band[/b] (clock, battery, "+",
## the games' logo) keeps to the screen's top, the [b]bottom band[/b] (the rail, the hints, the search ribbon) to its
## bottom, each part on the left edge, the middle or the right edge. On a 4:3 screen all three are the frame itself.
##
## How a family of screens lays out is data ([constant FILE]): the shapes it covers and its values, each defaulting to
## the 4:3 layout. A screen shape is changed or added there, never in code.

## Which edge of a band a part keeps to, across the screen's width.
enum Side { LEFT, MIDDLE, RIGHT }

const FILE := "res://data/screen_formats.json"


## One family of screens: those up to [member up_to] wide for 1 high, and how they lay out.
class Format:
	var name: String
	var up_to: float
	## Whether the games past the selected one's neighbours stand at the neighbours' height instead of going on down the
	## shelf's arc (out of the screen, on the 4:3 frame), so that a wider screen shows more of them.
	var shelf_level: bool

	func _init(data: Dictionary) -> void:
		name = data["name"]
		up_to = data.get("up_to", INF)
		shelf_level = data.get("shelf_level", false)


static var _formats: Array[Format] = []

## The screen, in px of the viewport.
var size: Vector2
var format: Format
## Where the frame's corner stands on the stage.
var stage_origin: Vector2


## The layout of a screen [param shown] px wide and high.
static func of(shown: Vector2) -> ScreenLayout:
	return ScreenLayout.new(shown)


## The layout of [param viewport]'s screen.
static func at(viewport: Viewport) -> ScreenLayout:
	return of(viewport.get_visible_rect().size)


## The families read from [constant FILE], from the narrowest.
static func formats() -> Array[Format]:
	if _formats.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		for entry: Dictionary in data["formats"]:
			_formats.append(Format.new(entry))
		_formats.sort_custom(func(a: Format, b: Format) -> bool: return a.up_to < b.up_to)
	return _formats


## Drops the file read, so that the next layout follows a file the debug bridge reloaded.
static func forget() -> void:
	_formats.clear()


func _init(shown: Vector2) -> void:
	size = shown
	var shape := shown.x / shown.y
	for family in formats():
		format = family
		if shape <= family.up_to:
			break
	stage_origin = (size - CarouselLayout.FRAME) / 2.0


## The stage's point [param design] (px of the frame), in px of the screen.
func on_stage(design: Vector2) -> Vector2:
	return stage_origin + design


## The screen's point [param shown] (px of the screen), in px of the frame on the stage.
func from_stage(shown: Vector2) -> Vector2:
	return shown - stage_origin


## Where a part of the top band drawn at [param design] stands, kept to [param side].
func top(design: Vector2, side := Side.MIDDLE) -> Vector2:
	return Vector2(design.x + spare_width() * side / 2.0, design.y)


## Where a part of the bottom band drawn at [param design] stands, kept to [param side].
func bottom(design: Vector2, side := Side.MIDDLE) -> Vector2:
	return Vector2(design.x + spare_width() * side / 2.0, design.y + size.y - CarouselLayout.FRAME.y)


## How much wider than the frame the screen is: room for more of a row on its two sides.
func spare_width() -> float:
	return size.x - CarouselLayout.FRAME.x
