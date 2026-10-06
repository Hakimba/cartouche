# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscProperties
extends PropertiesScreen
## The properties of the selected game. Its disc leaves the row for the middle of the screen, still
## and facing the camera, under the light of an operating table ([OperatingLight]), while the other
## discs and the console behind fade out; up and down go from one part of it to the other (its
## label, its name), the one with the focus outlined in black and named by a callout. A on the label opens the images it can show,
## one per region the art sources have, the closest to the game's own first: the disc shows the one
## with the focus at once, A keeps it, B goes back without changing it. The last card opens the
## system's picker on the user's own pictures: the one picked shows on the disc, to be framed with
## the stick (moving it) and L1 / R1 (zooming), then A keeps it, B goes back to the cards. A on the
## name opens a keyboard played with the stick: X erases, Y types a space, Start keeps the name (blank,
## the game's own title comes back), B goes back without changing it. B goes back to the row.
## By touch, a tap on the label, the name, a card or a key does what A does; the picture being
## framed follows a finger dragged over it, and a pinch zooms it.

## The image picked could not be kept.
signal choice_failed
## The game was given a name, or its own title back.
signal name_kept

enum Step { CLOSED, PROPERTIES, LABELS, FRAMING, NAMING }

## The disc's label reaches this far from its centre, in world units at the disc's size in the row
## (`dvd_shape.tres`); its ring stands a little further out.
const _LABEL_RADIUS := 0.59
const _RING_OUTSET := 1.04
## The callout's caption stands right of what it points at, this far, in pixels, and its arrow
## points at the disc's rim this far round from its right (radians, upwards).
const _CAPTION_AWAY := 70.0
const _RIM_ANGLE := -0.6
## How fast the stick moves a picture being framed, in label widths a second, and how many times
## closer L1 / R1 frame it in a second.
const _FRAMING_SPEED := 0.6
const _ZOOM_SPEED := 1.8
## How long the cards take to fade before the picker opens.
const _TO_PICKER_S := 0.2

## Where the disc stands on each screen and how the light falls on it: in the row; on the
## properties, its centre 1.4 cm above the camera's axis, 1.12 times its size in the row, the room
## 0.55 dark round a pool of light 400 pixels wide; with its images, higher and smaller.
static var _in_row := Staging.new(0.0, 0.18, 1.0, 0.0, 400.0)
static var _on_properties := Staging.new(1.0, 0.14, 1.12, 0.55, 400.0)
static var _on_labels := Staging.new(1.0, 0.34, 0.78, 0.45, 300.0)
## Framing a picture of one's own: the disc back in the middle, 1.2 cm above the camera's axis.
static var _on_framing := Staging.new(1.0, 0.12, 1.1, 0.4, 400.0)
## Typing its name: the disc high and small, 5.6 cm above the camera's axis, half its size.
static var _on_naming := Staging.new(1.0, 0.56, 0.5, 0.35, 220.0)
## The moves between the screens, in seconds.
static var _opening := Move.new(Leave.FADE, 0.15, 0.56, Arrive.RISE, 0.26, 0.38)
static var _to_labels := Move.new(Leave.FADE, 0.15, 0.42, Arrive.RISE, 0.24, 0.22)
static var _from_labels := Move.new(Leave.SLIDE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)
static var _closing := Move.new(Leave.FADE, 0.15, 0.46, Arrive.FADE, 0.2, 0.3)
## The picker covered the screen: the disc was put in place as it closed, the framing fades in.
static var _from_picker := Move.new(Leave.FADE, 0.0, 0.0, Arrive.FADE, 0.2, 0.0)
static var _framing_left := Move.new(Leave.FADE, 0.15, 0.4, Arrive.FADE, 0.2, 0.22)

## Set by the carousel before the first [method open].
var row: ShelfRow
var sequence: ConsoleSequence
var art: GameArt

