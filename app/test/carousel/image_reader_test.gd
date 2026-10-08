# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Image files read into textures off the main thread.

const Fixtures := preload("res://test/screens/fixtures.gd")
const FOLDER := "user://test-reader"

var _reader: ImageReader
var _told: Array[Array] = []


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_reader = auto_free(ImageReader.new())
	add_child(_reader)
	_told.clear()
	_reader.read.connect(func(key: String, texture: Texture2D) -> void: _told.append([key, texture, Engine.get_process_frames()]))


func after_test() -> void:
	for file in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file))


func _image(file: String, size: int) -> String:
	var path := ProjectSettings.globalize_path(FOLDER.path_join(file))
	Image.create_empty(size, size, false, Image.FORMAT_RGB8).save_png(path)
	return path


func _idle() -> void:
	assert_bool(await Fixtures.until(self, _reader.is_idle)).is_true()
	await await_idle_frame()


func test_a_key_asked_again_tells_only_its_latest_image() -> void:
	_reader.request("a", _image("small.png", 8), "a")
	_reader.request("a", _image("large.png", 32), "a")
	await _idle()
	assert_int(_told.size()).is_equal(1)
	var texture: Texture2D = _told[0][1]
	assert_that(texture.get_size()).is_equal(Vector2(32, 32))


func test_what_is_cancelled_is_never_told() -> void:
	_reader.request("a", _image("a.png", 8), "a")
	_reader.request("b", _image("b.png", 8), "b")
	_reader.cancel("a")
	_reader.request("c", _image("c.png", 8), "c")
	_reader.cancel_all()
	await _idle()
	for frame in 5:
		await await_idle_frame()
	assert_array(_told).is_empty()


func test_an_unreadable_file_is_told_without_an_image() -> void:
	var path := ProjectSettings.globalize_path(FOLDER.path_join("broken.png"))
	FileAccess.open(path, FileAccess.WRITE).store_string("not an image")
	_reader.request("broken", path, "broken")
	await _idle()
	assert_int(_told.size()).is_equal(1)
	assert_object(_told[0][1]).is_null()


func test_images_read_together_reach_the_gpu_one_a_frame() -> void:
	for i in 6:
		_reader.request(str(i), _image("%d.png" % i, 8), str(i))
	await _idle()
	assert_int(_told.size()).is_equal(6)
	for i in range(1, _told.size()):
		var frame: int = _told[i][2]
		var previous: int = _told[i - 1][2]
		assert_int(frame).is_greater(previous)


func test_an_image_of_three_byte_colours_reaches_the_gpu_in_four() -> void:
	_reader.request("rgb", _image("rgb.png", 8), "rgb")
	await _idle()
	var texture: ImageTexture = _told[0][1]
	assert_int(texture.get_format()).is_equal(Image.FORMAT_RGBA8)
