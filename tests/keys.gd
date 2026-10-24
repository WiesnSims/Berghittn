extends Node
## Run: godot --headless --fixed-fps 60 res://tests/keys.tscn
## Headless check of the key bindings (1.1.2, Keys): texts name the bound key; a new key goes first
## on its action and swaps with the action that had it; pause, debug and Esc cannot be had; a mouse
## button can be bound; the bindings are saved and come back; the Settings menu's buttons wait for a
## key (Esc cancels) and Reset brings the defaults back; the HUD's prompt and the title's controls
## line follow. The player's own bindings are put back after.

var failures: Array[String] = []


func _ready() -> void:
	var saved: Dictionary = Settings.bindings.duplicate(true)
	Keys.apply({})
	_names()
	_rebind()
	await _menu_and_hud()
	Settings.bindings = saved
	Keys.apply(saved)
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func _names() -> void:
	_check(Keys.name_of("interact") == "E" and Keys.name_of("jump") == "Space" and Keys.name_of("fire") == tr("UI_KEY_MOUSE_LEFT"),
		"the defaults: E, Space, %s" % Keys.name_of("fire"))
	_check(Keys.fill(tr("UI_BUY_WEAPON")) % ["Stutzen", 900] == "Press E to buy the Stutzen (900)", "a prompt names the key: %s" % (Keys.fill(tr("UI_BUY_WEAPON")) % ["Stutzen", 900]))
	_check(not "{" in Keys.fill(tr("UI_CONTROLS")) and Keys.fill(tr("UI_CONTROLS")).begins_with("WASD"), "the controls line: %s" % Keys.fill(tr("UI_CONTROLS")))
	for action: String in Keys.actions():
		_check(InputMap.has_action(action) and tr(Keys.ACTIONS[Keys.actions().find(action)][1]) != Keys.ACTIONS[Keys.actions().find(action)][1],
			"%s: an action with a name in the menu" % action)


func _rebind() -> void:
	var saved: Dictionary = Keys.rebind("interact", _key(KEY_F))
	_check(Keys.name_of("interact") == "F" and saved["interact"] == {"key": KEY_F}, "use on F")
	Input.parse_input_event(_key(KEY_F))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("interact"), "F now uses")
	var up := _key(KEY_F)
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	Keys.rebind("jump", _key(KEY_F))
	_check(Keys.name_of("jump") == "F" and Keys.name_of("interact") == "Space", "jump on F: use gets Space, a swap")
	_check(InputMap.action_get_events("move_forward").size() == 2, "forward keeps its arrow key")
	Keys.rebind("move_forward", _key(KEY_UP))
	var forward: Array[InputEvent] = InputMap.action_get_events("move_forward")
	_check(Keys.name_of("move_forward") == "Up" and forward.size() == 1, "forward on its own arrow key: not twice (%d)" % forward.size())
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	mouse.pressed = true
	Keys.rebind("melee", mouse)
	_check(Keys.name_of("melee") == tr("UI_KEY_MOUSE_4"), "melee on a mouse button: %s" % Keys.name_of("melee"))
	_check(not Keys.can_bind(_key(KEY_P)) and not Keys.can_bind(_key(KEY_F3)) and not Keys.can_bind(_key(KEY_ESCAPE)),
		"P (pause), F3 (debug) and Esc cannot be had")
	var kept: Dictionary = Keys.saved()
	Keys.apply({})
	_check(Keys.name_of("jump") == "Space" and Keys.name_of("interact") == "E", "the defaults again")
	Keys.apply(kept)
	_check(Keys.name_of("jump") == "F" and Keys.name_of("interact") == "Space" and Keys.name_of("melee") == tr("UI_KEY_MOUSE_4"),
		"the saved bindings come back")
	Keys.apply({"jump": {"key": KEY_P}, "fire": "nonsense", "crouch": {"mouse": -3}})
	_check(Keys.name_of("jump") == "Space" and Keys.name_of("crouch") == "C", "bad saved bindings are left out")


func _menu_and_hud() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var menu := main.get_node("UI/SettingsMenu") as SettingsMenu
	menu.open()
	var button := menu._key_buttons["reload"] as Button
	_check(button.text == "R", "the menu shows reload on R")
	button.pressed.emit()
	_check(button.text == tr("UI_KEYS_PRESS"), "pressed: it waits for a key")
	menu._input(_key(KEY_ESCAPE))
	_check(button.text == "R" and Keys.name_of("reload") == "R", "Esc leaves it as it was")
	button.pressed.emit()
	menu._input(_key(KEY_P))
	_check(Keys.name_of("reload") == "R" and menu._key_note.text == "UI_KEYS_TAKEN", "P is refused, and it says why")
	button.pressed.emit()
	menu._input(_key(KEY_T))
	_check(button.text == "T" and Keys.name_of("reload") == "T" and Settings.bindings.get("reload") == {"key": KEY_T}, "T: reload on T, kept in Settings")
	var start := main.get_node("UI/StartScreen") as StartScreen
	_check(" T " in (start.get_node("%Controls") as Label).text, "the title's controls line says T")
	var hud := main.get_node("UI/Hud") as Hud
	Keys.rebind("interact", _key(KEY_F))
	hud._on_prompt_changed(tr("UI_CHEST_BUY") % 950)
	_check(hud._prompt_label.text == "Press F to open the Hüttentruhe (950)", "the HUD's prompt: %s" % hud._prompt_label.text)
	for child: Node in menu._rows.get_children():
		if child is Button and (child as Button).text == "UI_KEYS_RESET":
			(child as Button).pressed.emit()
	_check(Keys.name_of("reload") == "R" and Keys.name_of("interact") == "E" and Settings.bindings.is_empty() and button.text == "R",
		"Reset: the defaults, nothing saved")
	menu.close()
	main.queue_free()
