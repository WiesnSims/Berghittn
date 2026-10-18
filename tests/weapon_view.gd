extends Node3D
## Frames of every weapon model (M6 part 4b) in a plain studio: each one from the side, and as it is
## held in first person. Windowed:
##     godot res://tests/weapon_view.tscn -- <out dir> [weapon id ...]

const WEAPONS_DIR: String = "res://data/weapons"

var _out: String
var _camera: Camera3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://weapon_view"
	var only: PackedStringArray = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_out)
	_studio()
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		var weapon := load(WEAPONS_DIR.path_join(file.trim_suffix(".remap"))) as WeaponData
		if weapon == null or weapon.viewmodel == null:
			continue
		var id: String = file.get_basename().trim_suffix(".tres")
		if not only.is_empty() and id not in only:
			continue
		await _shoot(id, weapon)
	get_tree().quit()


func _studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.3, 0.32, 0.36)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 50.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var warm := OmniLight3D.new()
	warm.position = Vector3(-1.0, 0.6, 1.0)
	warm.light_color = Color(1.0, 0.75, 0.5)
	warm.light_energy = 0.8
	warm.omni_range = 4.0
	add_child(warm)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.01
	add_child(_camera)
	_camera.current = true


func _shoot(id: String, weapon: WeaponData) -> void:
	var viewmodel: Node3D = weapon.viewmodel.instantiate()
	viewmodel.process_mode = Node.PROCESS_MODE_DISABLED
	var model := viewmodel.get_node("Model") as Node3D
	for node: Node in model.find_children("*", "", true, false):
		if node.name == "MuzzleFlash" or node is Light3D:
			(node as Node3D).visible = false
	# Side: the model alone, centred, its length filling the frame.
	viewmodel.remove_child(model)
	add_child(model)
	model.transform = Transform3D.IDENTITY
	var box: AABB = _bounds(model)
	var centre: Vector3 = box.get_center()
	var size: float = maxf(box.size.length(), 0.05)
	_camera.fov = 40.0
	_camera.look_at_from_position(centre + Vector3(size * 1.25, size * 0.25, 0.0), centre, Vector3.UP)
	await _save(id + "_side")
	_camera.look_at_from_position(centre + Vector3(-size * 0.9, size * 0.45, size * 0.75), centre, Vector3.UP)
	await _save(id + "_angle")
	# Held: back in its viewmodel, under a camera at the origin looking down -Z.
	remove_child(model)
	viewmodel.add_child(model)
	viewmodel.move_child(model, 0)
	add_child(viewmodel)
	viewmodel.transform = Transform3D.IDENTITY
	model.transform = (load(weapon.viewmodel.resource_path) as PackedScene).instantiate().get_node("Model").transform
	_camera.fov = 75.0
	_camera.transform = Transform3D.IDENTITY
	await _save(id + "_held")
	viewmodel.queue_free()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var local: AABB = root.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
