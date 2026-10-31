# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioText
extends RefCounted
## One line of text in a Studio face at its fractional size and em tracking, laid out to its exact width.
## Godot's font sizes and glyph spacing are whole pixels, which drifts a string by up to 20 px; so the glyphs
## are shaped once on an MSDF twin of the face (exact advances at any size, no raster at the shaping size),
## placed at their exact x, and drawn from the raster face at the nearest whole size with no scale (a scale
## near 1 blurs them).

## The shaping size: the twin's advances are exact at it.
const _SHAPE_SIZE := 4096
## The line box: every Studio text is 1.5 times its size tall.
const _LINE_HEIGHT := 1.5
const _ELLIPSIS := "…"
const _FILES: Array[String] = [
	"res://fonts/plus-jakarta-sans/PlusJakartaSans-Medium.ttf",
	"res://fonts/plus-jakarta-sans/PlusJakartaSans-Bold.ttf",
	"res://fonts/plus-jakarta-sans/PlusJakartaSans-ExtraBold.ttf",
	"res://fonts/ibm-plex-mono/IBMPlexMono-Medium.ttf",
	"res://fonts/ibm-plex-mono/IBMPlexMono-SemiBold.ttf",
]

## Each face loaded once, by [enum StudioTokens.Face]: its raster font to draw and its MSDF twin to shape.
static var _faces: Dictionary[StudioTokens.Face, Array] = {}
## The system's Japanese face, as MSDF, read the first time a line has kana or kanji: the whole file is read
## into memory, which a line without them never pays. None where the system has no font for them.
static var _japanese: Array[Font] = []
static var _japanese_looked := false
static var _kana_or_kanji := RegEx.create_from_string("[\\x{3000}-\\x{9fff}\\x{ff00}-\\x{ffef}]")

var text: String
## The line's width, the tracking after the last letter included; less once [method fit] cut it.
var width := 0.0
## The line box's height.
var height: float
## The baseline from the line box's top, half the leading above the font's ascent.
var baseline: float
## The font's ascent at this size, rounded, which sets the baseline from the box's top.
var ascent: float

var _face_id: StudioTokens.Face
var _tracking: float
var _tabular: bool
var _styled: StudioText
var _style_key: Array = []
var _px: float
var _display: Font
var _measure: Font
var _line := _Run.new()
var _ellipsis := _Run.new()
## The glyphs drawn: all of them, or those before the ellipsis.
var _shown := 0


## One glyph to draw: from which face, where, which.
class Placement:
	extends RefCounted

	var font: RID
	var at: Vector2
	var index: int

	func _init(face: RID, place: Vector2, glyph: int) -> void:
		font = face
		at = place
		index = glyph


## Shaped glyphs and each one's x from the run's left; the last x is the run's width.
class _Run:
	extends RefCounted

	var glyphs: Array[Dictionary] = []
	var x := PackedFloat64Array([0.0])


## [param shown] in [param face] at [param px], tracked by [param tracking_em], its figures tabular when
## [param tabular].
func _init(shown: String, face: StudioTokens.Face, px: float, tracking_em := 0.0, tabular := false) -> void:
	text = shown
	_face_id = face
	_tracking = tracking_em
	_tabular = tabular
	_px = px
	if not _japanese_looked and _kana_or_kanji.search(shown):
		_add_japanese()
	var fonts := _face(face)
	_display = fonts[0]
	_measure = fonts[1]
	var features := {"tnum": 1} if tabular else {}
	# Letters spaced apart take no optional ligatures.
	if tracking_em != 0.0:
		features["liga"] = 0
	height = px * _LINE_HEIGHT
	# The raster face's metrics are the font's own; the twin's are padded.
	var raw_ascent := _display.get_ascent(_SHAPE_SIZE) * px / _SHAPE_SIZE
	ascent = roundf(raw_ascent)
	baseline = (height - (raw_ascent + _display.get_descent(_SHAPE_SIZE) * px / _SHAPE_SIZE)) / 2.0 + raw_ascent
	_line = _shape(shown, tracking_em, features)
	_ellipsis = _shape(_ELLIPSIS, tracking_em, features)
	fit(INF)


## [param shown] in [param role] ([enum StudioTokens.Role]), its size times [param scale].
static func of(role: StudioTokens.Role, shown: String, scale := 1.0) -> StudioText:
	return StudioText.new(shown, StudioTokens.ROLE_FACE[role], StudioTokens.ROLE_PX[role] * scale,
		StudioTokens.ROLE_TRACKING[role], StudioTokens.ROLE_TNUM[role])


## Cuts the line to [param room] px with an ellipsis when it is wider; the whole line again when it fits.
func fit(room: float) -> void:
	_shown = _line.glyphs.size()
	width = _line.x[_shown]
	if width <= room:
		return
	var room_before := room - _ellipsis.x[-1]
	# Cut only before a cluster's first glyph: a letter and its accent stay together.
	while _shown > 0 and (_line.x[_shown] > room_before or _line.glyphs[mini(_shown, _line.glyphs.size() - 1)].count == 0):
		_shown -= 1
	width = _line.x[_shown] + _ellipsis.x[-1]


