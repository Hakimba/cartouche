# SPDX-License-Identifier: GPL-3.0-or-later
class_name ImageReader
extends Node
## Reads image files into textures without stalling a frame: each image is read, its mipmaps made
## and its colours laid out as the GPU takes them on a worker thread, as that takes tens of
## milliseconds on a handheld; at most one texture a frame is then sent to the GPU. What is asked
## again, or cancelled, while it is read is dropped once read.

## The image asked for as [param key] is ready; [param texture] is none when it could not be read.
signal read(key: String, texture: Texture2D)

var _next_ticket := 0
## The latest request of each key under way, as its ticket.
var _asked: Dictionary[String, int] = {}
var _tasks: Dictionary[int, int] = {}
var _waiting: Dictionary[String, Image] = {}


func _ready() -> void:
	set_process(false)


# Runs only while images wait for their texture.
func _process(_delta: float) -> void:
	var key: String = _waiting.keys()[0]
	var image := _waiting[key]
	_waiting.erase(key)
	set_process(not _waiting.is_empty())
	read.emit(key, ImageTexture.create_from_image(image))


func _exit_tree() -> void:
	for task: int in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)


## Starts reading the image at [param path] as [param key], instead of what was asked as it;
## [param title] says which in the traces.
func request(key: String, path: String, title: String) -> void:
	cancel(key)
	_next_ticket += 1
	_asked[key] = _next_ticket
	_tasks[_next_ticket] = WorkerThreadPool.add_task(_read.bind(key, path, title, _next_ticket))


## Whether what is asked as [param key] is still to be told.
func is_reading(key: String) -> bool:
	return key in _asked or key in _waiting


## Whether nothing is still to be told.
func is_idle() -> bool:
	return _asked.is_empty() and _waiting.is_empty()


## Forgets what was asked as [param key]: nothing will be told of it.
func cancel(key: String) -> void:
	_asked.erase(key)
	_waiting.erase(key)


func cancel_all() -> void:
	_asked.clear()
	_waiting.clear()


## Runs on a worker thread; hands the image, or none, to the main thread.
func _read(key: String, path: String, title: String, ticket: int) -> void:
	var started := Time.get_ticks_usec()
	var image := Image.load_from_file(path)
	if image and not image.is_empty():
		# Godot's renderer would turn three-byte colours into four on the main thread.
		if image.get_format() == Image.FORMAT_RGB8:
			image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		Diagnostics.trace("art", "%s read in %.1f ms" % [title, elapsed])
	else:
		image = null
		Diagnostics.trace("art", "%s: %s could not be read" % [title, path])
	_on_read.call_deferred(key, ticket, image)


func _on_read(key: String, ticket: int, image: Image) -> void:
	WorkerThreadPool.wait_for_task_completion(_tasks[ticket])
	_tasks.erase(ticket)
	if _asked.get(key, -1) != ticket:
		return
	_asked.erase(key)
	if image:
		_waiting[key] = image
		set_process(true)
	else:
		read.emit(key, null)
