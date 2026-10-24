class_name ShaderWarmup
extends Node3D
## WebGL compiles a material's shader the first time it is drawn, and in the browser one shader can
## stall a frame for most of a second (#78: on a first visit the hut's first frame took 16 s, so the
## loading bar sat at its end). So the camera starts out seeing only this warmup: behind the title
## screen, every material in the world, every weapon, enemy and player model and every effect the
## special weapons build in code is drawn a few at a time, tiny and right in front of the camera, and
## `progress` tells the title how far it is. Then the camera gets the world back, whose shaders are
## all built by then. A returning browser has them in its shader cache and is done in a moment.

## How far it is (0..1); 1 once the world is back.
signal progress(share: float)
signal finished

const WEAPONS_DIR: String = "res://data/weapons"
const MATERIALS_DIR: String = "res://assets/materials"
## Enemy models (M6 part 4): skinned meshes compile a shader of their own.
const ENEMIES_DIR: String = "res://data/enemies"
const HIKER: PackedScene = preload("res://scenes/net/hiker.tscn")
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
	preload("res://scripts/weapons/behaviors/tanzboden.gd"),
	preload("res://scripts/perks/boeller_blast.gd"),
	preload("res://scripts/effects/damage_number.gd"),
	preload("res://scripts/effects/gredn_line.gd"),
	preload("res://scripts/effects/dengel_sparks.gd"),
	preload("res://scripts/effects/mandl_gold.gd"),
	preload("res://scripts/effects/scope_glint.gd"),
]

## The world this warms up for (main's World); its materials are collected from it.
@export var world: Node3D

## Done once per browser session: a restart reloads the scene, but the shaders stay built.
static var _done: bool = false

var _camera: Camera3D
var _world_mask: int = 0
var _items: Array[Node3D] = []
var _shown: int = 0
var _running: bool = false


func is_done() -> bool:
	return not _running


func _ready() -> void:
	# Runs while the start screen pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = get_viewport().get_camera_3d()
	if _done or _camera == null:
		_finish.call_deferred()
		return
	_running = true
	# From the very first frame the camera sees only the warmup, so that frame is cheap and the
	# title shows at once.
	_world_mask = _camera.cull_mask
	_camera.cull_mask = Constants.WARMUP_LAYER
	_collect()
	for i: int in _items.size():
		var item: Node3D = _items[i]
		# Side by side, well inside the near view, small enough to vanish under the start screen.
		item.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * Constants.WARMUP_SCALE),
				Vector3((i - _items.size() * 0.5) * Constants.WARMUP_SPACING, 0.0, -Constants.WARMUP_DISTANCE))
		item.visible = false
		add_child(item)
		_set_layer(item)


func _process(_delta: float) -> void:
	if not _running:
		return
	global_transform = _camera.global_transform
	# A few more each frame: those whose shader is built already cost next to nothing, a new one
	# stalls its frame, but the title gets drawn in between and shows how far it is.
	for i: int in Constants.WARMUP_PER_FRAME:
		if _shown >= _items.size():
			break
		_items[_shown].visible = true
		_shown += 1
	progress.emit(float(_shown) / float(maxi(_items.size(), 1)) * Constants.WARMUP_ITEMS_SHARE)
	if _shown >= _items.size():
		_running = false
		# One more frame with everything up, then the world (its last shaders, if any, come now).
		await get_tree().process_frame
		_finish()


## The game starts before the warmup is through (a co-op match): the rest compiles in one go.
func finish_now() -> void:
	if not _running:
		return
	_running = false
	_finish()


func _finish() -> void:
	if _camera and _world_mask != 0:
		_camera.cull_mask = _world_mask
		_world_mask = 0
		# The world's own first frame (anything left compiles there) before the menu comes in.
		for i: int in 2:
			await get_tree().process_frame
		# In the browser console, for load-time reports (#78).
		print("Shaders ready: %d items, %d ms after start" % [_items.size(), Time.get_ticks_msec()])
	_done = true
	progress.emit(1.0)
	finished.emit()
	queue_free()


func _collect() -> void:
	# Every material the world draws with, each on a little box. Rooms behind closed doors would
	# otherwise compile theirs the moment the door opens.
	var seen: Dictionary = {}
	if world:
		for node: Node in world.find_children("*", "", true, false):
			for material: Material in _materials_of(node):
				if material and not seen.has(material):
					seen[material] = true
					_items.append(_swatch(material))
	for file: String in DirAccess.get_files_at(MATERIALS_DIR):
		var material := load(MATERIALS_DIR.path_join(file.trim_suffix(".remap"))) as Material
		if material and not seen.has(material):
			seen[material] = true
			_items.append(_swatch(material))
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		var weapon := load(WEAPONS_DIR.path_join(file.trim_suffix(".remap"))) as WeaponData
		if weapon == null or weapon.viewmodel == null:
			continue
		var model: Node3D = _model_of(weapon)
		if model:
			# Dengelt weapons draw with forged copies of the materials (the same shaders, but drawn once).
			ForgedLook.dress(model, weapon)
			_items.append(model)
	for file: String in DirAccess.get_files_at(ENEMIES_DIR):
		var enemy := load(ENEMIES_DIR.path_join(file.trim_suffix(".remap"))) as EnemyData
		if enemy and enemy.model:
			var model := enemy.model.instantiate() as Node3D
			_items.append(model)
			# A hat shot off flies as a plain, unskinned copy (Huat obschiaßn).
			var hat := model.find_child("Hat", true, false) as MeshInstance3D
			if hat:
				var copy := MeshInstance3D.new()
				copy.mesh = hat.mesh
				_items.append(copy)
	# Co-op: the other players' hikers.
	_items.append(HIKER.instantiate() as Node3D)
	for script: Script in EFFECTS:
		var effect := Node3D.new()
		effect.set_script(script)
		if "silent" in effect:
			effect.set("silent", true)
		_items.append(effect)
		# Built in its _ready, so shown in full only once it is in the tree.
		effect.ready.connect(_show_all.bind(effect), CONNECT_ONE_SHOT)


func _materials_of(node: Node) -> Array[Material]:
	var out: Array[Material] = []
	var geometry := node as GeometryInstance3D
	if geometry and geometry.material_override:
		out.append(geometry.material_override)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		for i: int in mesh_instance.mesh.get_surface_count():
			out.append(mesh_instance.get_active_material(i))
	var csg := node as CSGPrimitive3D
	if csg and "material" in csg:
		out.append(csg.get("material"))
	return out


func _swatch(material: Material) -> Node3D:
	var swatch := MeshInstance3D.new()
	swatch.mesh = BoxMesh.new()
	swatch.material_override = material
	return swatch


func _set_layer(item: Node) -> void:
	var geometry := item as VisualInstance3D
	if geometry and not item is Light3D:
		geometry.layers = Constants.WARMUP_LAYER
	for child: Node in item.get_children():
		_set_layer(child)


## An effect built in its _ready, drawn in full: its own script stopped (nothing flies off or does
## damage), every part visible, particles emitting, and lights kept, but too dim to see, so the
## lit shader variants compile too.
func _show_all(effect: Node3D) -> void:
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in effect.find_children("*", "", true, false):
		if node is Node3D:
			(node as Node3D).visible = true
		if node is CPUParticles3D:
			node.process_mode = Node.PROCESS_MODE_ALWAYS
			(node as CPUParticles3D).emitting = true
		if node is Light3D:
			(node as Light3D).light_energy = 0.001
	_set_layer(effect)


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
