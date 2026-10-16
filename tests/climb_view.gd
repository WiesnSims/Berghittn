extends Node
## Visual check of the window entry. Needs a real window (not --headless):
##   godot res://tests/climb_view.tscn -- <out_dir> [inside|outside|break|reload|melee|hud|shoot]
## Forces the spawn at the west-south window and saves frames while the enemy climbs
## (break: while it tears the boards off; reload/melee: first-person weapon; hud: one frame with the UI;
## shoot: wall shots, body hits and a headshot kill on an enemy in front of the player).

const SPAWN_NAME: String = "WestSouth"
const FRAME_INTERVAL: float = 0.12
const VIEWS: Dictionary = {
	"inside": [Vector3(-8.2, 1.7, 4.9), Vector3(-11.0, 1.0, 3.0)],
	"outside": [Vector3(-14.0, 1.6, 5.3), Vector3(-11.15, 1.0, 3.0)],
	"break": [Vector3(-8.6, 1.6, 4.1), Vector3(-11.15, 1.3, 3.0)],
}

var _out_dir: String
var _frame: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://climb"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "inside", VIEWS["inside"])
	var mode: String = args[1] if args.size() > 1 else "inside"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(960, 540)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	if mode != "hud":
		(main.get_node("UI") as CanvasLayer).hide()
	for marker: Node in get_tree().get_nodes_in_group("spawn_points"):
		if marker.name != SPAWN_NAME:
			marker.remove_from_group("spawn_points")
	get_tree().paused = false
	if mode == "reload":
		await _capture_reload(main.get_node("Player") as Player)
		get_tree().quit()
		return
	if mode == "melee":
		await _capture_melee(main.get_node("Player") as Player)
		get_tree().quit()
		return
	if mode == "shoot":
		await _capture_shoot(main)
		get_tree().quit()
		return
	if mode == "hud":
		await _capture_hud(main)
		get_tree().quit()
		return
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(view[0], view[1])
	camera.current = true
	var wanted: Enemy.State = Enemy.State.BREAKING if mode == "break" else Enemy.State.CLIMBING
	var enemy: Enemy = null
	while enemy == null or enemy._state != wanted:
		await get_tree().physics_frame
		enemy = get_tree().get_first_node_in_group("enemies") as Enemy
	var length: float = enemy.data.board_break_time * Constants.BARRICADE_MAX_BOARDS if mode == "break" else enemy.data.climb_time
	var end: float = Time.get_ticks_msec() / 1000.0 + length + 0.5
	while Time.get_ticks_msec() / 1000.0 < end:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
		await get_tree().create_timer(FRAME_INTERVAL).timeout
	get_tree().quit()


func _capture_reload(player: Player) -> void:
	await get_tree().create_timer(0.5).timeout
	# Empty mag, so the chamber rack is in the capture too.
	player.weapons.mag = 0
	player.weapons.start_reload()
	var end: float = Time.get_ticks_msec() / 1000.0 + player.weapons.weapon.reload_time + player.weapons.weapon.chamber_time + 0.2
	while Time.get_ticks_msec() / 1000.0 < end:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
		await get_tree().create_timer(0.08).timeout


func _capture_melee(player: Player) -> void:
	await get_tree().create_timer(0.5).timeout
	player.weapons._start_melee()
	var end: float = Time.get_ticks_msec() / 1000.0 + 1.0 / player.weapons.melee_weapon.fire_rate + 0.1
	while Time.get_ticks_msec() / 1000.0 < end:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
		await get_tree().create_timer(0.05).timeout


func _capture_hud(main: Node) -> void:
	for screen: String in ["UI/StartScreen", "UI/PauseMenu"]:
		(main.get_node(screen) as Control).hide()
	var player := main.get_node("Player") as Player
	# Face the west-south window from the repair spot, so the boards and the prompt are in view.
	var barricade := main.get_node("World/Stube/WindowWestSouth") as Barricade
	barricade.remove_board()
	barricade.remove_board()
	var spot: Vector3 = barricade.get_interact_position()
	player.global_position = Vector3(spot.x + 0.3, 0.0, spot.z)
	player.look_at(Vector3(barricade.global_position.x, 0.0, barricade.global_position.z), Vector3.UP)
	player.points.add(60)
	player.points.add(10)
	await get_tree().create_timer(5.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hud.png" % _out_dir)


func _capture_shoot(main: Node) -> void:
	var waves := main.get_node("WaveManager") as WaveManager
	waves._break_left = 1.0e6
	var player := main.get_node("Player") as Player
	player.global_position = Vector3(-1, 0, 1)
	player.rotation = Vector3.ZERO
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(waves.wave_table.entries[0].enemy, 1, Transform3D(Basis.IDENTITY, Vector3(-1, 0, -2.5)))
	await get_tree().create_timer(0.3).timeout
	var head := player.get_node("Head") as Node3D
	# Two wall shots off to the side, two body hits, then headshots until it dies.
	var shots: Array = [[0.35, 0.0], [0.3, 0.05], [0.0, 1.0], [0.0, 1.0], [0.0, 1.64], [0.0, 1.64], [0.0, 1.64]]
	for shot: Array in shots:
		var aim: Vector3 = enemy.global_position + Vector3(0, shot[1], 0) if shot[1] > 0.0 else Vector3(-4, 1.4, -5)
		player.look_at(Vector3(aim.x, player.global_position.y, aim.z), Vector3.UP)
		var d: Vector3 = aim - (player.get_node("Head/Camera3D") as Node3D).global_position
		head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		player.weapons._cooldown = 0.0
		player.weapons._fire()
		for i: int in 3:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
			_frame += 1
			await get_tree().create_timer(0.04).timeout
		if not enemy.is_alive():
			break
	for i: int in 6:
		await get_tree().create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
