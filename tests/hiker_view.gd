extends Node3D
## Visual check of the player hiker (M7): every head and hat in a row, each in other colours, from the
## front and the back, then a close-up of each stuffed hat (M8) from the front and from behind. Needs a
## real window (not --headless):
##   godot res://tests/hiker_view.tscn -- <out_dir>

const HIKER := preload("res://scenes/net/hiker.tscn")
const SPACING: float = 0.75
const STUFFED_FROM: int = 3


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://hiker_view"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 640)
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
	var count: int = maxi(HikerStyle.HEADS.size(), HikerStyle.HATS.size())
	var hikers: Array[Hiker] = []
	for i: int in count:
		var hiker := HIKER.instantiate() as Hiker
		add_child(hiker)
		hiker.position = Vector3((float(i) - float(count - 1) * 0.5) * SPACING, 0.0, 0.0)
		# The model faces -Z; turn it to the camera.
		hiker.rotation.y = PI
		hiker.apply({"name": "Hiker %d" % i, "head": i % HikerStyle.HEADS.size(), "hat": i % HikerStyle.HATS.size(),
				"jacket": i % HikerStyle.JACKETS.size(), "trousers": i % HikerStyle.TROUSERS.size()}, i + 1)
		hikers.append(hiker)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.35, 3.6)
	camera.look_at(Vector3(0.0, 1.05, 0.0))
	camera.fov = 50.0
	await _shot(out_dir.path_join("hiker_front.png"))
	camera.position = Vector3(0.0, 1.75, 1.3)
	camera.look_at(Vector3(0.0, 1.62, 0.0))
	await _shot(out_dir.path_join("hiker_heads.png"))
	for hiker: Hiker in hikers:
		hiker.rotation.y = 0.0
	camera.position = Vector3(0.0, 1.35, 3.6)
	camera.look_at(Vector3(0.0, 1.05, 0.0))
	await _shot(out_dir.path_join("hiker_back.png"))
	for hiker: Hiker in hikers:
		hiker.rotation.y = PI * 0.5
	await _shot(out_dir.path_join("hiker_side.png"))
	# The stuffed hats one by one on the middle hiker, the others hidden.
	var model: Hiker = hikers[0]
	for hiker: Hiker in hikers:
		hiker.visible = hiker == model
	model.position = Vector3.ZERO
	model.show_name(false)
	for hat: int in range(STUFFED_FROM, HikerStyle.HATS.size()):
		model.apply({"name": tr(HikerStyle.HATS[hat]), "head": hat % HikerStyle.HEADS.size(), "hat": hat,
				"jacket": hat % HikerStyle.JACKETS.size(), "trousers": 0}, 1)
		for view: Array in [["front", PI + 0.6], ["back", -0.7]]:
			model.rotation.y = view[1]
			camera.position = Vector3(0.0, 1.86, 0.95)
			camera.look_at(Vector3(0.0, 1.76, 0.0))
			await _shot(out_dir.path_join("hat_%d_%s.png" % [hat, view[0]]))
	get_tree().quit()


func _shot(path: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
