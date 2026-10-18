extends Node3D
## Frames of the prop models (M6 part 4c) in a plain studio, each from the front and at an angle.
## Their scripts are switched off. Windowed:
##     godot res://tests/prop_view.tscn -- <out dir>

const SCENES: Array[String] = [
	"res://scenes/zones/huettentruhe.tscn", "res://scenes/zones/schnaps_shrine.tscn",
	"res://scenes/zones/ammo_crate.tscn", "res://scenes/zones/brettljause.tscn",
	"res://scenes/props/table_set.tscn", "res://scenes/zones/door.tscn", "res://scenes/zones/window.tscn",
	"res://scenes/equipment/eisstock.tscn", "res://scenes/equipment/kuhfladen.tscn",
	"res://scenes/equipment/kuhglocke.tscn", "res://scenes/events/bierfassl.tscn",
	"res://scenes/events/resi_model.tscn", "res://scenes/events/murmeltier_model.tscn",
	"res://assets/models/guest.tscn",
]

var _out: String
var _camera: Camera3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://prop_view"
	DirAccess.make_dir_recursive_absolute(_out)
	_studio()
	for path: String in SCENES:
		await _shoot(path)
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
	sun.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.02
	add_child(_camera)
	_camera.current = true


func _shoot(path: String) -> void:
	var prop: Node = (load(path) as PackedScene).instantiate()
	prop.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(prop)
	var box: AABB = _bounds(prop)
	var centre: Vector3 = box.get_center()
	var size: float = maxf(box.size.length(), 0.1)
	var id: String = path.get_file().get_basename()
	# Props face the room along -Z (see Label3D notes): look at them from there.
	_camera.look_at_from_position(centre + Vector3(0.0, size * 0.2, -size * 1.3), centre, Vector3.UP)
	await _save(id + "_front")
	_camera.look_at_from_position(centre + Vector3(size * 0.9, size * 0.5, -size * 0.9), centre, Vector3.UP)
	await _save(id + "_angle")
	prop.queue_free()
	await get_tree().process_frame


func _bounds(root: Node) -> AABB:
	var box := AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree() or geometry is Label3D or geometry is GPUParticles3D or geometry is CPUParticles3D:
			continue
		var local: AABB = geometry.global_transform * geometry.get_aabb()
		if local.size.length() > 20.0:
			continue
		box = local if first else box.merge(local)
		first = false
	return box


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
