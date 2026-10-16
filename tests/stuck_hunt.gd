extends Node
## Run: godot --headless --fixed-fps 60 res://tests/stuck_hunt.tscn [-- seconds]
## Play-test bug: enemies sometimes hang in doorways and at corners. All zones open, the player hops to a
## random spot on the navmesh every few seconds, and a crowd of every enemy type chases. An enemy that is
## chasing but has not moved for STALL seconds while still far from the player counts as stuck.

const CROWD: int = 14
const HOP_EVERY: float = 12.0
const STALL: float = 2.5
const STALL_MOVE: float = 0.4
const NEAR: float = 2.5
const TYPES: Array[String] = ["wanderer", "wanderer", "tourist", "knappe", "perchte"]

var main: Node
var player: Player
var waves: WaveManager
var t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _enemies: Array[Enemy] = []
var _anchor: Dictionary = {}
var _stuck: Array[String] = []
var _arrived: int = 0


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _run() -> void:
	var limit: float = 300.0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		limit = float(args[0])
	_rng.seed = 7
	for i: int in 5:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	var zones := main.get_node("Zones") as ZoneMap
	for zone: ZoneData in zones.table.zones:
		zones.unlock(zone.id, null)
	for i: int in 30:
		await get_tree().physics_frame
	var stand: Vector3 = _random_spot()
	var hop_left: float = 0.0
	while t < limit:
		hop_left -= 1.0 / 60.0
		if hop_left <= 0.0:
			hop_left = HOP_EVERY
			stand = _random_spot()
			_anchor.clear()
		player.global_position = stand
		player.velocity = Vector3.ZERO
		player.health._health = float(player.health.max_health)
		while _enemies.size() < CROWD:
			_spawn()
		await get_tree().physics_frame
		t += 1.0 / 60.0
		_watch(stand)
	print("--- %.0f s, %d arrived, %d stuck" % [t, _arrived, _stuck.size()])
	for line: String in _stuck:
		print("  ", line)
	# A rare one is allowed: before the fix this found 12 to 19 in ten minutes, after it 0 or 1.
	var ok: bool = _stuck.size() <= 1
	print("RESULT: ", "PASS" if ok else "FAIL (%d stuck)" % _stuck.size())
	get_tree().quit(0 if ok else 1)


func _random_spot() -> Vector3:
	# Only spots a player can actually stand on and walk to from the Stube (the navmesh also covers roofs).
	var map: RID = player.get_world_3d().navigation_map
	while true:
		var spot: Vector3 = NavigationServer3D.map_get_random_point(map, 1, true)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(-2, 0, 1), spot, true)
		if path.size() > 0 and path[path.size() - 1].distance_to(spot) < 0.3:
			return spot + Vector3.UP * 0.05
	return Vector3.ZERO


func _spawn() -> void:
	var points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	var point := points[_rng.randi() % points.size()] as SpawnPoint
	var enemy := waves.enemy_scene.instantiate() as Enemy
	main.add_child(enemy)
	enemy.activate(load("res://data/enemies/%s.tres" % TYPES[_rng.randi() % TYPES.size()]), 3, point.global_transform)
	_enemies.append(enemy)


func _near_window(enemy: Enemy) -> bool:
	var result: NavigationPathQueryResult3D = enemy._agent.get_current_navigation_result()
	var start: int = enemy._agent.get_current_navigation_path_index()
	for i: int in range(start, mini(start + 3, result.path.size())):
		if result.path_types[i] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK:
			return enemy.global_position.distance_to(result.path[i]) < 3.0
	return false


func _remove(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_anchor.erase(enemy.get_instance_id())
	enemy.queue_free()


func _watch(stand: Vector3) -> void:
	for enemy: Enemy in _enemies.duplicate():
		var to_player: float = enemy.global_position.distance_to(stand)
		if enemy.global_position.y > 20.0:
			_stuck.append("t=%.0f %s flew off to %s" % [t, enemy.data.id, enemy.global_position.snapped(Vector3.ONE * 0.1)])
			_remove(enemy)
			continue
		if to_player < NEAR or enemy._state == Enemy.State.ATTACKING:
			_arrived += 1
			_remove(enemy)
			continue
		var id: int = enemy.get_instance_id()
		var chasing: bool = enemy._state == Enemy.State.CHASING
		if not chasing or not _anchor.has(id) or enemy.global_position.distance_to(_anchor[id].p) > STALL_MOVE:
			_anchor[id] = {"p": enemy.global_position, "t": t}
			continue
		# Waiting behind the crowd at a window is not stuck.
		if t - _anchor[id].t > STALL and not _near_window(enemy):
			var against: Array[String] = []
			for i: int in enemy.get_slide_collision_count():
				var c: KinematicCollision3D = enemy.get_slide_collision(i)
				var other := c.get_collider() as Node
				if other != null:
					against.append("%s n=%s" % [other.get_parent().name + "/" + other.name if other.get_parent() else other.name, c.get_normal().snapped(Vector3.ONE * 0.1)])
			_stuck.append("t=%.0f %s at %s, player at %s, next %s, against %s" % [t, enemy.data.id,
				enemy.global_position.snapped(Vector3.ONE * 0.1), stand.snapped(Vector3.ONE * 0.1),
				enemy._agent.get_next_path_position().snapped(Vector3.ONE * 0.1), against])
			_remove(enemy)