var _step := Step.CLOSED
var _game: AndroidServices.Game
## The images of [member _game]'s label downloaded since they were asked for, by region: one may
## arrive before the list of its images.
var _downloaded: Dictionary[String, String] = {}
var _reader := ImageReader.new()
## The picture of the user's own being framed, read from the plugin's copy.
var _picture_reader := ImageReader.new()
var _picture: AndroidServices.LabelPicture
var _picture_texture: Texture2D
var _framing := LabelFraming.new()
## The finger on the label (a tap opens its images) and on the picture being framed (a drag moves
## it); how wide the label shows, in pixels, which a drag across it moves the picture by.
var _finger := Finger.new()
var _label_px := 1.0
## The last pinch counted: its frame, place and factor.
var _pinched: Array = []
## The game whose picture, as framed, shows on its disc until its kept image is read.
var _framed_game := ""

@onready var _zone: LabelZone = %Zone
@onready var _labels: Control = %Labels
@onready var _cards: HBoxContainer = %Cards
@onready var _prompt: Label = %Prompt
@onready var _framing_screen: Control = %Framing


func _init() -> void:
	_staging = _in_row


func _ready() -> void:
	super()
	add_child(_reader)
	_reader.read.connect(_on_image_read)
	add_child(_picture_reader)
	_picture_reader.read.connect(_on_picture_read)
	_zone.gui_input.connect(_on_zone_input)
	_framing_screen.gui_input.connect(_on_framing_input)


func _process(delta: float) -> void:
	if _step == Step.FRAMING and not _busy:
		_frame(delta)
	var camera := get_viewport().get_camera_3d()
	var stand := row.selected_stand()
	var centre_3d := row.to_global(stand.origin)
	var centre := camera.unproject_position(centre_3d)
	var reach := _LABEL_RADIUS * row.global_basis.get_scale().x * stand.basis.get_scale().x
	var edge := camera.unproject_position(centre_3d + camera.global_basis.x * reach)
	var radius := centre.distance_to(edge)
	_label_px = 2.0 * radius
	light.look(centre, _staging.radius, _staging.darkness)
	_zone.size = Vector2.ONE * 2.0 * radius * _RING_OUTSET
	_zone.position = centre - _zone.size / 2.0
	_point_at_focus(centre, _zone.size.x / 2.0)


## Says what the focus is on: the label, round the disc of [param ring] pixels round [param centre],
## or the name.
func _point_at_focus(centre: Vector2, ring: float) -> void:
	if _zone.has_focus():
		var rim := centre + Vector2.from_angle(_RIM_ANGLE) * (ring + 10.0)
		_callout.point(tr("Label image"), Vector2(centre.x + ring + _CAPTION_AWAY, rim.y - _CAPTION_AWAY), rim)
	elif _name.has_focus():
		var name_box := _name.get_rect()
		var at := Vector2(maxf(name_box.end.x - 140.0, centre.x + ring + _CAPTION_AWAY), name_box.position.y - _CAPTION_AWAY)
		_callout.point(tr("Game name"), at, Vector2(minf(name_box.end.x - 30.0, at.x), name_box.position.y - 10.0))
	else:
		_callout.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.CLOSED or event.is_echo():
		return
	if _step == Step.FRAMING and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if not _busy:
			_keep_own()
		return
	if _step == Step.NAMING and _naming_press(event):
		return
	if not event.is_action_pressed(&"screen_back"):
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	match _step:
		Step.LABELS:
			Diagnostics.trace("properties", "images left, the label as it was")
			_back_to_properties()
		Step.FRAMING:
			Diagnostics.trace("properties", "framing left, back to the images")
			_back_to_labels()
		Step.NAMING:
			Diagnostics.trace("properties", "naming left, the name as it was")
			_back_to_properties(_naming, _from_editing, _name)
		_:
			_close()


## Whether the properties show, or are coming or going.
func is_open() -> bool:
	return _step != Step.CLOSED or _busy


## Opens the properties of the selected game of the row.
func open() -> void:
	_game = row.selected_game()
	_show_name(_name, _game.title)
	_step = Step.PROPERTIES
	Diagnostics.trace("properties", "open %s" % _game.title)
	show()
	_labels.hide()
	if not art.loaded.is_connected(_on_art_loaded):
		art.loaded.connect(_on_art_loaded)
	set_process(true)
	await _move(behind, [_properties, _zone], _on_properties, _opening)
	_zone.grab_focus()


