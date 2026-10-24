extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_kraxn.tscn
## Headless check of die Kraxn (#95) on the real main scene: it hangs in the Matratzenlager; strapped
## on for 2500 it gives a third gun slot, so a third gun no longer replaces the one in hand; key 3
## takes it; it stays through going down and bleeding out; it is bought once.

const GUNS: Array[String] = ["jagdflinte", "stutzen"]

var main: Node
var player: Player
var weapons: WeaponHolder
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	weapons = player.weapons
	main.get_node("WaveManager").process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	var kraxn := main.find_children("*", "Kraxn", true, false)[0] as Kraxn
	_check(kraxn != null and kraxn.global_position.y > 3.4 and kraxn.global_position.x < -10.0, "die Kraxn hangs in the Matratzenlager")
	var spot: Vector3 = kraxn.get_interact_position()
	player.global_position = Vector3(spot.x, kraxn.global_position.y + 0.05, spot.z)
	player.look_at(Vector3(kraxn.global_position.x, player.global_position.y, kraxn.global_position.z), Vector3.UP)
	await _frames(5)
	_check(player.interactor._target == kraxn and player.interactor._prompt == tr("UI_KRAXN_NEED") % Constants.KRAXN_COST, "too poor: \"%s\"" % player.interactor._prompt)
	# Two guns first: a third one replaces the one in hand.
	weapons.give_weapon(load("res://data/weapons/jagdflinte.tres"))
	_check(not weapons.has_free_slot(), "without it: two guns and no room")
	player.points.add(Constants.KRAXN_COST + 100)
	await _frames(2)
	_check(player.interactor._prompt == tr("UI_KRAXN") % Constants.KRAXN_COST, "\"%s\"" % player.interactor._prompt)
	player.interactor._use()
	await _frames(2)
	_check(weapons.has_kraxn() and weapons.slots == 3 and player.points.total == 100, "strapped on for %d: three gun slots" % Constants.KRAXN_COST)
	_check(player.interactor._prompt == "" or player.interactor._target != kraxn, "bought once")
	_check(weapons.has_free_slot(), "room for a third gun")
	weapons.give_weapon(load("res://data/weapons/stutzen.tres"))
	_check(weapons.gun_count() == 3 and weapons.has_weapon(load("res://data/weapons/pistole.tres")) and weapons.has_weapon(load("res://data/weapons/jagdflinte.tres")),
			"a third gun joins the others: pistol, Jagdflinte, Stutzen")
	_check(not weapons.has_free_slot(), "then it is full again")
	_check(weapons.stowed().size() == 2, "two guns ride on the Kraxn while one is in hand")
	# Key 3, with real input where the mouse can be taken.
	weapons._select(0)
	await _frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var press := InputEventAction.new()
		press.action = &"weapon_slot_3"
		press.pressed = true
		Input.parse_input_event(press)
		await _frames(2)
		_check(weapons.weapon.id == &"stutzen", "key 3 takes the third gun")
	else:
		print("(no mouse capture here: key 3 not checked)")
	# Going down and bleeding out take nothing.
	var pistol: WeaponData = load("res://data/weapons/pistole.tres")
	weapons.set_downed(true, pistol)
	weapons.set_downed(false, pistol)
	_check(weapons.gun_count() == 3 and weapons.has_kraxn(), "going down takes nothing")
	weapons.reset_loadout()
	_check(weapons.has_kraxn() and weapons.slots == 3, "bled out and back: the Kraxn is still on")
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
