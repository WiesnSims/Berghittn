class_name ShaderWarmup
extends Node3D
## WebGL compiles a material's shader the first time it is drawn, which in the browser stalls a
## frame for up to a second or two (play-test: opening the Hüttentruhe froze while its roll showed
## the specials for the first time). So at load, behind the start screen, every weapon's model is
## drawn for a few frames, tiny and right in front of the camera, and then thrown away.

const WEAPONS_DIR: String = "res://data/weapons"


func _ready() -> void:
	# Runs while the start screen pauses the tree; the camera exists once the player has spawned.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var models: Array[Node3D] = []
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		var weapon := load(WEAPONS_DIR.path_join(file.trim_suffix(".remap"))) as WeaponData
		if weapon == null or weapon.viewmodel == null:
			continue
		var model: Node3D = _model_of(weapon)
		if model:
			models.append(model)
	for i: int in models.size():
		var model: Node3D = models[i]
		# Side by side, well inside the near view, small enough to vanish under the start screen.
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * Constants.WARMUP_SCALE),
				Vector3((i - models.size() * 0.5) * Constants.WARMUP_SPACING, 0.0, -Constants.WARMUP_DISTANCE))
		add_child(model)
	global_transform = camera.global_transform
	for i: int in Constants.WARMUP_FRAMES:
		await get_tree().process_frame
		global_transform = camera.global_transform
	queue_free()


## Only the meshes of the weapon's viewmodel: its script, and its lights (they would flash), stay behind.
func _model_of(weapon: WeaponData) -> Node3D:
	var viewmodel: Node = weapon.viewmodel.instantiate()
	var model := viewmodel.get_node_or_null("Model") as Node3D
	if model == null:
		viewmodel.free()
		return null
	viewmodel.remove_child(model)
	viewmodel.free()
	for light: Node in model.find_children("*", "Light3D", true, false):
		light.free()
	# A muzzle flash is hidden until a shot; it has to be drawn now to be compiled.
	for node: Node in model.find_children("*", "Node3D", true, false):
		(node as Node3D).visible = true
	return model
