extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_events.tscn
## Section 8a events on the real main scene. Die Resi: only with the Terrasse open, walks down into the
## beer garden, is marked map-wide, her bell pulls outside enemies to her (they make her bolt), and
## milking her heals fully and gives a free Brettljause helping.

var main: Node
var player: Player
var zones: ZoneMap
var waves: WaveManager
var director: EventDirector
var hud: Hud
var failures: Array[String] = []
var _banners: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Events.event_announced.connect(func(text: String) -> void: _banners.append(text))
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
	await _frames(5)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	waves = main.get_node("WaveManager")
	director = main.get_node("EventDirector")
	hud = main.get_node("UI/Hud")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	await _schedule()
	for zone: ZoneData in zones.table.zones:
		zones.unlock(zone.id, null)
	await _frames(30)
	await _resi_walks_in()
	await _resi_lures()
	await _resi_milked()
	await _resi_leaves()
	print("RESULT: ", "PASS" if failures.is_empty() else "%d FAILED" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _schedule() -> void:
	director._on_wave_started(3, false)
	_check(director._next_resi == 3, "no Resi while the Terrasse is shut (she waits)")
	zones.unlock(&"terrasse", null)
	director._on_wave_started(3, false)
	_check(director._next_resi >= 6 and director._next_resi <= 8, "with the Terrasse open she comes at wave 3, next at %d" % director._next_resi)
	# The timer would send her in RESI_DELAY s; the tests send her themselves.
	await _frames(1)


func _resi_walks_in() -> void:
	var resi: Resi = director.send_resi()
	_check(resi != null and _banners.back() == "Die Resi hat si verlaufen!", "announced: %s" % [_banners.back() if not _banners.is_empty() else "-"])
	_check(get_tree().get_nodes_in_group("map_markers").size() == 1, "marked on the map (light column, label, edge arrow)")
	var grazed: bool = false
	for i: int in 60 * 30:
		await get_tree().physics_frame
		if resi._state == Resi.State.GRAZING:
			grazed = true
			break
	var p: Vector3 = resi.global_position
	_check(grazed and p.y < -1.2 and p.x > -11.0 and p.x < 7.0 and p.z > 11.3 and p.z < 18.0, "she walks down into the beer garden (%s)" % p.snapped(Vector3.ONE * 0.1))
	resi.queue_free()
	await _frames(2)


func _resi_lures() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(12.0)
	# An enemy outside, by the hut's west side: without the bell it would go for a window.
	var enemy := waves._create_enemy()
	var at := Vector3(-14.0, -0.3, 8.0)
	enemy.activate(load("res://data/enemies/tourist.tres"), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	var start: float = enemy.global_position.distance_to(resi.global_position)
	var bolted: bool = false
	for i: int in 60 * 20:
		await get_tree().physics_frame
		if not is_instance_valid(resi) or resi._state == Resi.State.BOLTING:
			bolted = true
			break
	_check(start <= Constants.RESI_LURE_RADIUS and bolted, "her bell pulls an outside enemy (%.0f m off) to her, and she bolts" % start)
	_check(_banners.back() == "Die Resi is davon!", "announced: %s" % _banners.back())
	_check(get_tree().get_nodes_in_group("map_markers").is_empty(), "the marker goes with her")
	await _frames(2)
	_check(enemy._find_lure() == null, "the enemy is back after the players")
	enemy.receive_hit(100000, false, false, null)
	if is_instance_valid(resi):
		resi.queue_free()
	await _seconds(0.5)


func _resi_milked() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(14.0)
	var speck: JauseData = load("res://data/jause/speck.tres")
	var germ: JauseData = load("res://data/jause/germknedl.tres")
	var kas: JauseData = load("res://data/jause/kasnockn.tres")
	var before: int = player.perks.jause_level(speck) + player.perks.jause_level(germ) + player.perks.jause_level(kas)
	player.health._health = 20.0
	var side: Vector3 = resi.global_basis.x
	player.global_position = resi.global_position + side * 1.1 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _frames(3)
	_check(resi.get_interact_prompt(player) == tr("UI_MILK"), "prompt: %s" % resi.get_interact_prompt(player))
	var pulls: int = 0
	while resi.is_milkable() and pulls < 40:
		player.global_position = resi.global_position + side * 1.1
		resi.interact(player)
		pulls += 1
		await _seconds(resi.interact_repeat)
	var after: int = player.perks.jause_level(speck) + player.perks.jause_level(germ) + player.perks.jause_level(kas)
	_check(resi._state == Resi.State.MILKED and pulls == roundi(Constants.RESI_MILK_TIME / resi.interact_repeat), "milked in %d pulls (%.1f s)" % [pulls, pulls * resi.interact_repeat])
	_check(player.health.current() == player.health.max_health and after == before + 1, "fully healed (%d) and a free helping (%d -> %d): %s" % [player.health.current(), before, after, _banners.back()])
	_check(resi.get_interact_prompt(player) == "", "only once")
	await _seconds(20.0)
	_check(not is_instance_valid(resi), "then she goes home")


func _resi_leaves() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(2.0)
	resi._stay_left = 0.1
	var halfway: float = 0.0
	await _seconds(30.0)
	_check(not is_instance_valid(resi), "after %.0f s she leaves on her own" % Constants.RESI_STAY_TIME)
	# A milk pull that stops counts for nothing.
	resi = director.send_resi()
	await _seconds(14.0)
	resi.interact(player)
	halfway = resi._milk
	await _seconds(0.5)
	_check(halfway > 0.0 and resi._milk == 0.0, "letting go of E spills the milk")
	resi.queue_free()
