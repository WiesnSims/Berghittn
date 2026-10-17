extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_waves.tscn
## M5 acceptance "wave 10 reachable": the real wave manager runs waves 1 to 10 (boss waves 5 and 10
## included) against an immortal bot in the Stube that kills whatever reaches it. Every enemy type must
## show up and find its way in; an enemy that never arrives counts as stuck.

const STAND: Vector3 = Vector3(-2.0, 0.0, 3.5)
const REACH: float = 7.0
# An enemy alive this long has not found the way in.
const STUCK_AFTER: float = 75.0
const TIME_LIMIT: float = 1800.0

var main: Node
var player: Player
var waves: WaveManager
var t: float = 0.0
var failures: Array[String] = []
var _born: Dictionary = {}
var _types: Dictionary = {}
var _stuck: Array[String] = []
var _cleared: Array[int] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Events.wave_cleared.connect(func(w: int) -> void:
		_cleared.append(w)
		print("t=%.0f wave %d cleared" % [t, w]))
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	while t < TIME_LIMIT and not _cleared.has(10):
		await get_tree().physics_frame
		t += 1.0 / 60.0
		player.global_position = STAND
		player.velocity = Vector3.ZERO
		player.health._health = float(player.health.max_health)
		_bot()
	print("--- t=%.0f, reached wave %d" % [t, waves.wave])
	_check(_cleared.has(10), "waves 1 to 10 cleared (last cleared %s)" % [_cleared.back() if not _cleared.is_empty() else 0])
	for id: StringName in [&"wanderer", &"tourist", &"knappe", &"perchte", &"krampus"]:
		_check(_types.get(id, 0) > 0, "%s came in (%d)" % [id, _types.get(id, 0)])
	_check(_stuck.size() <= 1, "%d stuck: %s" % [_stuck.size(), _stuck])
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _bot() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.is_alive():
			_born.erase(e.get_instance_id())
			continue
		var id: int = e.get_instance_id()
		if not _born.has(id):
			_born[id] = t
		if e.global_position.distance_to(STAND) <= REACH:
			_types[e.data.id] = _types.get(e.data.id, 0) + 1
			e.receive_hit(100000, true, false, player)
		elif t - _born[id] > STUCK_AFTER:
			_stuck.append("%s at %s (%s)" % [e.data.id, e.global_position.snapped(Vector3.ONE * 0.1), Enemy.State.keys()[e._state]])
			e.receive_hit(100000, false, false, null)
