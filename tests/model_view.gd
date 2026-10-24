extends Node3D
## Frames of the enemy models (M6 part 4) in a plain studio: the line-up from the front and the
## back, the faces, every action pose (the Venedigermandl's dig, the Wilderer's aim and shot, the Bergdohle's wings too), and a ragdoll fall. Windowed:
##     godot res://tests/model_view.tscn -- <out dir>

const IDS: Array[String] = ["wanderer", "tourist", "knappe", "perchte", "krampus", "venedigermandl", "wilderer", "bergdohle"]

var _out: String
var _camera: Camera3D
var _rigs: Array[EnemyRig] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://model_view"
	DirAccess.make_dir_recursive_absolute(_out)
	_studio()
	var x: float = -10.5
	for id: String in IDS:
		var data: EnemyData = load("res://data/enemies/%s.tres" % id)
		var rig := data.model.instantiate() as EnemyRig
		add_child(rig)
		rig.position = Vector3(x, 0.0, 0.0)
		_rigs.append(rig)
		x += 3.0
	await _run()
	get_tree().quit()


func _studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.32, 0.34, 0.38)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 30.0)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(30.0, 30.0)
	plane.mesh = mesh
	floor_body.add_child(plane)
	add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.current = true


func _run() -> void:
	_look(Vector3(0.0, 1.6, -11.0), Vector3(0.0, 1.1, 0.0))
	await _settle(0.2)
	await _save("lineup_front")
	_look(Vector3(-2.0, 2.2, 6.5), Vector3(0.0, 1.1, 0.0))
	await _save("lineup_back")
	for i: int in _rigs.size():
		var rig: EnemyRig = _rigs[i]
		var head: Vector3 = rig.head_position()
		_look(head + Vector3(0.5, 0.05, -1.0) * rig.build_scale, head)
		await _save("face_" + IDS[i])
		_look(rig.position + Vector3(2.0, 1.2, -2.2) * rig.build_scale, rig.position + Vector3(0, 0.95, 0) * rig.build_scale)
		await _save("side_" + IDS[i])
	_look(Vector3(-3.0, 1.6, -6.5), Vector3(0.0, 1.0, 0.0))
	for pose: Array in [["walk", EnemyRig.Action.NONE, 2.0, 0.3], ["strike_windup", EnemyRig.Action.STRIKE, 0.0, 0.4],
			["strike_hit", EnemyRig.Action.STRIKE, 0.0, 0.62], ["pull", EnemyRig.Action.PULL, 0.0, 0.3], ["climb", EnemyRig.Action.CLIMB, 0.0, 0.5],
			["crouch", EnemyRig.Action.CROUCH, 0.0, 0.3], ["leap", EnemyRig.Action.LEAP, 0.0, 0.3],
			["dance", EnemyRig.Action.DANCE, 0.0, 0.7], ["dazed", EnemyRig.Action.DAZED, 0.0, 0.6], ["carried", EnemyRig.Action.CARRIED, 0.0, 0.5],
			["dig_up", EnemyRig.Action.DIG, 0.0, 0.5], ["dig_down", EnemyRig.Action.DIG, 0.0, 0.75], ["run", EnemyRig.Action.NONE, 5.5, 0.3],
			["aim", EnemyRig.Action.AIM, 0.0, 0.5], ["shoot", EnemyRig.Action.SHOOT, 0.0, 0.1]]:
		await _pose(pose[0], pose[1], pose[2], pose[3])
	for rig: EnemyRig in _rigs:
		rig.reset()
	await _settle(0.1)
	for i: int in _rigs.size():
		_rigs[i].start_ragdoll(Vector3(0.0, 1.0, 3.0 + i))
	await get_tree().create_timer(0.25).timeout
	await _save("ragdoll_0")
	await get_tree().create_timer(2.5).timeout
	_look(Vector3(-1.0, 3.5, -5.5), Vector3(0.0, 0.2, 2.0))
	await _save("ragdoll_1")
	for rig: EnemyRig in _rigs:
		rig.freeze()
	await get_tree().create_timer(0.3).timeout
	await _save("ragdoll_frozen")


## Holds the action for `at` of its length (walking at `speed`), then takes the frame.
func _pose(name: String, action: EnemyRig.Action, speed: float, at: float) -> void:
	for rig: EnemyRig in _rigs:
		rig.reset()
		if action != EnemyRig.Action.NONE:
			rig.play(action, 1.0)
	var t: float = 0.0
	while t < at:
		var step: float = 1.0 / 60.0
		for rig: EnemyRig in _rigs:
			rig.update(step, speed)
		t += step
	await _save("pose_" + name)


func _look(from: Vector3, at: Vector3) -> void:
	_camera.look_at_from_position(from, at, Vector3.UP)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
