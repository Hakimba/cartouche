# SPDX-License-Identifier: GPL-3.0-or-later
class_name Palette
extends RefCounted
## One backdrop's values, as [constant StudioTokens.SCHEMES] gives them, typed: every drawing that depends on the
## backdrop reads them here, from [member Backdrop.palette] for the backdrop shown or from its own palette for a
## preview of another. Each field is a key of the scheme.

static var _made: Array[Palette] = []

var scheme: StudioTokens.Scheme
var ink: Color
var mute: Color
var line: Color
## The gel of a screen with no console's colour, as this backdrop draws [constant StudioTokens.NEUTRAL].
var neutral: Color
var plinth_top_shade: Color
## The order ring's arrow: its rim, its highlight and its drop shadow.
var arrow_stroke: Color
var arrow_shine: Color
var arrow_drop: Color
var sticker_shadow: Color
## The ring round a callout's dot.
var callout_ring: Color
## The search ribbon's current key: its mark, drawn over a key filled in [member ink].
var ribbon_key_ink: Color
## A button's round mark.
var key_mark: Color
## A form's pill that does not act yet.
var form_off: Color
var toggle_off_track: Color
## The warm colour of the media's shadows, and of the form's switches'.
var warm_shadow: Color
var toggle_warm: Color
var knob_top: Color
var toggle_knob_edge: Color
var switch_knob_middle: Color
var switch_knob_edge: Color
var switch_track_off: Color
var switch_shadow_knob: Color
var switch_shadow_track: Color
## The smoothing cards' close-up: its ground and the edge drawn on it.
var smoothing_ground: Color
var smoothing_disc: Color
## The veil under a card over the screens.
var scrim: Color
var caret: Color
## [constant StudioTokens.LOOKS] in this backdrop's colours.
var looks: Array[Array]
## The project theme's items this backdrop changes: `Type/colors/item`, or `Type/styles/name/property` of a flat box.
var theme: Dictionary[String, Color]
## The viewport's clear colour, seen where nothing is drawn.
var clear: Color
## The consoles' room light.
var room_light: float
## Whether the logos show their pictures made for a dark ground.
var dark_logos: bool
## How the wall is drawn: `studio` (the baked studio, its glows and the rail's pool of light in the gel), `mapped`
## (the studio's lightness mapped from [member wall_low] to [member wall_high]) or `black`.
var wall: StringName
var wall_low: Color
var wall_high: Color
## The wall's mean colour, which the pixel veil is matched to.
var veil_base: Color
## The pixel veil's colours, one to three, painted over the wall by [method Cyclorama.veil_paint], and how they
## spread: `pixels` (each pixel one of them, at random) or `waves` (mixed in big slow waves).
var veil_colours: Array[Color]
var veil_spread: StringName
## The properties' operating light: the dark it falls off to, the warm alpha at its centre, and the pool it shapes
## round a game, [member operating_pool] mixed in OKLab with the gel by [member operating_pool_gel_share].
var operating_dark: Color
var operating_warm_alpha: float
var operating_pool: Color
var operating_pool_gel_share: float


func _init(shown: StudioTokens.Scheme) -> void:
	scheme = shown
	var values := StudioTokens.SCHEMES[shown]
	for key: StringName in values:
		var value: Variant = values[key]
		# A typed collection takes the untyped one by its elements; set() would leave it empty.
		if value is Array:
			var field: Array = get(key)
			var items: Array = value
			field.assign(items)
		elif value is Dictionary:
			var field: Dictionary = get(key)
			var entries: Dictionary = value
			field.assign(entries)
		else:
			set(key, value)


## [param chosen], a console's gel or [constant StudioTokens.NEUTRAL], in this backdrop: a gel held from before another
## backdrop showed, the neutral of any, is this one's neutral; the gel of a console stays itself.
func gel(chosen: Color) -> Color:
	for each: Palette in _made:
		if chosen == each.neutral:
			return neutral
	return chosen


## The palette of [param shown], made once.
static func of(shown: StudioTokens.Scheme) -> Palette:
	if _made.is_empty():
		for each: int in StudioTokens.Scheme.values():
			_made.append(Palette.new(each as StudioTokens.Scheme))
	return _made[shown]

