extends Node
## Frame-time probe for one-off hitches. Needs a real window (not --headless):
##   godot res://tests/hitch_probe.tscn
## Runs moments that happen for the first time in a match (a door bought, the Hüttentruhe's glow, its
## roll, taking a weapon, each special weapon's first shot and secondary, each enemy type turning up) and prints every frame over SLOW_MS and the worst
## frame of each phase.

const SLOW_MS: float = 25.0

var main: Node
var player: Player
var zones: ZoneMap
var waves: WaveManager
var _phase: String = "load"
var _last_usec: int = 0
var _worst: Dictionary = {}


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0:
		var ms: float = (now - _last_usec) / 1000.0
		_worst[_phase] = maxf(_worst.get(_phase, 0.0), ms)
		if ms > SLOW_MS:
			print("SLOW %-14s %6.1f ms" % [_phase, ms])
	_last_usec = now


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout


func _look_at(point: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	player.look_at(Vector3(point.x, player.global_position.y, point.z), Vector3.UP)
	var d: Vector3 = point - cam.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _run() -> void:
	await _seconds(0.5)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	_phase = "idle"
	await _seconds(2.0)

	_phase = "door"
	zones.unlock(&"kueche", player)
	await _seconds(1.5)

	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	player.global_position = chest.get_interact_position() + Vector3(0, -0.6, 0)
	player.velocity = Vector3.ZERO
	_look_at(chest.global_position + Vector3(0, 0.6, 0))
	_phase = "walk_in"
	await _seconds(3.0)

	_phase = "glow_only"
	chest._glow.visible = true
	await _seconds(1.0)
	chest._glow.visible = false
	await _seconds(1.0)

	_phase = "chest_roll"
	player.points.total = 100000
	chest.interact(player)
	await _seconds(chest.pool.roll_time + 0.3)
	_phase = "chest_take"
	chest.interact(player)
	await _seconds(1.5)

	_phase = "chest_roll2"
	chest.interact(player)
	await _seconds(chest.pool.roll_time + 0.3)
	chest.interact(player)
	await _seconds(1.5)

	# Every special weapon's first shot and first secondary (play-test 2026-10-18: the Brennlacke's
	# first squirt stalled).
	for id: String in ["brennkessel", "knoedelwerfer", "rodelkanone", "handboeller", "alphorn", "harmonika"]:
		var gun: WeaponData = load("res://data/weapons/%s.tres" % id)
		player.weapons.give_weapon(gun)
		await _seconds(Constants.WEAPON_SWITCH_TIME + 0.5)
		_phase = "fire_" + id
		player.weapons._fire()
		await _seconds(1.5)
		_phase = "alt_" + id
		if gun.secondary == WeaponData.Secondary.BEHAVIOR:
			player.weapons._cooldown = 0.0
			player.weapons.fire_secondary()
		await _seconds(1.5)

	for file: String in ["wanderer", "tourist", "knappe", "perchte", "krampus"]:
		_phase = "enemy_" + file
		var data: EnemyData = load("res://data/enemies/%s.tres" % file)
		var enemy: Enemy = waves._create_enemy()
		var ahead: Vector3 = player.global_position - player.global_basis.z * 5.0
		enemy.activate(data, 1, Transform3D(Basis.IDENTITY, ahead))
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		await _seconds(1.0)

	_phase = "done"
	for phase: String in _worst:
		print("WORST %-14s %6.1f ms" % [phase, _worst[phase]])
	get_tree().quit()
