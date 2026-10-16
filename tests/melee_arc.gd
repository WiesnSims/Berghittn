extends Node
## Run: godot --headless --fixed-fps 60 res://tests/melee_arc.tscn
## One shovel swing must hit every enemy in the arc in front of the player and none behind.

func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	var waves := main.get_node("WaveManager") as WaveManager
	# Stall the countdown; disabling the manager would take its enemies' hit areas out of physics too.
	waves._break_left = 1.0e6
	var player := main.get_node("Player") as Player
	player.global_position = Vector3(-1, 0, 1)
	player.rotation = Vector3.ZERO
	var spots: Array[Vector3] = [Vector3(-1, 0, -0.3), Vector3(-2.0, 0, 0.0), Vector3(0.0, 0, 0.0), Vector3(-1, 0, 2.3)]
	var enemies: Array[Enemy] = []
	for spot: Vector3 in spots:
		var e: Enemy = waves._create_enemy()
		e.activate(waves.wave_table.entries[0].enemy, 1, Transform3D(Basis.IDENTITY, spot))
		enemies.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for e: Enemy in enemies:
		print("enemy at ", e.global_position)
	var full: int = enemies[0].health
	player.weapons._start_melee()
	for i: int in 60:
		await get_tree().physics_frame
	var hit: Array[bool] = []
	for e: Enemy in enemies:
		hit.append(e.health < full)
	print("hit front/left/right/behind: ", hit)
	var ok: bool = hit == [true, true, true, false]
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