func _close() -> void:
	_step = Step.CLOSED
	Diagnostics.trace("properties", "closed")
	if _framed_game:
		_show_kept_label()
	_put_back([_properties, _zone], behind, _in_row, _closing)


## The images the label can show, the current one with the focus.
func _open_labels() -> void:
	_busy = true
	_release_focus()
	_downloaded.clear()
	if not android.label_variant_downloaded.is_connected(_on_label_variant_downloaded):
		android.label_variant_downloaded.connect(_on_label_variant_downloaded)
	var started := Time.get_ticks_msec()
	var answer := await android.label_variants(_game)
	if not answer.ok:
		Diagnostics.trace("properties", "no images listed (%s): %s" % [answer.code, answer.detail])
	Diagnostics.trace("properties", "%d images of %s listed in %d ms" % [
		answer.variants.size(), _game.title, Time.get_ticks_msec() - started])
	_step = Step.LABELS
	_fill_cards(answer.variants)
	await _move([_properties, _zone], [_labels], _on_labels, _to_labels)
	_focus_current()


## Back to the properties from [param screen], the focus on [param focused], the disc showing its own
## label (the one kept, or as it was), unless [param own_label] is false: what it shows stays then.
func _back_to_properties(screen: Control = _labels, move := _from_labels, focused: Control = _zone,
		own_label := true) -> void:
	_step = Step.PROPERTIES
	if own_label:
		row.show_own_label()
	await _move([screen], [_properties, _zone], _on_properties, move)
	_clear_cards()
	focused.grab_focus()


func _fill_cards(variants: Array[AndroidServices.LabelVariant]) -> void:
	_clear_cards()
	for variant in variants:
		var card := LabelCard.new(variant.region, _region_name(variant.region))
		card.focus_entered.connect(_preview.bind(card))
		card.pressed.connect(_choose.bind(card))
		_cards.add_child(card)
		var path: String = variant.path if variant.has_path else _downloaded.get(variant.region, "")
		if path:
			_read(variant.region, path)
	var own := LabelCard.new("", tr("My own image"), true)
	own.focus_entered.connect(row.show_own_label)
	own.pressed.connect(_pick_own)
	_cards.add_child(own)
	if _game.label_own:
		if art.has_texture(_game):
			own.show_label(art.texture(_game))
		else:
			art.request(_game)
	_prompt.text = (tr("Choose the label's image") if variants
		else tr("No other image of this game is known"))


func _clear_cards() -> void:
	_reader.cancel_all()
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()


## The focus on the card of the image the label shows: the one chosen (the user's own picture
## included), else the first: the closest region's, or the user's own when there is none.
func _focus_current() -> void:
	var cards: Array[LabelCard] = []
	cards.assign(_cards.get_children())
	var chosen := cards.filter(func(card: LabelCard) -> bool:
		return (card.own and _game.label_own) or (not card.own and _game.has_label_region and card.region == _game.label_region))
	for card: LabelCard in chosen + cards:
		card.grab_focus()
		return


func _region_cards() -> Array[LabelCard]:
	var cards: Array[LabelCard] = []
	for card: LabelCard in _cards.get_children():
		if not card.own:
			cards.append(card)
	return cards


func _preview(card: LabelCard) -> void:
	if card.is_ready():
		Diagnostics.trace("properties", "image of '%s' on the disc" % card.region)
		row.preview_label(card.label)


func _choose(card: LabelCard) -> void:
	if _busy:
		return
	if not card.is_ready():
		Diagnostics.trace("properties", "image of '%s' not downloaded yet: not kept" % card.region)
		return
	_busy = true
	_release_focus()
	var answer := await android.choose_label(_game, card.region)
	_busy = false
	if not answer.ok:
		Diagnostics.trace("properties", "label not kept (%s): %s" % [answer.code, answer.detail])
		card.grab_focus()
		choice_failed.emit()
		return
	Diagnostics.trace("properties", "%s: label of region '%s' kept" % [_game.title, card.region])
	_game.has_label_region = true
	_game.label_region = card.region
	_game.label_own = false
	art.add(answer.art, card.label)
	_back_to_properties()


