extends Node
## Pictures of the real map from given spots, for checking where props sit. Windowed:
##     godot res://tests/room_view.tscn -- <out dir> <x,y,z:tx,ty,tz> [...]
## Each shot is saved as <out dir>/view_<n>.jpg. A shot ending in "!" first hangs every hat on the
## Huatständer (1.2), to see it full. "gun=<id>" (before the shots) holds that gun's viewmodel in front
## of the camera, as the player sees it in hand.

var _main: Node


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://room_view"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1600, 900)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().process_frame
	(_main.get_node("UI") as CanvasLayer).hide()
	(_main.get_node("EventDirector") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(_main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var player := _main.get_node("Player") as Player
	player.weapons.visible = false
	get_tree().paused = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	add_child(camera)
	for i: int in range(1, args.size()):
		var spec: String = args[i]
		if spec.begins_with("gun="):
			var gun := load("res://data/weapons/%s.tres" % spec.trim_prefix("gun=")) as WeaponData
			camera.fov = 75.0
			camera.add_child(gun.viewmodel.instantiate())
			continue
		if spec.ends_with("!"):
			spec = spec.trim_suffix("!")
			var rack := get_tree().get_first_node_in_group("hat_rack")
			if rack:
				rack.call("hang_all")
		var parts: PackedStringArray = spec.split(":")
		var from: PackedFloat64Array = parts[0].split_floats(",")
		var to: PackedFloat64Array = parts[1].split_floats(",")
		camera.look_at_from_position(Vector3(from[0], from[1], from[2]), Vector3(to[0], to[1], to[2]))
		camera.current = true
		for f: int in 40:
			await get_tree().process_frame
		for f: int in 3:
			await RenderingServer.frame_post_draw
		var path: String = "%s/view_%d.jpg" % [out, i]
		get_viewport().get_texture().get_image().save_jpg(path, 0.88)
		print("saved ", path)
	get_tree().quit()
