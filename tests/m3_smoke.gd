extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m3_smoke.tscn
## Headless M3 check on the real main scene. A bot holds the middle of the Stube and plays to wave 3:
## shoots (head and body), uses the shovel on some enemies, repairs barricades in the break.
## Checks wave sizes, spawn interval, break length, that nobody climbs through a boarded window,
## and that the points shown equal what the bot's own hits, kills and repairs are worth.

const STAND: Vector3 = Vector3(-2.0, 0.0, 3.5)
const ROOM_MIN: Vector3 = Vector3(-10.9, -0.5, -5.9)
const ROOM_MAX: Vector3 = Vector3(6.9, 3.0, 5.9)
const MELEE_REACH: float = 1.7

var main: Node
var player: Player
var waves: WaveManager
var t: float = 0.0
var failures: Array[String] = []
var expected_points: int = 0
var kills_in_wave: Dictionary = {}
var spawn_times: Dictionary = {}
var wave_start_time: Dictionary = {}
var clear_time: Dictionary = {}
var melee_kills: int = 0
var head_kills: int = 0
var body_kills: int = 0
var repairs: int = 0
var climbs_checked: int = 0
var _melee_active: bool = false
var _was_alive: Dictionary = {}
var _was_climbing: Dictionary = {}
# How the bot kills each enemy, handed out in turn: 0 shovel, 1 headshots, 2 body shots.
var _modes: Dictionary = {}


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Events.wave_started.connect(func(w: int, _boss: bool) -> void:
		wave_start_time[w] = t
		print("t=%.1f WAVE %d started (points %d)" % [t, w, player.points.total]))
	Events.wave_cleared.connect(func(w: int) -> void:
		clear_time[w] = t
		print("t=%.1f WAVE %d cleared, kills %d" % [t, w, kills_in_wave.get(w, 0)]))
	Events.enemy_killed.connect(func(_e: Node3D, _h: bool, _m: bool, _s: Node3D) -> void:
		kills_in_wave[waves.wave] = kills_in_wave.get(waves.wave, 0) + 1)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _step() -> void:
	await get_tree().physics_frame
	t += 1.0 / 60.0
	# God mode: this test is about waves and points, M2 already covers dying.
	player.health._health = float(player.health.max_health)
	player.weapons.reserve = 64
	_watch_enemies()


func _watch_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		var id: int = e.get_instance_id()
		var alive: bool = e.is_alive()
		if alive and not _was_alive.get(id, false):
			var list: Array = spawn_times.get(waves.wave, [])
			list.append(t)
			spawn_times[waves.wave] = list
		_was_alive[id] = alive
		var climbing: bool = e._state == Enemy.State.CLIMBING
		if climbing and not _was_climbing.get(id, false):
			climbs_checked += 1
			if e._window != null and e._window.boards > 0:
				_check(false, "enemy climbed through a window with %d boards" % e._window.boards)
		_was_climbing[id] = climbing


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	player.weapons.hit_confirmed.connect(_on_hit_confirmed)
	# Kill streak bonuses (M9 part 2) pay on top.
	player.feedback.streak.connect(func(_text: String, bonus: int) -> void: expected_points += bonus)
	Events.board_repaired.connect(func(_b: Node3D, s: Node3D) -> void:
		if s == player:
			repairs += 1
			expected_points += Constants.POINTS_REPAIR_BOARD)
	player.global_position = STAND
	while t < 400.0 and not wave_start_time.has(3):
		await _step()
		if waves._phase == WaveManager.Phase.BREAK and waves.wave >= 1 and repairs == 0:
			await _repair_all()
		_bot()
	# A little of wave 3, to see it running.
	var until: float = t + 8.0
	while t < until:
		await _step()
		_bot()
	_report()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _bot() -> void:
	player.global_position = STAND
	player.velocity = Vector3.ZERO
	var weapons: WeaponHolder = player.weapons
	if weapons._melee_left > 0.0:
		return
	_melee_active = false
	var target: Enemy = _pick_target()
	if target == null:
		return
	# Every third enemy is left to walk up and gets the shovel instead.
	if not _modes.has(target):
		_modes[target] = _modes.size() % 3
	var wants_melee: bool = _modes[target] == 0
	var distance: float = Vector2(target.global_position.x - STAND.x, target.global_position.z - STAND.z).length()
	var aim_head: bool = _modes[target] == 1
	_aim_at(target.global_position + Vector3(0, 1.64 if aim_head else 1.0, 0))
	if wants_melee:
		if distance <= MELEE_REACH:
			_melee_active = true
			weapons._start_melee()
		return
	if weapons.is_reloading() or weapons._cooldown > 0.0:
		return
	if weapons.mag == 0:
		weapons.start_reload()
		return
	if _sees(target):
		weapons._fire()


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.is_alive():
			continue
		# Wave 1: only enemies inside, so every window gets broken and climbed. Later: anything.
		if waves.wave <= 1 and not _inside(e.global_position):
			continue
		var d: float = e.global_position.distance_squared_to(STAND)
		if d < best_distance:
			best = e
			best_distance = d
	return best