## Opens the system's picker on the user's pictures, the cards fading out meanwhile; the picture
## picked is read to be framed ([method _on_picture_read]), and the cards come back if none is.
func _pick_own() -> void:
	if _busy:
		return
	_busy = true
	_release_focus()
	await create_tween().tween_property(_labels, ^"modulate:a", 0.0, _TO_PICKER_S).finished
	var started := Time.get_ticks_msec()
	_picture = await android.pick_label_picture()
	if not _picture.ok:
		Diagnostics.trace("properties", "no picture picked (%s): %s" % [_picture.code, _picture.detail])
		_back_from_picker()
		# Closing the picker is no failure; a picture that cannot be read, or no picker, is.
		if _picture.code != &"cancelled":
			choice_failed.emit()
		return
	Diagnostics.trace("properties", "picture of %dx%d picked in %d ms" % [
		_picture.size.x, _picture.size.y, Time.get_ticks_msec() - started])
	# The disc goes where it is framed while nothing shows: the cards have gone.
	_stage(1.0, _staging, _on_framing)
	_picture_reader.request("picture", _picture.path, "%s, own picture" % _game.title)


## The cards as they were before the picker, the focus on the user's own card.
func _back_from_picker() -> void:
	_stage(1.0, _staging, _on_labels)
	_labels.modulate.a = 1.0
	_busy = false
	_own_card().grab_focus()


## The card of the user's own picture: the last one.
func _own_card() -> LabelCard:
	return _cards.get_child(-1) as LabelCard


func _on_picture_read(_key: String, picture: Texture2D) -> void:
	if _step != Step.LABELS:
		return
	if not picture:
		Diagnostics.trace("properties", "picture picked not readable")
		_back_from_picker()
		choice_failed.emit()
		return
	_picture_texture = picture
	_framing = LabelFraming.new()
	_step = Step.FRAMING
	row.preview_label(_picture_texture, _framing.window(_picture.size))
	await _move([_labels], [_framing_screen], _on_framing, _from_picker)


