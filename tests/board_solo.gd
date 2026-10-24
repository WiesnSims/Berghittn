extends Node
## Das Gipfelbuch in the game against a local server (board/test/local.mjs), all in one run:
##     node tools/board_test.mjs
## (or by hand: godot --headless --fixed-fps 60 res://tests/board_solo.tscn -- --board=http://127.0.0.1:8789)
## Wave 1 gets the run a ticket; the death sends the run and the end screen shows its place; the
## entry is listed with our name and highlighted in the title screen's panel (Solo / Co-op, all
## time / this week). Without a name the end screen asks for one (and keeps it); "Don't sign" turns
## the switch off. Switched off, after F4 debug points, or without a server, nothing is sent; an
## unreachable board says so. The player's settings are put back after.

const PISTOLE := preload("res://data/weapons/pistole.tres")

var failures: Array[String] = []
var _main: Node
var _ranks: Array = []


func _ready() -> void:
	var saved: Array = [Settings.board, Settings.board_ids.duplicate(), Settings.profile.duplicate(), Settings.best_wave, Settings.best_points]
	Board.ranked.connect(func(rank: int, week_rank: int, id: int) -> void: _ranks.append([rank, week_rank, id]))
	_check(Board.base_url().begins_with("http://127.0.0.1"), "the board from --board (%s)" % Board.base_url())
	Settings.board = true
	Settings.board_ids.clear()
	Settings.profile = {"name": "Testsepp", "head": 1, "hat": 0, "jacket": 1, "trousers": 2}
	await _scene()
	await _signed_run()
	await _panel()
	await _scene()
	await _ask_for_name()
	await _scene()
	await _not_sent()
	await _offline()
	Settings.board = saved[0]
	Settings.board_ids.assign(saved[1])
	Settings.profile = saved[2]
	Settings.best_wave = saved[3]
	Settings.best_points = saved[4]
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _until(condition: Callable, seconds: float = 10.0) -> bool:
	var left: float = seconds
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return condition.call()


