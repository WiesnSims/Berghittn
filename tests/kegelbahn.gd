extends Node
## Run: godot --headless --fixed-fps 60 res://tests/kegelbahn.tscn
## Da Kegelbahn and da Bolingboi (1.2), headless on the real main scene: the lane's rules (pins, a
## Pudel, the same throw giving the same pins), that three good balls can clear all nine, a set
## played from the player's own throw, three balls without clearing (no prize, balls back five waves
## later), clearing (da Bolingboi), the ball bowling over an enemy on the lane; and the Bolingboi:
## its ball rolls along the floor, bowls over what is in its way, explodes at the wall, and Hoch
## damit! sets it off early.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)
const BOLINGBOI: WeaponData = preload("res://data/weapons/bolingboi.tres")

var main: Node
var player: Player
var waves: WaveManager
var lane: Kegelbahn
var failures: Array[String] = []
var banners: Array[String] = []


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


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.health.invincible_left = 9999.0
	lane = get_tree().get_first_node_in_group("kegelbahnen") as Kegelbahn
	Events.event_announced.connect(func(text: String) -> void: banners.append(text))
	_check(lane != null and lane.standing_count() == 9 and lane.balls_of(1) == Constants.KEGEL_BALLS,
		"the Kegelbahn is in the Skiraum: nine pins standing, three balls")
	if lane == null:
		get_tree().quit(1)
		return
	_rules()
	await _from_the_line()
	await _missed_set()
	await _cleared_set()
	await _bowled_over()
	await _bolingboi()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _all_up() -> Array[bool]:
	var up: Array[bool] = []
	for i: int in 9:
		up.append(true)
	return up


func _down(plan: Dictionary) -> int:
	return (plan["falls"] as Array).size()


## A throw from the middle of the line, `degrees` off straight (positive to the right).
func _aimed(degrees: float, x: float = 0.0) -> Array:
	return [Vector3(x, 0.0, Kegelbahn.LINE_Z), Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(degrees))]


## The throw (of a fan from the line) that knocks over the most of `up`.
func _best(up: Array[bool]) -> Array:
	var best: Array = []
	var most: int = -1
	for x: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		for step: int in range(-24, 25):
			var throw: Array = _aimed(step * 0.25, x)
			var count: int = _down(lane.roll(throw[0], throw[1], up))
			if count > most:
				most = count
				best = throw
	return best


func _rules() -> void:
	var straight: Array = _aimed(0.0)
	var plan: Dictionary = lane.roll(straight[0], straight[1], _all_up())
	_check(_down(plan) >= 3 and not plan["gutter"], "straight down the middle: %d pins" % _down(plan))
	_check(_down(lane.roll(straight[0], straight[1], _all_up())) == _down(plan) and str(lane.roll(straight[0], straight[1], _all_up())["falls"]) == str(plan["falls"]),
		"the same throw, the same pins (what co-op relies on)")
	var pudel: Array = _aimed(8.0, 0.4)
	var wide: Dictionary = lane.roll(pudel[0], pudel[1], _all_up())
	_check(wide["gutter"] and _down(wide) == 0, "too far right: a Pudel, nothing falls")
	# Three good balls clear the lot.
	var up: Array[bool] = _all_up()
	var balls: int = 0
	var first: int = 0
	while up.has(true) and balls < 3:
		var throw: Array = _best(up)
		var falls: Array = lane.roll(throw[0], throw[1], up)["falls"]
		if balls == 0:
			first = falls.size()
		for fall: Array in falls:
			up[fall[1]] = false
		balls += 1
	_check(not up.has(true), "three good balls clear all nine (%d balls, the first took %d)" % [balls, first])
	# Alle Neune is possible, but only from a few throws.
	var throws: int = 0
	var neune: int = 0
	var counts: Array[int] = []
	for x: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		for step: int in range(-24, 25):
			var throw: Array = _aimed(step * 0.25, x)
			var count: int = _down(lane.roll(throw[0], throw[1], _all_up()))
			counts.append(count)
			throws += 1
			if count == 9:
				neune += 1
	var average: float = counts.reduce(func(a: int, b: int) -> int: return a + b, 0) / float(throws)
	_check(neune > 0 and neune * 10 < throws, "Alle Neune from %d of %d throws in a fan (on average %.1f pins)" % [neune, throws, average])


func _wait_free() -> void:
	var waited: int = 0
	while not lane.is_free() and waited < 600:
		await _frames(1)
		waited += 1


