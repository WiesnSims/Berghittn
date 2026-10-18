extends Node
## Frame rate with a full crowd (M6 part 4): 24 enemies walk at the player on the pasture, and every
## 3 s the six nearest are killed (six ragdolls at once) and sent back in from the edge. Prints the
## average FPS and the worst frame every 2 s for 30 s. Windowed, or in a web build of the tests:
##     godot res://tests/crowd_bench.tscn

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)
const IDS: Array[String] = ["wanderer", "wanderer", "wanderer", "tourist", "knappe", "perchte"]
const CROWD: int = 24

var main: Node
var player: Player
var waves: WaveManager
var _crowd: Array[Enemy] = []
var _frames: int = 0
var _time: float = 0.0
var _worst: float = 0.0
var _total: float = 0.0
var _kill_left: float = 3.0


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	(main.get_node("UI/StartScreen") as Control).hide()
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = FIELD
	for i: int in CROWD:
		var enemy: Enemy = waves._create_enemy()
		_crowd.append(enemy)
		_send_in(enemy, i)
	print("BENCH start")


func _send_in(enemy: Enemy, i: int) -> void:
	var angle: float = TAU * float(i) / float(CROWD) + randf() * 0.2
	var at: Vector3 = FIELD + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(9.0, 13.0)
	enemy.activate(load("res://data/enemies/%s.tres" % IDS[i % IDS.size()]), 5, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if player == null:
		return
	player.health._health = float(player.health.max_health)
	_frames += 1
	_time += delta
	_total += delta
	_worst = maxf(_worst, delta)
	_kill_left -= delta
	if _kill_left <= 0.0:
		_kill_left = 3.0
		var living: Array[Enemy] = _crowd.filter(func(e: Enemy) -> bool: return e.is_alive())
		living.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			return a.global_position.distance_squared_to(FIELD) < b.global_position.distance_squared_to(FIELD))
		for enemy: Enemy in living.slice(0, 6):
			enemy.receive_hit(100000, false, false, player)
	for i: int in _crowd.size():
		var enemy: Enemy = _crowd[i]
		if enemy._state == Enemy.State.INACTIVE:
			_send_in(enemy, i)
	if _time >= 2.0:
		print("BENCH fps %.1f worst %.1f ms alive %d ragdolls %d" % [_frames / _time, _worst * 1000.0,
				_crowd.filter(func(e: Enemy) -> bool: return e.is_alive()).size(), Enemy._ragdolls.size()])
		_frames = 0
		_time = 0.0
		_worst = 0.0
	if _total >= 30.0:
		print("BENCH done")
		set_process(false)
		if not OS.has_feature("web"):
			get_tree().quit()
