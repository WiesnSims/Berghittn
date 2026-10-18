extends Node
## Co-op lobby over the real relay (M7 part 1), one role per Godot process. Run all roles with
##     node tools/net_test.mjs
## which starts the relay locally (wrangler dev) and launches
##     godot --headless res://tests/net_lobby.tscn -- --relay=ws://127.0.0.1:8790 --role=host
##     ... --role=guest --room=<code>    and, once the match started,    ... --role=late --room=<code>
## Prints "ROOM <code>", "STARTED" and finally "PASS" or "FAIL <why>" for the launcher.

const TIMEOUT: float = 20.0
const PROBES: int = 20
const PROBES_NEEDED: int = 15

var _probes: int = 0
var _ended_reason: String = ""


func _ready() -> void:
	var role: String = _arg("role", "host")
	Net.ended.connect(func(reason: String) -> void: _ended_reason = reason)
	var ok: bool = false
	match role:
		"host":
			ok = await _host()
		"guest":
			ok = await _guest()
		"late":
			ok = await _late()
	print("PASS" if ok else "FAIL %s (ended: %s)" % [role, _ended_reason])
	get_tree().quit(0 if ok else 1)


func _host() -> bool:
	Settings.profile = {"name": "Wirt", "head": 1, "hat": 1, "jacket": 0, "trousers": 0}
	Net.create_room()
	if not await _until(func() -> bool: return Net.in_lobby()):
		return _fail("no room")
	print("ROOM %s" % Net.code)
	if not await _until(func() -> bool: return Net.roster.size() == 2 and int(Net.roster.get(2, {}).get("hat", 0)) == 3):
		return _fail("guest or their new hat never arrived: %s" % Net.roster)
	if Net.roster[2]["name"] != "Gast":
		return _fail("guest name %s" % Net.roster[2])
	if not Net.can_start():
		return _fail("cannot start with two")
	Net.start_match()
	print("STARTED")
	if not await _until(func() -> bool: return _probes >= PROBES_NEEDED):
		return _fail("only %d of %d probes arrived" % [_probes, PROBES])
	# Give the late joiner its chance to be refused before the room closes.
	await get_tree().create_timer(3.0).timeout
	Net.leave()
	return _ended_reason == "left"


func _guest() -> bool:
	Settings.profile = {"name": "Gast", "head": 3, "hat": 0, "jacket": 2, "trousers": 1}
	Net.join_room(_arg("room", ""))
	if not await _until(func() -> bool: return Net.in_lobby() and Net.roster.size() == 2):
		return _fail("no lobby: %s / %s" % [Net.state, _ended_reason])
	if Net.roster.get(1, {}).get("name", "") != "Wirt" or Net.my_id() != 2:
		return _fail("roster %s, id %d" % [Net.roster, Net.my_id()])
	# Changing the hiker in the lobby reaches the host.
	Net.update_profile({"name": "Gast", "head": 3, "hat": 3, "jacket": 2, "trousers": 1})
	if not await _until(func() -> bool: return Net.in_match()):
		return _fail("match never started")
	for i: int in PROBES:
		_probe.rpc_id(1, i)
		await get_tree().create_timer(Constants.NET_POSE_INTERVAL).timeout
	if not await _until(func() -> bool: return _ended_reason != ""):
		return _fail("never heard the host leave")
	return _ended_reason == "host_left"


func _late() -> bool:
	Net.join_room(_arg("room", ""))
	if not await _until(func() -> bool: return _ended_reason != ""):
		return _fail("was let in")
	return _ended_reason == "started"


@rpc("any_peer", "call_remote", "unreliable")
func _probe(_n: int) -> void:
	_probes += 1


func _until(condition: Callable) -> bool:
	var left: float = TIMEOUT
	while not condition.call():
		if left <= 0.0:
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true


func _fail(why: String) -> bool:
	print("FAIL: " + why)
	return false


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback
