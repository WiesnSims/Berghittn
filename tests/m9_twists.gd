extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_twists.tscn
## Headless check of the dengelt special weapons' twists (M9 part 4b) on the real main scene: the
## Großglockner-Alphorn rings twice, the Knödelhagel-Werfer's Knödel breaks into three, the
## Pranger-Böller cracks three more times, the Doppelsitzer-Kanone sends two sleds, the
## Musikantenstadl-Harmonika's dancers heal, the Feuerwasser-Kessel's fire jumps, the Donner-Goaßl's
## crack jumps on, the Fladen-Gabel's hurled body leaves a Kuhfladen, the Kaiserschmarrn-Pfanne's
## guard dazes, and the Höllen-Rute's swat sets alight.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var weapons: WeaponHolder
var waves: WaveManager
var failures: Array[String] = []
var _enemies: Array[Enemy] = []


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
		player.health._health = maxf(player.health._health, 1.0)


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func _ground(at: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


## A still enemy with plenty of health, `offset` from the field (-Z is ahead of the player).
func _spawn(offset: Vector3, id: String = "wanderer") -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var at: Vector3 = _ground(FIELD + offset)
	enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.data = enemy.data.duplicate()
	enemy.data.speed = 0.0
	enemy.global_position = at
	enemy.health = 100000
	enemy.max_health = 100000
	enemy._groan_left = 999.0
	_enemies.append(enemy)
	return enemy


func _clear() -> void:
	for enemy: Enemy in _enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy._take_hit(100000000, false, false, null)
	_enemies.clear()
	await _seconds(0.3)


func _hold(id: String) -> void:
	weapons.reset_loadout()
	var data: WeaponData = _weapon(id)
	if data.is_melee:
		weapons.set_melee(data)
	else:
		weapons.give_weapon(data)
	player.global_position = _ground(FIELD)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)


func _count(script_name: String) -> int:
	var count: int = 0
	for node: Node in main.find_children("*", "Node3D", true, false):
		var script := node.get_script() as Script
		if script and script.resource_path.ends_with(script_name):
			count += 1
	return count


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	weapons = player.weapons
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	await _alphorn()
	await _knoedel()
	await _boeller()
	await _rodel()
	await _harmonika()
	await _brennkessel()
	await _goassl()
	await _mistgabel()
	await _pfanne()
	await _rute()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _alphorn() -> void:
	await _hold("alphorn_dengelt")
	var enemy: Enemy = _spawn(Vector3(0, 0, -5))
	await _frames(3)
	weapons._behavior.fire(1)
	await _frames(2)
	var first: int = 100000 - enemy.health
	await _seconds(Constants.TWIST_RING_GAP + 0.1)
	var both: int = 100000 - enemy.health
	_check(first > 0 and both == first * 2, "Großglockner-Alphorn: a second ring hits again (%d, then %d)" % [first, both])
	await _clear()


func _knoedel() -> void:
	await _hold("knoedelwerfer_dengelt")
	var behavior: WeaponBehavior = weapons._behavior
	behavior.call("burst", _ground(FIELD + Vector3(0, 0, -8)), 200, 3.0, 1.0)
	var flying: int = (behavior.get("_knoedel") as Array).filter(func(k: Node3D) -> bool: return k.call("is_busy")).size()
	_check(flying == 3, "Knödelhagel-Werfer: the Knödel bursts into %d" % flying)
	await _seconds(2.0)


func _boeller() -> void:
	await _hold("handboeller_dengelt")
	var before: int = _count("boeller_blast.gd")
	weapons._behavior.call("burst", _ground(FIELD + Vector3(0, 0, -8)), 300, 3.0, 1.0)
	await _seconds(Constants.TWIST_BANG_DELAY + 0.12 * 3 + 0.2)
	var bangs: int = _count("boeller_blast.gd") - before
	_check(bangs >= 4, "Pranger-Böller: the burst and %d small bangs" % (bangs - 1))
	await _seconds(2.0)


