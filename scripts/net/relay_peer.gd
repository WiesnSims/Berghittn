class_name RelayPeer
extends MultiplayerPeerExtension
## Godot's multiplayer over the co-op relay (NETWORKING.md section 2): one WebSocket to the room's
## Durable Object, which forwards frames between the players. The host is peer 1, as Godot expects.
##
## Every packet Godot queues goes into a frame per target that is sent NET_FLUSH_INTERVAL_MS later at
## the latest, so a player sends about 20 frames a second whatever the game does: the relay bills
## incoming frames, not packets. Frame: [peer i8] then [length u16][packet] for each packet.
## Text frames are the relay's JSON control messages (welcome, joined, left, closed).

## A relay control message the session (Net) cares about: welcome, closed.
signal control(message: Dictionary)

const LENGTH_BYTES: int = 2

var _socket := WebSocketPeer.new()
var _status: ConnectionStatus = CONNECTION_DISCONNECTED
var _id: int = 0
var _target: int = 0
var _mode: TransferMode = TRANSFER_MODE_RELIABLE
var _channel: int = 0
var _refusing: bool = false
var _peers: Array[int] = []
# Arrived packets: [sender, PackedByteArray].
var _incoming: Array = []
# Target -> the frame being filled for it.
var _outgoing: Dictionary = {}
var _last_flush: int = 0
var _last_ping: int = 0
var _close_reason: String = ""


func open(url: String) -> Error:
	_socket.outbound_buffer_size = Constants.NET_SOCKET_BUFFER
	_socket.inbound_buffer_size = Constants.NET_SOCKET_BUFFER
	var error: Error = _socket.connect_to_url(url)
	if error == OK:
		_status = CONNECTION_CONNECTING
	return error


## Sends a control message to the relay (host only: start, kick).
func send_control(message: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))


func _poll() -> void:
	_socket.poll()
	while _socket.get_available_packet_count() > 0:
		var data: PackedByteArray = _socket.get_packet()
		if _socket.was_string_packet():
			_on_control(JSON.parse_string(data.get_string_from_utf8()))
		else:
			_unpack(data)
	var state: WebSocketPeer.State = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if _status != CONNECTION_DISCONNECTED:
			_drop()
		return
	if state != WebSocketPeer.STATE_OPEN or _status != CONNECTION_CONNECTED:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_flush >= Constants.NET_FLUSH_INTERVAL_MS:
		_flush()
		_last_flush = now
	# The relay answers "ping" without waking up; it keeps a quiet lobby's connection alive.
	if now - _last_ping >= Constants.NET_PING_INTERVAL_MS:
		_socket.send_text("ping")
		_last_ping = now


func _on_control(message: Variant) -> void:
	if not message is Dictionary:
		return
	var m: Dictionary = message
	match String(m.get("t", "")):
		"welcome":
			_id = int(m["id"])
			_status = CONNECTION_CONNECTED
			_last_flush = Time.get_ticks_msec()
			_last_ping = _last_flush
			# Peers first: an RPC sent from the welcome handler needs its target known.
			for peer: Variant in m.get("peers", []):
				_add_peer(int(peer))
			control.emit(m)
		"joined":
			_add_peer(int(m["id"]))
		"left":
			_remove_peer(int(m["id"]))
		"closed":
			_close_reason = String(m.get("reason", ""))
			_socket.close()
		"pong":
			pass


func _add_peer(peer: int) -> void:
	if peer in _peers or peer == _id:
		return
	_peers.append(peer)
	peer_connected.emit(peer)


func _remove_peer(peer: int) -> void:
	if not peer in _peers:
		return
	_peers.erase(peer)
	peer_disconnected.emit(peer)


func _drop() -> void:
	# The relay's "closed" message can arrive in the same poll as the close itself, and a closed
	# socket hands out no more packets; the close reason says the same.
	if _close_reason == "":
		_close_reason = _socket.get_close_reason()
	for peer: int in _peers.duplicate():
		_remove_peer(peer)
	_status = CONNECTION_DISCONNECTED
	_outgoing.clear()
	_incoming.clear()
	control.emit({"t": "closed", "reason": _close_reason if _close_reason != "" else "lost"})


func _unpack(data: PackedByteArray) -> void:
	if data.size() < 1 + LENGTH_BYTES:
		return
	var sender: int = data[0]
	var at: int = 1
	while at + LENGTH_BYTES <= data.size():
		var length: int = data.decode_u16(at)
		at += LENGTH_BYTES
		if at + length > data.size():
			return
		_incoming.append([sender, data.slice(at, at + length)])
		at += length


func _flush() -> void:
	for target: int in _outgoing:
		_socket.put_packet(_outgoing[target])
	_outgoing.clear()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	if buffer.size() > _get_max_packet_size():
		return ERR_OUT_OF_MEMORY
	var frame: PackedByteArray = _outgoing.get(_target, PackedByteArray([_target & 0xff]))
	var at: int = frame.size()
	frame.resize(at + LENGTH_BYTES)
	frame.encode_u16(at, buffer.size())
	frame.append_array(buffer)
	_outgoing[_target] = frame
	# The relay refuses frames over 64 KiB; send early rather than grow past it.
	if frame.size() > Constants.NET_FRAME_SOFT_LIMIT:
		_socket.put_packet(frame)
		_outgoing.erase(_target)
	return OK


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return (_incoming.pop_front() as Array)[1]


# SceneMultiplayer asks for the sender before it takes the packet.
func _get_packet_peer() -> int:
	return (_incoming[0] as Array)[0] if not _incoming.is_empty() else 0


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_max_packet_size() -> int:
	return Constants.NET_FRAME_SOFT_LIMIT


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _id == 1


# The relay delivers to any peer directly, so SceneMultiplayer need not route through the host.
func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


func _get_connection_status() -> ConnectionStatus:
	return _status


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _is_server():
		send_control({"t": "kick", "id": peer})


func _close() -> void:
	_flush()
	_close_reason = "left"
	_socket.close()
	_drop()
