extends Node
## Run: godot --headless --fixed-fps 60 res://tests/main_menu.tscn
## Headless check of the ways back to the title (1.1.2): the solo pause menu has Main menu, which
## asks once more before it ends the run; the death screen has the Gipfelbuch (on the run's board)
## and Main menu, after the same wait as its other buttons. Main's own handlers are taken off first,
## since they reload the scene.

var failures: Array[String] = []
var asked: int = 0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var pause := main.get_node("UI/PauseMenu") as PauseMenu
	var death := main.get_node("UI/DeathScreen") as DeathScreen
	_check(pause.menu_requested.get_connections().size() == 1 and death.menu_requested.get_connections().size() == 1,
		"the game listens to both")
	for connection: Dictionary in pause.menu_requested.get_connections() + death.menu_requested.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"])
	pause.menu_requested.connect(func() -> void: asked += 1)
	death.menu_requested.connect(func() -> void: asked += 1)
	# The pause menu, solo.
	pause.show()
	await get_tree().process_frame
	var leave := pause.get_node("%LeaveButton") as Button
	_check(leave.visible and leave.text == "UI_MAIN_MENU", "pause, solo: %s" % tr(leave.text))
	leave.pressed.emit()
	_check(asked == 0 and leave.text == "UI_MAIN_MENU_SURE", "one click asks: %s" % tr(leave.text))
	leave.pressed.emit()
	_check(asked == 1, "the second ends the run")
	pause.hide()
	pause.show()
	_check(leave.text == "UI_MAIN_MENU", "and it asks again next time")
	pause.hide()
	# The death screen.
	death.present(4, 1234, PlayerStats.new(), false)
	var board := death.get("_board_button") as Button
	var menu := death.get("_menu_button") as Button
	_check(board.visible and menu.visible and board.disabled and menu.disabled, "the death screen: Gipfelbuch and Main menu, waiting out the stray click")
	for i: int in roundi((death.get_node("EnableTimer") as Timer).wait_time * 60.0) + 10:
		await get_tree().process_frame
	_check(not board.disabled and not menu.disabled, "then they work")
	board.pressed.emit()
	var panel := death.get("_board_panel") as BoardPanel
	_check(panel.visible and panel._mode == "solo", "the Gipfelbuch opens on the solo board")
	panel.close()
	menu.pressed.emit()
	_check(asked == 2, "Main menu goes back to the title")
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
