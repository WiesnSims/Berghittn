extends Node
## Visual check of the window entry. Needs a real window (not --headless):
##   godot res://tests/climb_view.tscn -- <out_dir> [inside|outside|reload]
## Forces the spawn at the west-south window and saves frames while the enemy climbs.

const SPAWN_NAME: String = "WestSouth"
const FRAME_INTERVAL: float = 0.12
const VIEWS: Dictionary = {
	"inside": [Vector3(-4.2, 1.7, 4.4), Vector3(-7.0, 1.0, 2.5)],
	"outside": [Vector3(-10.0, 1.6, 4.8), Vector3(-7.15, 1.0, 2.5)],
}

var _out_dir: String
var _frame: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://climb"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "inside", VIEWS["inside"])
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(960, 540)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	(main.get_node("UI") as CanvasLayer).hide()
	for marker: Node in get_tree().get_nodes_in_group("spawn_points"):
		if marker.name != SPAWN_NAME:
			marker.remove_from_group("spawn_points")
	get_tree().paused = false
	if args.size() > 1 and args[1] == "reload":
		await _capture_reload(main.get_node("Player") as Player)
		get_tree().quit()
		return
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(view[0], view[1])
	camera.current = true
	var enemy: Enemy = null
	while enemy == null or enemy._state != Enemy.State.CLIMBING:
		await get_tree().physics_frame
		enemy = get_tree().get_first_node_in_group("enemies") as Enemy
	var end: float = Time.get_ticks_msec() / 1000.0 + enemy.data.climb_time + 0.5
	while Time.get_ticks_msec() / 1000.0 < end:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
		await get_tree().create_timer(FRAME_INTERVAL).timeout
	get_tree().quit()


func _capture_reload(player: Player) -> void:
	await get_tree().create_timer(0.5).timeout
	player.weapons.mag = 2
	player.weapons.start_reload()
	var end: float = Time.get_ticks_msec() / 1000.0 + player.weapons.weapon.reload_time + 0.2
	while Time.get_ticks_msec() / 1000.0 < end:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%02d.png" % [_out_dir, _frame])
		_frame += 1
		await get_tree().create_timer(0.08).timeout