## Moves and zooms the picture being framed as the stick and L1 / R1 are held, for [param delta]
## seconds.
func _frame(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var zoom := Input.get_axis(&"label_zoom_out", &"label_zoom_in")
	if push.is_zero_approx() and is_zero_approx(zoom):
		return
	# The picture follows the stick: what is right of the label comes into it as it goes left.
	_framing.move(-push * _FRAMING_SPEED * delta, _picture.size)
	_framing.zoom_by(pow(_ZOOM_SPEED, zoom * delta), _picture.size)
	row.preview_label(_picture_texture, _framing.window(_picture.size))


## Keeps the picture as framed on the label, then goes back to the properties; stays on the
## framing when it cannot be kept.
func _keep_own() -> void:
	_busy = true
	var answer := await android.keep_own_label(_game, _framing.zoom, _framing.centre)
	if not answer.ok:
		Diagnostics.trace("properties", "own picture not kept (%s): %s" % [answer.code, answer.detail])
		_busy = false
		choice_failed.emit()
		return
	Diagnostics.trace("properties", "%s: own picture kept, zoom %.2f, centre %s" % [_game.title, _framing.zoom, _framing.centre])
	_game.label_own = true
	_game.has_label_region = false
	# The picture as framed stays on the disc until the image the plugin cut is read.
	art.add(answer.art)
	_framed_game = _game.id
	art.request(_game)
	_back_to_properties(_framing_screen, _from_editing, _zone, false)


## Back to the cards from the framing, nothing kept; the focus on the user's own card.
func _back_to_labels() -> void:
	_step = Step.LABELS
	row.show_own_label()
	_picture_texture = null
	await _move([_framing_screen], [_labels], _on_labels, _framing_left)
	_own_card().grab_focus()


## The disc shows the image kept for its label, read now, in place of the picture as framed.
func _show_kept_label() -> void:
	_framed_game = ""
	_picture_texture = null
	row.show_own_label()


func _on_art_loaded(game_id: String) -> void:
	if game_id == _framed_game:
		_show_kept_label()
	elif _step == Step.LABELS and game_id == _game.id and _game.label_own:
		_own_card().show_label(art.texture(_game))


## The keyboard under the disc, the name as it is to start with.
func _open_naming() -> void:
	if _busy:
		return
	_step = Step.NAMING
	_naming.open(_game.title, _game.own_title())
	await _move([_properties, _zone], [_naming], _on_naming, _to_naming)
	_naming.focus_keys()


## Keeps the name typed, then goes back to the properties; stays on the keyboard when it cannot be
## kept.
func _keep_name() -> void:
	if _busy:
		return
	# A name left as it was is no name to keep: the game keeps its own title.
	var typed := _naming.typed()
	if typed.strip_edges() == _game.title:
		_back_to_properties(_naming, _from_editing, _name)
		return
	var answer := await _renaming(android.rename_game.bind(_game, typed)) as AndroidServices.Renamed
	if not answer.ok:
		return
	Diagnostics.trace("properties", "%s now shown as '%s'" % [_game.id, answer.title])
	_game.title = answer.title
	_game.has_original_title = answer.has_original_title
	_game.original_title = answer.original_title
	_show_name(_name, _game.title)
	name_kept.emit()
	_back_to_properties(_naming, _from_editing, _name)


func _on_label_variant_downloaded(variant: AndroidServices.LabelVariant) -> void:
	if not _game or variant.game_id != _game.id:
		return
	if not variant.has_path:
		Diagnostics.trace("properties", "image of '%s' not downloaded: %s" % [
			variant.region, variant.failure])
		return
	_downloaded[variant.region] = variant.path
	if _region_cards().any(func(card: LabelCard) -> bool: return card.region == variant.region):
		_read(variant.region, variant.path)


func _read(region: String, path: String) -> void:
	_reader.request(region, path, "%s, %s" % [_game.title, region])


func _on_image_read(region: String, image: Texture2D) -> void:
	if not image:
		return
	for card in _region_cards():
		if card.region == region:
			card.show_label(image)
			if card.has_focus():
				_preview(card)


## How the art sources' [param region] reads on a card.
func _region_name(region: String) -> String:
	return tr(region) if region else tr("No region")


func _place() -> void:
	row.stage = _staging.amount
	row.neighbours = 1.0 - _staging.amount
	var centre := row.to_local(Vector3(0.0, _staging.height, row.global_position.z))
	row.staged = Transform3D(Basis.from_scale(Vector3.ONE * _staging.size), centre)
	sequence.fade_behind(1.0 - _staging.amount)


func _on_zone_input(event: InputEvent) -> void:
	# Touches go on to the carousel too: it turns the disc with a drag, and lifts its own finger.
	var now: int = clock.call()
	var tapped := _finger.read(event, now) == Finger.Gesture.TAP
	if (tapped or (event.is_action_pressed(&"ui_accept") and not event.is_echo())) and not _busy:
		if not tapped:
			_zone.accept_event()
		_open_labels()


## By touch, the picture being framed follows the finger.
func _on_framing_input(event: InputEvent) -> void:
	var now: int = clock.call()
	var dragged := _finger.read(event, now) == Finger.Gesture.DRAG
	if dragged and not _busy:
		_framing_screen.accept_event()
		_framing.move(-_finger.moved / _label_px, _picture.size)
		row.preview_label(_picture_texture, _framing.window(_picture.size))


# Pinching zooms the picture being framed. Godot hands the same pinch over twice in a frame: only
# the first counts.
func _input(event: InputEvent) -> void:
	var pinch := event as InputEventMagnifyGesture
	if pinch and _step == Step.FRAMING and not _busy:
		get_viewport().set_input_as_handled()
		var seen := [Engine.get_process_frames(), pinch.position, pinch.factor]
		if seen == _pinched:
			return
		_pinched = seen
		_framing.zoom_by(pinch.factor, _picture.size)
		row.preview_label(_picture_texture, _framing.window(_picture.size))
