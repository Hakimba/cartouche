# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const FOLDER := "user://test-art"

var _art: GameArt
var _made := 0


func before_test() -> void:
	_made = 0
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_art = auto_free(GameArt.new())
	add_child(_art)


func after_test() -> void:
	for file in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file))


## [param game]'s scan, a JPEG of [param size] pixels stored as the plugin stores it, named [param file].
func _stored(game: AndroidServices.Game, size := 64, file := game.title) -> AndroidServices.Art:
	var path := ProjectSettings.globalize_path(FOLDER.path_join("%s.jpg" % file.validate_filename()))
	Image.create(size, size, false, Image.FORMAT_RGB8).save_jpg(path)
	return AndroidServices.Art.new({"game_id": game.id, "path": path})


## Runs frames until every image asked for is read and made a texture, for 5 s at most.
func _settled() -> void:
	var until := Time.get_ticks_msec() + 5000
	while not _art._reader.is_idle() and Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_a_requested_image_is_read_in_the_background_then_becomes_its_game_s_texture() -> void:
	var game := Fixtures.games(1)[0]
	_art.add(_stored(game, 96))
	var loaded: Array[String] = []
	_art.loaded.connect(loaded.append)
	_art.request(game)
	assert_bool(_art.has_texture(game)).is_false()
	await _settled()
	assert_bool(_art.has_texture(game)).is_true()
	assert_that(_art.texture(game).get_size()).is_equal(Vector2(96, 96))
	assert_array(loaded).is_equal([game.id])


func test_a_game_without_art_reads_nothing() -> void:
	var game := Fixtures.games(1)[0]
	_art.request(game)
	await _settled()
	assert_bool(_art.has_art(game)).is_false()
	assert_bool(_art.has_texture(game)).is_false()


func test_art_replaced_while_its_old_image_is_read_shows_the_new_one() -> void:
	var game := Fixtures.games(1)[0]
	_art.add(_stored(game, 16, "old"))
	_art.request(game)
	_art.add(_stored(game, 48, "new"))
	await _settled()
	_art.request(game)
	await _settled()
	assert_that(_art.texture(game).get_size()).is_equal(Vector2(48, 48))


func test_an_unreadable_image_gives_no_texture_and_the_carousel_goes_on() -> void:
	var game := Fixtures.games(1)[0]
	var path := ProjectSettings.globalize_path(FOLDER.path_join("broken.jpg"))
	FileAccess.open(path, FileAccess.WRITE).store_string("not a JPEG")
	_art.add(AndroidServices.Art.new({"game_id": game.id, "path": path}))
	_art.request(game)
	await _settled()
	assert_bool(_art.has_texture(game)).is_false()
	# Not read again as its place comes back into view.
	_art.request(game)
	assert_bool(_art._reader.is_idle()).is_true()


func test_labels_arriving_together_reach_the_gpu_one_a_frame_and_only_the_latest_are_kept() -> void:
	var games := Fixtures.games(30)
	_art.loaded.connect(func(_id: String) -> void: _made += 1)
	for game in games:
		_art.add(_stored(game, 16))
		_art.request(game)
	var made := 0
	var until := Time.get_ticks_msec() + 5000
	while made < games.size() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var now := _made
		assert_int(now).is_less_equal(made + 1)
		made = now
	assert_int(made).is_equal(games.size())
	assert_int(games.filter(_art.has_texture).size()).is_equal(24)


func test_art_added_with_its_image_is_ready_at_once_and_an_older_read_of_the_same_file_is_dropped() -> void:
	var game := Fixtures.games(1)[0]
	var old := _stored(game, 16, "same")
	_art.add(old)
	_art.request(game)
	var chosen := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGB8))
	var loaded: Array[String] = []
	_art.loaded.connect(loaded.append)
	_art.add(AndroidServices.Art.new({"game_id": game.id, "path": old.path}), chosen)
	assert_array(loaded).contains_exactly([game.id])
	assert_object(_art.texture(game)).is_same(chosen)
	await _settled()
	assert_object(_art.texture(game)).is_same(chosen)
