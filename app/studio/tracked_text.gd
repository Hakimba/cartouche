# SPDX-License-Identifier: GPL-3.0-or-later
class_name TrackedText
extends RefCounted
## The theme's tracked text roles, drawn through [StudioText]: Godot's whole-pixel glyph spacing and font sizes
## put the right edge of a tracked line up to 10 px off the browser's, a [StudioText] line is exact.
## The theme keeps each role's font and size (the layout measures with them); this is the face and the tracking in
## em the roles are drawn with.

## Each role's face and tracking in em, as the design sets them.
const ROLES: Dictionary[StringName, Array] = {
	&"ScreenTitle": [StudioTokens.Face.JAKARTA_800, -0.04],
	&"PanelTitle": [StudioTokens.Face.JAKARTA_800, -0.04],
	&"NameButton": [StudioTokens.Face.JAKARTA_800, -0.035],
	&"Title": [StudioTokens.Face.JAKARTA_800, -0.01],
	&"SearchCount": [StudioTokens.Face.PLEX_600, 0.08],
}


## [param shown] in [param role] at [param px].
static func line(role: StringName, shown: String, px: float) -> StudioText:
	var told: Array = ROLES[role]
	var face: StudioTokens.Face = told[0]
	var tracking: float = told[1]
	return StudioText.new(shown, face, px, tracking)


## [param shown] in [param role] at [param px], wrapped at spaces to lines of at most [param room] px.
static func lines(role: StringName, shown: String, px: float, room: float) -> Array[StudioText]:
	var wrapped: Array[StudioText] = []
	for paragraph in shown.split("\n"):
		var current := ""
		for word in paragraph.split(" "):
			var next := word if current.is_empty() else current + " " + word
			if not current.is_empty() and line(role, next, px).width > room:
				wrapped.append(line(role, current, px))
				next = word
			current = next
		wrapped.append(line(role, current, px))
	return wrapped
