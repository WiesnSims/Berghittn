extends Node
## Das Gipfelbuch in co-op, over the local relay and a local board, one role per process:
##     node tools/board_test.mjs   (or: BOARD_URL=<a running board> node tools/net_test.mjs res://tests/net_board.tscn)
## The host's wave 1 gets the match its ticket; at game over the host sends one entry for the
## group, best points first, the guest (who switched the Gipfelbuch off) without a name; both end
## screens show the group's place, and both remember the entry. The co-op board lists it, the solo
## board does not. The player's settings are put back after.

const TIMEOUT: float = 25.0

var _main: Node
var _ranks: Array = []


func _ready() -> void:
	var role: String = _arg("role", "host")
	var saved: Array = [Settings.board, Settings.board_ids.duplicate(), Settings.profile.duplicate()]
	Settings.profile = {"name": {"host": "Wirt", "guest": "Gast"}[role], "head": 1, "hat": 0, "jacket": 1, "trousers": 2}
	Settings.board = role == "host"
	Settings.board_ids.clear()
	Board.ranked.connect(func(rank: int, week_rank: int, id: int) -> void: _ranks.append([rank, week_rank, id]))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var ok: bool = false
	if role == "host":
		ok = await _host()
	else:
		ok = await _guest()
	Settings.board = saved[0]
	Settings.board_ids.assign(saved[1])
	Settings.profile = saved[2]
	Settings.save()
	print("PASS" if ok else "FAIL %s" % role)
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
	await get_tree().create_timer(2.0).timeout
	# Wave 1 as the wave manager starts it (it would after the co-op countdown).
	Events.wave_started.emit(1, false)
	if not await _until(func() -> bool: return Board.has_run("coop") and Board._ticket != ""):
		return _fail("the host's wave 1 got no co-op ticket")
	var player := _main.get_node("Player") as Player
	player.points.add(700)
	var world := _main.get_node("CoopWorld") as CoopWorld
	world._end.rpc(1)
	world._end(1)
	if not await _placed():
		return false
	var got: Array = [null, null]
	Board.listed.connect(func(mode: String, _period: String, entries: Array, _ok: bool) -> void:
		got[0 if mode == "coop" else 1] = entries)
	Board.fetch("coop", "all")
	Board.fetch("solo", "all")
	if not await _until(func() -> bool: return got[0] != null and got[1] != null):
		return _fail("the boards were not listed")
	var coop: Array = got[0]
	if coop.size() != 1 or coop[0]["names"] != ["Wirt", tr("UI_DEATH_NONE")] or int(coop[0]["players"]) != 2:
		return _fail("the co-op board: %s" % [coop])
	if int(coop[0]["points"]) != player.points.total + _guest_points():
		return _fail("the group's points: %d, not %d" % [coop[0]["points"], player.points.total + _guest_points()])
	if (got[1] as Array).any(func(e: Dictionary) -> bool: return int(e["id"]) == int(coop[0]["id"])):
		return _fail("the group's entry is on the solo board")
	print("LISTED %s" % [coop[0]["names"]])
	# Let the guest see its place before the room closes.
	await get_tree().create_timer(3.0).timeout
	Net.leave()
	return true


func _guest() -> bool:
	if not await _until(func() -> bool: return Net.in_match()):
		return _fail("match never started (%s)" % Net.state)
	if Board.has_run("coop"):
		return _fail("a guest opened a ticket of its own")
	return await _placed()


func _guest_points() -> int:
	for peer: int in Net.runs:
		if peer != Net.my_id():
			return int(Net.runs[peer]["points"])
	return 0


## The group's place on our end screen, and the entry remembered.
func _placed() -> bool:
	var screen := _main.get_node("UI/DeathScreen") as DeathScreen
	if not await _until(func() -> bool: return screen.visible and _ranks.size() == 1, TIMEOUT + Constants.BOARD_COOP_WAIT):
		return _fail("no place for the group (%s)" % [_ranks])
	var line: Label = screen._board_line
	if not line.visible or line.text != tr("UI_BOARD_RANK") % 1:
		return _fail("the end screen says '%s'" % line.text)
	if not int(_ranks[0][2]) in Settings.board_ids:
		return _fail("the entry is not remembered")
	print("PLACED %s" % [_ranks[0]])
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
