extends Node
## Run: godot --headless --fixed-fps 60 res://tests/upstairs.tscn
## Every change of level must work for real bodies, not just on the navmesh: the player walks up the hall
## stairs, and an enemy chases a player up each of them (hall stairs to the gallery, garden steps to the
## deck, the hay-loft ramp, the gondola platform ramp). Enemies have no step climbing, so a ramp with a
## ledge they can catch on shows up here as an enemy stuck at the bottom.

const CLIMBS: Array = [
	["hall stairs to the gallery", Vector3(3, 0, 2), Vector3(-6.0, 3.5, -4.8)],
	["garden steps to the deck", Vector3(-6, -1.5, 16.5), Vector3(-5.0, 0.0, 8.0)],
	["ramp to the hay loft", Vector3(10, 0, 14), Vector3(18.5, 3.5, 14.0)],
	["ramp onto the gondola platform", Vector3(8.5, 0, 0.5), Vector3(14.5, 1.0, 3.5)],
]

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run() -> void:
	for i: int in 5:
		await get_tree().physics_frame
	get_tree().paused = false
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var player := main.get_node("Player") as Player
	player.global_position = Vector3(6.2, 0.0, -5.3)
	player.rotation.y = PI * 0.5
	Input.action_press("move_forward")
	for i: int in 240:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.y > 3.4, "player walks up the hall stairs onto the gallery (at %s)" % player.global_position)

	var waves := main.get_node("WaveManager") as WaveManager
	for climb: Array in CLIMBS:
		var enemy := waves.enemy_scene.instantiate() as Enemy
		main.add_child(enemy)
		var goal: Vector3 = climb[2]
		enemy.activate(load("res://data/enemies/wanderer.tres"), 1, Transform3D(Basis.IDENTITY, climb[1]))
		var t: float = 0.0
		while t < 25.0 and not (absf(enemy.global_position.y - goal.y) < 0.4 and Vector2(enemy.global_position.x - goal.x, enemy.global_position.z - goal.z).length() < 2.5):
			player.global_position = goal
			player.velocity = Vector3.ZERO
			player.health._health = 100.0
			await get_tree().physics_frame
			t += 1.0 / 60.0
		_check(t < 25.0, "enemy follows up the %s in %.1f s (ended at %s)" % [climb[0], t, enemy.global_position])
		enemy.queue_free()
	print("RESULT: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
