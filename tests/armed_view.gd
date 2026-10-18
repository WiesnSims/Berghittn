extends Node3D
## Visual check of other players' hikers in a co-op match (M7 part 3): each holds a different gun the
## way the others see it, from the side and at three quarters, one aiming up. Needs a real window:
##   godot res://tests/armed_view.tscn -- <out_dir>

const HIKER := preload("res://scenes/net/hiker.tscn")
const GUNS: Array[String] = ["pistole", "jagdflinte", "repetierer", "alphorn", "knoedelwerfer", "rodelkanone", "brennkessel", "handboeller"]
const SPACING: float = 1.1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://armed_view"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 640)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var hikers: Array[Hiker] = []
	for i: int in GUNS.size():
		var hiker := HIKER.instantiate() as Hiker
		add_child(hiker)
		hiker.position = Vector3((float(i) - float(GUNS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		hiker.apply({"name": GUNS[i], "head": i % HikerStyle.HEADS.size(), "hat": i % HikerStyle.HATS.size(),
				"jacket": i % HikerStyle.JACKETS.size(), "trousers": i % HikerStyle.TROUSERS.size()}, i + 1)
		hiker.arm()
		hiker.hold(load("res://data/weapons/%s.tres" % GUNS[i]) as WeaponData)
		hiker.aim(0.5 if i == 1 else 0.0)
		hiker.rig.pose_now()
		hikers.append(hiker)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 50.0
	# From their right side: the guns point left across the picture.
	for hiker: Hiker in hikers:
		hiker.rotation.y = PI * 0.5
	camera.position = Vector3(0.0, 1.3, 7.0)
	camera.look_at(Vector3(0.0, 1.1, 0.0))
	await _shot(out_dir.path_join("armed_side.png"))
	for hiker: Hiker in hikers:
		hiker.rotation.y = PI * 0.8
	await _shot(out_dir.path_join("armed_front.png"))
	get_tree().quit()


func _shot(path: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
