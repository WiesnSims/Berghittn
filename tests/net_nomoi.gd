extends Node
## M9 "Nomoi!" over the real relay, one role per process:
##     node tools/net_test.mjs res://tests/net_nomoi.tscn
## Host and guest play; a friend opens the invite link while the match runs (--role=late) and must
## wait in the lobby. At game over both end screens show the Hüttenwertung with both runs, the late
## friend gets into the room, and the Nomoi! count leaves them out (they are not on an end screen).
## The guest presses Nomoi! first ("1 / 2"), then the host, and the next match starts by itself for
## all three: host and guest in a fresh scene behind "Join match" (no click of the host's to lock
## the pointer with), the late friend straight from the lobby.

const TIMEOUT: float = 25.0

var _main: Node
var _ended_reason: String = ""


func _ready() -> void:
	var role: String = _arg("role", "host")
	if Engine.has_meta("net_nomoi_done"):
		get_tree().quit(int(Engine.get_meta("net_nomoi_done")))
		return
	var again: bool = Engine.has_meta("net_nomoi_over")
	if not again:
		Settings.profile = {"name": {"host": "Wirt", "guest": "Gast", "late": "Spaet"}[role], "head": 1, "hat": 0, "jacket": 1, "trousers": 2}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	if not again:
		Net.ended.connect(func(reason: String) -> void: _ended_reason = reason)
	var ok: bool = false
	if again:
		ok = await _next_match(role)
	else:
		match role:
			"host":
				ok = await _host()
			"guest":
				ok = await _guest()
			"late":
				ok = await _late()
	if not ok or role == "late" or again:
		_finish(ok, role)


func _finish(ok: bool, role: String) -> void:
	Engine.set_meta("net_nomoi_done", 0 if ok else 1)
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
	# Long enough for the late friend to be turned away at least once.
	await get_tree().create_timer(6.0).timeout
	var world := _main.get_node("CoopWorld") as CoopWorld
	world._end.rpc(3)
	world._end(3)
	if not await _end_screen():
		return false
	if not await _until(func() -> bool: return Net.roster.size() == 3):
		return _fail("the late friend never got into the room after the game over")
	if not await _until(func() -> bool: return Net.nomoi_ready == 1 and Net.nomoi_total == 2):
		return _fail("count after the guest's Nomoi! is %d / %d, not 1 / 2" % [Net.nomoi_ready, Net.nomoi_total])
	print("COUNT 1 / 2")
	return await _press_nomoi()


func _guest() -> bool:
	# main joins by itself from --room (the invite link).
	if not await _until(func() -> bool: return Net.in_match()):
		return _fail("match never started (%s)" % Net.state)
	if not await _end_screen():
		return false
	return await _press_nomoi()


func _late() -> bool:
	# Opened the invite link while the match runs: waits in the lobby, knocking.
	var lobby := _main.get_node("UI/Lobby") as Lobby
	if not await _until(func() -> bool: return lobby._waiting_code != ""):
		return _fail("not waiting for the running match (%s)" % _ended_reason)
	if lobby._status.text != tr("UI_LOBBY_MATCH_RUNNING"):
		return _fail("the lobby says '%s'" % lobby._status.text)
	print("WAITING")
	if not await _until(func() -> bool: return Net.in_lobby()):
		return _fail("never got in after the game over")
	if not await _until(func() -> bool: return Net.in_match(), 40.0):
		return _fail("not taken along by Nomoi!")
	if Net.roster.size() != 3:
		return _fail("roster %s" % Net.roster)
	return true


## Both runs in the Hüttenwertung, and Nomoi! clickable once the stray-click wait is over.
func _end_screen() -> bool:
	var screen := _main.get_node("UI/DeathScreen") as DeathScreen
	if not await _until(func() -> bool: return screen.visible and Net.runs.size() == 2):
		return _fail("no end screen with both runs (%d)" % Net.runs.size())
	var names: Array = Net.runs.values().map(func(row: Dictionary) -> String: return row["name"])
	if not ("Wirt" in names and "Gast" in names):
		return _fail("runs %s" % [Net.runs])
	var grid := screen.get_node("%Wertung") as GridContainer
	if not await _until(func() -> bool: return grid.get_child_count() == 18):
		return _fail("the Hüttenwertung has %d cells" % grid.get_child_count())
	if not (screen.get_node("%Invite") as Control).visible:
		return _fail("no invite link on the end screen")
	print("WERTUNG %s" % [names])
	return true


func _press_nomoi() -> bool:
	var button := _main.get_node("UI/DeathScreen").get_node("%NomoiButton") as Button
	if not await _until(func() -> bool: return not button.disabled):
		return _fail("Nomoi! stays greyed out")
	Engine.set_meta("net_nomoi_over", true)
	button.pressed.emit()
	print("NOMOI")
	if not await _until(func() -> bool: return button.disabled):
		return _fail("Nomoi! still clickable after pressing it")
	# The next match reloads this scene, which goes on in _next_match.
	if not await _until(func() -> bool: return false, 30.0):
		return _fail("no new match after Nomoi!")
	return false


func _next_match(role: String) -> bool:
	if not await _until(func() -> bool: return Net.in_match() and Net.roster.size() == 3):
		return _fail("not in the next match with three (%s, %s)" % [Net.state, Net.roster])
	var start := _main.get_node("UI/StartScreen") as Control
	if not await _until(func() -> bool: return start.visible):
		return _fail("no 'Join match' title in the next match")
	if role == "host" and not Net.auto_started:
		return _fail("the host's match does not know it was started by Nomoi!")
	print("NEXT MATCH")
	if role == "host":
		# Let the others see the match before the room closes.
		await get_tree().create_timer(3.0).timeout
		Net.leave()
	return true


func _until(condition: Callable, timeout: float = TIMEOUT) -> bool:
	var left: float = timeout
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
