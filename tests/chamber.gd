extends Node
## Run: godot --headless --fixed-fps 60 res://tests/chamber.tscn
## Magazine + 1: a gun starts chambered, a reload with a round still chambered loads mag + 1,
## a reload from empty loads mag.

func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var weapons := (main.get_node("Player") as Player).weapons
	var size: int = weapons.weapon.mag_size
	var results: Array[bool] = []
	results.append(weapons.mag == size + 1)
	print("start: %d" % weapons.mag)
	for i: int in 3:
		weapons._fire()
	weapons.start_reload()
	weapons._finish_reload()
	results.append(weapons.mag == size + 1)
	print("reload with %d left: %d" % [size - 2, weapons.mag])
	weapons.mag = 0
	weapons.start_reload()
	weapons._finish_reload()
	results.append(weapons.mag == size)
	print("reload from empty: %d" % weapons.mag)
	weapons.start_reload()
	weapons._finish_reload()
	results.append(weapons.mag == size + 1)
	print("reload again (chambered now): %d" % weapons.mag)
	var ok: bool = not results.has(false)
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
