extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_pfanne.tscn
## Headless check of the Schmarrnpfanne (section 6/6a) on the real main scene: the Küche wall-buy
## (400, replaces the shovel in the melee slot), the blow (90 and a small shove), and the guard on a
## held V: hits from the front are caught and the attacker bonked back, hits from behind are not,
## walking slows down, and a real enemy's swings do nothing against it.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var pan: WeaponData
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
	enemy.activate(data, 1, Transform3D(Basis.IDENTITY, at).looking_at(player.global_position, Vector3.UP))
	# The wave manager is switched off in this test; its enemies must not inherit that.
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	return enemy


func _look_flat(direction: Vector3) -> void:
	player.look_at(player.global_position + direction, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Zones") as ZoneMap).unlock(&"kueche", player)
	pan = load("res://data/weapons/schmarrnpfanne.tres")
	await _frames(10)

	await _buy()
	await _blow()
	await _guard()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _buy() -> void:
	var buys: Array = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.weapon == pan)
	_check(buys.size() == 1, "one Schmarrnpfanne wall-buy")
	if buys.is_empty():
		return
	var buy: WallBuy = buys[0]
	_check((main.get_node("World/Kueche") as Node3D).is_ancestor_of(buy), "it hangs in the Küche")
	player.global_position = buy.get_interact_position()
	player.velocity = Vector3.ZERO
	var at: Vector3 = buy.global_position
	player.look_at(Vector3(at.x, player.global_position.y, at.z), Vector3.UP)
	await _frames(3)
	player.points.add(1000)
	_check(player.interactor._find_target() == buy and buy.get_interact_prompt(player).contains("400"), "wall-buy in reach: %s" % buy.get_interact_prompt(player))
	var before: int = player.points.total
	var guns: int = player.weapons.gun_count()
	buy.interact(player)
	_check(player.weapons.melee_weapon == pan and player.points.total == before - 400 and player.weapons.gun_count() == guns, "bought for 400; the pan replaces the shovel, guns untouched")
	_check(buy.get_interact_prompt(player) == "", "nothing more to buy once carried")


func _blow() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = FIELD
	_look_flat(Vector3(1, 0, 0))
	var enemy: Enemy = _spawn(wanderer, FIELD + Vector3(1.4, 0, 0))
	enemy.health = 1000
	enemy.set_physics_process(false)
	await _frames(3)
	player.weapons._start_melee()
	await _seconds(1.0 / pan.fire_rate * Constants.MELEE_HIT_FRACTION + 0.05)
	_check(enemy.health == 1000 - pan.damage, "one blow takes %d (%d left)" % [pan.damage, enemy.health])
	_check(not player.weapons.is_blocking(), "a tap of V does not raise the guard")
	enemy.set_physics_process(true)
	await _seconds(0.3)
	var shoved: float = enemy.global_position.x - (FIELD.x + 1.4)
	_check(shoved > 0.15, "the blow shoves it back a little (%.2f m)" % shoved)
	await _seconds(1.0)
	enemy.receive_hit(100000, false, false, null)


func _guard() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = FIELD
	_look_flat(Vector3(1, 0, 0))
	await _frames(2)
	holder.force_melee_hold = true
	holder._start_melee()
	await _seconds(0.5)
	_check(holder.is_blocking(), "holding V past the blow raises the guard")
	_check(not holder._viewmodel.visible, "the gun stays down behind the guard")
	_check(is_equal_approx(player._base_speed(Vector2(0, -1)), Constants.PLAYER_WALK_SPEED * pan.aim_move_multiplier), "walking slows to %.0f %% behind the guard" % (pan.aim_move_multiplier * 100))
	var front: Enemy = _spawn(wanderer, FIELD + Vector3(1.2, 0, 0))
	var back: Enemy = _spawn(wanderer, FIELD + Vector3(-1.2, 0, 0))
	front.set_physics_process(false)
	back.set_physics_process(false)
	var health: int = player.health.current()
	player.take_damage(20, front)
	_check(player.health.current() == health, "a hit from the front is caught on the pan")
	front.set_physics_process(true)
	await _seconds(0.3)
	_check(front.global_position.x > FIELD.x + 1.5, "and the attacker is bonked back (%.2f m)" % (front.global_position.x - FIELD.x - 1.2))
	player.take_damage(20, back)
	_check(player.health.current() == health - 20, "a hit from behind gets through")
	player.health.heal_full()
	# A real enemy swinging at the guard for a while.
	front.receive_hit(100000, false, false, null)
	back.receive_hit(100000, false, false, null)
	var attacker: Enemy = _spawn(wanderer, FIELD + Vector3(1.0, 0, 0))
	attacker.health = 100000
	# Bonked back, it comes round the side again: the player keeps turning to face it, as one would.
	for i: int in 180:
		_look_flat(Vector3(attacker.global_position.x - player.global_position.x, 0.0, attacker.global_position.z - player.global_position.z))
		await _frames(1)
	_check(player.health.current() == player.health.max_health, "a wanderer hammering at the guard for 3 s does no harm while faced (%d hp)" % player.health.current())
	holder.force_melee_hold = false
	await _frames(2)
	_check(not holder.is_blocking(), "letting go of V lowers the guard")
	await _seconds(0.6)
	var hp: int = player.health.current()
	await _seconds(2.0)
	_check(player.health.current() < hp, "without the guard the wanderer hurts again (%d -> %d)" % [hp, player.health.current()])
	attacker.receive_hit(100000, false, false, null)
