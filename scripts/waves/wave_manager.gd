class_name WaveManager
extends Node3D
## Runs the waves: countdown, spawning at the active spawn points, and the break once every enemy is dead.
## Enemies are pooled because instancing during combat causes hitches in web builds.

enum Phase { BREAK, SPAWNING, CLEARING }

@export var enemy_scene: PackedScene
@export var wave_table: WaveTable
@export var zones: ZoneMap

## Current wave number; 0 before wave 1 starts.
var wave: int = 0
var _phase: Phase = Phase.BREAK
var _break_left: float = Constants.FIRST_WAVE_DELAY
var _to_spawn: int = 0
var _alive: int = 0
var _spawn_left: float = 0.0
var _pool: Array[Enemy] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Deferred so the HUD, which is set up after the world, hears the first countdown.
	Events.wave_break_started.emit.call_deferred(1, _break_left)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.BREAK:
			_break_left -= delta
			if _break_left <= 0.0:
				_start_wave(wave + 1)
		Phase.SPAWNING:
			_spawn_left -= delta
			if _spawn_left <= 0.0 and _alive < Constants.MAX_ALIVE_ENEMIES:
				_spawn_left = wave_table.spawn_interval(wave)
				_spawn()


func _start_wave(number: int) -> void:
	wave = number
	_to_spawn = wave_table.enemy_count(wave, get_tree().get_nodes_in_group("player").size())
	# First enemy right away: the countdown already was the wait.
	_spawn_left = 0.0
	_phase = Phase.SPAWNING
	Events.wave_started.emit(wave)


func _spawn() -> void:
	var point: Node3D = _pick_spawn_point()
	var data: EnemyData = wave_table.pick_enemy(wave, _rng)
	if point == null or data == null:
		push_warning("Wave %d: no spawn point or no enemy type; skipping a spawn." % wave)
		_count_spawned()
		return
	var enemy: Enemy = _pool.pop_back() if not _pool.is_empty() else _create_enemy()
	var angle: float = _rng.randf() * TAU
	var scatter := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * Constants.SPAWN_SCATTER_RADIUS
	enemy.activate(data, wave, point.global_transform.translated(scatter))
	_alive += 1
	_count_spawned()


func _count_spawned() -> void:
	_to_spawn -= 1
	if _to_spawn <= 0:
		_phase = Phase.CLEARING
		_check_cleared()


func _pick_spawn_point() -> Node3D:
	# Only points of open zones and their neighbours (section 4), so enemies come from near the players.
	var points: Array[SpawnPoint] = []
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if point and zones.is_spawn_active(point.zone):
			points.append(point)
	if points.is_empty():
		return null
	return points[_rng.randi() % points.size()]


func _check_cleared() -> void:
	if _phase != Phase.CLEARING or _alive > 0:
		return
	_phase = Phase.BREAK
	_break_left = wave_table.break_time
	Events.wave_cleared.emit(wave)
	Events.wave_break_started.emit(wave + 1, _break_left)


func _create_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.despawned.connect(_on_enemy_despawned)
	return enemy


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1
	_check_cleared()


func _on_enemy_despawned(enemy: Enemy) -> void:
	_pool.append(enemy)
