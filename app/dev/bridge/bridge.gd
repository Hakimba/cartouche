# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const Commands := preload("res://dev/bridge/commands.gd")
## The version of the commands and answers: raised whenever one changes shape, so a client can refuse an app
## it does not speak to instead of failing on a command.
const PROTOCOL := 1
const URL := "ws://127.0.0.1:5201"
const RETRY_MS := 2000
const BUFFER_BYTES := 16 << 20
## What a message's header takes in the buffer, with room to spare.
const FRAMING_BYTES := 1024

var clock := Callable(Time, &"get_ticks_msec")
var url := URL
var _socket := WebSocketPeer.new()
var _open := false
var _retry_at := 0
var _queue: Array[Dictionary] = []
var _running := false
var _commands: Commands


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _commands == null:
		_commands = Commands.new()
	add_child(_commands)
	# Several clients may run side by side on a desktop, each on its own port.
	var port := Diagnostics.argument("bridge-port")
	if port.is_valid_int():
		url = "ws://127.0.0.1:%s" % port
	_connect()


func _exit_tree() -> void:
	_socket.close()


func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_open = false
		if _now() >= _retry_at:
			_connect()
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not _open:
		_open = true
		_queue.clear()
		var screen := get_viewport().get_visible_rect().size
		_socket.send_text(JSON.stringify({"hello": {
			"device": "android" if OS.has_feature("android") else "pc",
			"os": OS.get_name(), "screen": [screen.x, screen.y], "protocol": PROTOCOL}}))
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		if not _socket.was_string_packet():
			continue
		var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if parsed is Dictionary:
			_queue.append(parsed)
	if not _running and not _queue.is_empty():
		_drain()


func _connect() -> void:
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = BUFFER_BYTES
	_socket.outbound_buffer_size = BUFFER_BYTES
	_socket.connect_to_url(url)
	_retry_at = _now() + RETRY_MS


func _drain() -> void:
	_running = true
	var connection := _socket
	while not _queue.is_empty() and connection == _socket:
		var message: Dictionary = _queue.pop_front()
		var answer := await _commands.run(message)
		var bytes: PackedByteArray = answer.get("_bytes", PackedByteArray())
		answer.erase("_bytes")
		if connection != _socket or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			break
		if not _send(answer, bytes):
			_socket.send_text(JSON.stringify({"id": answer.get("id"), "cmd": answer.get("cmd"), "ok": false,
				"error": "answer too big for the transport"}))
	_running = false


## Whether the answer, then its picture, went out: both fit in the room left, or neither is sent, so that the
## client never gets an answer whose picture is missing.
func _send(answer: Dictionary, bytes: PackedByteArray) -> bool:
	var text := JSON.stringify(answer)
	if text.to_utf8_buffer().size() + bytes.size() + FRAMING_BYTES > BUFFER_BYTES - _socket.get_current_outbound_buffered_amount():
		return false
	return _socket.send_text(text) == OK \
		and (bytes.is_empty() or _socket.send(bytes, WebSocketPeer.WRITE_MODE_BINARY) == OK)


func _now() -> int:
	return clock.call()
