# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelChooser
extends Node
## The images a game's label can show, as cards: the sources' images, read as they download, and
## a card for a picture of the user's own, picked with the system's picker and framed with the stick,
## L1 / R1 or by touch. The disc previews the card with the focus. [DiscProperties] plays the moves
## between its screens and asks for what is kept.

## A source's card was pressed, or the user's own.
signal card_pressed(card: LabelCard)
signal own_pressed
## The picture picked is read; [param picture] is none when it could not be.
signal picture_read(picture: Texture2D)

## How fast the stick moves a picture being framed, in label widths a second, and how many times
## closer L1 / R1 frame it in a second.
const _FRAMING_SPEED := 0.6
const _ZOOM_SPEED := 1.8

var row: ShelfRow
var art: GameArt
var android: AndroidServices
## The game whose picture, as framed, shows on its disc until its kept image is read.
var framed_game := ""

var _cards: HBoxContainer
var _prompt: Label
var _game: AndroidServices.Game
var _kind := LabelZone.Shape.DISC
## The images of [member _game]'s label downloaded since they were asked for, by source and region
## (see [method _image_key]): one may arrive before the list of its images.
var _downloaded: Dictionary[String, String] = {}
var _reader := ImageReader.new()
## The picture of the user's own being framed, read from the plugin's copy.
var _picture_reader := ImageReader.new()
var _picture: AndroidServices.LabelPicture
var _picture_texture: Texture2D
var _framing := LabelFraming.new()
## The last pinch counted: its frame, place and factor.
var _pinched: Array = []


func _init(cards: HBoxContainer, prompt: Label) -> void:
	_cards = cards
	_prompt = prompt


func _ready() -> void:
	add_child(_reader)
	_reader.read.connect(_on_image_read)
	add_child(_picture_reader)
	_picture_reader.read.connect(func(_key: String, picture: Texture2D) -> void: picture_read.emit(picture))


## Lists the images [param game]'s label can show, as cards, its [param kind] shaping them.
func fill(game: AndroidServices.Game, kind: LabelZone.Shape) -> void:
	_game = game
	_kind = kind
	_downloaded.clear()
	if not android.label_variant_downloaded.is_connected(_on_label_variant_downloaded):
		android.label_variant_downloaded.connect(_on_label_variant_downloaded)
	var started := Time.get_ticks_msec()
	var answer := await android.label_variants(_game)
	if not answer.ok:
		Diagnostics.trace("properties", "no images listed (%s): %s" % [answer.code, answer.detail])
	Diagnostics.trace("properties", "%d images of %s listed in %d ms" % [
		answer.variants.size(), _game.title, Time.get_ticks_msec() - started])
	clear()
	for variant in answer.variants:
		var card := LabelCard.new(variant.region, variant.source,
			"%s · %s" % [_region_name(variant.region), variant.source_name])
		card.focus_entered.connect(_preview.bind(card))
		card.pressed.connect(card_pressed.emit.bind(card))
		_cards.add_child(card)
		_shape_card(card)
		var path: String = variant.path if variant.has_path else _downloaded.get(_image_key(variant.region, variant.source), "")
		if path:
			_read(card, path)
	var own := LabelCard.new("", "", tr("My own image"), true)
	own.focus_entered.connect(row.show_own_label)
	own.pressed.connect(own_pressed.emit)
	_cards.add_child(own)
	_shape_card(own)
	if _game.label_own:
		if art.has_texture(_game):
			own.show_label(art.texture(_game))
		else:
			art.request(_game)
	_prompt.text = (tr("Choose the label's image") if answer.variants
		else tr("No other image of this game is known"))


func clear() -> void:
	_reader.cancel_all()
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()


## The focus on the card of the image the label shows: the one chosen (the user's own picture
## included), else the first: the closest region's, or the user's own when there is none.
func focus_current() -> void:
	var cards: Array[LabelCard] = []
	cards.assign(_cards.get_children())
	var chosen := cards.filter(func(card: LabelCard) -> bool:
		return (card.own and _game.label_own) or (not card.own and _game.has_label_region
			and card.region == _game.label_region and card.source == _game.label_source))
	for card: LabelCard in chosen + cards:
		card.grab_focus()
		return


## The card of the user's own picture: the last one.
func own_card() -> LabelCard:
	return _cards.get_child(-1) as LabelCard


## Keeps [param card]'s image, downloaded, on the label.
func choose(card: LabelCard) -> AndroidServices.Result:
	var answer := await android.choose_label(_game, card.region, card.source)
	if not answer.ok:
		Diagnostics.trace("properties", "label not kept (%s): %s" % [answer.code, answer.detail])
		return answer
	Diagnostics.trace("properties", "%s: label of region '%s' from %s kept" % [_game.title, card.region, card.source])
	_game.has_label_region = true
	_game.label_region = card.region
	_game.label_source = card.source
	_game.label_own = false
	art.add(answer.art, card.label)
	return answer


