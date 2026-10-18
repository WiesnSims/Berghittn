extends Node
## A co-op match in the real main scene over the real relay (M7 part 1), one role per process:
##     node tools/net_test.mjs res://tests/net_match.tscn
## The guest gets in the way an invite link does (--room=<code> is the desktop's ?room=). After the
## host starts, each player walks to a spot of their own, and each must see the other's hiker there.
## Then the host leaves and the guest must be sent back to the title.

const TIMEOUT: float = 20.0
## Where each peer walks to, from the spawn (m).
const SPOTS: Dictionary = {1: Vector3(2.0, 0.0, 1.5), 2: Vector3(-2.0, 0.0, -1.0)}
const NEAR: float = 0.4

var _main: Node
var _ended_reason: String = ""


func _ready() -> void:
	# main reloads the current scene when a match ends, which would start this test again.
	if Engine.has_meta("net_match_done"):
		get_tree().quit(int(Engine.get_meta("net_match_done")))
		return
	var role: String = _arg("role", "host")
	Settings.profile = {"name": "Wirt" if role == "host" else "Gast", "head": 2, "hat": 4, "jacket": 1, "trousers": 2}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	Net.ended.connect(func(reason: String) -> void: _ended_reason = reason)
	var ok: bool = false
	if role == "host":
		ok = await _host()
	else:
		ok = await _guest()
	Engine.set_meta("net_match_done", 0 if ok else 1)
	print("PASS" if ok else "FAIL %s (ended: %s)" % [role, _ended_reason])
	get_tree().quit(0 if ok else 1)


func _host() -> bool:
	await get_tree().process_frame
	Net.create_room()
	if not await _until(func() -> bool: return Net.in_lobby()):
		return _fail("no room")
	print("ROOM %s" % Net.code)
	if not await _until(func() -> bool: return Net.roster.size() == 2):
		return _fail("guest never arrived")
	Net.start_match()
	print("STARTED")
	if not await _meet(1, 2):
		return false
	# Let the guest see us too before the room closes.
	await get_tree().create_timer(2.0).timeout
	Net.leave()
	return true


func _guest() -> bool:
	# main joins by itself from --room (the invite link).
	if not await _until(func() -> bool: return Net.in_match()):
		return _fail("match never started (%s)" % Net.state)
	if (_main.get_node("UI/StartScreen") as Control).visible == false:
		return _fail("no 'click to join' title for the guest")
	if get_tree().paused:
		return _fail("the guest's world is paused in a co-op match")
	if not await _meet(2, 1):
		return false
	if not await _until(func() -> bool: return _ended_reason != ""):
		return _fail("never heard the host leave")
	return _ended_reason == "host_left" and GameState.notice != ""


## Walks our player to its spot and waits until the other's hiker stands at theirs.
func _meet(me: int, other: int) -> bool:
	var player := _main.get_node("Player") as Player
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	var mine: Vector3 = spawn.global_position + SPOTS[me]
	var theirs: Vector3 = spawn.global_position + SPOTS[other]
	var coop := _main.get_node_or_null("CoopPlayers") as CoopPlayers
	if coop == null:
		return _fail("no CoopPlayers")
	var seen := func() -> bool:
		player.global_position = mine
		for child: Node in coop.get_children():
			var hiker := child as Hiker
			if hiker and hiker.visible and Vector2(hiker.global_position.x - theirs.x, hiker.global_position.z - theirs.z).length() < NEAR:
				return true
		return false
	if not await _until(seen):
		var where: Array = []
		for child: Node in coop.get_children():
			where.append((child as Node3D).global_position)
		return _fail("peer %d's hiker not at %s: %s" % [other, theirs, where])
	print("SEEN peer %d" % other)
	return true


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