func _from_the_line() -> void:
	# The player at the line, looking down the lane, presses E.
	player.global_position = lane.to_global(Vector3(0.0, 0.0, 0.2))
	player.look_at(lane.to_global(Vector3(0.0, 0.0, -10.0)) + Vector3.UP * 0.0, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	await _frames(3)
	_check(lane.get_interact_prompt(player) == tr("UI_KEGEL_BOWL") % [1, 3], "at the ball return: \"%s\"" % lane.get_interact_prompt(player))
	lane.interact(player)
	_check(not lane.is_free() and lane.balls_of(1) == 2, "E bowls the first ball")
	_check(lane.get_interact_prompt(player) == tr("UI_KEGEL_BUSY"), "the lane is busy while it rolls")
	await _wait_free()
	_check(lane.standing_count() < 9 and lane.standing_count() > 0, "it knocked some over, %d stand" % lane.standing_count())
	var hidden: int = 0
	for pin: Node3D in lane._pins:
		if not pin.visible:
			hidden += 1
	_check(hidden == 9 - lane.standing_count(), "the knocked pins are cleared away (%d)" % hidden)


func _missed_set() -> void:
	# The rest of this set into the gutter: no prize.
	var pudel: Array = _aimed(8.0, 0.4)
	banners.clear()
	lane.bowl(1, pudel[0], pudel[1])
	await _wait_free()
	lane.bowl(1, pudel[0], pudel[1])
	await _wait_free()
	_check(lane.balls_of(1) == 0 and not player.weapons.has_weapon(BOLINGBOI), "three balls without clearing: no Bolingboi")
	_check(lane.back_in(1) == waves.wave + Constants.KEGEL_BALLS_BACK, "the balls are back in wave %d" % lane.back_in(1))
	_check(banners.has(tr("EVENT_KEGEL_OVER") % lane.standing_count()) or banners.any(func(b: String) -> bool: return b.begins_with("De Kugeln")), "and it says so %s" % [banners])
	_check(not lane.bowl(1, Vector3.ZERO, Vector3.FORWARD), "no ball left to bowl")
	await _wait_free()
	_check(lane.standing_count() == 9, "the pins stand up again")
	var back: int = lane.back_in(1)
	Events.wave_started.emit(back - 1, false)
	_check(lane.balls_of(1) == 0, "not yet in wave %d" % (back - 1))
	Events.wave_started.emit(back, false)
	_check(lane.balls_of(1) == Constants.KEGEL_BALLS, "three balls again in wave %d" % back)


func _cleared_set() -> void:
	banners.clear()
	var cleared: Array = []
	lane.cleared.connect(func(peer: int, first: bool) -> void: cleared.append([peer, first]), CONNECT_ONE_SHOT)
	var balls: int = 0
	while lane.standing_count() > 0 and balls < 3:
		var throw: Array = _best(lane.standing)
		lane.bowl(1, throw[0], throw[1])
		balls += 1
		await _wait_free()
		await _frames(2)
	_check(not cleared.is_empty() and cleared[0][0] == 1, "all nine cleared in %d balls" % balls)
	_check(player.weapons.has_weapon(BOLINGBOI), "da Bolingboi is the prize")
	_check(banners.has(tr("EVENT_KEGEL_PRIZE")) and (banners.has(tr("EVENT_KEGEL_CLEARED")) or banners.has(tr("EVENT_KEGEL_NEUNE"))), "with a banner %s" % [banners])
	_check(lane.balls_of(1) == 0 and lane.back_in(1) > 0, "and the balls are away for five waves")
	await _wait_free()
	Events.wave_started.emit(lane.back_in(1), false)


func _bowled_over() -> void:
	var wanderer: Enemy = waves._take(load("res://data/enemies/wanderer.tres"), Transform3D(Basis.IDENTITY, lane.to_global(Vector3(0.0, 0.0, -4.0))))
	wanderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	wanderer.set_physics_process(false)
	wanderer.health = 10000
	var straight: Array = _aimed(0.0)
	lane.bowl(1, straight[0], straight[1])
	await _wait_free()
	_check(wanderer.health == 10000 - Constants.KEGEL_ENEMY_DAMAGE and wanderer._knock.length() > 1.0,
		"an enemy on the lane is bowled over (%d)" % (10000 - wanderer.health))
	wanderer._despawn()
	wanderer.set_physics_process(true)


## A spot on the pasture, set down on the ground there.
func _ground(offset: Vector3) -> Vector3:
	var at: Vector3 = FIELD + offset
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _wall(offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 3.0, 8.0)
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	body.global_position = _ground(offset) + Vector3.UP * 1.0
	return body


func _enemy(offset: Vector3) -> Enemy:
	var enemy: Enemy = waves._take(load("res://data/enemies/wanderer.tres"), Transform3D(Basis.IDENTITY, _ground(offset)))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.set_physics_process(false)
	enemy.health = 10000
	return enemy


func _right_click() -> void:
	Input.action_press("secondary")
	await _frames(2)
	Input.action_release("secondary")
	await _frames(1)


func _bolingboi() -> void:
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + Vector3(1, 0, 0), Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	holder._select(holder._slot_of(BOLINGBOI))
	await _seconds(1.0)
	_check(holder.weapon == BOLINGBOI and holder.mag == BOLINGBOI.mag_size, "da Bolingboi in hand, %d balls" % holder.mag)
	_check(holder.weapon.secondary == WeaponData.Secondary.BEHAVIOR and holder.weapon.secondary_rounds == 0, "its right click is its own: Hoch damit!, for no ball")
	var in_way: Enemy = _enemy(Vector3(5, 0, 0))
	var beside: Enemy = _enemy(Vector3(9, 0, 3.0))
	var near_wall: Enemy = _enemy(Vector3(11.4, 0, 1.2))
	var wall: StaticBody3D = _wall(Vector3(12.5, 0, 0))
	await _frames(2)
	holder._fire()
	var behavior: Object = holder._behavior
	_check(behavior.call("rolling") == 1 and holder.mag == BOLINGBOI.mag_size - 1, "a ball rolls out of the hand")
	var ball: Node3D = (behavior.get("_balls") as Array)[0]
	await _frames(12)
	_check(absf(ball.global_position.y - _ground(Vector3(ball.global_position.x - FIELD.x, 0, ball.global_position.z - FIELD.z)).y) < 0.1,
		"along the floor (%.2f m up)" % (ball.global_position.y - FIELD.y))
	var waited: int = 0
	while ball.call("is_busy") and waited < 300:
		await _frames(1)
		waited += 1
	_check(10000 - in_way.health == BOLINGBOI.damage, "the enemy in its way is bowled over (%d)" % (10000 - in_way.health))
	_check(ball.global_position.x < wall.global_position.x, "it stops at the wall, not through it")
	_check(10000 - near_wall.health >= BOLINGBOI.secondary_damage / 2, "and explodes there: the one by the wall takes %d" % (10000 - near_wall.health))
	_check(beside.health == 10000, "not one 3 m beside its way and far from the blast")
	wall.queue_free()
	# Hoch damit! (play-test 1.2: right click had to wait out the throw, did nothing during the reload
	# that follows the last ball, and played an animation with nothing rolling). Clicked for real.
	holder.force_aim = true
	var crowd: Array[Enemy] = [_enemy(Vector3(4.5, 0, 1.0)), _enemy(Vector3(4.5, 0, -1.0))]
	var far: Enemy = _enemy(Vector3(16, 0, 0))
	await _seconds(1.2)
	var mag: int = holder.mag
	await _right_click()
	_check(holder.mag == mag and holder._cooldown <= 0.0, "with nothing rolling a right click does nothing")
	holder._fire()
	await _frames(20)
	_check(holder._cooldown > 0.0, "the throw's cooldown is still running")
	mag = holder.mag
	await _right_click()
	_check(behavior.call("rolling") == 0 and holder.mag == mag, "Hoch damit! right after the throw: it goes off at once, for no ball")
	_check(crowd.all(func(e: Enemy) -> bool: return e.health < 10000), "the enemies beside it are caught in the blast")
	_check(far.health == 10000, "the one further on is not")
	# The last ball in the hand: the reload starts by itself while it still rolls.
	await _seconds(1.2)
	holder.mag = 1
	holder._fire()
	await _seconds(1.1)
	_check(holder.is_reloading() and behavior.call("rolling") == 1, "after the last ball the reload starts while it rolls")
	await _right_click()
	_check(behavior.call("rolling") == 0 and holder.is_reloading(), "Hoch damit! still sets it off, and the reload goes on")
	await _seconds(BOLINGBOI.reload_time)
	_check(holder.mag == BOLINGBOI.mag_size, "reloaded: %d balls" % holder.mag)
	holder.force_aim = false
	for e: Enemy in [in_way, beside, near_wall, far] + crowd:
		e.set_physics_process(true)
		if e.is_alive():
			e._despawn()