## Opens the system's picker on the user's pictures; the picture picked is read ([signal picture_read]).
func pick() -> AndroidServices.LabelPicture:
	var started := Time.get_ticks_msec()
	_picture = await android.pick_label_picture()
	if not _picture.ok:
		Diagnostics.trace("properties", "no picture picked (%s): %s" % [_picture.code, _picture.detail])
		return _picture
	Diagnostics.trace("properties", "picture of %dx%d picked in %d ms" % [
		_picture.size.x, _picture.size.y, Time.get_ticks_msec() - started])
	_picture_reader.request("picture", _picture.path, "%s, own picture" % _game.title)
	return _picture


## The disc shows [param picture], read from the one picked, whole, to be framed.
func start_framing(picture: Texture2D) -> void:
	_picture_texture = picture
	_framing = LabelFraming.new(row.selected_label_proportion())
	_preview_framed()


## Moves and zooms the picture being framed as the stick and L1 / R1 are held, for [param delta]
## seconds.
func frame(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var zoom := Input.get_axis(&"label_zoom_out", &"label_zoom_in")
	if push.is_zero_approx() and is_zero_approx(zoom):
		return
	_follow(push * _FRAMING_SPEED * delta)
	_framing.zoom_by(pow(_ZOOM_SPEED, zoom * delta), _picture.size)
	_preview_framed()


## Moves the picture being framed by [param by], in label widths.
func move_picture(by: Vector2) -> void:
	_follow(by)
	_preview_framed()


## Pinching zooms the picture being framed. Godot hands the same pinch over twice in a frame: only
## the first counts.
func pinch(event: InputEventMagnifyGesture) -> void:
	var seen := [Engine.get_process_frames(), event.position, event.factor]
	if seen == _pinched:
		return
	_pinched = seen
	_framing.zoom_by(event.factor, _picture.size)
	_preview_framed()


## Keeps the picture as framed on the label.
func keep_own() -> AndroidServices.Result:
	var answer := await android.keep_own_label(_game, _framing)
	if not answer.ok:
		Diagnostics.trace("properties", "own picture not kept (%s): %s" % [answer.code, answer.detail])
		return answer
	Diagnostics.trace("properties", "%s: own picture kept, zoom %.2f, centre %s" % [_game.title, _framing.zoom, _framing.centre])
	_game.label_own = true
	_game.has_label_region = false
	art.add(answer.art)
	framed_game = _game.id
	art.request(_game)
	return answer


## The picture being framed is dropped, the disc showing its own label again.
func drop_picture() -> void:
	row.show_own_label()
	_picture_texture = null


## The disc shows the image kept for its label, read now, in place of the picture as framed.
func show_kept_label() -> void:
	framed_game = ""
	drop_picture()


func _preview(card: LabelCard) -> void:
	if card.is_ready():
		Diagnostics.trace("properties", "image of '%s' from %s on the disc" % [card.region, card.source])
		row.preview_label(card.label)


## The picture moves by [param by] under the label: the label's window over it goes the other way.
func _follow(by: Vector2) -> void:
	_framing.move(-by, _picture.size)


func _preview_framed() -> void:
	row.preview_label(_picture_texture, _framing.window(_picture.size))


func _region_cards() -> Array[LabelCard]:
	var cards: Array[LabelCard] = []
	for card: LabelCard in _cards.get_children():
		if not card.own:
			cards.append(card)
	return cards


func _on_label_variant_downloaded(variant: AndroidServices.LabelVariant) -> void:
	if not _game or variant.game_id != _game.id:
		return
	if not variant.has_path:
		Diagnostics.trace("properties", "image of '%s' from %s not downloaded: %s" % [
			variant.region, variant.source, variant.failure])
		return
	_downloaded[_image_key(variant.region, variant.source)] = variant.path
	for card in _region_cards():
		if card.region == variant.region and card.source == variant.source:
			_read(card, variant.path)


func _read(card: LabelCard, path: String) -> void:
	_reader.request(_image_key(card.region, card.source), path, "%s, %s from %s" % [_game.title, card.region, card.source])


func _on_image_read(key: String, image: Texture2D) -> void:
	if not image:
		return
	for card in _region_cards():
		if _image_key(card.region, card.source) == key:
			card.show_label(image)
			if card.has_focus():
				_preview(card)


## What names an image among a game's: its [param source], then its [param region].
func _image_key(region: String, source: String) -> String:
	return source + "/" + region


## How the art sources' [param region] reads on a card.
func _region_name(region: String) -> String:
	return tr(region) if region else tr("No region")


func _shape_card(card: LabelCard) -> void:
	var thumbnail := card.get_child(0).get_child(0) as TextureRect
	var shader := thumbnail.material as ShaderMaterial
	shader.set_shader_parameter(&"cartridge", _kind == LabelZone.Shape.RECTANGLE)
	shader.set_shader_parameter(&"proportion", row.selected_label_proportion())
