extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_kuhglocke.tscn
## Headless check of the Kuhglocke (section 6a) on the real main scene: the Stube wall-buy (300 for a
## full slot of two, the swap warning over an Eisstock), the throw (lands and rings), the lure (every
## enemy within 20 m walks to it and leaves the player be, also one that came in through a window; one
## further out and the Krampus do not), and the end after 10 s.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var bell: EquipmentData
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _spawn(data: EnemyData, at: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(data, 1, Transform3D(Basis.IDENTITY, at))
	# The wave manager is switched off in this test; its enemies must not inherit that.
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.health = 100000
	return enemy


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	bell = load("res://data/equipment/kuhglocke.tres")
	await _frames(10)

	await _buy()
	await _lure()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _buy() -> void:
	var buys: Array = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.equipment == bell)
	_check(buys.size() == 1 and (main.get_node("World/Stube") as Node3D).is_ancestor_of(buys[0]), "one Kuhglocke wall-buy, in the Stube")
	if buys.is_empty():
		return
	var buy: WallBuy = buys[0]
	player.global_position = buy.get_interact_position()
	player.velocity = Vector3.ZERO
	var at: Vector3 = buy.global_position
	player.look_at(Vector3(at.x, player.global_position.y, at.z), Vector3.UP)
	await _frames(3)
	player.points.add(2000)
	# Holding the Eisstock: the prompt says it would be given up.
	player.equipment.give(load("res://data/equipment/eisstock.tres"), 2)
	_check(player.interactor._find_target() == buy and buy.get_interact_prompt(player).contains("Eisstock") and buy.get_interact_prompt(player).contains("300"), "in reach, warns about the Eisstock: %s" % buy.get_interact_prompt(player))
	var before: int = player.points.total
	buy.interact(player)
	_check(player.equipment.item == bell and player.equipment.count == 2 and player.points.total == before - 300, "300 for two Kuhglocken")
	_check(buy.get_interact_prompt(player) == "", "nothing to buy with the slot full")
	player.equipment.count = 1
	_check(buy.get_interact_prompt(player).contains("300"), "one thrown: the wall-buy fills it up again (%s)" % buy.get_interact_prompt(player))
	buy.interact(player)
	_check(player.equipment.count == 2, "back to two")


func _lure() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var krampus: EnemyData = load("res://data/enemies/krampus.tres")
	player.global_position = FIELD
	player.look_at(FIELD + Vector3(1, 0, 0), Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-10.0)
	await _frames(2)
	_check(player.equipment.throw(), "thrown")
	var thrown: Array = main.find_children("*", "Kuhglocke", true, false)
	_check(thrown.size() == 1, "one Kuhglocke in the world")
	if thrown.is_empty():
		return
	var glocke: Kuhglocke = thrown[0]
	await _seconds(2.0)
	_check(glocke.is_ringing(), "it lies %.1f m away and rings" % Vector2(glocke.global_position.x - FIELD.x, glocke.global_position.z - FIELD.z).length())
	var spot: Vector3 = glocke.global_position
	# Right next to the player but within reach of the bell; one that came in through a window; the
	# Krampus; one beyond 20 m.
	var near := _spawn(wanderer, FIELD + Vector3(-1.5, 0, 1.5))
	var inside := _spawn(wanderer, FIELD + Vector3(0, 0, -3.0))
	inside._inside = true
	var boss := _spawn(krampus, FIELD + Vector3(-3.0, 0, 3.0))
	var far := _spawn(wanderer, Vector3(spot.x - 23.0, FIELD.y, FIELD.z))
	var boss_start: float = _flat_distance(boss, FIELD)
	await _seconds(0.5)
	_check(far._lure == null, "one %.0f m from the bell keeps after the player" % _flat_distance(far, spot))
	await _seconds(0.5)
	# Taken off before it can strike: a Krampus hit would end the test run.
	_check(boss._lure == null and _flat_distance(boss, FIELD) < boss_start - 1.0, "the Krampus does not fall for it (%.1f m -> %.1f m from the player)" % [boss_start, _flat_distance(boss, FIELD)])
	boss.receive_hit(1000000, false, false, null)
	await _seconds(4.0)
	_check(_flat_distance(near, spot) < 2.5 and _flat_distance(inside, spot) < 2.5, "the wanderers walk off to the bell and stand round it (%.1f m, %.1f m)" % [_flat_distance(near, spot), _flat_distance(inside, spot)])
	far.receive_hit(1000000, false, false, null)
	var health: int = player.health.current()
	await _seconds(2.0)
	_check(player.health.current() == health, "the lured ones leave the player alone")
	for i: int in 240:
		if not glocke.is_ringing():
			break
		await _frames(1)
	await _frames(2)
	_check(not glocke.is_ringing() and near._lure == null, "after %.0f s it goes quiet and they come for the player again" % Constants.KUHGLOCKE_RING_TIME)
	await _seconds(1.0)
	_check(not is_instance_valid(glocke), "and the bell is gone")
	near.receive_hit(1000000, false, false, null)
	inside.receive_hit(1000000, false, false, null)


func _flat_distance(enemy: Node3D, to: Vector3) -> float:
	return Vector2(enemy.global_position.x - to.x, enemy.global_position.z - to.z).length()
