extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_kuhfladen.tscn
## Headless check of the Kuhfladen-Mine (section 6a) on the real main scene: the Schuppen wall-buy (250
## for three), placing one on the floor a step ahead, an enemy walking through it (40 damage and slowed,
## once), the Krampus (hurt but not slowed), trodden flat after four, and at most six lying about.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)
# Either side of the door between the Terrasse and the Schuppen (west wall at x 7.15, z 10.3).
const DOOR_INSIDE: Vector3 = Vector3(8.6, 0.0, 10.3)
const DOOR_OUTSIDE: Vector3 = Vector3(4.0, 0.0, 10.3)

var main: Node
var player: Player
var waves: WaveManager
var pat: EquipmentData
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


func _placed() -> Array[Node]:
	return get_tree().get_nodes_in_group(Kuhfladen.GROUP)


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Zones") as ZoneMap).unlock(&"terrasse", player)
	(main.get_node("Zones") as ZoneMap).unlock(&"schuppen", player)
	pat = load("res://data/equipment/kuhfladen.tres")
	await _frames(10)

	await _buy()
	await _place_and_catch()
	await _limit()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _buy() -> void:
	var buys: Array = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.equipment == pat)
	_check(buys.size() == 1 and (main.get_node("World/Schuppen") as Node3D).is_ancestor_of(buys[0]), "one Kuhfladen wall-buy, in the Schuppen")
	if buys.is_empty():
		return
	var buy: WallBuy = buys[0]
	player.global_position = buy.get_interact_position()
	player.velocity = Vector3.ZERO
	var at: Vector3 = buy.global_position
	player.look_at(Vector3(at.x, player.global_position.y, at.z), Vector3.UP)
	await _frames(3)
	player.points.add(2000)
	_check(player.interactor._find_target() == buy and buy.get_interact_prompt(player).contains("250"), "in reach: %s" % buy.get_interact_prompt(player))
	var before: int = player.points.total
	buy.interact(player)
	_check(player.equipment.item == pat and player.equipment.count == 3 and player.points.total == before - 250, "250 for three Kuhfladen")


func _place_and_catch() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var krampus: EnemyData = load("res://data/enemies/krampus.tres")
	# Where a player would put one: in the Schuppen's doorway to the Terrasse, from inside.
	player.global_position = DOOR_INSIDE
	player.look_at(DOOR_INSIDE + Vector3(-1, 0, 0), Vector3.UP)
	await _frames(2)
	_check(player.equipment.throw() and player.equipment.count == 2, "placed one, two left")
	await _frames(2)
	var placed: Array[Node] = _placed()
	_check(placed.size() == 1, "one Kuhfladen on the ground")
	if placed.is_empty():
		return
	var mine: Kuhfladen = placed[0]
	var ahead: float = DOOR_INSIDE.x - mine.global_position.x
	_check(ahead > 0.8 and ahead < 2.0 and absf(mine.global_position.y - DOOR_INSIDE.y) < 0.3, "a step ahead on the floor, in the doorway (%.1f m ahead, at x %.1f)" % [ahead, mine.global_position.x])
	# The player backs into the shed; a wanderer comes in from the Terrasse through the door.
	player.global_position = DOOR_INSIDE + Vector3(5.0, 0.0, 3.0)
	var walker := _spawn(wanderer, DOOR_OUTSIDE)
	var health: int = walker.health
	for i: int in 240:
		if mine.catches() > 0:
			break
		await _frames(1)
	_check(walker.health == health - Constants.KUHFLADEN_DAMAGE and is_equal_approx(walker._slow_factor, Constants.KUHFLADEN_SLOW_FACTOR), "a wanderer steps in: %d damage, slowed to %.0f %%" % [health - walker.health, walker._slow_factor * 100.0])
	await _seconds(1.0)
	_check(walker.health == health - Constants.KUHFLADEN_DAMAGE and mine.catches() == 1, "only once, however long it stands in it")
	walker.receive_hit(1000000, false, false, null)
	var boss := _spawn(krampus, DOOR_OUTSIDE)
	health = boss.health
	for i: int in 240:
		if mine.catches() > 1:
			break
		await _frames(1)
	_check(boss.health == health - Constants.KUHFLADEN_DAMAGE and is_equal_approx(boss._slow_factor, 1.0), "the Krampus is hurt but not slowed (bosses shrug off slows)")
	boss.receive_hit(1000000, false, false, null)
	# Two more trample it flat.
	for i: int in 2:
		var more := _spawn(wanderer, mine.global_position + Vector3(0.2 * i, 0.0, 0.0))
		await _frames(3)
		more.receive_hit(1000000, false, false, null)
	await _seconds(1.0)
	_check(not is_instance_valid(mine), "trodden flat after %d" % Constants.KUHFLADEN_CATCHES)
	await _seconds(Constants.ENEMY_CORPSE_TIME)


func _limit() -> void:
	player.global_position = FIELD
	player.equipment.give(pat, 3)
	for i: int in Constants.KUHFLADEN_MAX_ACTIVE + 1:
		if player.equipment.count == 0:
			player.equipment.give(pat, 3)
		player.equipment._cooldown = 0.0
		player.global_position = FIELD + Vector3(0.0, 0.0, 2.0 * i)
		player.equipment.throw()
		await _frames(2)
	await _frames(2)
	_check(_placed().size() == Constants.KUHFLADEN_MAX_ACTIVE, "%d placed, %d lie about (the oldest went)" % [Constants.KUHFLADEN_MAX_ACTIVE + 1, _placed().size()])