func _inside(p: Vector3) -> bool:
	return p.x > ROOM_MIN.x and p.x < ROOM_MAX.x and p.z > ROOM_MIN.z and p.z < ROOM_MAX.z


func _aim_at(point: Vector3) -> void:
	var cam := player.get_node("Head/Camera3D") as Camera3D
	player.look_at(Vector3(point.x, player.global_position.y, point.z), Vector3.UP)
	var d: Vector3 = point - cam.global_position
	(player.get_node("Head") as Node3D).rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _sees(enemy: Enemy) -> bool:
	var from: Vector3 = player.weapons.global_position
	var to: Vector3 = from - player.weapons.global_basis.z * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, [player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is Hurtbox and (hit.collider as Hurtbox).receiver == enemy


func _on_hit_confirmed(is_headshot: bool, killed: bool) -> void:
	if not killed:
		expected_points += Constants.POINTS_HIT
	elif _melee_active:
		melee_kills += 1
		expected_points += Constants.POINTS_KILL_MELEE
	elif is_headshot:
		head_kills += 1
		expected_points += Constants.POINTS_KILL_HEADSHOT
	else:
		body_kills += 1
		expected_points += Constants.POINTS_KILL_BODY


func _repair_all() -> void:
	# Walk up to every broken window and hold E through the real input path where possible.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var real_input: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("t=%.1f repairing (real input: %s)" % [t, real_input])
	var broken: int = 0
	for node: Node in get_tree().get_nodes_in_group("barricades"):
		var b := node as Barricade
		var before: int = b.boards
		if before >= Constants.BARRICADE_MAX_BOARDS:
			continue
		broken += 1
		var spot: Vector3 = b.get_interact_position()
		player.global_position = Vector3(spot.x, 0.0, spot.z)
		await _step()
		await _step()
		_check(player.interactor._prompt == tr("UI_REPAIR_HINT"), "repair prompt shown at %s" % b.name)
		if real_input:
			Input.action_press("interact")
		var end: float = t + Constants.BARRICADE_REPAIR_INTERVAL * Constants.BARRICADE_MAX_BOARDS + 0.5
		while t < end and b.boards < Constants.BARRICADE_MAX_BOARDS:
			if not real_input and fmod(t, Constants.BARRICADE_REPAIR_INTERVAL) < 1.0 / 60.0:
				player.interactor._use()
			await _step()
			player.global_position = Vector3(spot.x, 0.0, spot.z)
		Input.action_release("interact")
		print("  %s boards %d -> %d" % [b.name, before, b.boards])
		# Four windows take longer than the 10 s break, so the next wave may already be tearing at the last one.
		_check(b.boards > before, "%s repaired (%d -> %d)" % [b.name, before, b.boards])
	_check(broken > 0, "wave 1 broke at least one barricade")
	player.global_position = STAND


func _report() -> void:
	print("--- report at t=%.1f" % t)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.is_alive():
			print("  still alive: %s at %s, state %s, mode %s" % [e.data.id, e.global_position, Enemy.State.keys()[e._state], _modes.get(e, -1)])
	for w: int in [1, 2]:
		var expected: int = waves.wave_table.enemy_count(w, 1)
		_check(kills_in_wave.get(w, 0) == expected, "wave %d had %d kills, formula says %d" % [w, kills_in_wave.get(w, 0), expected])
		var times: Array = spawn_times.get(w, [])
		_check(times.size() == expected, "wave %d spawned %d" % [w, times.size()])
		if times.size() > 1:
			var interval: float = (times[-1] - times[0]) / (times.size() - 1)
			_check(absf(interval - waves.wave_table.spawn_interval(w)) < 0.1, "wave %d spawn interval %.2f (formula %.2f)" % [w, interval, waves.wave_table.spawn_interval(w)])
		if clear_time.has(w) and wave_start_time.has(w + 1):
			var gap: float = wave_start_time[w + 1] - clear_time[w]
			_check(absf(gap - waves.wave_table.break_time) < 0.1, "break after wave %d lasted %.2f s" % [w, gap])
	_check(waves.wave == 3, "reached wave 3")
	_check(climbs_checked > 0, "%d window climbs checked against boards" % climbs_checked)
	_check(melee_kills > 0 and head_kills > 0 and body_kills > 0, "kills: %d melee, %d head, %d body" % [melee_kills, head_kills, body_kills])
	_check(repairs > 0, "%d boards repaired" % repairs)
	_check(player.points.total == expected_points, "points %d, expected %d" % [player.points.total, expected_points])
	var hud_points: String = (main.get_node("UI/Hud/PointsLabel") as Label).text
	_check(hud_points == str(player.points.total), "HUD shows %s" % hud_points)
	var hud_wave: String = (main.get_node("UI/Hud/WaveLabel") as Label).text
	_check(hud_wave == tr("UI_WAVE") % 3, "HUD wave label '%s'" % hud_wave)
	print("RESULT: %s" % ("ALL PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