func _rodel() -> void:
	await _hold("rodelkanone_dengelt")
	weapons._behavior.fire(1)
	var sleds: int = (weapons._behavior.get("_sleds") as Array).filter(func(s: Node3D) -> bool: return s.call("is_busy")).size()
	_check(sleds == 2, "Doppelsitzer-Kanone: %d sleds side by side" % sleds)
	await _seconds(3.0)


func _harmonika() -> void:
	await _hold("harmonika_dengelt")
	for x: float in [-2.0, 0.0, 2.0]:
		_spawn(Vector3(x, 0, -4))
	await _frames(3)
	player.health._health = 20.0
	weapons._behavior.fire(1)
	var gained: int = player.health.current() - 20
	_check(gained == roundi(3 * weapons.weapon.twist), "Musikantenstadl-Harmonika: three dancers heal %d" % gained)
	await _clear()


func _brennkessel() -> void:
	await _hold("brennkessel_dengelt")
	var lit: Enemy = _spawn(Vector3(0, 0, -4))
	# Beside it, well outside the narrow flame.
	var beside: Enemy = _spawn(Vector3(1.2, 0, -4))
	await _frames(3)
	# A narrow flame aimed at the first one's middle, so only the jump can reach the other.
	var head := player.get_node("Head") as Node3D
	var d: Vector3 = lit.global_position + Vector3.UP * 1.0 - head.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _frames(1)
	var cone: float = weapons.weapon.area_angle
	weapons.weapon.area_angle = 3.0
	weapons._behavior.fire(1)
	weapons.weapon.area_angle = cone
	await _frames(2)
	_check(lit.is_burning() and beside.is_burning(), "Feuerwasser-Kessel: the fire jumps to the one beside (%s, %s)" % [lit.is_burning(), beside.is_burning()])
	await _clear()


func _goassl() -> void:
	await _hold("goassl_dengelt")
	var chain: Array[Enemy] = [_spawn(Vector3(0, 0, -2)), _spawn(Vector3(3, 0, -3)), _spawn(Vector3(6, 0, -4)), _spawn(Vector3(9, 0, -5))]
	var far: Enemy = _spawn(Vector3(-20, 0, -2))
	await _frames(3)
	weapons._melee_behavior.melee_hit()
	var stunned: int = chain.filter(func(e: Enemy) -> bool: return e.is_stunned()).size()
	_check(stunned == 4 and not far.is_stunned(), "Donner-Goaßl: the crack jumps on to %d more" % (stunned - 1))
	await _clear()


func _mistgabel() -> void:
	await _hold("mistgabel_dengelt")
	var enemy: Enemy = _spawn(Vector3(0, 0, -3))
	await _frames(3)
	var before: int = get_tree().get_nodes_in_group(Kuhfladen.GROUP).size()
	weapons._melee_behavior.call("_landed", enemy)
	await _frames(2)
	_check(get_tree().get_nodes_in_group(Kuhfladen.GROUP).size() == before + 1, "Fladen-Gabel: a Kuhfladen where the body lands")
	await _clear()


func _pfanne() -> void:
	await _hold("schmarrnpfanne_dengelt")
	var enemy: Enemy = _spawn(Vector3(0, 0, -1.5))
	await _frames(3)
	weapons._blocking = true
	var caught: bool = weapons.block(enemy)
	weapons._blocking = false
	_check(caught and enemy.is_stunned(), "Kaiserschmarrn-Pfanne: the blocked attacker stands dazed")
	await _clear()


func _rute() -> void:
	await _hold("krampusrute_dengelt")
	var enemy: Enemy = _spawn(Vector3(0, 0, -1.5))
	await _frames(3)
	weapons._melee_behavior.melee_hit()
	_check(enemy.is_burning(), "Höllen-Rute: the struck one burns")
	await _clear()