## A fresh main scene, as a restart gives one.
func _scene() -> void:
	if _main:
		_main.free()
	get_tree().paused = false
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	(_main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame


func _screen() -> DeathScreen:
	return _main.get_node("UI/DeathScreen") as DeathScreen


## Wave 1 begins (the wave manager's signal), with its ticket.
func _wave_one() -> bool:
	Events.wave_started.emit(1, false)
	return await _until(func() -> bool: return Board._ticket != "")


## The player dies at wave 1 with a few kills.
func _die(kills: int) -> void:
	var player := _main.get_node("Player") as Player
	player.weapons.give_weapon(PISTOLE)
	for i: int in kills:
		Events.enemy_killed.emit(null, i % 2 == 0, false, player)
	player.points.add(100 * kills)
	(_main.get_node("WaveManager") as WaveManager).wave = 1
	_main._on_player_died()


func _signed_run() -> void:
	_check(await _wave_one(), "wave 1 gets the run a ticket")
	_check(Board.has_run("solo") and not Board.has_run("coop"), "a solo run")
	_ranks.clear()
	_die(4)
	_check(await _until(func() -> bool: return _ranks.size() == 1), "the death sends the run")
	var line: Label = _screen()._board_line
	_check(_ranks.size() == 1 and line.visible and line.text == tr("UI_BOARD_RANK") % 1, "the end screen: place 1 (%s)" % line.text)
	_check(_ranks.size() == 1 and int(_ranks[0][2]) in Settings.board_ids, "our entry is remembered")
	var got: Array = [[], false]
	Board.listed.connect(func(mode: String, period: String, entries: Array, ok: bool) -> void:
		if mode == "solo" and period == "week":
			got[0] = entries
			got[1] = ok, CONNECT_ONE_SHOT)
	Board.fetch("solo", "week")
	await _until(func() -> bool: return got[1])
	var entries: Array = got[0]
	_check(entries.size() == 1 and entries[0]["names"] == ["Testsepp"] and int(entries[0]["kills"]) == 4
			and int(entries[0]["headshots"]) == 2 and entries[0]["fav"] == String(PISTOLE.display_name),
		"listed this week: Testsepp, 4 kills, 2 headshots, the Dienstpistole (%s)" % [entries])
	Board.submit({"names": ["Again"], "wave": 1, "points": 1, "kills": 0, "headshots": 0, "fav": ""})
	await _until(func() -> bool: return false, 1.0)
	_check(_ranks.size() == 1, "the run's ticket counts once")


func _panel() -> void:
	var start := _main.get_node("UI/StartScreen") as StartScreen
	var panel: BoardPanel = start._board
	(start.get_node("%BoardButton") as Button).pressed.emit()
	_check(panel.visible, "the title screen's Gipfelbuch button opens the panel")
	var grid: GridContainer = panel._grid
	var columns: int = BoardPanel.HEADER_KEYS.size()
	_check(await _until(func() -> bool: return grid.get_child_count() == 2 * columns), "Solo, all time: the header and our entry")
	var name_cell := grid.get_child(columns + 1) as Label if grid.get_child_count() > columns + 1 else null
	_check(name_cell != null and name_cell.text == "Testsepp" and name_cell.get_theme_color("font_color") == BoardPanel.MINE_COLOR,
		"our entry highlighted")
	(panel._mode_buttons["coop"] as Button).pressed.emit()
	_check(await _until(func() -> bool: return panel._status.visible and panel._status.text == tr("UI_BOARD_EMPTY")),
		"Co-op: no entries yet")
	(panel._mode_buttons["solo"] as Button).pressed.emit()
	(panel._period_buttons["week"] as Button).pressed.emit()
	_check(await _until(func() -> bool: return grid.get_child_count() == 2 * columns) and panel._period == "week",
		"Solo, this week: our entry")
	panel.close()


func _ask_for_name() -> void:
	Settings.profile = {}
	_check(await _wave_one(), "a run without a name gets a ticket too")
	_ranks.clear()
	_die(2)
	var screen: DeathScreen = _screen()
	_check(await _until(func() -> bool: return screen._ask.visible), "without a name the end screen asks for one")
	_check(_ranks.is_empty() and not screen._board_line.visible, "and sends nothing yet")
	screen._name_edit.text = "  Resi vom Berg  "
	screen._name_edit.text_submitted.emit(screen._name_edit.text)
	_check(await _until(func() -> bool: return _ranks.size() == 1), "signed with the name typed")
	_check(str(Settings.profile.get("name", "")) == "Resi vom Berg", "the name is ours from now on (%s)" % Settings.profile)
	_check(_ranks.size() == 1 and int(_ranks[0][0]) == 2, "behind Testsepp's run: place 2")
	# "Don't sign" switches the Gipfelbuch off.
	Settings.profile = {}
	await _scene()
	await _wave_one()
	_die(1)
	screen = _screen()
	await _until(func() -> bool: return screen._ask.visible)
	for button: Node in screen._ask.get_children():
		if button is Button and (button as Button).text == "UI_BOARD_SKIP":
			(button as Button).pressed.emit()
	_check(not Settings.board and screen._board_line.text == tr("UI_BOARD_OFF_HINT"), "Don't sign: switched off, and it says where to switch it on")
	Settings.profile = {"name": "Testsepp", "head": 1, "hat": 0, "jacket": 1, "trousers": 2}


func _not_sent() -> void:
	Settings.board = false
	Events.wave_started.emit(1, false)
	await _until(func() -> bool: return false, 0.5)
	_check(Board._ticket == "" and not Board.has_run("solo"), "switched off: no ticket")
	Settings.board = true
	await _scene()
	_check(await _wave_one(), "switched on again: a ticket")
	Board.forfeit()
	_check(not Board.has_run("solo"), "F4 debug points: the run no longer counts")
	_ranks.clear()
	_die(1)
	await _until(func() -> bool: return false, 1.5)
	_check(_ranks.is_empty() and not _screen()._board_line.visible, "and nothing is sent")


func _offline() -> void:
	var got: Array = [null]
	Board.listed.connect(func(_mode: String, _period: String, _entries: Array, ok: bool) -> void: got[0] = ok, CONNECT_ONE_SHOT)
	# A board nobody answers at (the port is closed).
	Board.set_meta("test_url", "http://127.0.0.1:1")
	Board.fetch("solo", "all")
	await _until(func() -> bool: return got[0] != null, Constants.BOARD_TIMEOUT + 2.0)
	_check(got[0] == false, "an unreachable board says so")
	Board.remove_meta("test_url")
