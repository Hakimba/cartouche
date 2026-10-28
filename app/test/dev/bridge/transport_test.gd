# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Bridge := preload("res://dev/bridge/bridge.gd")
const Fixtures := preload("res://test/dev/bridge/fixtures.gd")


func test_the_transport_says_hello_first_and_sends_a_shot_answer_then_one_binary_picture() -> void:
	var server := TCPServer.new()
	assert_int(server.listen(0, "127.0.0.1")).is_equal(OK)
	var bridge: Bridge = auto_free(Bridge.new())
	bridge.url = "ws://127.0.0.1:%d" % server.get_local_port()
	bridge._commands = Fixtures.CommandHost.new()
	add_child(bridge)
	var peer := await _accept(server)
	var hello := await _packet(peer)
	assert_bool(hello["text"]).is_true()
	var message: Dictionary = JSON.parse_string(_text(hello))
	var identity: Dictionary = message["hello"]
	assert_str(identity["device"]).is_equal("pc")
	assert_str(identity["os"]).is_equal(OS.get_name())
	assert_float(identity["protocol"]).is_equal(1.0)
	var size: Array = identity["screen"]
	assert_int(size.size()).is_equal(2)
	assert_int(bridge._socket.inbound_buffer_size).is_equal(16 << 20)
	assert_int(bridge._socket.outbound_buffer_size).is_equal(16 << 20)
	peer.send_text(JSON.stringify({"id": 2, "cmd": "shot", "format": "png"}))
	peer.send_text(JSON.stringify({"id": 3, "cmd": "state"}))
	var answer := await _packet(peer)
	assert_bool(answer["text"]).is_true()
	message = JSON.parse_string(_text(answer))
	assert_float(message["id"]).is_equal(2.0)
	assert_bool(message["ok"]).is_true()
	var picture := await _packet(peer)
	assert_bool(picture["text"]).is_false()
	var bytes: PackedByteArray = picture["bytes"]
	assert_float(message["size"]).is_equal(float(bytes.size()))
	var image := Image.new()
	assert_int(image.load_png_from_buffer(bytes)).is_equal(OK)
	assert_vector(image.get_size()).is_equal(Vector2i(8, 6))
	answer = await _packet(peer)
	message = JSON.parse_string(_text(answer))
	assert_float(message["id"]).is_equal(3.0)
	assert_str(message["cmd"]).is_equal("state")
	peer.close()
	bridge.free()
	peer.poll()
	server.stop()


func test_a_picture_too_big_for_the_transport_is_answered_by_a_small_error_with_its_id() -> void:
	var server := TCPServer.new()
	assert_int(server.listen(0, "127.0.0.1")).is_equal(OK)
	var bridge: Bridge = auto_free(Bridge.new())
	bridge.url = "ws://127.0.0.1:%d" % server.get_local_port()
	bridge._commands = Fixtures.BigPictureHost.new()
	add_child(bridge)
	var peer := await _accept(server)
	await _packet(peer)
	peer.send_text(JSON.stringify({"id": 9, "cmd": "shot", "format": "png"}))
	var answer := await _packet(peer)
	var message: Dictionary = JSON.parse_string(_text(answer))
	assert_float(message["id"]).is_equal(9.0)
	assert_bool(message["ok"]).is_false()
	assert_str(message["error"]).contains("too big")
	peer.close()
	bridge.free()
	peer.poll()
	server.stop()


func test_a_closed_transport_retries_after_two_seconds_and_connects_when_the_server_returns() -> void:
	var server := TCPServer.new()
	server.listen(0, "127.0.0.1")
	var port := server.get_local_port()
	server.stop()
	var now := [100]
	var bridge: Bridge = auto_free(Bridge.new())
	bridge.clock = func() -> int: return now[0]
	bridge.url = "ws://127.0.0.1:%d" % port
	add_child(bridge)
	for frame in 10: await get_tree().process_frame
	assert_int(bridge._retry_at).is_equal(2100)
	assert_int(server.listen(port, "127.0.0.1")).is_equal(OK)
	now[0] = 2099
	for frame in 3: await get_tree().process_frame
	assert_bool(server.is_connection_available()).is_false()
	now[0] = 2100
	var peer := await _accept(server)
	var hello := await _packet(peer)
	assert_bool(hello["text"]).is_true()
	assert_str(_text(hello)).contains("hello")
	peer.close()
	bridge.free()
	peer.poll()
	server.stop()


func _accept(server: TCPServer) -> WebSocketPeer:
	for frame in 240:
		if server.is_connection_available():
			var peer := WebSocketPeer.new()
			assert_int(peer.accept_stream(server.take_connection())).is_equal(OK)
			for handshake in 240:
				peer.poll()
				if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
					return peer
				await get_tree().process_frame
		await get_tree().process_frame
	fail("bridge did not connect to the fake server")
	return WebSocketPeer.new()


func _packet(peer: WebSocketPeer) -> Dictionary:
	for frame in 240:
		peer.poll()
		if peer.get_available_packet_count() > 0:
			var bytes := peer.get_packet()
			return {"bytes": bytes, "text": peer.was_string_packet()}
		await get_tree().process_frame
	fail("bridge did not send a packet")
	return {"bytes": PackedByteArray(), "text": false}


func _text(packet: Dictionary) -> String:
	var bytes: PackedByteArray = packet["bytes"]
	return bytes.get_string_from_utf8()
