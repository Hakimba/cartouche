# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioMaterial
extends RefCounted
## One of the Studio materials, as [StudioTokens] gives it: its fill, its corner radius and its box
## shadows. [SatinPanel] draws it with a shader, [SatinStyle] as a StyleBox for Godot's own controls.

## The fill's stops (parts of the way), and their colours.
var stops: Array[float] = []
var colors: Array[Color] = []
## A radial fill's centre in parts of the box (to the farthest corner), or (-1, -1) for a fill from top to bottom.
var centre: Vector2
var radius: float
## Insets first, then the outer shadows, each group in the tokens' order (the first one drawn on top).
var shadows: Array[Shadow] = []


## A box shadow: its offset, blur, spread, colour, whether inside the box, and whether it takes the gel.
class Shadow:
	extends RefCounted

	var offset: Vector2
	## A Gaussian of standard deviation blur / 2.
	var blur: float
	var spread: float
	var color: Color
	var inset: bool
	var tinted: bool
	## A tinted shadow's share of the gel, mixed with white in OKLab; 1, the gel alone.
	var gel_share := 1.0

	func _init(entry: Array) -> void:
		var shape: Vector4 = entry[0]
		offset = Vector2(shape.x, shape.y)
		blur = shape.z
		spread = shape.w
		color = entry[1]
		inset = entry[2]
		tinted = entry[3]
		if entry.size() > 4:
			gel_share = entry[4]

	## Its colour, the gel's when it takes it.
	func shown(gel: Color) -> Color:
		return Color(StudioMaterial.whitened(gel, gel_share), color.a) if tinted else color


func _init(look: StudioTokens.Look) -> void:
	var recipe: Array = StudioTokens.LOOKS[look]
	var shown_stops: Array = recipe[0]
	var shown_colors: Array = recipe[1]
	var shown_shadows: Array = recipe[4]
	stops.assign(shown_stops)
	colors.assign(shown_colors)
	centre = recipe[2]
	radius = recipe[3]
	for entry: Array in shown_shadows:
		shadows.append(Shadow.new(entry))


## How far past the box its outer shadows reach.
func reach() -> float:
	var far := 0.0
	for shadow in shadows:
		if not shadow.inset:
			far = maxf(far, shadow.offset.length() + shadow.spread + shadow.blur * 1.5 + 1.0)
	return ceilf(far)


## The fill's colour at [param t] of its way.
func fill_at(t: float) -> Color:
	var color := colors[0]
	for i in range(1, stops.size()):
		color = color.lerp(colors[i], clampf((t - stops[i - 1]) / maxf(stops[i] - stops[i - 1], 1e-5), 0.0, 1.0))
	return color


## [param colour] mixed with white in OKLab, [param share] of it; a mix out of the screen's colours is clipped
## to them.
static func whitened(colour: Color, share: float) -> Color:
	if share >= 1.0:
		return colour
	return srgb(oklab(colour).lerp(oklab(Color.WHITE), 1.0 - share)).clamp()


## [param colour] mixed with black in OKLab, [param share] of it.
static func shaded(colour: Color, share: float) -> Color:
	return srgb(oklab(colour) * share).clamp()


static func oklab(c: Color) -> Vector3:
	var r := c.srgb_to_linear()
	var l := pow(0.4122214708 * r.r + 0.5363325363 * r.g + 0.0514459929 * r.b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r.r + 0.6806995451 * r.g + 0.1073969566 * r.b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r.r + 0.2817188376 * r.g + 0.6299787005 * r.b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func srgb(lab: Vector3) -> Color:
	var l := pow(lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z, 3.0)
	var m := pow(lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z, 3.0)
	var s := pow(lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z, 3.0)
	return Color(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s).linear_to_srgb()
