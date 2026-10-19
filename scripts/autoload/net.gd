extends Node
## The co-op session (M7, NETWORKING.md): joining a room through the relay, the lobby's roster of
## names and hikers, and the host starting the match. An autoload because the session must outlive
## a scene reload. Solo never touches it: Net stays OFFLINE and multiplayer stays offline.

signal state_changed
## Someone joined, left or changed their name or hiker.
signal roster_changed
signal match_started
## The session is over; `reason` is a relay reason (host_left, kicked, full, started, version,
## no_room, lost) or "left" when we left ourselves.
signal ended(reason: String)

enum State { OFFLINE, CONNECTING, LOBBY, MATCH }

const BUILD_ID_PATH: String = "res://build_id.txt"

var state: State = State.OFFLINE
## The room's 4-digit code once in a lobby.
var code: String = ""
## Peer id -> HikerStyle profile of everyone in the room, ourselves included.
var roster: Dictionary = {}
## Must match the host's: the relay refuses a browser running another build (stale cache).
var build_id: String = "dev"

var _peer: RelayPeer


func _ready() -> void:
	# The lobby lives behind the paused title screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(BUILD_ID_PATH):
		build_id = FileAccess.get_file_as_string(BUILD_ID_PATH).strip_edges()
	# Desktop bots joining a browser on a deployed build (tests/net_four.gd bench mode) pass its id.
	build_id = _user_arg("build", build_id)
	multiplayer.peer_disconnected.connect(_on_peer_left)


func in_lobby() -> bool:
	return state == State.LOBBY


func in_match() -> bool:
	return state == State.MATCH


func is_host() -> bool:
	return state != State.OFFLINE and multiplayer.get_unique_id() == 1


func my_id() -> int:
	return multiplayer.get_unique_id()


## Bytes received and sent over the relay since this session opened (zero offline).
func traffic() -> Vector2i:
	return Vector2i(_peer.bytes_in, _peer.bytes_out) if _peer else Vector2i.ZERO


func create_room() -> void:
	_open("new")


func join_room(room_code: String) -> void:
	_open(room_code.strip_edges())


func leave() -> void:
	if _peer == null:
		return
	_end("left")


## Our own name or hiker changed in the lobby.
func update_profile(profile: Dictionary) -> void:
	var p: Dictionary = HikerStyle.sanitize(profile)
	if state != State.LOBBY:
		return
	roster[my_id()] = p
	if is_host():
		_send_roster()
	else:
		_hello.rpc_id(1, p)
	roster_changed.emit()


func can_start() -> bool:
	return is_host() and state == State.LOBBY and roster.size() >= Constants.NET_MIN_PLAYERS


func start_match() -> void:
	if not can_start():
		return
	_peer.send_control({"t": "start"})
	_start.rpc()
	_begin_match()


## Host, after a co-op game over: everyone is back in the lobby (same room, joining open again).
func back_to_lobby() -> void:
	if not is_host() or state != State.MATCH:
		return
	_peer.send_control({"t": "lobby"})
	_to_lobby.rpc()
	_to_lobby()


@rpc("authority", "call_remote", "reliable")
func _to_lobby() -> void:
	if state == State.MATCH:
		_set_state(State.LOBBY)


## Where the relay is: the page's own origin in the browser, else --relay=<url> or the live site.
func relay_base() -> String:
	if OS.has_feature("web"):
		var origin: String = str(JavaScriptBridge.eval("location.origin", true))
		return origin.replace("https://", "wss://").replace("http://", "ws://")
	return _user_arg("relay", Constants.NET_SITE.replace("https://", "wss://"))


## The link that opens the game straight into this room's lobby.
func invite_url() -> String:
	var page: String = Constants.NET_SITE + "/"
	if OS.has_feature("web"):
		page = str(JavaScriptBridge.eval("location.origin + location.pathname", true))
	return "%s?room=%s" % [page, code]


## A room code the page was opened with (?room=4711), or --room=<code> on the desktop.
func room_from_url() -> String:
	var room: String = ""
	if OS.has_feature("web"):
		room = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('room') || ''", true))
	else:
		room = _user_arg("room", "")
	return room if room.length() == Constants.NET_CODE_LENGTH and room.is_valid_int() else ""


func _user_arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback


func _open(path: String) -> void:
	if _peer != null:
		_end("left")
	_peer = RelayPeer.new()
	_peer.control.connect(_on_control)
	var url: String = "%s/api/room/%s?build=%s" % [relay_base(), path, build_id.uri_encode()]
	if _peer.open(url) != OK:
		_peer = null
		ended.emit("lost")
		return
	multiplayer.multiplayer_peer = _peer
	(multiplayer as SceneMultiplayer).server_relay = false
	_set_state(State.CONNECTING)


func _on_control(message: Dictionary) -> void:
	match String(message.get("t", "")):
		"welcome":
			code = String(message.get("code", ""))
			# In the browser console, for play-test reports and the browser test.
			print("Co-op: room %s, peer %d, build %s" % [code, my_id(), build_id])
			roster = {my_id(): Settings.profile_for(my_id())}
			_set_state(State.LOBBY)
			if not is_host():
				_hello.rpc_id(1, roster[my_id()])
			roster_changed.emit()
		"closed":
			_end(String(message.get("reason", "lost")))


func _end(reason: String) -> void:
	var peer: RelayPeer = _peer
	_peer = null
	if peer != null:
		peer.control.disconnect(_on_control)
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
	roster.clear()
	code = ""
	_set_state(State.OFFLINE)
	ended.emit(reason)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit()


func _on_peer_left(peer: int) -> void:
	if roster.erase(peer):
		if is_host():
			_send_roster()
		roster_changed.emit()


func _send_roster() -> void:
	_roster.rpc(roster)


func _begin_match() -> void:
	_set_state(State.MATCH)
	match_started.emit()


## A guest's name and hiker, to the host.
@rpc("any_peer", "call_remote", "reliable")
func _hello(profile: Dictionary) -> void:
	if not is_host() or state != State.LOBBY:
		return
	roster[multiplayer.get_remote_sender_id()] = HikerStyle.sanitize(profile)
	_send_roster()
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _roster(data: Dictionary) -> void:
	roster.clear()
	for peer: Variant in data:
		roster[int(peer)] = HikerStyle.sanitize(data[peer])
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _start() -> void:
	_begin_match()
