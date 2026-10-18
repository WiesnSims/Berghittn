extends Node
## Run: godot --headless --fixed-fps 60 res://tests/fire_after_reload.tscn
## Play-test 2026-10-18: a click during a reload (or one buffered from the last shot's cycle) fired as
## soon as the reload was done. Only a pull of the trigger once the gun is ready may shoot; a trigger
## held through the reload does nothing until it is let go and pulled again.

var weapons: WeaponHolder
var failures: Array[String] = []
var _shots: int = 0


func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(5)
	get_tree().paused = false
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	weapons = (main.get_node("Player") as Player).weapons
	# Stands in for a captured mouse, so the trigger is read.
	weapons.force_aim = true
	weapons.fired.connect(func(_rounds: int) -> void: _shots += 1)
	await _frames(30)
	await _buffered_click()
	await _click_during_reload()
	await _held_through_reload()
	print("RESULT: ", "PASS" if failures.is_empty() else "%d FAILED" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _click() -> void:
	Input.action_press("fire")
	await _frames(1)
	Input.action_release("fire")
	await _frames(1)


func _reload_done() -> void:
	while weapons.is_reloading():
		await _frames(1)


func _buffered_click() -> void:
	# The last round, then a second click while it still cycles: the gun reloads by itself.
	weapons.mag = 1
	_shots = 0
	await _click()
	await _click()
	await _frames(60)
	_check(weapons.is_reloading(), "the empty gun reloads by itself")
	await _reload_done()
	await _frames(30)
	_check(_shots == 1 and weapons.mag == weapons.weapon.loaded_capacity(false), "the click from before the reload does not fire after it (%d shots)" % _shots)


func _click_during_reload() -> void:
	weapons.mag = 1
	weapons.start_reload()
	_shots = 0
	await _frames(10)
	await _click()
	await _reload_done()
	await _frames(30)
	_check(_shots == 0, "a click during the reload does not fire when it is done (%d shots)" % _shots)
	await _click()
	_check(_shots == 1, "a click once it is ready fires")


func _held_through_reload() -> void:
	weapons.mag = 0
	weapons.reserve = 100
	Input.action_press("fire")
	await _frames(30)
	_check(weapons.is_reloading(), "pulling the trigger on the empty gun reloads")
	_shots = 0
	await _reload_done()
	await _frames(30)
	_check(_shots == 0, "a trigger held through the reload does not fire (%d shots)" % _shots)
	Input.action_release("fire")
	await _frames(1)
	await _click()
	_check(_shots == 1, "let go and pulled again, it fires")
