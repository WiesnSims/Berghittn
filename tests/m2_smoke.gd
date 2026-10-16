extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m2_smoke.tscn
## Headless M2 check: navmesh, enemy reaches player through a window, attack, kill by pistol, player death.

var main: Node
var player: Player
var kills: int = 0
var headshots: int = 0
var t: float = 0.0
var player_died: bool = false


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Events.enemy_killed.connect(func(_e: Node3D, head: bool) -> void:
		kills += 1
		if head: headshots += 1)
	_run()


func _wait(seconds: float) -> void:
	var end: float = t + seconds
	while t < end:
		await get_tree().physics_frame
		t += 1.0 / 60.0


func _enemy() -> Enemy:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).is_alive():
			return e
	return null


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	player = main.get_node("Player")
	await _wait(0.2)
	var region := main.get_node("Stube/Navigation") as NavigationRegion3D
	print("NAV polygons: ", region.navigation_mesh.get_polygon_count())
	var start_pos: Vector3 = player.global_position
	print("PLAYER at ", start_pos)
	await _wait(1.0)
	var map: RID = region.get_navigation_map()
	print("map iter ", NavigationServer3D.map_get_iteration_id(map), " regions ", NavigationServer3D.map_get_regions(map).size(), " links ", NavigationServer3D.map_get_links(map).size(), " world map ", map == region.get_world_3d().navigation_map, " region enabled ", region.enabled)
	for q: Vector3 in [Vector3(-11, -0.3, 2.5), Vector3(-7.9, -0.3, 2.5), Vector3(-6.4, 0, 2.5), start_pos]:
		print("closest to %s = %s" % [q, NavigationServer3D.map_get_closest_point(map, q)])
	print("PATH ", NavigationServer3D.map_get_path(map, Vector3(-11, -0.3, 2.5), start_pos, true))
	var verts: PackedVector3Array = region.navigation_mesh.get_vertices()
	var ys: Dictionary = {}
	for v: Vector3 in verts:
		ys[snappedf(v.y, 0.1)] = true
	print("vertex heights ", ys.keys())
	print("region closest ", NavigationServer3D.region_get_closest_point(region.get_rid(), start_pos), " region iter ", NavigationServer3D.region_get_iteration_id(region.get_rid()))
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for v: Vector3 in verts:
		mn = mn.min(v)
		mx = mx.max(v)
	print("bounds ", mn, " .. ", mx, " count ", verts.size())
	# 1) wait for spawn and approach
	var enemy: Enemy = null
	var got_inside: bool = false
	var hp_before: int = player.health.current()
	var log_every: float = 0.0
	while t < 40.0:
		await _wait(0.1)
		player.global_position = start_pos
		enemy = _enemy()
		if enemy == null:
			continue
		var p: Vector3 = enemy.global_position
		if not got_inside and p.x > -7.0 and p.z < 5.0 and p.y > -0.1:
			got_inside = true
			print("ENEMY inside at t=%.1f pos=%s" % [t, p])
		log_every -= 0.1
		if log_every <= 0.0:
			log_every = 2.0
			print("t=%.1f enemy %s state=%d hp=%d" % [t, p, enemy._state, enemy.health])
		if player.health.current() < hp_before:
			print("PLAYER damaged at t=%.1f hp=%d" % [t, player.health.current()])
			break
	if player.health.current() >= hp_before:
		print("FAIL: enemy never damaged the player")
	# 2) shoot it: aim at head
	enemy = _enemy()
	if enemy:
		var shots: int = 0
		while enemy.is_alive() and shots < 30:
			var head: Vector3 = enemy.global_position + Vector3(0, 1.64, 0)
			var cam := player.get_node("Head/Camera3D") as Camera3D
			var flat := Vector3(head.x, player.global_position.y, head.z)
			player.look_at(flat, Vector3.UP)
			var head_node := player.get_node("Head") as Node3D
			var d: Vector3 = head - cam.global_position
			head_node.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
			await get_tree().physics_frame
			player.weapons._cooldown = 0.0
			if player.weapons.mag == 0:
				player.weapons._reload_left = 0.0
				player.weapons.start_reload()
				player.weapons._finish_reload()
			player.weapons._fire()
			shots += 1
			await get_tree().physics_frame
		print("KILLED=%s after %d shots, kills=%d headshots=%d, ammo %d/%d" % [not enemy.is_alive(), shots, kills, headshots, player.weapons.mag, player.weapons.reserve])
	# 3) regen check then die to next enemy
	var hp_now: int = player.health.current()
	await _wait(6.5)
	print("REGEN: hp %d -> %d" % [hp_now, player.health.current()])
	player.died.connect(func() -> void: player_died = true)
	while t < 120.0 and not player_died:
		await _wait(0.1)
		player.global_position = start_pos
	print("PLAYER died=%s at t=%.1f" % [player_died, t])
	await get_tree().create_timer(2.0).timeout
	var ds := main.get_node("UI/DeathScreen") as Control
	print("DEATH SCREEN visible=%s paused=%s" % [ds.visible, get_tree().paused])
	get_tree().quit()