## Draws the line in [param canvas] with its box's top left at [param at], in [param outline_color] a
## [param outline_size] px round each glyph first.
func draw(canvas: CanvasItem, at: Vector2, color: Color, outline_size := 0, outline_color := Color.WHITE) -> void:
	if not ControlTokens.has_text_edits():
		_draw_line(canvas, at, color, outline_size, outline_color)
		return
	var style := ControlTokens.text_style(canvas)
	var px: float = style.get(&"studio_font_size", _px)
	var colour: Color = style.get(&"studio_text_colour", color)
	if px != _px:
		var key: Array = [px, text]
		if key != _style_key:
			_styled = StudioText.new(text, _face_id, px, _tracking, _tabular)
			_styled.fit(width * px / _px)
			_style_key = key
		_styled._draw_line(canvas, at, colour, outline_size, outline_color)
	else:
		_draw_line(canvas, at, colour, outline_size, outline_color)


func _draw_line(canvas: CanvasItem, at: Vector2, color: Color, outline_size: int, outline_color: Color) -> void:
	var ts := TextServerManager.get_primary_interface()
	var item := canvas.get_canvas_item()
	var whole := roundi(_px)
	var oversampling := canvas.get_viewport().get_oversampling()
	var drawn := placements(at)
	if outline_size > 0:
		for placed in drawn:
			ts.font_draw_glyph_outline(placed.font, item, whole, outline_size, placed.at, placed.index, outline_color, oversampling)
	for placed in drawn:
		ts.font_draw_glyph(placed.font, item, whole, placed.at, placed.index, color, oversampling)


## Each glyph drawn with the box's top left at [param at], the ellipsis's after the glyphs shown: its face (the
## raster one, or the fallback face that shaped it), its place (its exact x, on a baseline on a whole pixel) and
## its index.
func placements(at: Vector2) -> Array[Placement]:
	var placed: Array[Placement] = []
	var on_line := roundf(at.y + baseline)
	var display := _display.get_rids()[0]
	var measure := _measure.get_rids()[0]
	var runs: Array[Array] = [[_line, _shown, 0.0]]
	if _shown < _line.glyphs.size():
		runs.append([_ellipsis, _ellipsis.glyphs.size(), _line.x[_shown]])
	for shown: Array in runs:
		var run: _Run = shown[0]
		var count: int = shown[1]
		var start: float = shown[2]
		for i in count:
			var glyph := run.glyphs[i]
			var face: RID = display if glyph.font_rid == measure else glyph.font_rid
			var index: int = glyph.index
			placed.append(Placement.new(face, Vector2(at.x + start + run.x[i], on_line), index))
	return placed


func _shape(shown: String, tracking_em: float, features: Dictionary) -> _Run:
	var ts := TextServerManager.get_primary_interface()
	var shaped := ts.create_shaped_text()
	ts.shaped_text_add_string(shaped, shown, _measure.get_rids(), _SHAPE_SIZE, features)
	var k := _px / _SHAPE_SIZE
	var run := _Run.new()
	run.glyphs = ts.shaped_text_get_glyphs(shaped)
	ts.free_rid(shaped)
	run.x.resize(run.glyphs.size() + 1)
	var x := 0.0
	for i in run.glyphs.size():
		var glyph := run.glyphs[i]
		run.x[i] = x + glyph.offset.x * k
		x += glyph.advance * k
		if glyph.count > 0:
			x += tracking_em * _px * (glyph.end - glyph.start)
	run.x[run.glyphs.size()] = x
	return run


## The raster font and its MSDF twin of [param face], loaded the first time.
static func _face(face: StudioTokens.Face) -> Array:
	if face not in _faces:
		var display: FontFile = load(_FILES[face])
		var measure: FontFile = display.duplicate()
		measure.multichannel_signed_distance_field = true
		# A tiny MSDF raster: only the advances are read from it, and its first use is six times faster.
		measure.msdf_size = 8
		measure.msdf_pixel_range = 2
		# A letter the face lacks comes from the system's fonts, as MSDF too, and is drawn from that font: its main
		# face, then its Japanese one once a line needs it, as a system's main face has no kana nor kanji.
		measure.allow_system_fallback = false
		var fallback := SystemFont.new()
		fallback.multichannel_signed_distance_field = true
		measure.fallbacks = [fallback] + _japanese
		_faces[face] = [display, measure]
	return _faces[face]


## Adds the system's Japanese face after the other fallbacks of every face, once.
static func _add_japanese() -> void:
	_japanese_looked = true
	var paths := OS.get_system_font_path_for_text("sans-serif", "日本語", "ja")
	var font := FontFile.new()
	if paths.is_empty() or font.load_dynamic_font(paths[0]) != OK or not font.has_char("日".unicode_at(0)):
		return
	font.multichannel_signed_distance_field = true
	_japanese = [font]
	for fonts: Array in _faces.values():
		var measure: Font = fonts[1]
		measure.fallbacks = measure.fallbacks + _japanese
