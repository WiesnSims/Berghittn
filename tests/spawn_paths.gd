extends Node
## Run: godot --headless --fixed-fps 60 res://tests/spawn_paths.tscn
## From every spawn point that is active at the start (only the Stube open), one enemy must make it into the
## Stube: around the hut, down into the beer garden and up to the deck, through a barricaded window.
## Catches spots on the map where bodies get stuck that the navmesh thinks are fine.

const STAND: Vector3 = Vector3(-2.0, 0.0, 1.0)
const LIMIT: float = 70.0

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
	var waves := main.get_node("WaveManager") as WaveManager
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	var zones := main.get_node("Zones") as ZoneMap
	var player := main.get_node("Player") as Player
	var data: EnemyData = load("res://data/enemies/wanderer.tres")
	var enemies: Array[Enemy] = []
	var names: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if not zones.is_spawn_active(point.zone):
			continue
		var enemy := waves.enemy_scene.instantiate() as Enemy
		main.add_child(enemy)
		enemy.activate(data, 1, point.global_transform)
		enemies.append(enemy)
		names.append("%s/%s" % [point.zone, point.name])
	var arrived: Dictionary = {}
	var last_pos: Dictionary = {}
	var t: float = 0.0
	while t < LIMIT and arrived.size() < enemies.size():
		player.global_position = STAND
		player.velocity = Vector3.ZERO
		player.health._health = 100.0
		await get_tree().physics_frame
		t += 1.0 / 60.0
		for i: int in enemies.size():
			var p: Vector3 = enemies[i].global_position
			last_pos[i] = p
			if not arrived.has(i) and p.x > -11.0 and p.x < 7.0 and p.z > -6.0 and p.z < 6.0 and p.y > -0.1 and p.y < 1.0:
				arrived[i] = t
	for i: int in enemies.size():
		_check(arrived.has(i), "%s reaches the Stube%s" % [names[i], " in %.1f s" % arrived[i] if arrived.has(i) else " (stuck at %s, state %d)" % [last_pos[i], enemies[i]._state]])
	print("RESULT: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
