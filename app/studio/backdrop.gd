# SPDX-License-Identifier: GPL-3.0-or-later
class_name Backdrop
extends RefCounted
## The backdrop behind every screen, as the settings chose it, whether its pixel veil moves and in what colours. One place holds
## it: [member palette], the backdrop's values every drawing reads. Showing another backdrop or turning the veil
## changes the project theme's items it names, then the theme tells every control at once
## ([constant Control.NOTIFICATION_THEME_CHANGED]): a control drawn from the palette is drawn again, and one keeping
## something made from it ([SatinPanel.Backing], a material, a texture) makes it again then.

## Each backdrop the settings offer, by the name the plugin stores it under, and its name on screen. `device` is
## Light or Dark as the system's theme is, followed while the app runs.
const NAMES: Dictionary[StringName, String] = {&"light": "Light", &"dark": "Dark", &"light_grey": "Light grey",
	&"anthracite": "Anthracite", &"device": "Like the device"}

## The backdrop chosen, a key of [constant NAMES].
static var choice := &"light"
## Whether the pixel veil moves behind the screens. A fresh install's backdrop is shown until the stored one is read,
## before the first frame.
static var veil := true
## Whether the veil takes the staged console's gel instead of the backdrop's own veil colours.
static var veil_gel := false
## The values of the backdrop shown.
static var palette := Palette.of(StudioTokens.Scheme.LIGHT)
## Whether the system's theme is dark, as `device` reads it; a test stands in for the system with its own.
static var system_dark := func() -> bool: return DisplayServer.is_dark_mode()
## The theme's items as the project's theme file has them, for the light backdrop: read before the first change.
static var _theme_as_made: Dictionary[String, Color] = {}


## Shows [param chosen] (a key of [constant NAMES]) with the veil [param moving] or still, in the console's gel when
## [param in_gel], on every screen at once; nothing is drawn again when all are as shown. Returns what shows, for the
## traces.
static func show(chosen: StringName, moving: bool, in_gel: bool) -> String:
	choice = chosen
	var shown := Palette.of(scheme_of(chosen))
	var said := "%s (%s), veil %s%s" % [StudioTokens.Scheme.find_key(shown.scheme), chosen,
		"moving" if moving else "still", " in the gel" if in_gel else ""]
	if shown == palette and moving == veil and in_gel == veil_gel:
		return said
	palette = shown
	veil = moving
	veil_gel = in_gel
	RenderingServer.set_default_clear_color(palette.clear)
	var theme := ThemeDB.get_project_theme()
	theme.set_block_signals(true)
	if _theme_as_made.is_empty():
		for scheme: Dictionary in StudioTokens.SCHEMES:
			for item: String in scheme[&"theme"]:
				_theme_as_made[item] = theme.get_indexed(_path(item))
	for item: String in _theme_as_made:
		theme.set_indexed(_path(item), palette.theme.get(item, _theme_as_made[item]))
	theme.set_block_signals(false)
	theme.emit_changed()
	return said


## The scheme [param chosen] draws, the one of its name: `device` follows the system's light or dark theme.
static func scheme_of(chosen: StringName) -> StudioTokens.Scheme:
	if chosen == &"device":
		return StudioTokens.Scheme.DARK if system_dark.call() else StudioTokens.Scheme.LIGHT
	return StudioTokens.Scheme[chosen.to_upper()]


## Shows the device's theme again when it changed and the backdrop follows it.
static func follow_system() -> String:
	return show(choice, veil, veil_gel)


## [param item] as a property path of the theme: a colour's own, or a flat box's and then its property.
static func _path(item: String) -> NodePath:
	return NodePath(item if item.count("/") == 2 else "%s:%s" % [item.get_base_dir(), item.get_file()])
