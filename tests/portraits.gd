extends Node3D
## The Steckbriefe's pictures (1.2 extras): every enemy from the chest up, on a clear background,
## rendered from its model. Windowed:
##     godot --audio-driver Dummy res://tests/portraits.tscn [-- <out dir>]
## Writes assets/ui/steckbriefe/<id>.png by default.

const OUT: String = "res://assets/ui/steckbriefe"
const SIZE := Vector2i(256, 320)
## More room over the head for a tall headdress (the Tafel, horns).
const ROOMY: Dictionary = {"schoenperchte": 1.35, "krampus": 1.15, "perchte": 1.12}

var _view: SubViewport
var _camera: Camera3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(out)
	_view = SubViewport.new()
	_view.size = SIZE
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.own_world_3d = true
	add_child(_view)
	_studio()
	for id: String in SteckbriefPanel.ENEMIES:
		var data: EnemyData = load("res://data/enemies/%s.tres" % id)
		var rig := data.model.instantiate() as EnemyRig
		_view.add_child(rig)
		# A little turned, standing in its stance as it walks in.
		rig.rotation_degrees.y = 20.0
		for i: int in 20:
			rig.update(1.0 / 60.0, 0.0)
		var head: Vector3 = rig.head_position()
		var size: float = rig.build_scale * (2.4 if data.flies else 1.0) * ROOMY.get(id, 1.0)
		var look: Vector3 = head - Vector3(0.0, 0.22 - 0.3 * (ROOMY.get(id, 1.0) - 1.0), 0.0) * size
		_camera.look_at_from_position(look + Vector3(-0.4, 0.1, -2.0) * size, look)
		for f: int in 4:
			await RenderingServer.frame_post_draw
		_view.get_texture().get_image().save_png(out.path_join(id + ".png"))
		print("portrait ", id)
		rig.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.58, 0.52)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	_view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, 150.0, 0.0)
	key.light_color = Color(1.0, 0.9, 0.75)
	key.light_energy = 1.3
	_view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, -20.0, 0.0)
	rim.light_energy = 0.5
	_view.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_view.add_child(_camera)
	_camera.current = true
