class_name EnemySpawner
extends Node3D
## M2 stand-in for the wave manager: keeps one enemy alive, respawning it after a short delay.
## Enemies are pooled because instancing during combat causes hitches in web builds.

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData

var _pool: Array[Enemy] = []
var _alive: int = 0
var _spawn_left: float = Constants.TEST_SPAWN_DELAY
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if _alive > 0:
		return
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_left = Constants.TEST_SPAWN_DELAY
		_spawn()


func _spawn() -> void:
	var points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	if points.is_empty():
		push_warning("No nodes in group spawn_points; nothing to spawn at.")
		return
	var point := points[_rng.randi() % points.size()] as Node3D
	var enemy: Enemy = _pool.pop_back() if not _pool.is_empty() else _create_enemy()
	enemy.activate(enemy_data, Constants.TEST_SPAWN_WAVE, point.global_transform)
	_alive += 1


func _create_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.despawned.connect(_on_enemy_despawned)
	return enemy


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1


func _on_enemy_despawned(enemy: Enemy) -> void:
	_pool.append(enemy)
