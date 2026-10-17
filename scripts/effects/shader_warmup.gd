class_name ShaderWarmup
extends Node3D
## WebGL compiles a material's shader the first time it is drawn, which in the browser stalls a
## frame for up to a second or two (play-test: opening the Hüttentruhe froze while its roll showed
## the specials for the first time). So at load, behind the start screen, every weapon's model and
## every effect the special weapons build in code (play-test 2026-10-18: the Brennlacke stalled on its
## first squirt) is drawn for a few frames, tiny and right in front of the camera, and then thrown
## away.

const WEAPONS_DIR: String = "res://data/weapons"
## Effects built in code: shots, piles, puddles, rings, notes and blasts.
const EFFECTS: Array[Script] = [
	preload("res://scripts/weapons/behaviors/schnaps_blob.gd"),
	preload("res://scripts/weapons/behaviors/brennlacke.gd"),
	preload("res://scripts/weapons/behaviors/knoedel.gd"),
	preload("res://scripts/weapons/behaviors/knoedel_pile.gd"),
	preload("res://scripts/weapons/behaviors/rodel_sled.gd"),
	preload("res://scripts/weapons/behaviors/handboeller_shell.gd"),
	preload("res://scripts/weapons/behaviors/alphorn_wave.gd"),
	preload("res://scripts/weapons/behaviors/harmonika_notes.gd"),
	preload("res://scripts/perks/boeller_blast.gd"),
]


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
	var effects: Array[Node3D] = []
	for script: Script in EFFECTS:
		var effect := Node3D.new()
		effect.set_script(script)
		if "silent" in effect:
			effect.set("silent", true)
		models.append(effect)
		effects.append(effect)
	for i: int in models.size():
		var model: Node3D = models[i]
		# Side by side, well inside the near view, small enough to vanish under the start screen.
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * Constants.WARMUP_SCALE),
				Vector3((i - models.size() * 0.5) * Constants.WARMUP_SPACING, 0.0, -Constants.WARMUP_DISTANCE))
		add_child(model)
	for effect: Node3D in effects:
		_show_all(effect)
	global_transform = camera.global_transform
	for i: int in Constants.WARMUP_FRAMES:
		await get_tree().process_frame
		global_transform = camera.global_transform
	queue_free()


## An effect built in its _ready, drawn in full: its own script stopped (nothing flies off or does
## damage), every part visible, particles emitting, and lights kept, but too dim to see, so the
## lit shader variants compile too.
func _show_all(effect: Node3D) -> void:
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	effect.visible = true
	for node: Node in effect.find_children("*", "", true, false):
		if node is Node3D:
			(node as Node3D).visible = true
		if node is CPUParticles3D:
			node.process_mode = Node.PROCESS_MODE_ALWAYS
			(node as CPUParticles3D).emitting = true
		if node is Light3D:
			(node as Light3D).light_energy = 0.001


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
