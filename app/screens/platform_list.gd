# SPDX-License-Identifier: GPL-3.0-or-later
class_name PlatformList
extends Control
## The configured consoles, as logo tiles on their own screen. A opens the existing editor; B returns.

signal chosen(index: int)

const COLUMNS := 4

@onready var _rows: GridContainer = %Rows


class Tile:
	extends Button
	var platform_id: String
	var logo := LogoView.new()

	func _init(platform: AndroidServices.Platform, folder: String) -> void:
		platform_id = platform.id
		name = platform.id
		text = platform.name
		clip_text = true
		add_theme_constant_override(&"outline_size", 0)
		auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		custom_minimum_size = Vector2(230.4, 153.6)
		var tint: Color = StudioTokens.GEL.get(StringName(folder), StudioTokens.NEUTRAL)
		SatinStyle.apply_to(self, tint)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color", &"font_disabled_color"]:
			add_theme_color_override(state, Color.TRANSPARENT)
		logo.show_logo(LogoView.Slot.RAIL_TILE, folder)
		add_child(logo)
		logo.size = logo.texture.get_size()
		resized.connect(func() -> void: logo.position = (size - logo.size) / 2.0)


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.BACK)
		chosen.emit(-1)


func open(platforms: Array[AndroidServices.Platform], focus: int) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var models := Appearance.defaults(ConsoleManifest.found())
	for i in platforms.size():
		var manifest: ConsoleManifest = models.get(platforms[i].id)
		var tile := Tile.new(platforms[i], ConsoleManifest.folder_of(manifest))
		tile.pressed.connect(_choose.bind(i))
		_rows.add_child(tile)
	for i in platforms.size():
		var tile := _rows.get_child(i) as Control
		var left := i - 1 if i % COLUMNS > 0 else i
		var right := i + 1 if i % COLUMNS < COLUMNS - 1 and i + 1 < platforms.size() else i
		tile.focus_neighbor_left = tile.get_path_to(_rows.get_child(left))
		tile.focus_neighbor_right = tile.get_path_to(_rows.get_child(right))
		tile.focus_neighbor_top = tile.get_path_to(_rows.get_child(maxi(i - COLUMNS, i % COLUMNS)))
		var below := i - i % COLUMNS + COLUMNS
		var down := mini(i + COLUMNS, platforms.size() - 1) if below < platforms.size() else i
		tile.focus_neighbor_bottom = tile.get_path_to(_rows.get_child(down))
	(_rows.get_child(clampi(focus, 0, platforms.size() - 1)) as Control).grab_focus()


func _choose(index: int) -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	chosen.emit(index)
